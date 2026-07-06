class ArticleModel {
  final String id;
  final String title;
  final String content;
  final String category;
  final String readTime;
  final String image;
  final List<String> bookmarks;

  ArticleModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.readTime,
    required this.image,
    required this.bookmarks,
  });

  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    return ArticleModel(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? '',
      readTime: json['readTime'] ?? '5 mins read',
      image: json['image'] ?? '',
      bookmarks: List<String>.from(json['bookmarks'] ?? []),
    );
  }
}
