import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardcorez_forge/core/models/document_model.dart';
import 'package:hardcorez_forge/core/theme/app_theme.dart';
import 'package:hardcorez_forge/features/word_editor/word_editor_screen.dart';
import 'package:hardcorez_forge/features/spreadsheet/spreadsheet_screen.dart';
import 'package:hardcorez_forge/features/signature/signature_screen.dart';
import 'package:hardcorez_forge/features/splash/splash_screen.dart';

void main() {
  group('DocumentModel serialization', () {
    test('Correctly serializes and deserializes', () {
      final now = DateTime.now();
      final doc = DocumentModel(
        id: 'test_1',
        title: 'Laporan Keuangan',
        type: DocType.sheet,
        updatedAt: now,
        createdAt: now,
        content: '{"rows": 10}',
        isStarred: true,
        sizeInBytes: 1024,
      );

      final jsonStr = doc.toJson();
      final revived = DocumentModel.fromJson(jsonStr);

      expect(revived.id, 'test_1');
      expect(revived.title, 'Laporan Keuangan');
      expect(revived.type, DocType.sheet);
      expect(revived.isStarred, true);
      expect(revived.sizeInBytes, 1024);
    });
  });

  group('WordEditorScreen Widget Test', () {
    testWidgets('Renders word editor canvas and toolbar', (tester) async {
      final doc = DocumentModel(
        id: 'word_1',
        title: 'Naskah Uji',
        type: DocType.word,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        content: 'Halo Dunia!',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: WordEditorScreen(document: doc),
        ),
      );

      expect(find.text('Naskah Uji'), findsOneWidget);
      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      expect(find.byIcon(Icons.format_italic), findsOneWidget);
    });
  });

  group('SpreadsheetScreen Widget Test', () {
    testWidgets('Renders spreadsheet grid and formula bar', (tester) async {
      final doc = DocumentModel(
        id: 'sheet_1',
        title: 'Tabel Uji',
        type: DocType.sheet,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        content: '{"rows": 5, "cols": 4, "cells": {"A1": "100"}}',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SpreadsheetScreen(document: doc),
        ),
      );

      expect(find.text('Tabel Uji'), findsOneWidget);
      expect(find.text('fx'), findsOneWidget);
      expect(find.text('∑ SUM'), findsOneWidget);
    });
  });

  group('SignatureScreen Layout Test', () {
    testWidgets('Renders toolbar, slider, and stamps without overflow on narrow screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SignatureScreen(),
        ),
      );

      expect(find.text('Tanda Tangan & Stempel'), findsOneWidget);
      expect(find.text('Tinta:'), findsOneWidget);
      expect(find.text('Tebal:'), findsOneWidget);
      expect(find.text('Stempel:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SplashScreen Layout Test', () {
    testWidgets('Renders properly without overflow on short screen', (tester) async {
      tester.view.physicalSize = const Size(360, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      expect(find.text('Mulai Bekerja'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
