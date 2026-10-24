import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/document_model.dart';
import '../../core/theme/app_theme.dart';
import '../../data/document_repository.dart';

class SlideData {
  String title;
  String subtitle;
  String content;
  int themeIndex;

  SlideData({
    required this.title,
    required this.subtitle,
    required this.content,
    this.themeIndex = 0,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'subtitle': subtitle,
    'content': content,
    'themeIndex': themeIndex,
  };

  factory SlideData.fromMap(Map<String, dynamic> map) => SlideData(
    title: map['title'] as String? ?? '',
    subtitle: map['subtitle'] as String? ?? '',
    content: map['content'] as String? ?? '',
    themeIndex: map['themeIndex'] as int? ?? 0,
  );
}

class PresentationScreen extends StatefulWidget {
  final DocumentModel document;

  const PresentationScreen({super.key, required this.document});

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen> {
  final TextEditingController _docTitleController = TextEditingController();
  final TextEditingController _slideTitleController = TextEditingController();
  final TextEditingController _slideSubtitleController =
      TextEditingController();
  final TextEditingController _slideContentController = TextEditingController();

  final List<SlideData> _slides = [];
  int _activeSlideIndex = 0;
  bool _isSaving = false;
  bool _isDirty = false;

  final List<Map<String, dynamic>> _themes = [
    {
      'name': 'Corporate Navy',
      'bg': const Color(0xFF0F172A),
      'card': const Color(0xFF1E293B),
      'title': Colors.white,
      'subtitle': const Color(0xFF38BDF8),
      'body': const Color(0xFF94A3B8),
    },
    {
      'name': 'Minimalist Light',
      'bg': const Color(0xFFF8FAFC),
      'card': Colors.white,
      'title': const Color(0xFF0F172A),
      'subtitle': AppTheme.primaryBlue,
      'body': const Color(0xFF475569),
    },
    {
      'name': 'Emerald Business',
      'bg': const Color(0xFF064E3B),
      'card': const Color(0xFF065F46),
      'title': Colors.white,
      'subtitle': const Color(0xFF6EE7B7),
      'body': const Color(0xFFD1FAE5),
    },
    {
      'name': 'Sunset Amber',
      'bg': const Color(0xFF7C2D12),
      'card': const Color(0xFF9A3412),
      'title': Colors.white,
      'subtitle': const Color(0xFFFDBA74),
      'body': const Color(0xFFFFEDD5),
    },
  ];

  @override
  void initState() {
    super.initState();
    _docTitleController.text = widget.document.title;
    _loadSlides();
  }

  void _loadSlides() {
    try {
      if (widget.document.content.isNotEmpty) {
        final data =
            json.decode(widget.document.content) as Map<String, dynamic>;
        final slideList = data['slides'] as List<dynamic>? ?? [];
        _slides.clear();
        for (final item in slideList) {
          _slides.add(SlideData.fromMap(item as Map<String, dynamic>));
        }
      }
    } catch (_) {}

    if (_slides.isEmpty) {
      _slides.addAll([
        SlideData(
          title: 'Strategi Pertumbuhan HardcorezForge',
          subtitle: 'Presentasi Bisnis & Rencana Q4',
          content:
              '• Peningkatan performa aplikasi mobile\n• Ekspresi fitur tanda tangan digital\n• Dukungan penuh format Word, Excel, dan PDF',
          themeIndex: 0,
        ),
        SlideData(
          title: 'Target Pengguna & Pasar',
          subtitle: 'Analisis Demografi & Kebutuhan',
          content:
              '• Profesional yang membutuhkan office suite offline & aman\n• Tanpa iklan dan tanpa pelacakan data pribadi\n• Kompatibilitas lintas platform Android dan iOS',
          themeIndex: 1,
        ),
        SlideData(
          title: 'Langkah Implementasi',
          subtitle: 'Roadmap & Rencana Peluncuran',
          content:
              '1. Rilis versi stabil di Android\n2. Optimasi pipeline CI/CD untuk build iOS\n3. Integrasi cloud storage opsional (Google Drive / Nextcloud)',
          themeIndex: 2,
        ),
      ]);
    }

    _syncCurrentSlideToControllers();
  }

  void _syncCurrentSlideToControllers() {
    if (_activeSlideIndex < _slides.length) {
      final s = _slides[_activeSlideIndex];
      _slideTitleController.text = s.title;
      _slideSubtitleController.text = s.subtitle;
      _slideContentController.text = s.content;
    }
  }

  void _onSlideContentChanged() {
    if (_activeSlideIndex < _slides.length) {
      setState(() {
        _slides[_activeSlideIndex].title = _slideTitleController.text;
        _slides[_activeSlideIndex].subtitle = _slideSubtitleController.text;
        _slides[_activeSlideIndex].content = _slideContentController.text;
        _isDirty = true;
      });
    }
  }

  void _addNewSlide() {
    setState(() {
      _slides.add(
        SlideData(
          title: 'Slide Baru ${_slides.length + 1}',
          subtitle: 'Subjudul Presentasi',
          content: '• Masukkan poin materi Anda di sini',
          themeIndex: _slides.isNotEmpty ? _slides.last.themeIndex : 0,
        ),
      );
      _activeSlideIndex = _slides.length - 1;
      _syncCurrentSlideToControllers();
      _isDirty = true;
    });
  }

  void _duplicateCurrentSlide() {
    if (_activeSlideIndex < _slides.length) {
      final s = _slides[_activeSlideIndex];
      setState(() {
        _slides.insert(
          _activeSlideIndex + 1,
          SlideData(
            title: '${s.title} (Salinan)',
            subtitle: s.subtitle,
            content: s.content,
            themeIndex: s.themeIndex,
          ),
        );
        _activeSlideIndex++;
        _syncCurrentSlideToControllers();
        _isDirty = true;
      });
    }
  }

  void _deleteSlide(int index) {
    if (_slides.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Presentasi harus memiliki minimal satu slide'),
        ),
      );
      return;
    }
    setState(() {
      _slides.removeAt(index);
      if (_activeSlideIndex >= _slides.length) {
        _activeSlideIndex = _slides.length - 1;
      }
      _syncCurrentSlideToControllers();
      _isDirty = true;
    });
  }

