import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isReadOnly = false;
  double _fontSize = 15.0;
  TextAlign _alignment = TextAlign.left;
  bool _isBold = false;
  bool _isItalic = false;

  int _wordCount = 0;
  int _charCount = 0;
  String _lastText = '';
  final ValueNotifier<String> _countNotifier = ValueNotifier<String>(
    '0 kata • 0 karakter',
  );

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
        final data =
            json.decode(widget.document.content) as Map<String, dynamic>;
        _bodyController.text = data['text'] as String? ?? '';
        _fontSize = (data['fontSize'] as num?)?.toDouble() ?? 15.0;
      }
    } catch (_) {
      _bodyController.text = widget.document.content;
    }
    _calculateInitialCounts();
  }

  int _countWords(String s) {
    int count = 0;
    bool inWord = false;
    for (int i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      final isSpace = code <= 32 || code == 160;
      if (!isSpace) {
        if (!inWord) {
          count++;
          inWord = true;
        }
      } else {
        inWord = false;
      }
    }
    return count;
  }

  void _calculateInitialCounts() {
    final text = _bodyController.text.trim();
    _lastText = _bodyController.text;
    _charCount = text.length;
    _wordCount = _countWords(text);
    _countNotifier.value = '$_wordCount kata • $_charCount karakter';
    _isDirty = false;
  }

  void _updateCounts() {
    final text = _bodyController.text;
    if (text == _lastText) return;
    _lastText = text;
    _isDirty = true;
    _charCount = text.length;
    _wordCount = _countWords(text);
    _countNotifier.value = '$_wordCount kata • $_charCount karakter';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _focusNode.dispose();
    _countNotifier.dispose();
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
        selection: TextSelection.collapsed(
          offset: selection.start + bullet.length,
        ),
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
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        numPrefix,
      );
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + numPrefix.length,
        ),
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
            _buildStatRow(
              'Estimasi Waktu Baca',
              '${(_wordCount / 200).ceil()} menit',
            ),
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

  void _promptRename() {
    final c = TextEditingController(text: _titleController.text);
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
          controller: c,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nama Dokumen',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final newName = c.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  _titleController.text = newName;
                  widget.document.title = newName;
                  _isDirty = true;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showFullTitleSheet(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.article_rounded,
                    size: 20,
                    color: AppTheme.docBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Nama Lengkap Dokumen',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(
                title.isEmpty ? 'Dokumen Tanpa Judul' : title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (widget.document.filePath != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.document.filePath!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: title));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nama berkas disalin'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Salin Nama'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _promptRename();
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Ganti Nama'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayTitle = _titleController.text.trim().isEmpty
        ? 'Dokumen Baru'
        : _titleController.text.trim();

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
              icon: Icon(
                _isReadOnly
                    ? Icons.edit_note_rounded
                    : Icons.visibility_outlined,
                size: 22,
                color: _isReadOnly
                    ? AppTheme.docBlue
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
              tooltip: _isReadOnly
                  ? 'Beralih ke Mode Sunting'
                  : 'Beralih ke Mode Baca',
              onPressed: () => setState(() => _isReadOnly = !_isReadOnly),
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
                          ? AppTheme.primaryBlue
                          : (isDark ? Colors.white54 : Colors.grey),
                    ),
              tooltip: _isDirty ? 'Simpan Perubahan' : 'Sudah Tersimpan',
              onPressed: _saveDocument,
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
                if (val == 'stats') _showStatsDialog();
                if (val == 'copy') {
                  Clipboard.setData(ClipboardData(text: _bodyController.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Semua teks disalin'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
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
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Salin Semua Teks'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'stats',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Statistik Dokumen'),
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
                      color:
                          (_isReadOnly
                                  ? const Color(0xFF059669)
                                  : AppTheme.docBlue)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isReadOnly ? 'MODE BACA' : 'WORD',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: _isReadOnly
                            ? const Color(0xFF059669)
                            : AppTheme.docBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(_wordCount / 200).ceil().clamp(1, 999)} mnt baca',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_wordCount kata',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.format_size_rounded,
                        size: 13,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${_fontSize.toInt()}pt',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Formatting Toolbar (WPS Style)
            if (!_isReadOnly)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppTheme.darkBorder
                          : AppTheme.lightBorder,
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
                        onTap: () =>
                            setState(() => _alignment = TextAlign.left),
                      ),
                      _buildToolbarIcon(
                        icon: Icons.format_align_center,
                        isActive: _alignment == TextAlign.center,
                        onTap: () =>
                            setState(() => _alignment = TextAlign.center),
                      ),
                      _buildToolbarIcon(
                        icon: Icons.format_align_right,
                        isActive: _alignment == TextAlign.right,
                        onTap: () =>
                            setState(() => _alignment = TextAlign.right),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
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
              child: ValueListenableBuilder<String>(
                valueListenable: _countNotifier,
                builder: (context, countText, _) {
                  return Text(
                    countText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  );
                },
              ),
            ),

            // Document Paper Canvas
            Expanded(
              child: Container(
                color: isDark ? AppTheme.darkBg : const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 700),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkBorder
                            : AppTheme.lightBorder,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.04,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: _isReadOnly
                        ? SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: SelectableText(
                              _bodyController.text.isEmpty
                                  ? 'Dokumen kosong'
                                  : _bodyController.text,
                              textAlign: _alignment,
                              style: TextStyle(
                                fontSize: _fontSize,
                                fontWeight: _isBold
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontStyle: _isItalic
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                height: 1.6,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.lightTextPrimary,
                              ),
                            ),
                          )
                        : TextField(
                            controller: _bodyController,
                            focusNode: _focusNode,
                            maxLines: null,
                            expands: true,
                            scrollPhysics: const BouncingScrollPhysics(),
                            spellCheckConfiguration:
                                const SpellCheckConfiguration.disabled(),
                            enableInteractiveSelection: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            textAlign: _alignment,
                            style: TextStyle(
                              fontSize: _fontSize,
                              fontWeight: _isBold
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontStyle: _isItalic
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              height: 1.6,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
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
        color: isActive
            ? AppTheme.docBlue.withValues(alpha: 0.18)
            : Colors.transparent,
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
