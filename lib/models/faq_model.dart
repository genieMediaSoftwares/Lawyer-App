class FaqModel {
  final String id;
  final String question;
  final String answer;
  final String category;

  FaqModel({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
  });

  factory FaqModel.fromJson(Map<String, dynamic> json) {
    return FaqModel(
      id: json['_id'] ?? '',
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      category: json['category'] ?? '',
    );
  }
}
