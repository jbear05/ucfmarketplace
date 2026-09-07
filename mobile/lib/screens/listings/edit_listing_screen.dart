import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/listing.dart';
import '../../providers/listings_provider.dart';
import '../../services/api_service.dart';
import '../../utils/listing_status.dart';

class EditListingScreen extends StatefulWidget {
  final String listingId;
  const EditListingScreen({super.key, required this.listingId});

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  Listing? _listing;
  bool _isLoading   = true;
  bool _isSubmitting = false;
  final _formKey    = GlobalKey<FormState>();
  final _api        = ApiService();

  List<String>  _existingImages = [];
  List<XFile>   _newImages      = [];
  List<Uint8List> _newPreviews  = [];

  final _titleCtrl      = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _priceCtrl      = TextEditingController();
  final _meetupAreaCtrl = TextEditingController();

  String _category  = kListingCategories.first;
  String _condition = kListingConditions.first;
  String _status     = 'active';

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _meetupAreaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadListing() async {
    final listing = await context.read<ListingsProvider>().fetchListingById(widget.listingId);
    if (listing != null && mounted) {
      setState(() {
        _listing             = listing;
        _existingImages      = List.from(listing.images);
        _titleCtrl.text      = listing.title;
        _descCtrl.text       = listing.description;
        _priceCtrl.text      = listing.price.toStringAsFixed(0);
        _meetupAreaCtrl.text = listing.meetupArea;
        _category            = listing.category;
        _condition           = listing.condition;
        _status              = listing.status;
        _isLoading           = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ── Images ───────────────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    final total = _existingImages.length + _newImages.length;
    if (total >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80, limit: 3 - total);
    if (picked.isNotEmpty) {
      final newBytes = await Future.wait(picked.map((x) => x.readAsBytes()));
      setState(() {
        _newImages   = [..._newImages, ...picked].take(3 - _existingImages.length).toList();
        _newPreviews = [..._newPreviews, ...newBytes].take(3 - _existingImages.length).toList();
      });
    }
  }

  Future<void> _removeExistingImage(String url) async {
    try {
      await _api.delete('/listings/${widget.listingId}/image', data: {'imageUrl': url});
      setState(() => _existingImages.remove(url));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove image')),
        );
      }
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingImages.isEmpty && _newImages.isEmpty) {
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
      for (final img in _newImages) {
        final bytes = await img.readAsBytes();
        formData.files.add(MapEntry(
          'images',
          MultipartFile.fromBytes(bytes, filename: img.name),
        ));
      }
      await _api.putMultipart('/listings/${widget.listingId}', formData);
      // Update status separately via its own endpoint
      if (_listing!.status != _status) {
        await _api.patch('/listings/${widget.listingId}/status', data: {'status': _status});
      }
      if (mounted) {
        await context.read<ListingsProvider>().fetchMyListings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing updated!')),
        );
        context.pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message'] ?? 'Failed to update listing')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }
    if (_listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Listing')),
        body: const Center(child: Text('Listing not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Listing'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                : const Text('Save', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── Basic Info ───────────────────────────────────────
            const Text('Basic Info', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (\$) *'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),

            // ── Meetup area ──────────────────────────────────────
            const SizedBox(height: 24),
            const Text('Meetup Area', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _meetupAreaCtrl,
              decoration: const InputDecoration(labelText: 'General Area *'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),

            // ── Status ───────────────────────────────────────────
            const SizedBox(height: 24),
            const Text('Status', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            Row(children: [
              _StatusChip(value: 'active',    selected: _status == 'active',    onTap: () => setState(() => _status = 'active')),
              const SizedBox(width: 8),
              _StatusChip(value: 'pending',   selected: _status == 'pending',   onTap: () => setState(() => _status = 'pending')),
              const SizedBox(width: 8),
              _StatusChip(value: 'offMarket', selected: _status == 'offMarket', onTap: () => setState(() => _status = 'offMarket')),
            ]),

            // ── Photos ───────────────────────────────────────────
            const SizedBox(height: 24),
            Row(children: [
              const Text('Photos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              Text('${_existingImages.length + _newImages.length}/3', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_existingImages.length + _newImages.length < 3)
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 90, height: 90,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(12), color: AppTheme.bgCard),
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
                  ..._existingImages.map((url) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 90, height: 90,
                        margin: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: -6, right: 2,
                        child: GestureDetector(
                          onTap: () => _removeExistingImage(url),
                          child: Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  )),
                  ..._newImages.asMap().entries.map((entry) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 90, height: 90,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: entry.key < _newPreviews.length
                              ? DecorationImage(image: MemoryImage(_newPreviews[entry.key]), fit: BoxFit.cover)
                              : null,
                        ),
                      ),
                      Positioned(
                        top: -6, right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _newImages.removeAt(entry.key);
                            if (entry.key < _newPreviews.length) _newPreviews.removeAt(entry.key);
                          }),
                          child: Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  )),
                ],
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
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.black : AppTheme.textPrimary)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChip({required this.value, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = listingStatusColor(value);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : AppTheme.bgInput,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 2 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(height: 4),
            Text(listingStatusLabel(value), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? color : AppTheme.textSecondary), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
