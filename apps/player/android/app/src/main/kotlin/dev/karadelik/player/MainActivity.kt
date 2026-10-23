package dev.karadelik.player

import android.app.ActivityManager
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "karadelik/keystore").setMethodCallHandler { call, result ->
            when (call.method) {
                "secretsKey" ->
                    try {
                        val (key, fresh) = SecretsKey.get(applicationContext)
                        result.success(mapOf("key" to key, "fresh" to fresh))
                    } catch (e: Exception) {
                        result.error("keystore", e.message, null)
                    }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "karadelik/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "isTv" -> result.success(isTv())
                // Low-RAM phones skip the glass blur (lib/mobile/glass.dart).
                "isLowRam" -> result.success((getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager)?.isLowRamDevice ?: false)
                else -> result.notImplemented()
            }
        }
    }

    /** Android TV / Google TV: the remote layout (lib/shell/tv.dart). */
    private fun isTv(): Boolean {
        val uiMode = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        return uiMode?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
    }
}

/**
 * The 32-byte key that seals saved passwords in the app's private folder
 * (core/crates/kp-core/src/secret.rs). Random, stored wrapped by an AES key
 * that never leaves the Android Keystore. "fresh" says a new key was made, so
 * a sealed file left from an old key (a restore, a cleared Keystore) can no
 * longer open and is to be discarded.
 */
object SecretsKey {
    private const val ALIAS = "karadelik.secrets"
    private const val PREFS = "karadelik.keystore"
    private const val WRAPPED = "secrets_key"

    @Synchronized
    fun get(context: Context): Pair<ByteArray, Boolean> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getString(WRAPPED, null)?.let { stored ->
            try {
                return unwrap(Base64.decode(stored, Base64.NO_WRAP)) to false
            } catch (_: Exception) {
                // The Keystore key is gone or changed: start over below.
            }
        }
        val key = ByteArray(32).also { SecureRandom().nextBytes(it) }
        prefs.edit().putString(WRAPPED, Base64.encodeToString(wrap(key), Base64.NO_WRAP)).commit()
        return key to true
    }

    private fun keystoreKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    /** IV (12 bytes) then the AES-GCM ciphertext. */
    private fun wrap(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, keystoreKey())
        return cipher.iv + cipher.doFinal(plain)
    }

    private fun unwrap(data: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, keystoreKey(), GCMParameterSpec(128, data, 0, 12))
        return cipher.doFinal(data, 12, data.size - 12)
    }
}
