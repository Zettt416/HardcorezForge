import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/document_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/platform_share.dart';
import '../../data/document_repository.dart';

enum MdBlockType {
  h1,
  h2,
  h3,
  h4,
  paragraph,
  codeBlock,
  blockquote,
  bulletItem,
  numberedItem,
  taskItem,
  divider,
  table,
}

class MdBlock {
  final MdBlockType type;
  final String text;
  final String? extra; // Language for codeBlock, task state for taskItem, etc.
  final List<List<String>>? tableRows;
  List<InlineSpan>? spansDark;
  List<InlineSpan>? spansLight;

  MdBlock({
    required this.type,
    required this.text,
    this.extra,
    this.tableRows,
    this.spansDark,
    this.spansLight,
  });
}

class MarkdownReaderScreen extends StatefulWidget {
  final DocumentModel document;

  const MarkdownReaderScreen({super.key, required this.document});

  @override
  State<MarkdownReaderScreen> createState() => _MarkdownReaderScreenState();
}

class _MarkdownReaderScreenState extends State<MarkdownReaderScreen> {
  bool _isEditing = false;
  late TextEditingController _editorController;
  late ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();

  double _fontSize = 15.0;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isSaving = false;
  bool _isDirty = false;

  List<MdBlock> _blocks = [];
  int _wordCount = 0;
  int _readingTimeMinutes = 1;

  @override
  void initState() {
    super.initState();
    _editorController = TextEditingController();
    _scrollController = ScrollController();
    _loadContent();
  }

  void _loadContent() {
    String rawText = '';
    try {
      if (widget.document.content.isNotEmpty) {
        final decoded = json.decode(widget.document.content);
        if (decoded is Map<String, dynamic> && decoded.containsKey('text')) {
          rawText = decoded['text'] as String? ?? '';
        } else {
          rawText = widget.document.content;
        }
      }
    } catch (_) {
      rawText = widget.document.content;
    }

    _editorController.text = rawText;
    _parseMarkdown(rawText);
  }

  static final RegExp _tableSepPattern = RegExp(r'^\|[\s\-:|]+\|$');
  static final RegExp _quotePattern = RegExp(r'^>\s*');
  static final RegExp _taskPattern = RegExp(r'^[-*]\s*\[([ xX])\]\s+(.*)$');
  static final RegExp _bulletMatchPattern = RegExp(r'^[-*+]\s+');
  static final RegExp _numPattern = RegExp(r'^(\d+)\.\s+(.*)$');

  static int _countWords(String text) {
    int count = 0;
    bool inWord = false;
    for (int i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) > 32) {
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

  void _parseMarkdown(String content) {
    final lines = content.split('\n');
    final List<MdBlock> parsed = [];

    final words = _countWords(content);
    bool inCodeBlock = false;
    String codeLang = '';
    final StringBuffer codeBuffer = StringBuffer();

    List<List<String>> currentTable = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // 1. Code Block Fence (```)
      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          parsed.add(
            MdBlock(
              type: MdBlockType.codeBlock,
              text: codeBuffer.toString().trimRight(),
              extra: codeLang,
            ),
          );
          codeBuffer.clear();
          inCodeBlock = false;
          codeLang = '';
        } else {
          inCodeBlock = true;
          codeLang = trimmed.substring(3).trim();
          codeBuffer.clear();
        }
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.writeln(line);
        continue;
      }

      // 2. Table handling (| col1 | col2 |)
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        // Skip separator row like |---|---|
        if (_tableSepPattern.hasMatch(trimmed)) {
          continue;
        }
        final cols = trimmed
            .split('|')
            .where((c) => c.isNotEmpty)
            .map((c) => c.trim())
            .toList();
        currentTable.add(cols);

