/// Curated public meetup spots offered in the meetup picker.
/// Coordinates are approximate building locations.
class MeetupSpot {
  final String name;
  final double? lat;
  final double? lng;
  final String? hours;
  const MeetupSpot({required this.name, this.lat, this.lng, this.hours});
}

const List<MeetupSpot> kMeetupSpots = [
  MeetupSpot(name: 'UCF Police Department lobby', lat: 28.6077, lng: -81.1973),
  MeetupSpot(name: 'Student Union',               lat: 28.6016, lng: -81.2005),
  MeetupSpot(name: 'John C. Hitt Library',        lat: 28.6003, lng: -81.2015),
  MeetupSpot(name: 'Recreation & Wellness Center', lat: 28.5958, lng: -81.1995),
  MeetupSpot(name: 'Knights Plaza',               lat: 28.6074, lng: -81.1968),
  MeetupSpot(name: 'UCF Downtown — UnionWest',    lat: 28.5450, lng: -81.3880),
  MeetupSpot(name: 'Rosen College lobby',         lat: 28.4283, lng: -81.4422),
  MeetupSpot(name: 'Lake Nona — College of Medicine', lat: 28.3683, lng: -81.2797),
];
