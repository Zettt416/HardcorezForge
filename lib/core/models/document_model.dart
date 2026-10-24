import 'dart:convert';

enum DocType {
  word,
  sheet,
  presentation,
  pdf;

  String get displayName {
    switch (this) {
      case DocType.word:
        return 'Dokumen';
      case DocType.sheet:
        return 'Lembar Kerja';
      case DocType.presentation:
        return 'Presentasi';
      case DocType.pdf:
        return 'PDF';
    }
  }

  String get extension {
    switch (this) {
      case DocType.word:
        return '.docx';
      case DocType.sheet:
        return '.xlsx';
      case DocType.presentation:
        return '.pptx';
      case DocType.pdf:
        return '.pdf';
    }
  }
}

class DocumentModel {
  final String id;
  String title;
  final DocType type;
  DateTime updatedAt;
  final DateTime createdAt;
  String content; // JSON string or plain text content
  bool isStarred;
  int sizeInBytes;
  String? filePath;

  DocumentModel({
    required this.id,
    required this.title,
    required this.type,
    required this.updatedAt,
    required this.createdAt,
    required this.content,
    this.isStarred = false,
    this.sizeInBytes = 0,
    this.filePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'updatedAt': updatedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'content': content,
      'isStarred': isStarred,
      'sizeInBytes': sizeInBytes,
      'filePath': filePath,
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'] as String,
      title: map['title'] as String,
      type: DocType.values.byName(map['type'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      content: map['content'] as String,
      isStarred: map['isStarred'] as bool? ?? false,
      sizeInBytes: map['sizeInBytes'] as int? ?? 0,
      filePath: map['filePath'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory DocumentModel.fromJson(String source) =>
      DocumentModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
