import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/document_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/platform_share.dart';
import '../../data/document_repository.dart';
import 'formula_engine.dart';

class SpreadsheetScreen extends StatefulWidget {
  final DocumentModel document;

  const SpreadsheetScreen({super.key, required this.document});

  @override
  State<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends State<SpreadsheetScreen> {
  late int _rowCount;
  late int _colCount;
  final Map<String, String> _cells = {};
  String _selectedCell = 'A1';
  final TextEditingController _formulaController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.document.title;
    _loadDocumentContent();
  }

  void _loadDocumentContent() {
    try {
      if (widget.document.content.isNotEmpty) {
        final data =
            json.decode(widget.document.content) as Map<String, dynamic>;
        _rowCount = data['rows'] as int? ?? 20;
        _colCount = data['cols'] as int? ?? 8;
        final cellMap = data['cells'] as Map<String, dynamic>? ?? {};
        _cells.clear();
        cellMap.forEach((k, v) {
          _cells[k] = v.toString();
        });
      } else {
        _rowCount = 20;
        _colCount = 8;
      }
    } catch (_) {
      _rowCount = 20;
      _colCount = 8;
    }
    _formulaController.text = _cells[_selectedCell] ?? '';
  }

  @override
  void dispose() {
    _formulaController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  String _colName(int colIdx) => String.fromCharCode(65 + colIdx);

  void _onCellTapped(String cellKey) {
    setState(() {
      _selectedCell = cellKey;
      _formulaController.text = _cells[cellKey] ?? '';
    });
  }

  void _updateCellValue(String value) {
    setState(() {
      _cells[_selectedCell] = value;
      _isDirty = true;
    });
  }

  Future<void> _saveSheet({bool silent = false}) async {
    if (!silent) setState(() => _isSaving = true);
    widget.document.title = _titleController.text.trim().isEmpty
        ? 'Untitled Sheet'
        : _titleController.text.trim();
    widget.document.content = json.encode({
      'rows': _rowCount,
      'cols': _colCount,
      'cells': _cells,
    });

    await DocumentRepository.instance.saveDocument(widget.document);

    if (widget.document.filePath != null) {
      try {
        final f = File(widget.document.filePath!);
        if (await f.exists()) {
          final ext = widget.document.filePath!.split('.').last.toLowerCase();
          if (ext == 'csv' || ext == 'tsv') {
            final delimiter = ext == 'tsv' ? '\t' : ',';
            final buffer = StringBuffer();
            for (int r = 1; r <= _rowCount; r++) {
              final rowVals = <String>[];
              for (int c = 0; c < _colCount; c++) {
                final key = '${_colName(c)}$r';
                final val = FormulaEngine.evaluate(
                  formulaOrVal: _cells[key] ?? '',
                  cells: _cells,
                );
                if (ext == 'tsv') {
                  rowVals.add(val.replaceAll('\t', ' '));
                } else {
                  rowVals.add('"${val.replaceAll('"', '""')}"');
                }
              }
              buffer.writeln(rowVals.join(delimiter));
            }
            await f.writeAsString(buffer.toString());
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
            content: Text('Lembar kerja berhasil disimpan'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _applyQuickFormula(String formulaType) {
    final col = _selectedCell.replaceAll(RegExp(r'[0-9]'), '');
    final row =
        int.tryParse(_selectedCell.replaceAll(RegExp(r'[A-Z]'), '')) ?? 1;

    if (row > 1) {
      final formula = '=$formulaType(${col}1:$col${row - 1})';
      _formulaController.text = formula;
      _updateCellValue(formula);
    }
  }

  Future<void> _exportCSV() async {
    final buffer = StringBuffer();
    for (int r = 1; r <= _rowCount; r++) {
      final rowVals = <String>[];
      for (int c = 0; c < _colCount; c++) {
        final key = '${_colName(c)}$r';
        final val = FormulaEngine.evaluate(
          formulaOrVal: _cells[key] ?? '',
          cells: _cells,
        );

        rowVals.add('"${val.replaceAll('"', '""')}"');
      }
      buffer.writeln(rowVals.join(','));
    }

    final csvContent = buffer.toString();

    String baseDir = '/storage/emulated/0/Download';
    if (!Directory(baseDir).existsSync()) {
      final appDocDir = await getApplicationDocumentsDirectory();
      baseDir = appDocDir.path;
    }

    final cleanTitle = widget.document.title
        .replaceAll(RegExp(r'\.(csv|tsv|xlsx|xls)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetPath = '$baseDir/$cleanTitle.csv';

    try {
      final file = File(targetPath);
      await file.writeAsString(csvContent);

      final now = DateTime.now();
      final exportedDoc = DocumentModel(
        id: 'csv_${now.millisecondsSinceEpoch}',
        title: '$cleanTitle.csv',
        type: DocType.sheet,
        updatedAt: now,
        createdAt: now,
        content: json.encode({
          'rows': _rowCount,
          'cols': _colCount,
          'cells': _cells,
        }),
        sizeInBytes: await file.length(),
        filePath: targetPath,
      );
      await DocumentRepository.instance.saveDocument(exportedDoc);

      if (!mounted) return;

      final isDark = Theme.of(context).brightness == Brightness.dark;
      showModalBottomSheet(
        context: context,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.sheetGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.table_chart_rounded,
                        color: AppTheme.sheetGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Berkas CSV Fisik Berhasil Dibuat!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tersimpan di: $targetPath',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pratinjau Data CSV:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    csvContent.split('\n').take(5).join('\n'),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          PlatformShare.openFile(path: targetPath);
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Buka'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.sheetGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          PlatformShare.shareFile(
                            path: targetPath,
                            title: 'Bagikan $cleanTitle.csv',
                          );
                        },
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Bagikan CSV'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor berkas CSV: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _promptRename() {
    final c = TextEditingController(text: _titleController.text);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        title: const Text(
          'Ganti Nama Lembar Kerja',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nama Lembar Kerja',
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
                    Icons.table_chart_rounded,
                    size: 20,
                    color: AppTheme.sheetGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Nama Lengkap Lembar Kerja',
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
                title.isEmpty ? 'Lembar Kerja Tanpa Judul' : title,
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
                        backgroundColor: AppTheme.sheetGreen,
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

  void _addRow() {
    setState(() {
      _rowCount++;
      _isDirty = true;
    });
  }

  void _addColumn() {
    setState(() {
      _colCount++;
      _isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayTitle = _titleController.text.trim().isEmpty
        ? 'Lembar Kerja Baru'
        : _titleController.text.trim();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (_isDirty) {
          await _saveSheet(silent: true);
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
              icon: Icon(
                Icons.edit_note_rounded,
                size: 22,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
              tooltip: 'Ganti Nama Dokumen',
              onPressed: _promptRename,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.file_download_outlined,
                size: 21,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
              tooltip: 'Ekspor CSV',
              onPressed: _exportCSV,
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
                          ? AppTheme.sheetGreen
                          : (isDark ? Colors.white54 : Colors.grey),
                    ),
              tooltip: _isDirty ? 'Simpan Perubahan' : 'Sudah Tersimpan',
              onPressed: _saveSheet,
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
                if (val == 'csv') _exportCSV();
                if (val == 'add_row') _addRow();
                if (val == 'add_col') _addColumn();
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
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.file_download_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Ekspor ke CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_row',
                  child: Row(
                    children: [
                      Icon(Icons.table_rows_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Tambah Baris'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_col',
                  child: Row(
                    children: [
                      Icon(Icons.view_column_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Tambah Kolom'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
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
                      color: AppTheme.sheetGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EXCEL',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.sheetGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.grid_on_rounded,
                    size: 13,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_rowCount baris × $_colCount kolom',
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
                    'Sel: $_selectedCell',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.sheetGreen,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.functions_rounded,
                        size: 14,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Auto FX',
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

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.sheetGreen.withValues(alpha: 0.18)
                          : AppTheme.sheetGreenLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.sheetGreen.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _selectedCell,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppTheme.sheetGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'fx',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppTheme.sheetGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _formulaController,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Nilai atau rumus (misal =SUM(A1:A5))',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                      onChanged: _updateCellValue,
                    ),
                  ),
                  if (_formulaController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _formulaController.clear();
                        _updateCellValue('');
                      },
                      child: const Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildGridTable(isDark),
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickButton(
                          label: '∑ SUM',
                          onTap: () => _applyQuickFormula('SUM'),
                        ),
                        _buildQuickButton(
                          label: 'AVG',
                          onTap: () => _applyQuickFormula('AVG'),
                        ),
                        _buildQuickButton(
                          label: 'COUNT',
                          onTap: () => _applyQuickFormula('COUNT'),
                        ),
                        _buildQuickButton(
                          label: '+ Baris',
                          icon: Icons.add_circle_outline,
                          onTap: () {
                            setState(() {
                              _rowCount++;
                              _isDirty = true;
                            });
                          },
                        ),
                        _buildQuickButton(
                          label: '+ Kolom',
                          icon: Icons.add_circle_outline,
                          onTap: () {
                            if (_colCount < 26) {
                              setState(() {
                                _colCount++;
                                _isDirty = true;
                              });
                            }
                          },
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

  Widget _buildQuickButton({
    required String label,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: AppTheme.sheetGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: AppTheme.sheetGreen),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.sheetGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridTable(bool isDark) {
    const double colWidth = 100.0;
    const double rowHeight = 36.0;
    const double indexColWidth = 42.0;

    return Table(
      defaultColumnWidth: const FixedColumnWidth(colWidth),
      columnWidths: const {0: FixedColumnWidth(indexColWidth)},
      border: TableBorder.all(
        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        width: 1,
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
          ),
          children: [
            Container(
              height: rowHeight,
              alignment: Alignment.center,
              child: const Icon(Icons.grid_on, size: 14, color: Colors.grey),
            ),
            for (int c = 0; c < _colCount; c++)
              Container(
                height: rowHeight,
                alignment: Alignment.center,
                child: Text(
                  _colName(c),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),

        for (int r = 1; r <= _rowCount; r++)
          TableRow(
            children: [
              Container(
                height: rowHeight,
                alignment: Alignment.center,
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                child: Text(
                  '$r',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),

              for (int c = 0; c < _colCount; c++)
                _buildCellWidget(
                  colLetter: _colName(c),
                  rowNumber: r,
                  rowHeight: rowHeight,
                  isDark: isDark,
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCellWidget({
    required String colLetter,
    required int rowNumber,
    required double rowHeight,
    required bool isDark,
  }) {
    final cellKey = '$colLetter$rowNumber';
    final isSelected = _selectedCell == cellKey;
    final rawVal = _cells[cellKey] ?? '';

    final displayVal = FormulaEngine.evaluate(
      formulaOrVal: rawVal,
      cells: _cells,
    );

    final isNumeric = double.tryParse(displayVal) != null;
    final isError = displayVal.startsWith('#');

    return InkWell(
      onTap: () => _onCellTapped(cellKey),
      child: Container(
        height: rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.sheetGreen.withValues(alpha: 0.15)
              : (isDark ? AppTheme.darkSurface : Colors.white),
          border: isSelected
              ? Border.all(color: AppTheme.sheetGreen, width: 2)
              : null,
        ),
        alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          displayVal,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isError
                ? Colors.redAccent
                : (isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary),
            fontFamily: isNumeric ? 'monospace' : null,
          ),
        ),
      ),
    );
  }
}
