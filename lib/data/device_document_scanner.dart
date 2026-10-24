import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../core/models/document_model.dart';
import '../core/utils/platform_share.dart';

class DeviceDocumentScanner {
  static const List<String> supportedExtensions = [
    'docx', 'doc', 'odt', 'rtf', 'txt', 'md', 'gdoc',
    'xlsx', 'xls', 'csv', 'tsv', 'ods', 'gsheet',
    'pptx', 'ppt', 'odp', 'gslides',
    'pdf',
  ];

  /// Scans common storage locations on the device for office documents
  static Future<List<DocumentModel>> scanAllDeviceDocuments() async {
    final List<DocumentModel> results = [];
    final Set<String> foundPaths = {};

    final List<String> targetDirectories = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
      '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Documents',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents',
      '/storage/emulated/0/Telegram/Telegram Documents',
      '/storage/emulated/0',
    ];

    // Dynamically discover modern WhatsApp multi-account folders if accessible
    try {
      final waAccountsDir = Directory('/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/accounts');
      if (await waAccountsDir.exists()) {
        await for (final acc in waAccountsDir.list(recursive: false, followLinks: false)) {
          if (acc is Directory) {
            targetDirectories.add('${acc.path}/Media/WhatsApp Documents');
            targetDirectories.add('${acc.path}/Media/WhatsApp Documents/Private');
          }
        }
      }
    } catch (_) {}

    const Set<String> ignoredDirs = {
      'android', 'obb', 'cache', 'caches', 'thumbnails', 'dcim', 'alarms',
      'notifications', 'ringtones', 'podcasts'
    };

