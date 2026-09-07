import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../config/app_theme.dart';

/// Result of picking a meetup spot — returned via context.pop().
class MeetupPickResult {
  final String address;
  final double lat;
  final double lng;
  final DateTime? scheduledAt;
  MeetupPickResult({required this.address, required this.lat, required this.lng, this.scheduledAt});
}

/// Lets either side of a chat drop a pin on the map to propose a public
/// meetup spot (e.g. student union, a coffee shop) and pick a time to
/// exchange the item and complete payment in person.
class MeetupPickerScreen extends StatefulWidget {
  const MeetupPickerScreen({super.key});

  @override
  State<MeetupPickerScreen> createState() => _MeetupPickerScreenState();
}

class _MeetupPickerScreenState extends State<MeetupPickerScreen> {
  final _mapController = MapController();
  final _addressCtrl   = TextEditingController();

  LatLng _picked = const LatLng(28.6024, -81.2001); // UCF main campus default
  bool _reverseGeocoding = false;
  DateTime? _scheduledAt;

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTapMap(LatLng point) async {
    setState(() { _picked = point; _reverseGeocoding = true; });
    try {
      final res = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json'),
        headers: {'User-Agent': 'KnightMarket/1.0 (student-marketplace-app)'},
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (mounted && data['display_name'] != null) {
        setState(() => _addressCtrl.text = data['display_name']);
      }
    } catch (_) {
      // Reverse geocoding failed — user can still type an address manually
    } finally {
      if (mounted) setState(() => _reverseGeocoding = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _confirm() {
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter or tap a meetup location')),
      );
      return;
    }
    Navigator.pop(context, MeetupPickResult(
      address: _addressCtrl.text.trim(),
      lat: _picked.latitude,
      lng: _picked.longitude,
      scheduledAt: _scheduledAt,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arrange Meetup'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Tap the map to drop a pin at a public place to meet — like a coffee shop or the Student Union.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _picked,
                initialZoom: 15,
                onTap: (_, point) => _onTapMap(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.knightmarket.app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: _picked,
                    width: 44, height: 44,
                    child: const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 44),
                  ),
                ]),
              ],
            ),
          ),
          Container(
            color: AppTheme.bgCard,
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    labelText: 'Meetup location',
                    hintText: 'e.g. Starbucks — Student Union',
                    suffixIcon: _reverseGeocoding
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickDateTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgInput,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.event_rounded, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        _scheduledAt == null ? 'Pick a date & time (optional)' : _scheduledAt.toString(),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    child: const Text('Propose This Meetup'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
