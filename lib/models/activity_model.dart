class ActivityModel {
  final String id;
  final String businessId;
  final String title;
  final String description;
  final String category;
  final double price;
  final String location;
  final String imageUrl;
  final List<String> imageUrls; // gallery images
  final double rating;
  final int reviewCount;
  final String duration;
  final int maxGuests;
  final int spotsLeft;
  final DateTime dateTime;
  final DateTime? startAt; // optional: explicit start datetime
  final DateTime? endAt; // optional: explicit end datetime
  final bool isInstantBooking;
  final bool isPublic;
  final List<String> features;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  ActivityModel({
    required this.id,
    required this.businessId,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.location,
    required this.imageUrl,
    required this.imageUrls,
    required this.rating,
    required this.reviewCount,
    required this.duration,
    required this.maxGuests,
    required this.spotsLeft,
    required this.dateTime,
    this.startAt,
    this.endAt,
    required this.isInstantBooking,
    required this.isPublic,
    required this.features,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) => ActivityModel(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
    price: (json['price'] as num).toDouble(),
    location: json['location'] as String,
    imageUrl: json['image_url'] as String,
    // Prefer new 'gallery_images' column; fallback to legacy 'image_urls'
    imageUrls: (json['gallery_images'] is List)
        ? List<String>.from(json['gallery_images'] as List)
        : (json['image_urls'] is List)
            ? List<String>.from(json['image_urls'] as List)
            : <String>[],
    rating: (json['rating'] as num).toDouble(),
    reviewCount: json['review_count'] as int,
    duration: json['duration'] as String,
    maxGuests: json['max_guests'] as int,
    spotsLeft: json['spots_left'] as int,
    dateTime: DateTime.parse(json['date_time'] as String),
    startAt: json['start_at'] != null ? DateTime.tryParse(json['start_at'] as String) : null,
    endAt: json['end_at'] != null ? DateTime.tryParse(json['end_at'] as String) : null,
    isInstantBooking: json['is_instant_booking'] as bool,
    isPublic: json['is_public'] as bool,
    features: List<String>.from(json['features'] as List),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'business_id': businessId,
    'title': title,
    'description': description,
    'category': category,
    'price': price,
    'location': location,
    'image_url': imageUrl,
    // Write to new column name
    'gallery_images': imageUrls,
    'rating': rating,
    'review_count': reviewCount,
    'duration': duration,
    'max_guests': maxGuests,
    'spots_left': spotsLeft,
    'date_time': dateTime.toIso8601String(),
    if (startAt != null) 'start_at': startAt!.toIso8601String(),
    if (endAt != null) 'end_at': endAt!.toIso8601String(),
    'is_instant_booking': isInstantBooking,
    'is_public': isPublic,
    'features': features,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  ActivityModel copyWith({
    String? id,
    String? businessId,
    String? title,
    String? description,
    String? category,
    double? price,
    String? location,
    String? imageUrl,
    List<String>? imageUrls,
    double? rating,
    int? reviewCount,
    String? duration,
    int? maxGuests,
    int? spotsLeft,
    DateTime? dateTime,
    DateTime? startAt,
    DateTime? endAt,
    bool? isInstantBooking,
    bool? isPublic,
    List<String>? features,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ActivityModel(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    price: price ?? this.price,
    location: location ?? this.location,
    imageUrl: imageUrl ?? this.imageUrl,
    imageUrls: imageUrls ?? this.imageUrls,
    rating: rating ?? this.rating,
    reviewCount: reviewCount ?? this.reviewCount,
    duration: duration ?? this.duration,
    maxGuests: maxGuests ?? this.maxGuests,
    spotsLeft: spotsLeft ?? this.spotsLeft,
    dateTime: dateTime ?? this.dateTime,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    isInstantBooking: isInstantBooking ?? this.isInstantBooking,
    isPublic: isPublic ?? this.isPublic,
    features: features ?? this.features,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
