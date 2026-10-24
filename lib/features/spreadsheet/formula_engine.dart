class FormulaEngine {
  /// Evaluates cell content. If it starts with '=', computes the formula.
  /// Otherwise returns raw string value.
  static String evaluate({
    required String formulaOrVal,
    required Map<String, String> cells,
    Set<String>? visited,
  }) {
    if (!formulaOrVal.startsWith('=')) {
      return formulaOrVal;
    }

    final expression = formulaOrVal.substring(1).trim().toUpperCase();
    final currentVisited = visited ?? <String>{};

    try {
      // 1. Check Range Functions: SUM(A1:A5), AVG(A1:A5), MIN, MAX, COUNT
      final funcMatch = RegExp(r'^([A-Z]+)\(([A-Z0-9:]+)\)$').firstMatch(expression);
      if (funcMatch != null) {
        final funcName = funcMatch.group(1)!;
        final rangeStr = funcMatch.group(2)!;
        return _evalRangeFunction(funcName, rangeStr, cells, currentVisited);
      }

      // 2. Check Simple Binary Math: A1+B1, A1-B1, A1*B1, A1/B1
      final binOpMatch = RegExp(r'^([A-Z0-9]+)\s*([\+\-\*\/])\s*([A-Z0-9]+)$').firstMatch(expression);
      if (binOpMatch != null) {
        final leftOperand = binOpMatch.group(1)!;
        final op = binOpMatch.group(2)!;
        final rightOperand = binOpMatch.group(3)!;

        final double leftVal = _resolveOperand(leftOperand, cells, currentVisited);
        final double rightVal = _resolveOperand(rightOperand, cells, currentVisited);

        double res = 0;
        switch (op) {
          case '+':
            res = leftVal + rightVal;
            break;
          case '-':
            res = leftVal - rightVal;
            break;
          case '*':
            res = leftVal * rightVal;
            break;
          case '/':
            if (rightVal == 0) return '#DIV/0!';
            res = leftVal / rightVal;
            break;
        }
        return _formatNumber(res);
      }

      // 3. Simple Single Cell Reference e.g. =A1
      if (RegExp(r'^[A-Z]+[0-9]+$').hasMatch(expression)) {
        final refVal = _resolveCell(expression, cells, currentVisited);
        return refVal;
      }

      // Fallback: try parsing as number
      final directNum = double.tryParse(expression);
      if (directNum != null) {
        return _formatNumber(directNum);
      }

      return '#ERROR!';
    } catch (e) {
      return '#ERR';
    }
  }

  static double _resolveOperand(String token, Map<String, String> cells, Set<String> visited) {
    final direct = double.tryParse(token);
    if (direct != null) return direct;

    final cellVal = _resolveCell(token, cells, visited);
    return double.tryParse(cellVal) ?? 0.0;
  }

  static String _resolveCell(String cellKey, Map<String, String> cells, Set<String> visited) {
    if (visited.contains(cellKey)) {
      return '#CIRCULAR!';
    }
    visited.add(cellKey);
    final raw = cells[cellKey] ?? '';
    final result = evaluate(formulaOrVal: raw, cells: cells, visited: visited);
    visited.remove(cellKey);
    return result;
  }

  static String _evalRangeFunction(
    String func,
    String rangeStr,
    Map<String, String> cells,
    Set<String> visited,
  ) {
    final parts = rangeStr.split(':');
    if (parts.length != 2) return '#SYNTAX!';

    final fromCell = parts[0];
    final toCell = parts[1];

    final cellKeys = _expandRange(fromCell, toCell);
    final List<double> numbers = [];

    for (final key in cellKeys) {
      final raw = cells[key] ?? '';
      final evaluated = evaluate(formulaOrVal: raw, cells: cells, visited: visited);
      final num = double.tryParse(evaluated);
      if (num != null) {
        numbers.add(num);
      }
    }

    if (numbers.isEmpty && func != 'COUNT') {
      return '0';
    }

    switch (func) {
      case 'SUM':
        final sum = numbers.fold<double>(0, (prev, curr) => prev + curr);
        return _formatNumber(sum);
      case 'AVG':
      case 'AVERAGE':
        final sum = numbers.fold<double>(0, (prev, curr) => prev + curr);
        return _formatNumber(sum / (numbers.isEmpty ? 1 : numbers.length));
      case 'COUNT':
        return numbers.length.toString();
      case 'MIN':
        final minVal = numbers.reduce((a, b) => a < b ? a : b);
        return _formatNumber(minVal);
      case 'MAX':
        final maxVal = numbers.reduce((a, b) => a > b ? a : b);
        return _formatNumber(maxVal);
      default:
        return '#UNKNOWN!';
    }
  }

  static List<String> _expandRange(String start, String end) {
    final startCol = start.replaceAll(RegExp(r'[0-9]'), '');
    final startRow = int.tryParse(start.replaceAll(RegExp(r'[A-Z]'), '')) ?? 1;

    final endCol = end.replaceAll(RegExp(r'[0-9]'), '');
    final endRow = int.tryParse(end.replaceAll(RegExp(r'[A-Z]'), '')) ?? 1;

    final startColIdx = _colLetterToIndex(startCol);
    final endColIdx = _colLetterToIndex(endCol);

    final List<String> result = [];
    final minCol = startColIdx < endColIdx ? startColIdx : endColIdx;
    final maxCol = startColIdx > endColIdx ? startColIdx : endColIdx;
    final minRow = startRow < endRow ? startRow : endRow;
    final maxRow = startRow > endRow ? startRow : endRow;

    for (int col = minCol; col <= maxCol; col++) {
      final colName = _indexToColLetter(col);
      for (int row = minRow; row <= maxRow; row++) {
        result.add('$colName$row');
      }
    }
    return result;
  }

  static int _colLetterToIndex(String col) {
    int index = 0;
    for (int i = 0; i < col.length; i++) {
      index = index * 26 + (col.codeUnitAt(i) - 64);
    }
    return index;
  }

  static String _indexToColLetter(int index) {
    String res = '';
    while (index > 0) {
      final rem = (index - 1) % 26;
      res = String.fromCharCode(65 + rem) + res;
      index = (index - 1) ~/ 26;
    }
    return res;
  }

  static String _formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }
}
