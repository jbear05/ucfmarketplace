import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/meetup_spots.dart';

/// Result of picking a meetup spot — returned via context.pop().
class MeetupPickResult {
  final String address;
  final double? lat;
  final double? lng;
  final DateTime? scheduledAt;
  MeetupPickResult({required this.address, this.lat, this.lng, this.scheduledAt});
}

/// Lets either side of a chat pick a meetup spot from the curated,
/// safety-vetted campus list — not an open map. Students already know
/// where these buildings are, so the list is just names, not directions.
class MeetupPickerScreen extends StatefulWidget {
  const MeetupPickerScreen({super.key});

  @override
  State<MeetupPickerScreen> createState() => _MeetupPickerScreenState();
}

class _MeetupPickerScreenState extends State<MeetupPickerScreen> {
  final _detailCtrl = TextEditingController();
  MeetupSpot? _selected;
  DateTime? _scheduledAt;

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
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
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a meetup spot')),
      );
      return;
    }
    final detail = _detailCtrl.text.trim();
    final address = detail.isEmpty ? _selected!.name : '${_selected!.name} — $detail';
    Navigator.pop(context, MeetupPickResult(
      address: address,
      lat: _selected!.lat,
      lng: _selected!.lng,
      scheduledAt: _scheduledAt,
    ));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arrange Meetup'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pick a public campus spot to meet — these are all vetted, well-trafficked locations.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 20),
              Text('Meetup spot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<MeetupSpot>(
                initialValue: _selected,
                isExpanded: true,
                decoration: const InputDecoration(hintText: 'Choose a spot'),
                items: kMeetupSpots.map((spot) => DropdownMenuItem(
                  value: spot,
                  child: Text(spot.name, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (spot) => setState(() => _selected = spot),
              ),
              if (_selected?.hours != null) ...[
                const SizedBox(height: 6),
                Text(_selected!.hours!,
                    style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _detailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Extra detail (optional)',
                  hintText: 'e.g. 2nd floor coffee shop, near the printers',
                ),
              ),
              const SizedBox(height: 16),
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
                    Icon(Icons.event_rounded, size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      _scheduledAt == null ? 'Pick a date & time (optional)' : _scheduledAt.toString(),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
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
      ),
    );
  }
}
