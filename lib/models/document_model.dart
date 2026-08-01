class DocumentModel {
  final String name;
  final String url;
  final String size;
  final String? category;
  final String? uploadedBy;

  DocumentModel({
    required this.name,
    required this.url,
    required this.size,
    this.category,
    this.uploadedBy,
  });

  String get title => name.isNotEmpty ? name : 'Legal Document';
  String get fileName => name.isNotEmpty ? name : 'document.pdf';
  String get fileSize => size.isNotEmpty ? size : '2.4 MB';
  String get docCategory =>
      (category != null && category!.isNotEmpty) ? category! : 'Property';
  String get docUploadedBy => (uploadedBy != null && uploadedBy!.isNotEmpty)
      ? uploadedBy!
      : 'Client User';

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map<String, dynamic> ? json['user'] : {};
    return DocumentModel(
      name: json['name'] ?? json['title'] ?? json['fileName'] ?? '',
      url: json['url'] ?? json['path'] ?? '',
      size: json['size'] ?? json['fileSize'] ?? '2.4 MB',
      category: json['category'] ?? 'Property',
      uploadedBy: userMap['fullName'] ?? json['uploadedBy'] ?? 'Client User',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'size': size,
      'category': category,
      'uploadedBy': uploadedBy,
    };
  }
}
