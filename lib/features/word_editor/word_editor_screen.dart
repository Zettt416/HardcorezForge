import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models/document_model.dart';
import '../../core/theme/app_theme.dart';
import '../../data/document_repository.dart';

class WordEditorScreen extends StatefulWidget {
  final DocumentModel document;

  const WordEditorScreen({super.key, required this.document});

  @override
  State<WordEditorScreen> createState() => _WordEditorScreenState();
}

class _WordEditorScreenState extends State<WordEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSaving = false;
  bool _isDirty = false;
  double _fontSize = 15.0;
  TextAlign _alignment = TextAlign.left;
  bool _isBold = false;
  bool _isItalic = false;

  int _wordCount = 0;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.document.title;
    _loadDocument();
    _bodyController.addListener(_updateCounts);
  }

  void _loadDocument() {
    try {
      if (widget.document.content.isNotEmpty) {
        final data = json.decode(widget.document.content) as Map<String, dynamic>;
        _bodyController.text = data['text'] as String? ?? '';
        _fontSize = (data['fontSize'] as num?)?.toDouble() ?? 15.0;
      }
    } catch (_) {
      _bodyController.text = widget.document.content;
    }
    _calculateInitialCounts();
  }

  void _calculateInitialCounts() {
    final text = _bodyController.text.trim();
    _charCount = text.length;
    _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    _isDirty = false;
  }

  void _updateCounts() {
    final text = _bodyController.text.trim();
    setState(() {
      _charCount = text.length;
      _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
      _isDirty = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _saveDocument({bool silent = false}) async {
    if (!silent) setState(() => _isSaving = true);
    widget.document.title = _titleController.text.trim().isEmpty
        ? 'Untitled Document'
        : _titleController.text.trim();
    widget.document.content = json.encode({
      'text': _bodyController.text,
      'fontSize': _fontSize,
    });
    widget.document.sizeInBytes = _bodyController.text.length;

    await DocumentRepository.instance.saveDocument(widget.document);

    // Save-back to physical file on device if it's a text/markdown file
    if (widget.document.filePath != null) {
      try {
        final f = File(widget.document.filePath!);
        if (await f.exists()) {
          final ext = widget.document.filePath!.split('.').last.toLowerCase();
          if (['txt', 'md', 'rtf'].contains(ext)) {
            await f.writeAsString(_bodyController.text);
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
        _isDirty = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dokumen berhasil disimpan'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _insertBullet() {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    const bullet = '\n• ';
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, bullet);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + bullet.length),
      );
    } else {
      _bodyController.text += bullet;
    }
  }

  void _insertNumbered() {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    const numPrefix = '\n1. ';
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, numPrefix);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + numPrefix.length),
      );
    } else {
      _bodyController.text += numPrefix;
    }
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Statistik Dokumen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Jumlah Kata', '$_wordCount'),
            const Divider(),
            _buildStatRow('Jumlah Karakter', '$_charCount'),
            const Divider(),
            _buildStatRow('Estimasi Waktu Baca', '${(_wordCount / 200).ceil()} menit'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (_isDirty) {
          await _saveDocument(silent: true);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBg : Colors.white,
        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.docBlue.withValues(alpha: 0.2) : AppTheme.docBlueLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.docBlue.withValues(alpha: 0.25), width: 1),
              ),
              child: const Icon(Icons.article_rounded, color: AppTheme.docBlue, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _titleController,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: -0.2,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Nama Dokumen',
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
                onChanged: (_) => setState(() => _isDirty = true),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.info_outline_rounded,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            tooltip: 'Statistik Dokumen',
            onPressed: _showStatsDialog,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: _isDirty
                          ? AppTheme.primaryBlue
                          : (isDark ? AppTheme.darkSurface : const Color(0xFFE2E8F0)),
                      foregroundColor: _isDirty
                          ? Colors.white
                          : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: Icon(
                      Icons.save_rounded,
                      size: 16,
                      color: _isDirty
                          ? Colors.white
                          : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                    ),
                    label: Text(
                      _isDirty ? 'Simpan' : 'Tersimpan',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _saveDocument,
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Formatting Toolbar (WPS Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Bold Toggle
                  _buildToolbarIcon(
                    icon: Icons.format_bold,
                    isActive: _isBold,
                    onTap: () => setState(() => _isBold = !_isBold),
                  ),
                  // Italic Toggle
                  _buildToolbarIcon(
                    icon: Icons.format_italic,
                    isActive: _isItalic,
                    onTap: () => setState(() => _isItalic = !_isItalic),
                  ),
                  const VerticalDivider(width: 16),
                  // Alignment
                  _buildToolbarIcon(
                    icon: Icons.format_align_left,
                    isActive: _alignment == TextAlign.left,
                    onTap: () => setState(() => _alignment = TextAlign.left),
                  ),
                  _buildToolbarIcon(
                    icon: Icons.format_align_center,
                    isActive: _alignment == TextAlign.center,
                    onTap: () => setState(() => _alignment = TextAlign.center),
                  ),
                  _buildToolbarIcon(
                    icon: Icons.format_align_right,
                    isActive: _alignment == TextAlign.right,
                    onTap: () => setState(() => _alignment = TextAlign.right),
                  ),
                  const VerticalDivider(width: 16),
                  // Lists
                  _buildToolbarIcon(
                    icon: Icons.format_list_bulleted,
                    isActive: false,
                    onTap: _insertBullet,
                  ),
                  _buildToolbarIcon(
                    icon: Icons.format_list_numbered,
                    isActive: false,
                    onTap: _insertNumbered,
                  ),
                  const VerticalDivider(width: 16),
                  // Font Size
                  _buildToolbarIcon(
                    icon: Icons.remove,
                    isActive: false,
                    onTap: () {
                      if (_fontSize > 11) setState(() => _fontSize -= 1);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '${_fontSize.toInt()} pt',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  _buildToolbarIcon(
                    icon: Icons.add,
                    isActive: false,
                    onTap: () {
                      if (_fontSize < 32) setState(() => _fontSize += 1);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Word Count Indicator Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            alignment: Alignment.centerLeft,
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: Text(
              '$_wordCount kata • $_charCount karakter',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ),

          // Document Paper Canvas
          Expanded(
            child: Container(
              color: isDark ? AppTheme.darkBg : const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 700),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    controller: _bodyController,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    textAlign: _alignment,
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                      height: 1.6,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Mulai ketik dokumen Anda di sini',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
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

  Widget _buildToolbarIcon({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: isActive ? AppTheme.docBlue.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? AppTheme.docBlue : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