        // Check if next line is still a table row
        final hasNext =
            i + 1 < lines.length && lines[i + 1].trim().startsWith('|');
        if (!hasNext && currentTable.isNotEmpty) {
          parsed.add(
            MdBlock(
              type: MdBlockType.table,
              text: '',
              tableRows: List.from(currentTable),
            ),
          );
          currentTable.clear();
        }
        continue;
      }

      // 3. Horizontal Rule
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        parsed.add(MdBlock(type: MdBlockType.divider, text: ''));
        continue;
      }

      // 4. Headings
      if (trimmed.startsWith('# ')) {
        parsed.add(
          MdBlock(type: MdBlockType.h1, text: trimmed.substring(2).trim()),
        );
        continue;
      } else if (trimmed.startsWith('## ')) {
        parsed.add(
          MdBlock(type: MdBlockType.h2, text: trimmed.substring(3).trim()),
        );
        continue;
      } else if (trimmed.startsWith('### ')) {
        parsed.add(
          MdBlock(type: MdBlockType.h3, text: trimmed.substring(4).trim()),
        );
        continue;
      } else if (trimmed.startsWith('#### ')) {
        parsed.add(
          MdBlock(type: MdBlockType.h4, text: trimmed.substring(5).trim()),
        );
        continue;
      }

      // 5. Blockquotes (> quote)
      if (trimmed.startsWith('>')) {
        final text = trimmed.replaceFirst(_quotePattern, '');
        parsed.add(MdBlock(type: MdBlockType.blockquote, text: text));
        continue;
      }

      // 6. Task List (- [ ] or - [x])
      final taskMatch = _taskPattern.firstMatch(trimmed);
      if (taskMatch != null) {
        final isChecked = taskMatch.group(1)!.toLowerCase() == 'x';
        parsed.add(
          MdBlock(
            type: MdBlockType.taskItem,
            text: taskMatch.group(2) ?? '',
            extra: isChecked ? '1' : '0',
          ),
        );
        continue;
      }

      // 7. Bullet Lists (- or * or +)
      if (_bulletMatchPattern.hasMatch(trimmed)) {
        final text = trimmed.replaceFirst(_bulletMatchPattern, '');
        parsed.add(MdBlock(type: MdBlockType.bulletItem, text: text));
        continue;
      }

      // 8. Numbered Lists (1. )
      final numMatch = _numPattern.firstMatch(trimmed);
      if (numMatch != null) {
        parsed.add(
          MdBlock(
            type: MdBlockType.numberedItem,
            text: numMatch.group(2) ?? '',
            extra: numMatch.group(1),
          ),
        );
        continue;
      }

      // 9. Blank line
      if (trimmed.isEmpty) {
        continue;
      }

      // 10. Default Paragraph
      parsed.add(MdBlock(type: MdBlockType.paragraph, text: line));
    }

    if (inCodeBlock && codeBuffer.isNotEmpty) {
      parsed.add(
        MdBlock(
          type: MdBlockType.codeBlock,
          text: codeBuffer.toString().trimRight(),
          extra: codeLang,
        ),
      );
    }

    setState(() {
      _blocks = parsed;
      _wordCount = words;
      _readingTimeMinutes = (words / 200).ceil().clamp(1, 999);
    });
  }

  String _formatReadingTime(int minutes) {
    if (minutes <= 1) return '1 mnt baca';
    if (minutes < 60) return '$minutes mnt baca';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours jam baca';
    return '$hours jam $mins mnt baca';
  }

  @override
  void dispose() {
    _editorController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveContent({bool silent = false}) async {
    if (!silent) setState(() => _isSaving = true);
    final text = _editorController.text;

    widget.document.content = json.encode({
      'text': text,
      'fontSize': _fontSize,
    });
    widget.document.sizeInBytes = text.length;
    widget.document.updatedAt = DateTime.now();

    await DocumentRepository.instance.saveDocument(widget.document);

    // Save-back to physical disk file if available
    if (widget.document.filePath != null) {
      try {
        final file = File(widget.document.filePath!);
        if (await file.exists()) {
          await file.writeAsString(text);
        }
      } catch (_) {}
    }

    _parseMarkdown(text);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _isDirty = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Markdown berhasil disimpan'),
              ],
            ),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copyAllText() {
    Clipboard.setData(ClipboardData(text: _editorController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teks Markdown disalin ke clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareMarkdown() {
    PlatformShare.shareText(
      text: _editorController.text,
      title: widget.document.title,
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
                    Icons.description_rounded,
                    size: 20,
                    color: Color(0xFF0284C7),
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
                title,
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
              SizedBox(
                width: double.infinity,
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
                  label: const Text('Salin Nama Berkas'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
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

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (_isDirty) {
          await _saveContent(silent: true);
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
            // Mode Toggle (Baca / Edit)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _isEditing ? Icons.visibility_rounded : Icons.edit_note_rounded,
                size: 22,
                color: _isEditing
                    ? AppTheme.brandCrimson
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
              tooltip: _isEditing ? 'Mode Baca (Preview)' : 'Mode Edit Teks',
              onPressed: () {
                if (_isEditing) {
                  if (_isDirty) {
                    _parseMarkdown(_editorController.text);
                  }
                  setState(() => _isEditing = false);
                } else {
                  setState(() => _isEditing = true);
                }
              },
            ),

            // Search Toggle
            if (!_isEditing)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _isSearching ? Icons.close_rounded : Icons.search_rounded,
                  size: 21,
                  color: _isSearching
                      ? AppTheme.brandCrimson
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                tooltip: _isSearching ? 'Tutup Pencarian' : 'Cari di Dokumen',
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
              ),

            // Save Button (when editing)
            if (_isEditing)
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
                            ? AppTheme.brandCrimson
                            : (isDark ? Colors.white54 : Colors.grey),
                      ),
                tooltip: 'Simpan',
                onPressed: _saveContent,
              ),

            // More Options
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
                if (val == 'copy') _copyAllText();
                if (val == 'share') _shareMarkdown();
                if (val == 'font_inc') {
                  if (_fontSize < 24) {
                    setState(() {
                      _fontSize += 1;
                      for (final b in _blocks) {
                        b.spansDark = null;
                        b.spansLight = null;
                      }
                    });
                  }
                }
                if (val == 'font_dec') {
                  if (_fontSize > 12) {
                    setState(() {
                      _fontSize -= 1;
                      for (final b in _blocks) {
                        b.spansDark = null;
                        b.spansLight = null;
                      }
                    });
                  }
                }
              },
              itemBuilder: (context) => [
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
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Bagikan'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'font_inc',
                  child: Row(
                    children: [
                      const Icon(Icons.format_size_rounded, size: 18),
                      const SizedBox(width: 10),
                      Text('Perbesar Font (${_fontSize.toInt()}pt)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'font_dec',
                  child: const Row(
                    children: [
                      Icon(Icons.text_fields_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Perkecil Font'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Elegant Document Info Strip (No collision with AppBar actions!)
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
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'MARKDOWN',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0284C7),
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
                    _formatReadingTime(_readingTimeMinutes),
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
            // Search Bar (if searching)
            if (_isSearching && !_isEditing)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: isDark ? AppTheme.darkSurface : Colors.white,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cari kata di dokumen...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                      fontSize: 13,
                    ),
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),

            // Main Body: Reader Mode or Raw Editor Mode
            Expanded(
              child: _isEditing
                  ? _buildRawEditor(isDark)
                  : _buildRenderedView(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawEditor(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkBg : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: _editorController,
        maxLines: null,
        expands: true,
        scrollPhysics: const BouncingScrollPhysics(),
        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
        enableInteractiveSelection: true,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: _fontSize,
          height: 1.55,
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Tulis dokumen Markdown di sini...',
          hintStyle: TextStyle(
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        onChanged: (_) {
          if (!_isDirty) {
            setState(() => _isDirty = true);
          }
        },
      ),
    );
  }

  Widget _buildRenderedView(bool isDark) {
    final filteredBlocks = _searchQuery.isEmpty
        ? _blocks
        : _blocks
              .where((b) => b.text.toLowerCase().contains(_searchQuery))
              .toList();

    if (filteredBlocks.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty
              ? 'Tidak ada kata yang cocok dengan "$_searchQuery"'
              : 'Dokumen kosong',
          style: TextStyle(
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      cacheExtent: 1200,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 48),
      itemCount: filteredBlocks.length,
      itemBuilder: (context, index) {
        final block = filteredBlocks[index];
        return _buildBlockWidget(block, isDark);
      },
    );
  }

  Widget _buildBlockWidget(MdBlock block, bool isDark) {
    switch (block.type) {
      case MdBlockType.h1:
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                block.text,
                style: TextStyle(
                  fontSize: _fontSize + 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2,
                width: 40,
                decoration: BoxDecoration(
                  color: AppTheme.brandCrimson,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );

      case MdBlockType.h2:
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: _fontSize + 6,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
            ),
          ),
        );

      case MdBlockType.h3:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: _fontSize + 3,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
          ),
        );

      case MdBlockType.h4:
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: _fontSize + 1,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        );

      case MdBlockType.blockquote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D33) : const Color(0xFFF1F5F9),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(8),
            ),
            border: const Border(
              left: BorderSide(color: AppTheme.brandCrimson, width: 3.5),
            ),
          ),
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: _fontSize,
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        );

      case MdBlockType.codeBlock:
        return _buildCodeBlock(block, isDark);

      case MdBlockType.bulletItem:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 10),
                child: Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: BoxDecoration(
                    color: AppTheme.brandCrimson,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(child: _buildRichText(block, isDark)),
            ],
          ),
        );

      case MdBlockType.numberedItem:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${block.extra ?? '1'}.',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(child: _buildRichText(block, isDark)),
            ],
          ),
        );

      case MdBlockType.taskItem:
        final isChecked = block.extra == '1';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 1),
                child: Icon(
                  isChecked
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 19,
                  color: isChecked
                      ? AppTheme.brandCrimson
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
              Expanded(
                child: Text(
                  block.text,
                  style: TextStyle(
                    fontSize: _fontSize,
                    height: 1.5,
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                    color: isChecked
                        ? (isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8))
                        : (isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary),
                  ),
                ),
              ),
            ],
          ),
        );

      case MdBlockType.divider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Divider(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            thickness: 1,
          ),
        );

      case MdBlockType.table:
        return _buildTableBlock(block, isDark);

      case MdBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildRichText(block, isDark),
        );
    }
  }

  Widget _buildCodeBlock(MdBlock block, bool isDark) {
    final lang = block.extra?.toUpperCase() ?? 'CODE';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(
          0xFF0F172A,
        ), // Always clean obsidian slate for code blocks
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Code Block Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang.isEmpty ? 'KODE' : lang,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: block.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kode disalin ke clipboard'),
                        duration: Duration(milliseconds: 900),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Salin',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Code Text Content (horizontal scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(14),
            child: Text(
              block.text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableBlock(MdBlock block, bool isDark) {
    if (block.tableRows == null || block.tableRows!.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = block.tableRows!;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 52,
          horizontalMargin: 14,
          columnSpacing: 18,
          headingRowColor: WidgetStateProperty.all(
            isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          ),
          columns: rows.first
              .map(
                (col) => DataColumn(
                  label: Text(
                    col,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              )
              .toList(),
          rows: rows.skip(1).map((row) {
            return DataRow(
              cells: row.map((cell) {
                return DataCell(
                  Text(
                    cell,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  static final RegExp _inlinePattern = RegExp(
    r'(\*\*([^*]+)\*\*)|(\*([^*]+)\*)|(`([^`]+)`)|(~~([^~]+)~~)|(\[([^\]]+)\]\(([^)]+)\))',
  );

  Widget _buildRichText(MdBlock block, bool isDark) {
    List<InlineSpan>? spans = isDark ? block.spansDark : block.spansLight;
    if (spans == null) {
      spans = _parseInlineFormatting(block.text, isDark);
      if (isDark) {
        block.spansDark = spans;
      } else {
        block.spansLight = spans;
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontSize: _fontSize,
        height: 1.58,
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
      ),
    );
  }

  List<InlineSpan> _parseInlineFormatting(String text, bool isDark) {
    final List<InlineSpan> spans = [];

    int lastIndex = 0;
    for (final match in _inlinePattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      if (match.group(2) != null) {
        // Bold (**text**)
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(4) != null) {
        // Italic (*text*)
        spans.add(
          TextSpan(
            text: match.group(4),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else if (match.group(6) != null) {
        // Inline code (`code`) - ultra-lightweight TextSpan with background
        spans.add(
          TextSpan(
            text: ' ${match.group(6)!} ',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: (_fontSize - 1.5).clamp(10, 22),
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFE2E8F0),
              color: const Color(0xFF0284C7),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (match.group(8) != null) {
        // Strikethrough (~~text~~)
        spans.add(
          TextSpan(
            text: match.group(8),
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
        );
      } else if (match.group(10) != null) {
        // Link [title](url)
        spans.add(
          TextSpan(
            text: match.group(10),
            style: const TextStyle(
              color: AppTheme.primaryBlue,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return spans;
  }
}