    for (final dirPath in targetDirectories) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(recursive: false, followLinks: false)) {
            if (entity is File) {
              await _processFile(entity, results, foundPaths);
            } else if (entity is Directory && dirPath != '/storage/emulated/0') {
              // Also inspect 1-level subdirectories of Download & Documents
              try {
                final dirName = entity.uri.pathSegments.isNotEmpty
                    ? entity.uri.pathSegments[entity.uri.pathSegments.length - 2].toLowerCase()
                    : '';
                if (dirName.isNotEmpty && !dirName.startsWith('.') && !ignoredDirs.contains(dirName)) {
                  await for (final subEntity in entity.list(recursive: false, followLinks: false)) {
                    if (subEntity is File) {
                      await _processFile(subEntity, results, foundPaths);
                    }
                  }
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
    }

    // Sort by last modified descending
    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results;
  }

  static Future<void> _processFile(File file, List<DocumentModel> results, Set<String> foundPaths) async {
    if (foundPaths.contains(file.path)) return;

    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : '';
    if (fileName.isEmpty || fileName.startsWith('.')) return;

    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return;

    final ext = fileName.substring(dotIndex + 1).toLowerCase();
    if (!supportedExtensions.contains(ext)) return;

    foundPaths.add(file.path);

    DocType docType;
    if (['xlsx', 'xls', 'csv', 'tsv', 'ods', 'gsheet'].contains(ext)) {
      docType = DocType.sheet;
    } else if (['pptx', 'ppt', 'odp', 'gslides'].contains(ext)) {
      docType = DocType.presentation;
    } else if (ext == 'pdf') {
      docType = DocType.pdf;
    } else {
      docType = DocType.word;
    }

    int size = 0;
    DateTime modified = DateTime.now();
    try {
      final stat = await file.stat();
      size = stat.size;
      modified = stat.modified;
    } catch (_) {}

    final rawTitle = fileName.substring(0, dotIndex).replaceAll('_', ' ');

    results.add(
      DocumentModel(
        id: 'device_${file.path.hashCode.abs()}',
        title: rawTitle,
        type: docType,
        updatedAt: modified,
        createdAt: modified,
        content: '', // Lazily loaded when opened
        sizeInBytes: size,
        filePath: file.path,
      ),
    );
  }

  /// Prepare and populate content when a device file is opened
  static Future<void> loadDeviceFileContent(DocumentModel doc) async {
    if (doc.filePath == null) return;
    final file = File(doc.filePath!);
    if (!await file.exists()) return;

    final ext = doc.filePath!.split('.').last.toLowerCase();

    // 1. Spreadsheet formats (CSV, TSV, XLSX, XLS, ODS, GSHEET)
    if (['csv', 'tsv'].contains(ext)) {
      try {
        final lines = await file.readAsLines();
        final Map<String, String> cells = {};
        int maxCols = 6;
        final delimiter = ext == 'tsv' ? '\t' : ',';
        for (int r = 0; r < lines.length; r++) {
          final cols = lines[r].split(delimiter);
          if (cols.length > maxCols) maxCols = cols.length;
          for (int c = 0; c < cols.length && c < 26; c++) {
            final colLetter = String.fromCharCode(65 + c);
            cells['$colLetter${r + 1}'] = cols[c].replaceAll('"', '').trim();
          }
        }
        doc.content = json.encode({
          'rows': math.max(lines.length + 5, 20),
          'cols': math.max(maxCols + 2, 8),
          'cells': cells,
        });
      } catch (_) {
        doc.content = json.encode({'rows': 20, 'cols': 8, 'cells': {}});
      }
    } else if (['xlsx', 'xls', 'ods'].contains(ext)) {
      try {
        final nativeData = await PlatformShare.extractXlsxCells(doc.filePath!);
        if (nativeData != null && (nativeData['cells'] as Map?)?.isNotEmpty == true) {
          doc.content = json.encode(nativeData);
        } else {
          doc.content = json.encode({
            'rows': 20,
            'cols': 8,
            'cells': {
              'A1': 'Berkas:',
              'B1': doc.title,
              'A2': 'Format:',
              'B2': ext.toUpperCase(),
              'A3': 'Lokasi:',
              'B3': doc.filePath,
            },
          });
        }
      } catch (_) {
        doc.content = json.encode({'rows': 20, 'cols': 8, 'cells': {}});
      }
    } else if (ext == 'gsheet') {
      try {
        final raw = await file.readAsString();
        final data = json.decode(raw);
        final url = data['url'] ?? data['doc_url'] ?? '';
        final docId = data['doc_id'] ?? data['resource_id'] ?? '';
        final email = data['email'] ?? '';
        doc.content = json.encode({
          'rows': 20,
          'cols': 8,
          'cells': {
            'A1': 'GOOGLE SHEETS CLOUD',
            'B1': doc.title,
            'A2': 'Tautan Cloud:',
            'B2': url.toString(),
            'A3': 'ID Dokumen:',
            'B3': docId.toString(),
            'A4': 'Akun Terhubung:',
            'B4': email.toString(),
            'A6': 'Petunjuk:',
            'B6': 'Berkas ini tersinkronisasi dengan akun Google Drive Anda.',
          },
        });
      } catch (_) {
        doc.content = json.encode({'rows': 20, 'cols': 8, 'cells': {}});
      }
    }
    // 2. Presentation formats (PPTX, PPT, ODP, GSLIDES)
    else if (['pptx', 'ppt', 'odp'].contains(ext)) {
      try {
        final slides = await PlatformShare.extractPptxSlides(doc.filePath!);
        if (slides != null && slides.isNotEmpty) {
          doc.content = json.encode({'slides': slides});
        } else {
          doc.content = json.encode({
            'slides': [
              {
                'title': doc.title,
                'subtitle': 'Presentasi ${ext.toUpperCase()}',
                'content': '• Lokasi berkas:\n${doc.filePath}\n• Ukuran: ${doc.sizeInBytes} bytes\n• Siap diedit dan dipresentasikan',
                'themeIndex': 0,
              }
            ]
          });
        }
      } catch (_) {
        doc.content = json.encode({'slides': []});
      }
    } else if (ext == 'gslides') {
      try {
        final raw = await file.readAsString();
        final data = json.decode(raw);
        final url = data['url'] ?? data['doc_url'] ?? '';
        final email = data['email'] ?? '';
        doc.content = json.encode({
          'slides': [
            {
              'title': doc.title,
              'subtitle': 'Google Slides Cloud Document',
              'content': '• Tautan Presentasi:\n$url\n• Akun Terhubung: $email',
              'themeIndex': 0,
            },
            {
              'title': 'Presentasi Offline',
              'subtitle': 'Kompatibilitas Penuh',
              'content': '• Berkas pointer cloud Google Drive\n• Anda dapat mengunduh format .pptx untuk presentasi offline kapan pun',
              'themeIndex': 1,
            }
          ]
        });
      } catch (_) {
        doc.content = json.encode({'slides': []});
      }
    }
    // 3. Word & Text formats (DOCX, ODT, GDOC, RTF, TXT, MD, DOC)
    else if (['docx', 'odt'].contains(ext)) {
      try {
        final text = await PlatformShare.extractDocxText(doc.filePath!);
        if (text != null && text.trim().isNotEmpty) {
          doc.content = json.encode({'text': text, 'fontSize': 15.0});
        } else {
          doc.content = json.encode({
            'text': 'Berkas ${doc.title} (${ext.toUpperCase()})\nLokasi: ${doc.filePath}',
            'fontSize': 15.0,
          });
        }
      } catch (_) {
        doc.content = json.encode({
          'text': 'Berkas ${doc.title} (${ext.toUpperCase()})\nLokasi: ${doc.filePath}',
          'fontSize': 15.0,
        });
      }
    } else if (ext == 'gdoc') {
      try {
        final raw = await file.readAsString();
        final data = json.decode(raw);
        final url = data['url'] ?? data['doc_url'] ?? '';
        final docId = data['doc_id'] ?? data['resource_id'] ?? '';
        final email = data['email'] ?? '';
        final title = data['title'] ?? doc.title;
        doc.content = json.encode({
          'text': '📄 GOOGLE DOCS CLOUD DOCUMENT\n\n'
                  'Judul: $title\n'
                  'Akun Pemilik: ${email.isNotEmpty ? email : 'Terkoneksi'}\n'
                  'ID Berkas: $docId\n\n'
                  '🔗 Tautan Akses Cloud:\n$url\n\n'
                  '────────────────────────────────────\n'
                  'Petunjuk Integrasi:\n'
                  'Berkas .gdoc adalah penunjuk (pointer) resmi dokumen Google Docs di penyimpanan perangkat.\n'
                  'Aplikasi HardcorezForge dapat membaca metadata ini secara langsung, serta mendukung file unduhan Google Docs dalam format .docx atau .pdf untuk diedit secara offline kapan pun tanpa jaringan internet.',
          'fontSize': 15.0,
        });
      } catch (_) {
        doc.content = json.encode({
          'text': 'Dokumen Google Docs: ${doc.title}\nLokasi: ${doc.filePath}',
          'fontSize': 15.0,
        });
      }
    } else if (ext == 'rtf') {
      try {
        final raw = await file.readAsString();
        // Simple regex strip of RTF control words
        final cleanText = raw
            .replaceAll(RegExp(r'\\par[d]?'), '\n')
            .replaceAll(RegExp(r'\\[a-zA-Z0-9]+[ ]?'), '')
            .replaceAll(RegExp(r'[{}]'), '')
            .trim();
        doc.content = json.encode({'text': cleanText, 'fontSize': 15.0});
      } catch (_) {
        doc.content = json.encode({'text': 'Berkas RTF: ${doc.title}', 'fontSize': 15.0});
      }
    } else if (ext == 'pdf') {
      // Berkas PDF di-render secara dinamis dari file via native PdfRenderer
      if (doc.content.isEmpty) {
        doc.content = json.encode({
          'text': doc.title,
          'signatures': [],
        });
      }
    } else {
      // Plain text, Markdown, or raw fallback
      try {
        final text = await file.readAsString();
        doc.content = json.encode({'text': text, 'fontSize': 15.0});
      } catch (_) {
        doc.content = json.encode({
          'text': 'Berkas ${doc.title} (${doc.type.extension})\nLokasi: ${doc.filePath}',
          'fontSize': 15.0,
        });
      }
    }
  }
}

