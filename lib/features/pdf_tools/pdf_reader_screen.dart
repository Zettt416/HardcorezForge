import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/document_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/platform_share.dart';
import '../../data/document_repository.dart';
import '../signature/signature_screen.dart';

class PlacedSignature {
  Offset position;
  double width;
  double height;
  final int page;
  final List<List<SignaturePoint>> strokes;
  final String? stampText;
  bool isSelected;

  PlacedSignature({
    required this.position,
    this.width = 160.0,
    this.height = 70.0,
    required this.page,
    required this.strokes,
    this.stampText,
    this.isSelected = true,
  });

  Map<String, dynamic> toMap() => {
    'x': position.dx,
    'y': position.dy,
    'w': width,
    'h': height,
    'page': page,
    'stamp': stampText,
    'strokes': strokes.map((s) => s.map((p) => p.toMap()).toList()).toList(),
  };

  factory PlacedSignature.fromMap(Map<String, dynamic> map) => PlacedSignature(
    position: Offset(
      (map['x'] as num).toDouble(),
      (map['y'] as num).toDouble(),
    ),
    width: (map['w'] as num?)?.toDouble() ?? 160.0,
    height: (map['h'] as num?)?.toDouble() ?? 70.0,
    page: map['page'] as int? ?? 1,
    stampText: map['stamp'] as String?,
    isSelected: false,
    strokes:
        (map['strokes'] as List<dynamic>?)
            ?.map(
              (s) => (s as List<dynamic>)
                  .map((p) => SignaturePoint.fromMap(p as Map<String, dynamic>))
                  .toList(),
            )
            .toList() ??
        [],
  );
}

class PdfReaderScreen extends StatefulWidget {
  final DocumentModel document;

  const PdfReaderScreen({super.key, required this.document});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  int _currentPage = 1;
  int _totalPages = 1;
  int _viewMode = 0; // 0 = Day (white), 1 = Sepia, 2 = Night (dark)

  Uint8List? _pdfPageBytes;
  bool _isLoadingPdf = false;
  String? _pdfLoadError;

  bool get _isRealPdfFile =>
      widget.document.filePath != null && widget.document.filePath!.isNotEmpty;

  final List<PlacedSignature> _placedSignatures = [];

  final List<Color> _bgThemes = [
    Colors.white,
    const Color(0xFFFBF0D9), // Sepia
    const Color(0xFF1E293B), // Night
  ];

  final List<Color> _textThemes = [
    const Color(0xFF0F172A),
    const Color(0xFF5F4325),
    const Color(0xFFF1F5F9),
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingSignatures();
    if (_isRealPdfFile) {
      _loadCurrentPdfPage();
    }
  }

