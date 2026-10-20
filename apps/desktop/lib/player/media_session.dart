import 'package:flutter/services.dart';

import '../app/library.dart';
import 'player_controller.dart';

/// Windows media controls: the media flyout, keyboard media keys and the
/// lock screen show what plays; their buttons drive the player. Next and
/// previous change channel on live TV and seek in films and episodes.
class MediaSession {
  MediaSession(this.player, {MethodChannel? channel}) : _channel = channel ?? const MethodChannel('karadelik/media') {
    _channel.setMethodCallHandler(_onCall);
    player.addListener(_sync);
  }

  final PlayerController player;
  final MethodChannel _channel;
  String? _sent;

  void _sync() {
    final n = player.now;
    final state = <String, Object?>{
      'status': n == null ? 'closed' : (player.playing || player.opening ? 'playing' : 'paused'),
      'title': n?.title ?? '',
      'subtitle': switch (n) {
        null => '',
        final n when n.isCatchup => 'Geçmiş yayın',
        final n when n.isLive => 'Canlı yayın',
        final n when n.kind == Kind.series => 'Dizi',
        _ => 'Film',
      },
      'art': n?.item.logo ?? '',
    };
    // The player notifies often (position, buffering); Windows hears changes only.
    final key = state.values.join('|');
    if (key == _sent) return;
    _sent = key;
    _channel.invokeMethod<void>('update', state).catchError((_) {});
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'button') return;
    final live = player.now?.isLive ?? false;
    switch (call.arguments) {
      case 'play' when !player.playing:
      case 'pause' when player.playing:
        await player.togglePause();
      case 'stop':
        await player.stop();
      case 'next':
        live ? await player.zap(1) : await player.seekBy(const Duration(seconds: 30));
      case 'previous':
        live ? await player.zap(-1) : await player.seekBy(const Duration(seconds: -10));
    }
  }

  void dispose() {
    player.removeListener(_sync);
    _channel.setMethodCallHandler(null);
  }
}
