import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Maximum concurrent downloads
int _maxDownloads = 10;

/// Maximum concurrent decodes (1 for web, 3 for native)
int _maxDecodes = kIsWeb ? 1 : 3;

Map<String, _PhotolineLoaderData> _map = {};
final _PhotolineLoaderData _emptyData = _PhotolineLoaderData();

// Download queue
final Queue<_PhotolineLoaderQueueItem> _downloadQueue = Queue();
int _downloadCount = 0;

// Decode queue
final Queue<_PhotolineLoaderQueueItem> _decodeQueue = Queue();
int _decodeCount = 0;

class _PhotolineLoaderQueueItem {
  _PhotolineLoaderQueueItem(this.uri, this.data);

  final String uri;
  final _PhotolineLoaderData data;
}

class PhotolineLoaderNotifier extends ChangeNotifier {
  PhotolineLoaderNotifier._();

  static PhotolineLoaderNotifier? _instance;

  static PhotolineLoaderNotifier get instance => _instance ??= PhotolineLoaderNotifier._();

  String uri = '';

  set notify(String? uri) {
    if (uri == null || uri == this.uri) return;
    this.uri = uri;
    notifyListeners();
  }
}

class _PhotolineLoaderData {
  ui.Image? image;
  Uint8List? bytes;
  bool downloading = false;
  bool decoding = false;
  bool queued = false;
  int attempt = -1;
}

abstract class PhotolineLoader {
  /// Set maximum concurrent downloads (default: 10)
  static set maxDownloads(int value) => _maxDownloads = value;

  /// Set maximum concurrent decodes (default: 1 for web, 3 for native)
  static set maxDecodes(int value) => _maxDecodes = value;

  /// Get current download queue size
  static int get downloadQueueSize => _downloadQueue.length;

  /// Get current decode queue size
  static int get decodeQueueSize => _decodeQueue.length;

  /// Get current active downloads count
  static int get activeDownloads => _downloadCount;

  /// Get current active decodes count
  static int get activeDecodes => _decodeCount;

  String? get uri;

  ui.Image? blur;

  int get width;

  int get height;

  Color? get stripe;

  Color? color;

  _PhotolineLoaderData get _data {
    final u = uri;
    if (u == null) return _emptyData;
    final existing = _map[u];
    return existing ?? _emptyData;
  }

  ui.Image? get image => _data.image;

  double _opacity = -1;

  double get opacity => _opacity < 0 ? (_opacity = image != null ? 1.0 : 0.0) : _opacity;

  set opacity(double value) => _opacity = value;

  bool get imageLoaded => _data.image != null;

  /// Called by Photoline render to signal that loading should start.
  /// Automatically handles deduplication by URI.
  void spawn() {
    final u = uri;
    if (u == null || u.isEmpty) return;

    // Check if already in map
    final existing = _map[u];
    if (existing != null) {
      // Already loaded or in progress
      if (existing.image != null || existing.queued) return;
    }

    // Create new entry and add to download queue
    final data = existing ?? _PhotolineLoaderData()
      ..queued = true;
    _map[u] = data;
    _downloadQueue.add(_PhotolineLoaderQueueItem(u, data));
    _processDownloadQueue();
  }

  static void _processDownloadQueue() {
    while (_downloadCount < _maxDownloads && _downloadQueue.isNotEmpty) {
      final item = _downloadQueue.removeFirst();
      unawaited(_download(item));
    }
  }

  static Future<void> _download(_PhotolineLoaderQueueItem item) async {
    final data = item.data..downloading = true;
    data.attempt++;
    _downloadCount++;

    if (data.attempt > 1) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      data.bytes = await _getBytes(item.uri);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️PhotolineLoader download(${item.uri}): $e');
      }
    }

    _downloadCount--;
    data.downloading = false;

    // If downloaded successfully, add to decode queue
    if (data.bytes != null) {
      _decodeQueue.add(item);
      _processDecodeQueue();
    } else {
      // Failed - could retry by re-adding to download queue
      data.queued = false;
    }

    // Continue processing download queue
    _processDownloadQueue();
  }

  static void _processDecodeQueue() {
    while (_decodeCount < _maxDecodes && _decodeQueue.isNotEmpty) {
      final item = _decodeQueue.removeFirst();
      unawaited(_decode(item));
    }
  }

  static Future<void> _decode(_PhotolineLoaderQueueItem item) async {
    final data = item.data;
    final bytes = data.bytes;
    if (bytes == null) return;

    data.decoding = true;
    _decodeCount++;

    ui.Image? img;

    try {
      img = await _bytesToImage(bytes);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️PhotolineLoader decode(${item.uri}): $e');
      }
    }

    if (img != null) {
      data.image = img;
      PhotolineLoaderNotifier.instance.notify = item.uri;
    }

    _decodeCount--;
    data
      ..decoding = false
      ..queued = false;

    // Continue processing decode queue
    _processDecodeQueue();
  }
}

Future<Uint8List?> _getBytes(String uri) async {
  http.Response? response;

  try {
    response = await http
        .get(Uri.parse(uri))
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => http.Response('Error', 408),
        );
  } catch (e) {
    if (kDebugMode) {
      print('⚠️PhotolineLoader: $e');
    }
  }

  if (response == null || response.statusCode != 200) return null;

  return response.bodyBytes;
}

Future<ui.Image?> _bytesToImage(Uint8List bytes) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);

  buffer.dispose();

  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frameInfo = await codec.getNextFrame();

  return frameInfo.image;
}
