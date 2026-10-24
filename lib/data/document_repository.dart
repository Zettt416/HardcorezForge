import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../core/models/document_model.dart';

class DocumentRepository {
  static final DocumentRepository instance = DocumentRepository._internal();
  DocumentRepository._internal();

  final List<DocumentModel> _cachedDocs = [];
  bool _isInitialized = false;

  List<DocumentModel> get documents => List.unmodifiable(_cachedDocs);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = json.decode(content) as List<dynamic>;
          _cachedDocs.clear();
          for (final item in jsonList) {
            final doc = DocumentModel.fromMap(item as Map<String, dynamic>);
            _cachedDocs.add(doc);
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading stored documents: $e');
    }

    _isInitialized = true;
  }

  Future<File> _getStorageFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/hardcorez_documents.json');
  }

  Future<void> _persist() async {
    try {
      final file = await _getStorageFile();
      final jsonList = _cachedDocs.map((e) => e.toMap()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Error persisting documents: $e');
    }
  }

  Future<void> saveDocument(DocumentModel doc) async {
    final index = _cachedDocs.indexWhere((e) => e.id == doc.id);
    doc.updatedAt = DateTime.now();
    if (index >= 0) {
      _cachedDocs[index] = doc;
    } else {
      _cachedDocs.insert(0, doc);
    }
    await _persist();
  }

  Future<void> deleteDocument(String id) async {
    _cachedDocs.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<DocumentModel?> duplicateDocument(String id) async {
    final index = _cachedDocs.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final original = _cachedDocs[index];
      final now = DateTime.now();
      final duplicated = DocumentModel(
        id: 'doc_${now.millisecondsSinceEpoch}',
        title: '${original.title} (Salinan)',
        type: original.type,
        updatedAt: now,
        createdAt: now,
        content: original.content,
        isStarred: false,
        sizeInBytes: original.sizeInBytes,
        filePath: original.filePath,
      );
      _cachedDocs.insert(0, duplicated);
      await _persist();
      return duplicated;
    }
    return null;
  }

  Future<void> toggleStar(String id) async {
    final index = _cachedDocs.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _cachedDocs[index].isStarred = !_cachedDocs[index].isStarred;
      await _persist();
    }
  }

  Future<void> renameDocument(String id, String newTitle) async {
    final index = _cachedDocs.indexWhere((e) => e.id == id);
    if (index >= 0 && newTitle.trim().isNotEmpty) {
      _cachedDocs[index].title = newTitle.trim();
      _cachedDocs[index].updatedAt = DateTime.now();
      await _persist();
    }
  }
}
