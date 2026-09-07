import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../config/app_theme.dart';
import '../../models/listing.dart';
import '../../services/api_service.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _api      = ApiService();
  bool _isSubmitting = false;

  // Images — max 3, cover is index 0 after reorder
  List<XFile>  _images     = [];
  List<Uint8List> _previews = []; // web-safe byte previews
  int _coverIndex           = 0;

  // Controllers
  final _titleCtrl      = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _priceCtrl      = TextEditingController();
  final _meetupAreaCtrl = TextEditingController();

  String _category  = kListingCategories.first;
  String _condition = kListingConditions.first;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _meetupAreaCtrl.dispose();
    super.dispose();
  }

  // ── Images ───────────────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    if (_images.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80, limit: 3 - _images.length);
    if (picked.isNotEmpty) {
      final newBytes = await Future.wait(picked.map((x) => x.readAsBytes()));
      setState(() {
        _images   = [..._images, ...picked].take(3).toList();
        _previews = [..._previews, ...newBytes].take(3).toList();
        if (_coverIndex >= _images.length) _coverIndex = 0;
      });
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final formData = FormData();
      formData.fields.addAll([
        MapEntry('title',       _titleCtrl.text.trim()),
        MapEntry('description', _descCtrl.text.trim()),
        MapEntry('price',       _priceCtrl.text.trim()),
        MapEntry('category',    _category),
        MapEntry('condition',   _condition),
        MapEntry('meetupArea',  _meetupAreaCtrl.text.trim()),
      ]);
      // Cover first, then the rest
      final ordered = [
        _images[_coverIndex],
        ..._images.asMap().entries.where((e) => e.key != _coverIndex).map((e) => e.value),
      ];
      for (final img in ordered) {
        final bytes = await img.readAsBytes();
        formData.files.add(MapEntry(
          'images',
          MultipartFile.fromBytes(bytes, filename: img.name),
        ));
      }

      await _api.postMultipart('/listings', formData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing created!')),
        );
        context.go('/');
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message'] ?? 'Failed to create listing')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('List an Item'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.pop()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── Basic Info ───────────────────────────────────────
            _SectionHeader('Basic Info'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *', hintText: 'e.g. TI-84 Calculator'),
              validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (\$) *', hintText: '25'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Price is required';
                if (double.tryParse(v) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: kListingCategories.map((c) => _ChoiceChipTile(
                label: c, selected: _category == c, onTap: () => setState(() => _category = c),
              )).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Condition', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: kListingConditions.map((c) => _ChoiceChipTile(
                label: c, selected: _condition == c, onTap: () => setState(() => _condition = c),
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe the item, why you\'re selling, any flaws...'),
            ),

            // ── Meetup area ──────────────────────────────────────
            const SizedBox(height: 24),
            _SectionHeader('Meetup Area'),
            const SizedBox(height: 4),
            const Text('A general public area where you\'re willing to meet — not your address. You\'ll agree on an exact spot and time in chat.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _meetupAreaCtrl,
              decoration: const InputDecoration(
                labelText: 'General Area *',
                hintText: 'e.g. Near the Student Union, UCF Main Campus',
              ),
              validator: (v) => v == null || v.isEmpty ? 'A general meetup area is required' : null,
            ),

            // ── Photos ───────────────────────────────────────────
            const SizedBox(height: 24),
            Row(children: [
              _SectionHeader('Photos'),
              const Spacer(),
              Text('${_images.length}/3', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ]),
            const SizedBox(height: 4),
            const Text('Max 3 photos. Tap a photo to set it as cover.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_images.length < 3)
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 90, height: 90,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(12),
                          color: AppTheme.bgCard,
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primary, size: 28),
                            SizedBox(height: 4),
                            Text('Add', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                          ],
                        ),
                      ),
                    ),
                  ..._images.asMap().entries.map((entry) {
                    final isCover = entry.key == _coverIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _coverIndex = entry.key),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 90, height: 90,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isCover ? AppTheme.primary : Colors.transparent, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: entry.key < _previews.length
                                  ? Image.memory(_previews[entry.key], fit: BoxFit.cover, width: 90, height: 90)
                                  : Container(color: AppTheme.bgElevated),
                            ),
                          ),
                          Positioned(
                            top: -6, right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _images.removeAt(entry.key);
                                if (entry.key < _previews.length) _previews.removeAt(entry.key);
                                if (_coverIndex >= _images.length && _images.isNotEmpty) _coverIndex = _images.length - 1;
                              }),
                              child: Container(
                                width: 20, height: 20,
                                decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4, left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCover ? AppTheme.primary : Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(isCover ? 'Cover' : 'Set Cover',
                                  style: TextStyle(color: isCover ? Colors.black : Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // ── Submit ───────────────────────────────────────────
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text('Publish Listing', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary));
}

class _ChoiceChipTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChipTile({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.bgInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : AppTheme.textPrimary,
            )),
      ),
    );
  }
}
