/// Recipe model — соответствует схеме `Recipe` из foodapi 0.2.0
/// (https://app.swaggerhub.com/apis/dzolotov/foodapi/0.2.0).
class Recipe {
  final int id;
  final String name;

  /// Длительность приготовления в минутах.
  final int duration;

  /// URL фотографии блюда.
  final String photo;

  /// Описание / шаги приготовления.
  final String description;

  const Recipe({
    required this.id,
    required this.name,
    required this.duration,
    required this.photo,
    required this.description,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as int,
      name: json['name'] as String,
      duration: json['duration'] as int,
      photo: json['photo'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'duration': duration,
    'photo': photo,
    'description': description,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recipe &&
          other.id == id &&
          other.name == name &&
          other.duration == duration &&
          other.photo == photo &&
          other.description == description;

  @override
  int get hashCode => Object.hash(id, name, duration, photo, description);
}
