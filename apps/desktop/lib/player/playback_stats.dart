import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../src/rust/api/library.dart' show SourceHealth;

/// What mpv reports about the stream playing, sampled while the statistics
/// panel is open. Unknown values stay null (mpv leaves many unset until
/// the first keyframe, some for good on certain streams).
class PlaybackStats {
  const PlaybackStats({
    this.videoCodec,
    this.width,
    this.height,
    this.fps,
    this.hwdec,
    this.videoBitrate,
    this.audioCodec,
    this.audioBitrate,
    this.channels,
    this.cacheSeconds,
    this.inputRate,
    this.droppedFrames = 0,
    this.decoderDrops = 0,
  });

  final String? videoCodec;
  final int? width;
  final int? height;
  final double? fps;

  /// mpv's hwdec-current: "d3d11va", "videotoolbox", … or "no" (software).
  final String? hwdec;

  /// Bits per second.
  final int? videoBitrate;
  final String? audioCodec;
  final int? audioBitrate;
  final int? channels;

  /// Seconds of stream buffered ahead.
  final double? cacheSeconds;

  /// Network read speed, bytes per second.
  final int? inputRate;

  /// Frames dropped by the output (late) and by the decoder (behind).
  final int droppedFrames;
  final int decoderDrops;

  static const empty = PlaybackStats();
}

/// One line of "why is it stuttering", worst first in [diagnose].
enum Finding {
  sourceDown,
  accountExpired,
  connectionLimit,
  slowNetwork,
  cacheLow,
  framesDropping,
  softwareDecoding,
  reconnected,
  healthy,
}

/// Reads a sample (and the one before it) the way support would: is the
/// provider answering, is the network keeping up with the bitrate, is the
/// decoder keeping up with the picture.
List<Finding> diagnose(
  PlaybackStats s, {
  PlaybackStats? previous,
  bool live = true,
  int reconnects = 0,
  SourceHealth? health,
  int? nowUnix,
}) {
  final out = <Finding>[];
  if (health != null) {
    if (!health.ok) out.add(Finding.sourceDown);
    final now = nowUnix ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (health.expiresAt case final end? when end > 0 && end < now) out.add(Finding.accountExpired);
    final max = health.maxConnections, active = health.activeConnections;
    if (max != null && active != null && max > 0 && active >= max) out.add(Finding.connectionLimit);
  }
  final cache = s.cacheSeconds, rate = s.inputRate, bitrate = s.videoBitrate;
  final starving = cache != null && cache < 3;
  if (live && starving && rate != null && bitrate != null && bitrate > 0 && rate * 8 < bitrate * 0.9) {
    out.add(Finding.slowNetwork);
  } else if (cache != null && cache < 1) {
    out.add(Finding.cacheLow);
  }
  if (previous != null) {
    final dropped = (s.droppedFrames + s.decoderDrops) - (previous.droppedFrames + previous.decoderDrops);
    if (dropped >= 5) {
      out.add(Finding.framesDropping);
      if (s.hwdec == 'no') out.add(Finding.softwareDecoding);
    }
  }
  if (reconnects > 0) out.add(Finding.reconnected);
  if (out.isEmpty) out.add(Finding.healthy);
  return out;
}

/// One decimal in the UI language: "4,2" in Turkish, "4.2" in English.
String oneDecimal(double v) => NumberFormat('0.0', languageCode).format(v);

/// "4,2 Mbit/s", "640 kbit/s".
String bitrateText(int bitsPerSecond) {
  if (bitsPerSecond >= 1000000) return '${oneDecimal(bitsPerSecond / 1000000)} Mbit/s';
  return '${(bitsPerSecond / 1000).round()} kbit/s';
}