  Future<void> _loadCurrentPdfPage() async {
    final filePath = widget.document.filePath;
    if (filePath == null || filePath.isEmpty) return;

    setState(() {
      _isLoadingPdf = true;
      _pdfLoadError = null;
    });

    try {
      final res = await PlatformShare.renderPdfPage(
        path: filePath,
        pageIndex: _currentPage - 1,
      );

      if (!mounted) return;

      if (res != null) {
        final count = (res['pageCount'] as int?) ?? 1;
        final bytes = res['bytes'] as Uint8List?;
        setState(() {
          _totalPages = count;
          _pdfPageBytes = bytes;
          _isLoadingPdf = false;
          _pdfLoadError = bytes == null
              ? 'Gagal me-render halaman berkas PDF.'
              : null;
        });
      } else {
        setState(() {
          _isLoadingPdf = false;
          _pdfLoadError = 'Tidak dapat membaca berkas PDF di memori perangkat.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPdf = false;
        _pdfLoadError = 'Terjadi kesalahan saat memuat berkas: $e';
      });
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() => _currentPage = page);
    if (_isRealPdfFile) {
      _loadCurrentPdfPage();
    }
  }

  void _loadExistingSignatures() {
    try {
      if (widget.document.content.startsWith('{')) {
        final decoded = json.decode(widget.document.content);
        if (decoded is Map<String, dynamic> && decoded['signatures'] != null) {
          final sigList = decoded['signatures'] as List<dynamic>;
          for (final item in sigList) {
            _placedSignatures.add(
              PlacedSignature.fromMap(item as Map<String, dynamic>),
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveDocumentWithSignatures() async {
    try {
      final data = {
        'text': widget.document.title,
        'signatures': _placedSignatures.map((s) => s.toMap()).toList(),
      };
      widget.document.content = json.encode(data);
      widget.document.updatedAt = DateTime.now();
      await DocumentRepository.instance.saveDocument(widget.document);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dokumen berhasil disimpan dengan ${_placedSignatures.length} tanda tangan digital!',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan dokumen: $e')));
      }
    }
  }

  void _openSignPad() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignatureScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      final strokes = result['strokes'] as List<List<SignaturePoint>>? ?? [];
      final stamp = result['stamp'] as String?;

      if (strokes.isNotEmpty || stamp != null) {
        setState(() {
          // Deselect others
          for (final s in _placedSignatures) {
            s.isSelected = false;
          }

          // Initial placement on current page canvas
          final newSig = PlacedSignature(
            position: Offset(40, _currentPage == 4 ? 420 : 340),
            width: 170.0,
            height: 75.0,
            page: _currentPage,
            strokes: strokes,
            stampText: stamp,
            isSelected: true,
          );
          _placedSignatures.add(newSig);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tanda tangan dibubuhkan di Halaman $_currentPage! Geser untuk memindahkan, seret sudut untuk mengubah ukuran.',
              ),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Simpan',
                textColor: Colors.amberAccent,
                onPressed: _saveDocumentWithSignatures,
              ),
            ),
          );
        }
      }
    }
  }

  void _showFullTitleSheet(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.pdfRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PDF',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.pdfRed,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nama Berkas Dokumen',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.pdfRed,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Salin Nama Berkas'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: title));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama berkas PDF berhasil disalin'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _bgThemes[_viewMode];
    final textColor = _textThemes[_viewMode];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showFullTitleSheet(widget.document.title),
          onLongPress: () => _showFullTitleSheet(widget.document.title),
          child: Text(
            widget.document.title,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _viewMode == 0
                  ? Icons.wb_sunny_rounded
                  : (_viewMode == 1
                        ? Icons.menu_book_rounded
                        : Icons.dark_mode_rounded),
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
            tooltip: 'Mode Baca (Siang/Sepia/Malam)',
            onPressed: () {
              setState(() => _viewMode = (_viewMode + 1) % 3);
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.draw_rounded,
              color: AppTheme.pdfRed,
              size: 22,
            ),
            tooltip: 'Bubuhkan Tanda Tangan',
            onPressed: _openSignPad,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.save_rounded,
              color: AppTheme.pdfRed,
              size: 22,
            ),
            tooltip: 'Simpan Dokumen',
            onPressed: _saveDocumentWithSignatures,
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 21,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (val) {
              if (val == 'full_title') {
                _showFullTitleSheet(widget.document.title);
              }
              if (val == 'sign') _openSignPad();
              if (val == 'save') _saveDocumentWithSignatures();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'full_title',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Lihat Nama Lengkap'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sign',
                child: Row(
                  children: [
                    Icon(Icons.draw_rounded, size: 18, color: AppTheme.pdfRed),
                    SizedBox(width: 10),
                    Text('Bubuhkan TTD'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Simpan Dokumen'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Elegant Document Info Strip (Uniform across entire app!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111726) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.pdfRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PDF',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.pdfRed,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.layers_outlined,
                  size: 13,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  'Hal. $_currentPage dari $_totalPages',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                if (_placedSignatures.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.draw_rounded,
                    size: 13,
                    color: AppTheme.pdfRed,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_placedSignatures.length} TTD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _viewMode == 0
                        ? 'Mode Siang'
                        : (_viewMode == 1 ? 'Mode Sepia' : 'Mode Malam'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // Main PDF Page Viewer
                GestureDetector(
                  onTap: () {
                    // Tap on backdrop deselects any signature box
                    setState(() {
                      for (final s in _placedSignatures) {
                        s.isSelected = false;
                      }
                    });
                  },
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 3.0,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          constraints: const BoxConstraints(
                            maxWidth: 550,
                            minHeight: 680,
                          ),
                          decoration: BoxDecoration(
                            color: _isRealPdfFile ? Colors.white : bgColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          // Paper Stack: Contains Document text/render + Signatures on this page
                          child: Stack(
                            children: [
                              // 1. Document Page Rendering / Content
                              if (_isRealPdfFile) ...[
                                if (_isLoadingPdf)
                                  Container(
                                    height: 580,
                                    alignment: Alignment.center,
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                          color: AppTheme.pdfRed,
                                        ),
                                        SizedBox(height: 14),
                                        Text(
                                          'Memuat halaman PDF...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (_pdfPageBytes != null)
                                  _buildFilteredPdfImage()
                                else
                                  Container(
                                    height: 400,
                                    padding: const EdgeInsets.all(24),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.picture_as_pdf_outlined,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _pdfLoadError ??
                                              'Tidak dapat menampilkan halaman berkas PDF.',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ] else ...[
                                // Standalone / Newly created PDF in app
                                Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'HARDCOREZFORGE OFFICIAL',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          Text(
                                            'HLM $_currentPage',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Text(
                                        _getPageTitle(_currentPage),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        _getPageContent(_currentPage),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.65,
                                          color: textColor.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 80),
                                      const Divider(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Status: Terverifikasi Digital',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            'Dokumen PDF',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // 2. Render signatures placed on THIS page directly on the paper canvas
                              for (int i = 0; i < _placedSignatures.length; i++)
                                if (_placedSignatures[i].page == _currentPage)
                                  _buildDraggableSignature(
                                    _placedSignatures[i],
                                    i,
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Floating Page Navigation Bar
                Positioned(
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                  left: 40,
                  right: 40,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            onPressed: _currentPage > 1
                                ? () => _goToPage(_currentPage - 1)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '$_currentPage / $_totalPages',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            onPressed: _currentPage < _totalPages
                                ? () => _goToPage(_currentPage + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredPdfImage() {
    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        _pdfPageBytes!,
        fit: BoxFit.fitWidth,
        width: double.infinity,
      ),
    );

    if (_viewMode == 1) {
      // Sepia mode
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.9,
          0,
          0,
          0,
          30,
          0,
          0.85,
          0,
          0,
          20,
          0,
          0,
          0.75,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: image,
      );
    } else if (_viewMode == 2) {
      // Night mode (inverted colors)
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,
          0,
          0,
          0,
          255,
          0,
          -1,
          0,
          0,
          255,
          0,
          0,
          -1,
          0,
          255,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: image,
      );
    }

    return image;
  }

  Widget _buildDraggableSignature(PlacedSignature signature, int index) {
    return Positioned(
      left: signature.position.dx,
      top: signature.position.dy,
      child: GestureDetector(
        onTap: () {
          setState(() {
            for (final s in _placedSignatures) {
              s.isSelected = false;
            }
            signature.isSelected = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            signature.position = Offset(
              math.max(0.0, signature.position.dx + details.delta.dx),
              math.max(0.0, signature.position.dy + details.delta.dy),
            );
          });
        },
        child: Container(
          width: signature.width,
          height: signature.height,
          decoration: BoxDecoration(
            // When selected, show subtle blue border; when unselected, pure transparent
            border: signature.isSelected
                ? Border.all(color: const Color(0xFF2563EB), width: 1.5)
                : Border.all(color: Colors.transparent),
            borderRadius: BorderRadius.circular(6),
            color: signature.isSelected
                ? Colors.blue.withValues(alpha: 0.04)
                : Colors.transparent,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Signature / Stamp Vector Rendering with autoFit
              Positioned.fill(
                child: CustomPaint(
                  painter: SignaturePainter(
                    strokes: signature.strokes,
                    autoFit: true,
                    stampText: signature.stampText,
                  ),
                ),
              ),

              // Delete button (visible only when selected)
              if (signature.isSelected)
                Positioned(
                  top: -10,
                  right: -10,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _placedSignatures.removeAt(index));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: const Icon(
                        Icons.close,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Resize Handle in bottom right (visible only when selected)
              if (signature.isSelected)
                Positioned(
                  bottom: -6,
                  right: -6,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        signature.width = math.max(
                          80.0,
                          math.min(340.0, signature.width + details.delta.dx),
                        );
                        signature.height = math.max(
                          35.0,
                          math.min(160.0, signature.height + details.delta.dy),
                        );
                      });
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: const Icon(
                        Icons.open_in_full_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPageTitle(int page) {
    if (page == 1) {
      return widget.document.title;
    }
    return '${widget.document.title} (Halaman $page)';
  }

  String _getPageContent(int page) {
    if (widget.document.content.trim().isNotEmpty &&
        !widget.document.content.startsWith('{')) {
      return widget.document.content;
    }
    return 'Halaman $page dari dokumen ${widget.document.title}.\n\nAnda dapat menempelkan tanda tangan digital dan stempel resmi pada dokumen ini menggunakan tombol pena di bagian atas.';
  }
}
