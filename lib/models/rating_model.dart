class RatingModel {
  final String id;
  final String userId;
  final String activityId;
  final int rating; // 1-5 stars
  final String? comment; // optional text review
  final DateTime createdAt;
  final DateTime updatedAt;

  RatingModel({
    required this.id,
    required this.userId,
    required this.activityId,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) => RatingModel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    activityId: json['activity_id'] as String,
    rating: json['rating'] as int,
    comment: json['comment'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'activity_id': activityId,
    'rating': rating,
    if (comment != null) 'comment': comment,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  RatingModel copyWith({
    String? id,
    String? userId,
    String? activityId,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RatingModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    activityId: activityId ?? this.activityId,
    rating: rating ?? this.rating,
    comment: comment ?? this.comment,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
