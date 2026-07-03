class DocumentModel {
  final String name;
  final String url;
  final String size;

  DocumentModel({
    required this.name,
    required this.url,
    required this.size,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      size: json['size'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'size': size,
    };
  }
}
