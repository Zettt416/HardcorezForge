import 'package:flutter_test/flutter_test.dart';
import 'package:hardcorez_forge/features/spreadsheet/formula_engine.dart';

void main() {
  group('FormulaEngine Tests', () {
    test('Evaluates plain values correctly', () {
      final cells = {'A1': '100', 'A2': 'Hello'};
      expect(FormulaEngine.evaluate(formulaOrVal: '100', cells: cells), '100');
      expect(
        FormulaEngine.evaluate(formulaOrVal: 'Hello', cells: cells),
        'Hello',
      );
    });

    test('Evaluates simple cell references', () {
      final cells = {'A1': '250', 'B1': '=A1'};
      expect(
        FormulaEngine.evaluate(formulaOrVal: cells['B1']!, cells: cells),
        '250',
      );
    });

    test('Evaluates basic arithmetic operations', () {
      final cells = {'A1': '10', 'B1': '5'};
      expect(
        FormulaEngine.evaluate(formulaOrVal: '=A1+B1', cells: cells),
        '15',
      );
      expect(FormulaEngine.evaluate(formulaOrVal: '=A1-B1', cells: cells), '5');
      expect(
        FormulaEngine.evaluate(formulaOrVal: '=A1*B1', cells: cells),
        '50',
      );
      expect(FormulaEngine.evaluate(formulaOrVal: '=A1/B1', cells: cells), '2');
    });

    test('Handles division by zero gracefully', () {
      final cells = {'A1': '10', 'B1': '0'};
      expect(
        FormulaEngine.evaluate(formulaOrVal: '=A1/B1', cells: cells),
        '#DIV/0!',
      );
    });

    test('Evaluates SUM function across range', () {
      final cells = {'A1': '10', 'A2': '20', 'A3': '30'};
      expect(
        FormulaEngine.evaluate(formulaOrVal: '=SUM(A1:A3)', cells: cells),
        '60',
      );
    });

    test('Evaluates AVG function across range', () {
      final cells = {'B1': '10', 'B2': '20', 'B3': '30'};
      expect(
        FormulaEngine.evaluate(formulaOrVal: '=AVG(B1:B3)', cells: cells),
        '20',
      );
    });

    test('Evaluates COUNT, MIN, and MAX', () {
      final cells = {'C1': '15', 'C2': '5', 'C3': '25'};
      expect(
        FormulaEngine.evaluate(formulaOrVal: '=COUNT(C1:C3)', cells: cells),
        '3',
      );
      expect(
        FormulaEngine.evaluate(formulaOrVal: '=MIN(C1:C3)', cells: cells),
        '5',
      );
      expect(
        FormulaEngine.evaluate(formulaOrVal: '=MAX(C1:C3)', cells: cells),
        '25',
      );
    });
  });
}
