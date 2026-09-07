class ThreadParticipant {
  final String id;
  final String name;
  final bool isVerifiedStudent;

  ThreadParticipant({required this.id, required this.name, this.isVerifiedStudent = false});

  factory ThreadParticipant.fromJson(Map<String, dynamic> json) => ThreadParticipant(
    id:                json['_id'] ?? '',
    name:              json['name'] ?? '',
    isVerifiedStudent: json['isVerifiedStudent'] ?? false,
  );
}

class ListingSnapshot {
  final String id;
  final String title;
  final double price;
  final String? mainImage;
  final String status;

  ListingSnapshot({
    required this.id,
    required this.title,
    required this.price,
    this.mainImage,
    required this.status,
  });

  factory ListingSnapshot.fromJson(Map<String, dynamic> json) => ListingSnapshot(
    id:        json['_id'] ?? '',
    title:     json['title'] ?? '',
    price:     (json['price'] ?? 0).toDouble(),
    mainImage: json['mainImage'],
    status:    json['status'] ?? 'active',
  );
}

class ThreadMeetup {
  final double? lat;
  final double? lng;
  final String? address;
  final DateTime? scheduledAt;
  final String proposedBy; // user id
  final String status; // none | proposed | confirmed | completed | cancelled
  final List<String> confirmedBy;

  ThreadMeetup({
    this.lat,
    this.lng,
    this.address,
    this.scheduledAt,
    this.proposedBy = '',
    this.status = 'none',
    this.confirmedBy = const [],
  });

  bool get isActive => status == 'proposed' || status == 'confirmed';

  factory ThreadMeetup.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ThreadMeetup();
    final loc = json['location'];
    double? lat, lng;
    if (loc != null && loc['coordinates'] is List) {
      final c = List<dynamic>.from(loc['coordinates']);
      if (c.length == 2) {
        lng = (c[0] as num).toDouble();
        lat = (c[1] as num).toDouble();
      }
    }
    return ThreadMeetup(
      lat: lat,
      lng: lng,
      address: json['address'],
      scheduledAt: json['scheduledAt'] != null ? DateTime.tryParse(json['scheduledAt']) : null,
      proposedBy: (json['proposedBy'] ?? '').toString(),
      status: json['status'] ?? 'none',
      confirmedBy: (json['confirmedBy'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class Thread {
  final String id;
  final List<ThreadParticipant> participants;
  final ListingSnapshot? listingSnapshot;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isBlocked;
  final ThreadMeetup meetup;

  Thread({
    required this.id,
    required this.participants,
    this.listingSnapshot,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isBlocked = false,
    ThreadMeetup? meetup,
  }) : meetup = meetup ?? ThreadMeetup();

  factory Thread.fromJson(Map<String, dynamic> json) => Thread(
    id:              json['_id'] ?? '',
    participants:    (json['participants'] as List? ?? [])
        .map((p) => ThreadParticipant.fromJson(p))
        .toList(),
    listingSnapshot: json['listingSnapshot'] != null
        ? ListingSnapshot.fromJson(json['listingSnapshot'])
        : null,
    lastMessage:    json['lastMessage'],
    lastMessageAt:  json['lastMessageAt'] != null
        ? DateTime.tryParse(json['lastMessageAt'])
        : null,
    unreadCount:    json['unreadCount'] ?? 0,
    isBlocked:      json['isBlocked'] ?? false,
    meetup:         ThreadMeetup.fromJson(json['meetup']),
  );

  Thread copyWith({int? unreadCount, bool? isBlocked, String? lastMessage, DateTime? lastMessageAt, ThreadMeetup? meetup}) => Thread(
    id:              id,
    participants:    participants,
    listingSnapshot: listingSnapshot,
    lastMessage:     lastMessage ?? this.lastMessage,
    lastMessageAt:   lastMessageAt ?? this.lastMessageAt,
    unreadCount:     unreadCount ?? this.unreadCount,
    isBlocked:       isBlocked ?? this.isBlocked,
    meetup:          meetup ?? this.meetup,
  );
}
