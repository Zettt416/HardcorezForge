import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/document_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/platform_share.dart';
import '../../data/device_document_scanner.dart';
import '../../data/document_repository.dart';
import '../../main.dart';
import '../pdf_tools/pdf_reader_screen.dart';
import '../presentation/presentation_screen.dart';
import '../spreadsheet/spreadsheet_screen.dart';
import '../word_editor/word_editor_screen.dart';
import '../markdown/markdown_reader_screen.dart';
import 'app_guide_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final DocumentRepository _repo = DocumentRepository.instance;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isScanningDevice = false;
  bool _hasStoragePermission = true;
  String _searchQuery = '';
  String _selectedFilter =
      'all'; // all, device, word, sheet, presentation, pdf, starred
  DateTime? _lastBackPressTime;
  bool _showGuideOverlay = false;

  List<DocumentModel> _deviceDocs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDocs();
    _checkGuideStatus();
  }

  Future<void> _checkGuideStatus() async {
    final shouldShow = await AppGuideOverlay.shouldShowGuide();
    if (mounted && shouldShow) {
      setState(() => _showGuideOverlay = true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndScan(silent: true);
    }
  }

  Future<void> _loadDocs() async {
    await _repo.init();
    if (mounted) {
      setState(() => _isLoading = false);
    }
    await _checkPermissionAndScan(silent: true);
  }

  Future<void> _checkPermissionAndScan({bool silent = false}) async {
    final hasPerm = await PlatformShare.hasStoragePermission();
    if (mounted) {
      setState(() => _hasStoragePermission = hasPerm);
    }
    if (hasPerm) {
      await _scanDeviceFiles(silent: silent);
    }
  }

  Future<void> _requestPermission() async {
    await PlatformShare.requestStoragePermission();
    // After returning from system settings or dialog, re-check
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkPermissionAndScan();
  }

  Future<void> _scanDeviceFiles({bool silent = false}) async {
    if (_isScanningDevice) return;
    setState(() => _isScanningDevice = true);
    try {
      final scanned = await DeviceDocumentScanner.scanAllDeviceDocuments();
      if (mounted) {
        setState(() {
          _deviceDocs = scanned;
          _isScanningDevice = false;
        });
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                scanned.isEmpty
                    ? 'Tidak ditemukan berkas dokumen baru di HP'
                    : 'Ditemukan ${scanned.length} dokumen di HP Anda',
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isScanningDevice = false);
    }
  }

  List<DocumentModel> get _allCombinedDocs {
    if (_selectedFilter == 'device') {
      return _deviceDocs;
    }

    // Merge repo docs with device docs, avoiding path duplicates
    final Set<String> existingPaths = _repo.documents
        .where((d) => d.filePath != null)
        .map((d) => d.filePath!)
        .toSet();

    final List<DocumentModel> combined = [..._repo.documents];
    for (final devDoc in _deviceDocs) {
      if (devDoc.filePath != null && !existingPaths.contains(devDoc.filePath)) {
        combined.add(devDoc);
      }
    }
    // Sort all documents by updatedAt descending so newest/active files are at the top
    combined.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return combined;
  }

  List<DocumentModel> get _filteredDocs {
    return _allCombinedDocs.where((doc) {
      final ext = doc.filePath?.split('.').last.toLowerCase() ?? '';
      final isMd = ext == 'md' || doc.title.toLowerCase().endsWith('.md');

      // Filter Category
      if (_selectedFilter == 'device' && doc.filePath == null) return false;
      if (_selectedFilter == 'md' && !isMd) return false;
      if (_selectedFilter == 'word' && (doc.type != DocType.word || isMd)) {
        return false;
      }
      if (_selectedFilter == 'sheet' && doc.type != DocType.sheet) return false;
      if (_selectedFilter == 'presentation' &&
          doc.type != DocType.presentation) {
        return false;
      }
      if (_selectedFilter == 'pdf' && doc.type != DocType.pdf) return false;
      if (_selectedFilter == 'starred' && !doc.isStarred) return false;

      // Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = doc.title.toLowerCase().contains(query);
        final matchExt = (isMd ? 'md' : doc.type.extension.toLowerCase())
            .contains(query);
        return matchTitle || matchExt;
      }
      return true;
    }).toList();
  }

  void _openDocument(DocumentModel doc) async {
    if (doc.filePath != null && doc.content.isEmpty) {
      await DeviceDocumentScanner.loadDeviceFileContent(doc);
    }

    if (!mounted) return;

    final ext = doc.filePath?.split('.').last.toLowerCase() ?? '';
    Widget targetScreen;
    if (ext == 'md' || doc.title.toLowerCase().endsWith('.md')) {
      targetScreen = MarkdownReaderScreen(document: doc);
    } else {
      switch (doc.type) {
        case DocType.sheet:
          targetScreen = SpreadsheetScreen(document: doc);
          break;
        case DocType.presentation:
          targetScreen = PresentationScreen(document: doc);
          break;
        case DocType.pdf:
          targetScreen = PdfReaderScreen(document: doc);
          break;
        case DocType.word:
          targetScreen = WordEditorScreen(document: doc);
          break;
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => targetScreen),
    );
    setState(() {}); // refresh after edit
  }

  void _createNewDocument(DocType type) async {
    final now = DateTime.now();
    String defaultTitle;
    switch (type) {
      case DocType.sheet:
        defaultTitle = 'Lembar Kerja Baru';
        break;
      case DocType.presentation:
        defaultTitle = 'Presentasi Baru';
        break;
      case DocType.pdf:
        defaultTitle = 'Dokumen PDF Baru';
        break;
      case DocType.word:
        defaultTitle = 'Dokumen Baru';
        break;
    }

    final newDoc = DocumentModel(
      id: 'doc_${now.millisecondsSinceEpoch}',
      title: defaultTitle,
      type: type,
      updatedAt: now,
      createdAt: now,
      content: '',
      sizeInBytes: 0,
    );

    await _repo.saveDocument(newDoc);
    setState(() {});
    _openDocument(newDoc);
  }

  void _createNewMarkdownDoc() async {
    final now = DateTime.now();
    final newDoc = DocumentModel(
      id: 'doc_${now.millisecondsSinceEpoch}',
      title: 'Catatan Markdown Baru.md',
      type: DocType.word,
      updatedAt: now,
      createdAt: now,
      content: '# Judul Catatan\n\nTulis isi catatan markdown di sini...\n',
      sizeInBytes: 0,
    );

    await _repo.saveDocument(newDoc);
    if (!mounted) return;
    setState(() {});
    _openDocument(newDoc);
  }

  void _showRenameDialog(DocumentModel doc) {
    final controller = TextEditingController(text: doc.title);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        title: const Text(
          'Ganti Nama Dokumen',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nama baru dokumen',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                await _repo.renameDocument(doc.id, newTitle);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  setState(() {});
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _duplicateDocument(DocumentModel doc) async {
    final duplicated = await _repo.duplicateDocument(doc.id);
    if (duplicated != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Salinan "${duplicated.title}" berhasil dibuat!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() {});
    }
  }

  void _confirmDeleteDocument(DocumentModel doc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDeviceFile = doc.filePath != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Hapus Dokumen?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isDeviceFile
              ? 'Apakah Anda yakin ingin menghapus "${doc.title}"? Berkas fisik di penyimpanan perangkat juga akan dihapus.'
              : 'Apakah Anda yakin ingin menghapus "${doc.title}"? Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (doc.filePath != null) {
                  final file = File(doc.filePath!);
                  if (await file.exists()) {
                    await file.delete();
                  }
                  _deviceDocs.removeWhere(
                    (d) => d.id == doc.id || d.filePath == doc.filePath,
                  );
                }
              } catch (_) {}

              await _repo.deleteDocument(doc.id);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Dokumen "${doc.title}" berhasil dihapus'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _shareDocument(DocumentModel doc) {
    String textContent = 'Dokumen: ${doc.title} (${doc.type.extension})\n\n';
    if (doc.type == DocType.word) {
      try {
        final data = json.decode(doc.content);
        textContent += data['text'] ?? '';
      } catch (_) {
        textContent += doc.content;
      }
    } else {
      textContent += 'Dibuka dari HardcorezForge Mobile Office.';
    }
    PlatformShare.shareText(text: textContent, title: 'Bagikan ${doc.title}');
  }

  Future<void> _pickFileFromDevice() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'docx',
          'doc',
          'gdoc',
          'odt',
          'rtf',
          'txt',
          'md',
          'xlsx',
          'xls',
          'gsheet',
          'ods',
          'csv',
          'tsv',
          'pptx',
          'ppt',
          'gslides',
          'odp',
          'pdf',
        ],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final extension = fileName.split('.').last.toLowerCase();

        DocType docType;
        if ([
          'xlsx',
          'xls',
          'csv',
          'tsv',
          'ods',
          'gsheet',
        ].contains(extension)) {
          docType = DocType.sheet;
        } else if (['pptx', 'ppt', 'odp', 'gslides'].contains(extension)) {
          docType = DocType.presentation;
        } else if (extension == 'pdf') {
          docType = DocType.pdf;
        } else {
          docType = DocType.word;
        }

        final now = DateTime.now();
        final importedDoc = DocumentModel(
          id: 'imported_${now.millisecondsSinceEpoch}',
          title: fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
          type: docType,
          updatedAt: now,
          createdAt: now,
          content: '',
          sizeInBytes: result.files.single.size,
          filePath: filePath,
        );

        await DeviceDocumentScanner.loadDeviceFileContent(importedDoc);
        await _repo.saveDocument(importedDoc);
        setState(() {});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berkas "$fileName" berhasil diimpor!'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          _openDocument(importedDoc);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batal atau gagal memilih berkas: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickPdfToSign() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final now = DateTime.now();

        final pdfDoc = DocumentModel(
          id: 'pdf_${now.millisecondsSinceEpoch}',
          title: fileName.replaceAll(
            RegExp(r'\.pdf$', caseSensitive: false),
            '',
          ),
          type: DocType.pdf,
          updatedAt: now,
          createdAt: now,
          content: '',
          sizeInBytes: result.files.single.size,
          filePath: filePath,
        );

        await _repo.saveDocument(pdfDoc);
        if (mounted) {
          setState(() {});
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfReaderScreen(document: pdfDoc),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batal atau gagal memilih berkas PDF: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Baru saja';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mnt lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} hari lalu';
    } else {
      return DateFormat('dd MMM yyyy').format(dt);
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docs = _filteredDocs;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Jika overlay panduan sedang aktif, tombol back menutup panduan terlebih dahulu
        if (_showGuideOverlay) {
          setState(() => _showGuideOverlay = false);
          AppGuideOverlay.markGuideSeen();
          return;
        }

        // Jika pencarian sedang aktif terisi teks, tombol back pertama membersihkan pencarian
        if (_searchQuery.isNotEmpty) {
          setState(() {
            _searchController.clear();
            _searchQuery = '';
          });
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Tekan sekali lagi untuk keluar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          SystemNavigator.pop();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
            appBar: AppBar(
              backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 16,
              title: Row(
                children: [
                  // Clean Logo without box background
                  Image.asset(
                    'assets/images/app_logo.png',
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  // Title
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Hardcorez',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.4,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const TextSpan(
                              text: 'Forge',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.4,
                                color: AppTheme.brandCrimson,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                // Theme Toggle Button (Dark / Light Mode)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        final current = HardcorezForgeApp.themeNotifier.value;
                        HardcorezForgeApp.themeNotifier.value =
                            current == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkBorder
                                : AppTheme.lightBorder,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_outlined,
                          size: 19,
                          color: isDark
                              ? Colors.amber
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
                // Re-Scan Device Files Button
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _checkPermissionAndScan(silent: false),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkBorder
                                : AppTheme.lightBorder,
                            width: 1,
                          ),
                        ),
                        child: _isScanningDevice
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.lightTextPrimary,
                              ),
                      ),
                    ),
                  ),
                ),
                // Info Button
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Material(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'HardcorezForge',
                          applicationVersion: '1.0.4',
                          applicationIcon: Image.asset(
                            'assets/images/app_logo.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.contain,
                          ),
                          children: [
                            const Text(
                              'All-in-One Mobile Office Suite mandiri: Word, Excel Spreadsheet dengan Formula Engine, PowerPoint Slide Deck, PDF Document Reader, dan Vector Signature/Stamp Engine tanpa iklan.',
                              style: TextStyle(fontSize: 13, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() => _showGuideOverlay = true);
                              },
                              icon: const Icon(
                                Icons.help_outline_rounded,
                                size: 18,
                              ),
                              label: const Text('Buka Panduan Aplikasi'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.brandCrimson,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkBorder
                                : AppTheme.lightBorder,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 19,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await _repo.init();
                      await _scanDeviceFiles();
                    },
                    child: Column(
                      children: [
                        // Quick Tools Module Carousel (Horizontal Slider)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                          child: Row(
                            children: [
                              _buildQuickModuleCard(
                                icon: Icons.article_rounded,
                                color: AppTheme.docBlue,
                                bgColor: isDark
                                    ? const Color(0xFF131D33)
                                    : AppTheme.docBlueLight,
                                label: 'Word',
                                tag: '.docx',
                                onTap: () => _createNewDocument(DocType.word),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickModuleCard(
                                icon: Icons.table_chart_rounded,
                                color: AppTheme.sheetGreen,
                                bgColor: isDark
                                    ? const Color(0xFF0D251D)
                                    : AppTheme.sheetGreenLight,
                                label: 'Excel',
                                tag: '.xlsx',
                                onTap: () => _createNewDocument(DocType.sheet),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickModuleCard(
                                icon: Icons.slideshow_rounded,
                                color: AppTheme.pptOrange,
                                bgColor: isDark
                                    ? const Color(0xFF281810)
                                    : AppTheme.pptOrangeLight,
                                label: 'PPT',
                                tag: '.pptx',
                                onTap: () =>
                                    _createNewDocument(DocType.presentation),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickModuleCard(
                                icon: Icons.description_rounded,
                                color: const Color(0xFF0284C7),
                                bgColor: isDark
                                    ? const Color(0xFF0C243B)
                                    : const Color(0xFFE0F2FE),
                                label: 'Markdown',
                                tag: '.md',
                                onTap: _createNewMarkdownDoc,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickModuleCard(
                                icon: Icons.draw_rounded,
                                color: const Color(0xFF7C3AED),
                                bgColor: isDark
                                    ? const Color(0xFF1F1433)
                                    : const Color(0xFFF5F3FF),
                                label: 'Tanda Tangan',
                                tag: 'PDF Sign',
                                onTap: _pickPdfToSign,
                              ),
                            ],
                          ),
                        ),

                        // Search Bar Capsule & Import Button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF111726)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark
                                          ? AppTheme.darkBorder
                                          : const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.search_rounded,
                                        size: 20,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.lightTextSecondary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          decoration: InputDecoration(
                                            hintText:
                                                'Cari berkas dokumen, rumus, atau tipe',
                                            hintStyle: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? const Color(0xFF64748B)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: isDark
                                                ? AppTheme.darkTextPrimary
                                                : AppTheme.lightTextPrimary,
                                          ),
                                          onChanged: (val) {
                                            setState(() => _searchQuery = val);
                                          },
                                        ),
                                      ),
                                      if (_searchQuery.isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                          child: Icon(
                                            Icons.cancel_rounded,
                                            size: 18,
                                            color: isDark
                                                ? const Color(0xFF64748B)
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: isDark
                                    ? AppTheme.darkSurface
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _pickFileFromDevice,
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? AppTheme.darkBorder
                                            : const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: Tooltip(
                                      message: 'Impor Berkas dari HP',
                                      child: Icon(
                                        Icons.folder_open_rounded,
                                        size: 21,
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Category Filter Pills (Zero Layout Shifts)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _buildSegmentedTab(
                                'all',
                                'Semua',
                                Icons.grid_view_rounded,
                              ),
                              _buildSegmentedTab(
                                'device',
                                'Berkas HP (${_deviceDocs.length})',
                                Icons.phone_android_rounded,
                                color: const Color(0xFF0284C7),
                              ),
                              _buildSegmentedTab(
                                'word',
                                'Word',
                                Icons.article_rounded,
                                color: AppTheme.docBlue,
                              ),
                              _buildSegmentedTab(
                                'md',
                                'Markdown',
                                Icons.description_rounded,
                                color: const Color(0xFF0284C7),
                              ),
                              _buildSegmentedTab(
                                'sheet',
                                'Excel',
                                Icons.table_chart_rounded,
                                color: AppTheme.sheetGreen,
                              ),
                              _buildSegmentedTab(
                                'presentation',
                                'PPT',
                                Icons.slideshow_rounded,
                                color: AppTheme.pptOrange,
                              ),
                              _buildSegmentedTab(
                                'pdf',
                                'PDF',
                                Icons.picture_as_pdf_rounded,
                                color: AppTheme.pdfRed,
                              ),
                              _buildSegmentedTab(
                                'starred',
                                'Berbintang',
                                Icons.star_rounded,
                                color: Colors.amber,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Storage Permission Warning Banner (if not granted)
                        if (!_hasStoragePermission)
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.folder_shared_rounded,
                                    color: AppTheme.primaryBlue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Izin Akses Berkas HP Belum Aktif',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Beri izin agar dokumen Word, Excel, PPT, & PDF di HP terbaca otomatis.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppTheme.darkTextSecondary
                                              : AppTheme.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: _requestPermission,
                                  child: const Text(
                                    'Beri Izin',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Section Header: Documents Counter & Status
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _selectedFilter == 'device'
                                            ? 'Berkas di Memori HP'
                                            : 'Dokumen Tersimpan',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.2,
                                          color: isDark
                                              ? const Color(0xFFE2E8F0)
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                    if (_isScanningDevice) ...[
                                      const SizedBox(width: 8),
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkSurface
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? AppTheme.darkBorder
                                        : const Color(0xFFE2E8F0),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  '${docs.length} berkas',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Documents List
                        Expanded(
                          child: docs.isEmpty
                              ? _buildEmptyState(isDark)
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    24,
                                  ),
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final doc = docs[index];
                                    return _buildDocCard(doc, isDark);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (_showGuideOverlay)
            AppGuideOverlay(
              onDismiss: () {
                setState(() => _showGuideOverlay = false);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickModuleCard({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String label,
    required String tag,
    required VoidCallback onTap,
    double width = 82,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppTheme.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedTab(
    String key,
    String label,
    IconData icon, {
    Color? color,
  }) {
    final isSelected = _selectedFilter == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = color ?? AppTheme.primaryBlue;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected
            ? activeColor
            : (isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _selectedFilter = key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? activeColor
                    : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocCard(DocumentModel doc, bool isDark) {
    final ext = doc.filePath?.split('.').last.toLowerCase() ?? '';
    final isMd = ext == 'md' || doc.title.toLowerCase().endsWith('.md');
    final docColor = isMd
        ? const Color(0xFF0284C7)
        : AppTheme.getDocColor(doc.type);
    final docLightColor = isMd
        ? (isDark ? const Color(0xFF0C243B) : const Color(0xFFE0F2FE))
        : AppTheme.getDocLightColor(doc.type);
    final docIcon = isMd
        ? Icons.description_rounded
        : AppTheme.getDocIcon(doc.type);
    final isDeviceFile = doc.filePath != null;

    return Material(
      color: isDark ? AppTheme.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDocument(doc),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Squircle Module Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? docColor.withValues(alpha: 0.16)
                      : docLightColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: docColor.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Icon(docIcon, color: docColor, size: 22),
              ),
              const SizedBox(width: 14),

              // Title & Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 2,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: docColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isDeviceFile &&
                                    doc.filePath != null &&
                                    doc.filePath!.contains('.')
                                ? doc.filePath!.split('.').last.toUpperCase()
                                : doc.type.extension.toUpperCase().replaceAll(
                                    '.',
                                    '',
                                  ),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: docColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (isDeviceFile)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0284C7,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'HP',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          _formatDate(doc.updatedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                        if (doc.sizeInBytes > 0) ...[
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            _formatSize(doc.sizeInBytes),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Star Button
              IconButton(
                icon: Icon(
                  doc.isStarred
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: doc.isStarred
                      ? Colors.amber
                      : (isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFF94A3B8)),
                  size: 22,
                ),
                splashRadius: 20,
                tooltip: doc.isStarred ? 'Hapus Bintang' : 'Beri Bintang',
                onPressed: () async {
                  await _repo.toggleStar(doc.id);
                  setState(() {});
                },
              ),

              // More Options
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 19,
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFF94A3B8),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? AppTheme.darkCard : Colors.white,
                onSelected: (val) async {
                  if (val == 'open') {
                    _openDocument(doc);
                  } else if (val == 'open_md') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MarkdownReaderScreen(document: doc),
                      ),
                    );
                    setState(() {});
                  } else if (val == 'rename') {
                    _showRenameDialog(doc);
                  } else if (val == 'duplicate') {
                    _duplicateDocument(doc);
                  } else if (val == 'share') {
                    _shareDocument(doc);
                  } else if (val == 'delete') {
                    _confirmDeleteDocument(doc);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(
                          doc.filePath?.toLowerCase().endsWith('.md') ?? false
                              ? Icons.chrome_reader_mode_outlined
                              : Icons.edit_outlined,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          doc.filePath?.toLowerCase().endsWith('.md') ?? false
                              ? 'Baca Mode Markdown'
                              : 'Buka & Edit',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (doc.type == DocType.word &&
                      !(doc.filePath?.toLowerCase().endsWith('.md') ?? false))
                    PopupMenuItem(
                      value: 'open_md',
                      child: Row(
                        children: [
                          Icon(
                            Icons.chrome_reader_mode_outlined,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Baca Mode Markdown',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(
                          Icons.drive_file_rename_outline_rounded,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Ganti Nama',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 10),
                        const Text('Duplikat', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(
                          Icons.share_outlined,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 10),
                        const Text('Bagikan', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Hapus',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final bool needPermission = !_hasStoragePermission;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF131D33)
                    : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Icon(
                needPermission
                    ? Icons.folder_shared_rounded
                    : Icons.folder_open_rounded,
                size: 34,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              needPermission
                  ? 'Izin Akses Berkas Diperlukan'
                  : (_selectedFilter == 'device'
                        ? 'Tidak Ada Berkas HP Ditemukan'
                        : 'Belum Ada Dokumen'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              needPermission
                  ? 'Beri izin akses penyimpanan agar HardcorezForge dapat mendeteksi dan menampilkan semua dokumen Word, Excel, PPT, dan PDF yang ada di memori HP Anda.'
                  : (_selectedFilter == 'device'
                        ? 'Simpan berkas .docx, .xlsx, atau .pdf di folder Download/Documents HP Anda lalu tekan tombol refresh.'
                        : 'Mulai buat dokumen baru, spreadsheet formula, atau buka file dari penyimpanan internal Anda.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (needPermission)
              FilledButton.icon(
                onPressed: _requestPermission,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text(
                  'Izinkan Akses Semua Berkas',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _selectedFilter == 'device'
                    ? () => _checkPermissionAndScan(silent: false)
                    : () => _createNewDocument(DocType.word),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                icon: Icon(
                  _selectedFilter == 'device'
                      ? Icons.refresh_rounded
                      : Icons.add_rounded,
                  size: 18,
                  color: AppTheme.primaryBlue,
                ),
                label: Text(
                  _selectedFilter == 'device'
                      ? 'Pindai Ulang Berkas'
                      : 'Buat Dokumen Sekarang',
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
