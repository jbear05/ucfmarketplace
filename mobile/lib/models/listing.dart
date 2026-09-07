class ListingOwner {
  final String id;
  final String name;
  final bool isVerifiedStudent;
  final double ratingAvg;
  final int ratingCount;

  ListingOwner({
    required this.id,
    required this.name,
    this.isVerifiedStudent = false,
    this.ratingAvg = 0,
    this.ratingCount = 0,
  });

  factory ListingOwner.fromJson(Map<String, dynamic> json) => ListingOwner(
    id:                json['_id'] ?? json['id'] ?? '',
    name:              json['name'] ?? '',
    isVerifiedStudent: json['isVerifiedStudent'] ?? false,
    ratingAvg:         (json['ratingAvg'] ?? 0).toDouble(),
    ratingCount:       json['ratingCount'] ?? 0,
  );
}

class ListingCoordinates {
  final double lat;
  final double lng;
  ListingCoordinates({required this.lat, required this.lng});
}

const List<String> kListingCategories = [
  'Textbooks', 'Electronics', 'Furniture', 'Clothing',
  'Dorm & Home', 'Tickets & Events', 'Vehicles', 'Other',
];

const List<String> kListingConditions = ['New', 'Like New', 'Good', 'Fair', 'Poor'];

class Listing {
  final String id;
  final String title;
  final String description;
  final double price;
  final String category;
  final String condition;
  final String meetupArea;
  final List<String> images;
  final String status;
  final ListingOwner? owner;
  final ListingCoordinates? coordinates;
  final bool isBoosted;
  final DateTime createdAt;
  final int favoriteCount;

  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.condition,
    required this.meetupArea,
    required this.images,
    required this.status,
    this.owner,
    this.coordinates,
    this.isBoosted = false,
    required this.createdAt,
    this.favoriteCount = 0,
  });

  String  get mainImage     => images.isNotEmpty ? images.first : '';
  bool    get ownerVerified => owner?.isVerifiedStudent ?? false;

  Listing copyWith({String? status}) => Listing(
    id: id, title: title, description: description, price: price,
    category: category, condition: condition, meetupArea: meetupArea,
    images: images, status: status ?? this.status, owner: owner,
    coordinates: coordinates, isBoosted: isBoosted,
    createdAt: createdAt, favoriteCount: favoriteCount,
  );

  factory Listing.fromJson(Map<String, dynamic> json) {
    final ownerData = json['owner'];
    final loc       = json['coordinates'] ?? json['location'];
    ListingCoordinates? coords;
    if (loc != null && loc['coordinates'] is List) {
      final c = List<dynamic>.from(loc['coordinates']);
      if (c.length == 2 && (c[0] != 0 || c[1] != 0)) {
        coords = ListingCoordinates(lat: c[1].toDouble(), lng: c[0].toDouble());
      }
    }
    return Listing(
      id:          json['_id'] ?? json['id'] ?? '',
      title:       json['title'] ?? '',
      description: json['description'] ?? '',
      price:       (json['price'] ?? 0).toDouble(),
      category:    json['category'] ?? 'Other',
      condition:   json['condition'] ?? 'Good',
      meetupArea:  json['meetupArea'] ?? '',
      images:      List<String>.from(json['images'] ?? []),
      status:      json['status'] ?? 'active',
      owner:       ownerData is Map ? ListingOwner.fromJson(ownerData as Map<String, dynamic>) : null,
      coordinates: coords,
      isBoosted:   json['isBoosted'] ?? false,
      createdAt:   DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      favoriteCount: json['favoriteCount'] ?? 0,
    );
  }
}
