import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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

    // Save back to physical CSV/TSV file if imported from device
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
    // E.g. SUM for column above selected cell
    final col = _selectedCell.replaceAll(RegExp(r'[0-9]'), '');
    final row =
        int.tryParse(_selectedCell.replaceAll(RegExp(r'[A-Z]'), '')) ?? 1;

    if (row > 1) {
      final formula = '=$formulaType(${col}1:$col${row - 1})';
      _formulaController.text = formula;
      _updateCellValue(formula);
    }
  }

  void _exportCSV() {
    final buffer = StringBuffer();
    for (int r = 1; r <= _rowCount; r++) {
      final rowVals = <String>[];
      for (int c = 0; c < _colCount; c++) {
        final key = '${_colName(c)}$r';
        final val = FormulaEngine.evaluate(
          formulaOrVal: _cells[key] ?? '',
          cells: _cells,
        );
        // Escape quotes
        rowVals.add('"${val.replaceAll('"', '""')}"');
      }
      buffer.writeln(rowVals.join(','));
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ekspor CSV Selesai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pratinjau data CSV:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                buffer.toString().split('\n').take(6).join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.sheetGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              PlatformShare.shareText(
                text: buffer.toString(),
                title: 'Ekspor ${widget.document.title}.csv',
              );
            },
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Bagikan CSV'),
          ),
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
          await _saveSheet(silent: true);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkBg : Colors.white,
          foregroundColor: isDark
              ? AppTheme.darkTextPrimary
              : AppTheme.lightTextPrimary,
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
                  color: isDark
                      ? AppTheme.sheetGreen.withValues(alpha: 0.2)
                      : AppTheme.sheetGreenLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.sheetGreen.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: AppTheme.sheetGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: -0.2,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Nama Lembar Kerja',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
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
                Icons.file_download_outlined,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
              tooltip: 'Ekspor CSV',
              onPressed: _exportCSV,
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
                            ? AppTheme.sheetGreen
                            : (isDark
                                  ? AppTheme.darkSurface
                                  : const Color(0xFFE2E8F0)),
                        foregroundColor: _isDirty
                            ? Colors.white
                            : (isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      icon: Icon(
                        Icons.save_rounded,
                        size: 16,
                        color: _isDirty
                            ? Colors.white
                            : (isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary),
                      ),
                      label: Text(
                        _isDirty ? 'Simpan' : 'Tersimpan',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: _saveSheet,
                    ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Formula Bar (fx)
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

            // Spreadsheet Interactive Grid
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildGridTable(isDark),
                ),
              ),
            ),

            // Bottom Quick Bar for Formulas & Actions
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
        // Header Row (Column Names: A, B, C...)
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

        // Data Rows
        for (int r = 1; r <= _rowCount; r++)
          TableRow(
            children: [
              // Row Index (1, 2, 3...)
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

              // Cells
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

    // Calculate formula display
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
