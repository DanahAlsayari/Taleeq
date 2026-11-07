class ScenarioModel {
  final String id;
  final String name;
  final String description;
  final String instructions;  
  final String videoUrl;
  final int conversationStartTime;
  final bool isActive;

  ScenarioModel({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    required this.videoUrl,
    required this.conversationStartTime,
    required this.isActive,
  });

  factory ScenarioModel.fromJson(Map<String, dynamic> json) {
    return ScenarioModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      instructions: json['instructions'] ?? '',
      videoUrl: json['video_url'] ?? '',
      conversationStartTime:
          (json['conversation_start_time'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] ?? false,
    );
  }
}
