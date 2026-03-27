class BookingModel {
  final String id;
  final String userId;
  final String activityId;
  final String activityTitle;
  final String activityImage;
  final String location;
  final double price;
  final DateTime dateTime;
  final BookingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  BookingModel({
    required this.id,
    required this.userId,
    required this.activityId,
    required this.activityTitle,
    required this.activityImage,
    required this.location,
    required this.price,
    required this.dateTime,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    activityId: json['activity_id'] as String,
    activityTitle: json['activity_title'] as String,
    activityImage: json['activity_image'] as String,
    location: json['location'] as String,
    price: (json['price'] as num).toDouble(),
    dateTime: DateTime.parse(json['date_time'] as String),
    status: BookingStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => BookingStatus.pending),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'activity_id': activityId,
    'activity_title': activityTitle,
    'activity_image': activityImage,
    'location': location,
    'price': price,
    'date_time': dateTime.toIso8601String(),
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  BookingModel copyWith({
    String? id,
    String? userId,
    String? activityId,
    String? activityTitle,
    String? activityImage,
    String? location,
    double? price,
    DateTime? dateTime,
    BookingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BookingModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    activityId: activityId ?? this.activityId,
    activityTitle: activityTitle ?? this.activityTitle,
    activityImage: activityImage ?? this.activityImage,
    location: location ?? this.location,
    price: price ?? this.price,
    dateTime: dateTime ?? this.dateTime,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

enum BookingStatus {
  pending,
  confirmed,
  completed,
  cancelled
}