  Future<void> _savePresentation({bool silent = false}) async {
    if (!silent) setState(() => _isSaving = true);
    widget.document.title = _docTitleController.text.trim().isEmpty
        ? 'Untitled Presentation'
        : _docTitleController.text.trim();
    widget.document.content = json.encode({
      'slides': _slides.map((e) => e.toMap()).toList(),
    });

    await DocumentRepository.instance.saveDocument(widget.document);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _isDirty = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presentasi berhasil disimpan'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _startSlideshow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenSlideshow(slides: _slides, themes: _themes),
      ),
    );
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
                        color: AppTheme.pptOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'POWERPOINT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.pptOrange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nama Dokumen Lengkap',
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Salin Nama'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: title));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nama dokumen berhasil disalin'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.pptOrange,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Ganti Nama'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _promptRename();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _promptRename() {
    final controller = TextEditingController(text: _docTitleController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Ganti Nama Presentasi',
          style: TextStyle(fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nama Presentasi',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.pptOrange),
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                setState(() {
                  _docTitleController.text = newTitle;
                  widget.document.title = newTitle;
                  _isDirty = true;
                });
                _savePresentation(silent: true);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _docTitleController.dispose();
    _slideTitleController.dispose();
    _slideSubtitleController.dispose();
    _slideContentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSlide = _slides[_activeSlideIndex];
    final currentTheme = _themes[currentSlide.themeIndex % _themes.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayTitle = _docTitleController.text.trim().isEmpty
        ? widget.document.title
        : _docTitleController.text.trim();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (_isDirty) {
          await _savePresentation(silent: true);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF8FAFC),
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
            onTap: () => _showFullTitleSheet(displayTitle),
            onLongPress: () => _showFullTitleSheet(displayTitle),
            child: Text(
              displayTitle,
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
              icon: const Icon(
                Icons.play_circle_fill_rounded,
                color: AppTheme.pptOrange,
                size: 24,
              ),
              tooltip: 'Tayangkan Slideshow',
              onPressed: _startSlideshow,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.save_rounded,
                      size: 22,
                      color: _isDirty
                          ? AppTheme.pptOrange
                          : (isDark ? Colors.white54 : Colors.grey),
                    ),
              tooltip: _isDirty ? 'Simpan Presentasi' : 'Sudah Tersimpan',
              onPressed: _savePresentation,
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
                if (val == 'rename') _promptRename();
                if (val == 'slideshow') _startSlideshow();
                if (val == 'add_slide') _addNewSlide();
                if (val == 'duplicate_slide') _duplicateCurrentSlide();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Ganti Nama'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'slideshow',
                  child: Row(
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 18,
                        color: AppTheme.pptOrange,
                      ),
                      SizedBox(width: 10),
                      Text('Tayangkan Slideshow'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_slide',
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Tambah Slide Baru'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate_slide',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Duplikasi Slide Ini'),
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
                color: isDark
                    ? const Color(0xFF111726)
                    : const Color(0xFFF1F5F9),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppTheme.darkBorder
                        : const Color(0xFFE2E8F0),
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
                      color: AppTheme.pptOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'POWERPOINT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.pptOrange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.slideshow_rounded,
                    size: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Slide ${_activeSlideIndex + 1} dari ${_slides.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
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
                  Icon(
                    Icons.aspect_ratio_rounded,
                    size: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '16:9',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
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
                      currentTheme['name'] as String? ?? 'Tema',
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
            // Slide Canvas Preview
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black87,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9, // Standard widescreen 16:9
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: currentTheme['bg'] as Color,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSlide.title.isEmpty
                                ? 'Judul Slide'
                                : currentSlide.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: currentTheme['title'] as Color,
                            ),
                          ),
                          if (currentSlide.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              currentSlide.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: currentTheme['subtitle'] as Color,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(
                              currentSlide.content.isEmpty
                                  ? 'Poin materi slide'
                                  : currentSlide.content,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: currentTheme['body'] as Color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Slide Editor Input Fields
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _slideTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Judul Slide',
                        isDense: true,
                      ),
                      onChanged: (_) => _onSlideContentChanged(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _slideSubtitleController,
                      decoration: const InputDecoration(
                        labelText: 'Subjudul Slide',
                        isDense: true,
                      ),
                      onChanged: (_) => _onSlideContentChanged(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _slideContentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Poin / Isi Materi',
                        isDense: true,
                      ),
                      onChanged: (_) => _onSlideContentChanged(),
                    ),
                    const SizedBox(height: 10),

                    // Theme Selection for Slide
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text(
                            'Tema Slide:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          for (int t = 0; t < _themes.length; t++)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  currentSlide.themeIndex = t;
                                  _isDirty = true;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _themes[t]['bg'] as Color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: currentSlide.themeIndex == t
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Slide Thumbnails Strip at Bottom
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                border: const Border(top: BorderSide(color: Colors.white12)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 80,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.add_to_photos_rounded,
                            color: AppTheme.pptOrange,
                          ),
                          tooltip: 'Tambah Slide',
                          onPressed: _addNewSlide,
                        ),
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _slides.length,
                            itemBuilder: (ctx, i) {
                              final isSelected = i == _activeSlideIndex;
                              final s = _slides[i];
                              final theme =
                                  _themes[s.themeIndex % _themes.length];

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _activeSlideIndex = i;
                                    _syncCurrentSlideToControllers();
                                  });
                                },
                                child: Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme['bg'] as Color,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.pptOrange
                                          : Colors.white24,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${i + 1}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          if (_slides.length > 1)
                                            GestureDetector(
                                              onTap: () => _deleteSlide(i),
                                              child: const Icon(
                                                Icons.close,
                                                size: 12,
                                                color: Colors.white54,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        s.title.isEmpty ? 'Slide' : s.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullscreenSlideshow extends StatefulWidget {
  final List<SlideData> slides;
  final List<Map<String, dynamic>> themes;

  const FullscreenSlideshow({
    super.key,
    required this.slides,
    required this.themes,
  });

  @override
  State<FullscreenSlideshow> createState() => _FullscreenSlideshowState();
}

class _FullscreenSlideshowState extends State<FullscreenSlideshow> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _next() {
    if (_currentIndex < widget.slides.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.slides[_currentIndex];
    final theme = widget.themes[s.themeIndex % widget.themes.length];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.localPosition.dx > width * 0.5) {
            _next();
          } else {
            _prev();
          }
        },
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  color: theme['bg'] as Color,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme['title'] as Color,
                                ),
                              ),
                              if (s.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  s.subtitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: theme['subtitle'] as Color,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Text(
                                s.content,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: theme['body'] as Color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Top Bar with Exit and Counter
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.slides.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
