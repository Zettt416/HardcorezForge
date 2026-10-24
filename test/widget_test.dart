import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardcorez_forge/core/models/document_model.dart';
import 'package:hardcorez_forge/core/theme/app_theme.dart';
import 'package:hardcorez_forge/features/word_editor/word_editor_screen.dart';
import 'package:hardcorez_forge/features/spreadsheet/spreadsheet_screen.dart';
import 'package:hardcorez_forge/features/signature/signature_screen.dart';
import 'package:hardcorez_forge/features/splash/splash_screen.dart';
import 'package:hardcorez_forge/features/home/app_guide_overlay.dart';
import 'package:hardcorez_forge/features/markdown/markdown_reader_screen.dart';
import 'package:hardcorez_forge/features/presentation/presentation_screen.dart';
import 'package:hardcorez_forge/features/pdf_tools/pdf_reader_screen.dart';

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
    testWidgets(
      'Renders toolbar, slider, and stamps without overflow on narrow screen',
      (tester) async {
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
      },
    );
  });

  group('SplashScreen Layout Test', () {
    testWidgets('Renders properly without overflow on short screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      expect(find.text('Mulai Bekerja'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppGuideOverlay Layout & Navigation Test', () {
    testWidgets('Renders guide overlay and navigates steps cleanly', (
      tester,
    ) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AppGuideOverlay(onDismiss: () => dismissed = true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 1 check
      expect(find.text('LANGKAH 1 DARI 3'), findsOneWidget);
      expect(find.text('Modul Office Cepat'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);

      // Tap Lanjut to go to Step 2
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('LANGKAH 2 DARI 3'), findsOneWidget);
      expect(find.text('Pindai & Impor Berkas HP'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);

      // Tap Lanjut to go to Step 3
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('LANGKAH 3 DARI 3'), findsOneWidget);
      expect(find.text('Tanda Tangan & Stempel Resmi'), findsOneWidget);
      expect(find.text('Mulai Bekerja'), findsOneWidget);

      // Tap Mulai Bekerja to finish
      await tester.tap(find.text('Mulai Bekerja'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders guide overlay seamlessly in Light Theme', (
      tester,
    ) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppGuideOverlay(onDismiss: () => dismissed = true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LANGKAH 1 DARI 3'), findsOneWidget);
      expect(find.text('Modul Office Cepat'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);

      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('MarkdownReaderScreen Test', () {
    testWidgets('Renders parsed markdown elements smoothly in reader mode', (
      tester,
    ) async {
      final doc = DocumentModel(
        id: 'md_test_1',
        title: 'README.md',
        type: DocType.word,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        content:
            '# HardcorezForge Office\n\n'
            'Suite kantor mobile mandiri.\n\n'
            '## Fitur Unggulan\n'
            '- 100% Offline\n'
            '- Tanpa iklan\n\n'
            '```dart\n'
            'void main() => print("Hello");\n'
            '```\n\n'
            '> Catatan penting privasi berkas.\n',
        filePath: '/storage/emulated/0/Download/README.md',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MarkdownReaderScreen(document: doc),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('README.md'), findsOneWidget);
      expect(find.text('MARKDOWN'), findsOneWidget);
      expect(find.text('HardcorezForge Office'), findsOneWidget);
      expect(find.text('Fitur Unggulan'), findsOneWidget);
      expect(find.text('Catatan penting privasi berkas.'), findsOneWidget);
      expect(find.text('Salin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Shows full title bottom sheet when header title is held', (
      tester,
    ) async {
      const longTitle =
          'Dokumen_Laporan_Akhir_Tahun_2026_Analisis_Komprehensif_HardcorezForge_Final_Revisi_V3.md';
      final doc = DocumentModel(
        id: 'md_long_title',
        title: longTitle,
        type: DocType.word,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        content: '# Test Konten\n\nIsi tes',
        filePath: '/storage/emulated/0/Download/$longTitle',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MarkdownReaderScreen(document: doc),
        ),
      );

      await tester.pumpAndSettle();

      // Long press on header title
      await tester.longPress(find.text(longTitle));
      await tester.pumpAndSettle();

      // Verify bottom sheet appears with full title and copy button
      expect(find.text('Nama Lengkap Dokumen'), findsOneWidget);
      expect(find.text('Salin Nama Berkas'), findsOneWidget);
      expect(find.text(longTitle), findsNWidgets(2)); // in header and sheet
      expect(tester.takeException(), isNull);
    });
  });

  group('Harmonized Document Headers Test', () {
    testWidgets(
      'PresentationScreen renders POWERPOINT badge and status strip',
      (tester) async {
        final doc = DocumentModel(
          id: 'ppt_test',
          title: 'Presentasi Strategi 2026',
          type: DocType.presentation,
          updatedAt: DateTime.now(),
          createdAt: DateTime.now(),
          content: '',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: PresentationScreen(document: doc),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('POWERPOINT'), findsOneWidget);
        expect(find.text('16:9'), findsOneWidget);
        expect(find.text('Presentasi Strategi 2026'), findsOneWidget);
      },
    );

    testWidgets('PdfReaderScreen renders PDF badge and status strip', (
      tester,
    ) async {
      final doc = DocumentModel(
        id: 'pdf_test',
        title: 'Buku Panduan Pengguna.pdf',
        type: DocType.pdf,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        content: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PdfReaderScreen(document: doc),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Hal. 1 dari 1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Buku Panduan Pengguna.pdf'),
        ),
        findsOneWidget,
      );
    });
  });
}
