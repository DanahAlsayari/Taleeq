
class TechniqueModel {
  final int id;
  final String nameAr;
  final String nameEn;
  final String category;
  final String description;
  final List<String> steps;
  final String? example;
  final List<String> tips;
  final String? audioUrl;
  

  const TechniqueModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.category,
    required this.description,
    required this.steps,
    this.example,
    required this.tips,
    this.audioUrl,

  });

  factory TechniqueModel.fromJson(Map<String, dynamic> json) {
    return TechniqueModel(
      id: json['id'] as int,
      nameAr: json['name_ar'] as String,
      nameEn: json['name_en'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      steps: List<String>.from(json['steps'] as List),
      example: json['example'] as String?,
      tips: List<String>.from(json['tips'] ?? []),
      audioUrl: json['audio_url'] as String?,
    );
  }
}
