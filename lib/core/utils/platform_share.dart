import 'package:flutter/services.dart';

class PlatformShare {
  static const MethodChannel _channel = MethodChannel(
    'com.hardcorez.forge/platform',
  );

  static Future<bool> hasStoragePermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasStoragePermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestStoragePermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestStoragePermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> shareText({
    required String text,
    String title = 'Bagikan Dokumen',
  }) async {
    try {
      await _channel.invokeMethod('shareText', {'text': text, 'title': title});
    } catch (_) {}
  }

  static Future<String?> extractDocxText(String path) async {
    try {
      final res = await _channel.invokeMethod<String>('extractDocxText', {
        'path': path,
      });
      return res;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> extractXlsxCells(String path) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'extractXlsxCells',
        {'path': path},
      );
      return res;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> extractPptxSlides(
    String path,
  ) async {
    try {
      final res = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'extractPptxSlides',
        {'path': path},
      );
      if (res == null) return null;
      return res.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> renderPdfPage({
    required String path,
    required int pageIndex,
    int width = 1080,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'renderPdfPage',
        {'path': path, 'pageIndex': pageIndex, 'width': width},
      );
      return res;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> burnSignaturesToPdf({
    String? sourcePath,
    required String targetPath,
    required List<Map<String, dynamic>> signatures,
    String? title,
    String? content,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('burnSignaturesToPdf', {
        'sourcePath': sourcePath,
        'targetPath': targetPath,
        'signatures': signatures,
        'title': title,
        'content': content,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> shareFile({
    required String path,
    String title = 'Bagikan Berkas',
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('shareFile', {
        'path': path,
        'title': title,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openFile({required String path}) async {
    try {
      final res = await _channel.invokeMethod<bool>('openFile', {'path': path});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
