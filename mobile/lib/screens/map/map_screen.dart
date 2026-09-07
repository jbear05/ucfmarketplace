import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../../models/listing.dart';
import '../../providers/listings_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  Listing? _selectedListing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ListingsProvider>();
      await provider.fetchMapListings();
      if (!mounted) return;
      _fitToPins(provider.mapListings);
    });
  }

  /// Fits map camera to show all pins — matches web app MapController logic
  void _fitToPins(List<Listing> listings) {
    final valid = listings
        .where((l) => l.coordinates != null && l.coordinates!.lat != 0)
        .toList();

    if (valid.isEmpty) return;

    if (valid.length == 1) {
      _mapController.move(
        LatLng(valid.first.coordinates!.lat, valid.first.coordinates!.lng),
        13,
      );
      return;
    }

    final lats = valid.map((l) => l.coordinates!.lat).toList();
    final lngs = valid.map((l) => l.coordinates!.lng).toList();

    final bounds = LatLngBounds(
      LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
      LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
        maxZoom: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider      = context.watch<ListingsProvider>();
    final category      = provider.filters.category;
    final validListings = provider.mapListings
        .where((l) => l.coordinates != null && l.coordinates!.lat != 0)
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(28.6024, -81.2001), // UCF main campus
              initialZoom:   12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.knightmarket.app',
              ),
              MarkerLayer(
                markers: validListings.map((listing) {
                  final isSelected = _selectedListing?.id == listing.id;
                  final statusColor = listing.status == 'active'
                      ? const Color(0xFF34C759)
                      : listing.status == 'pending'
                          ? const Color(0xFFFFCC00)
                          : const Color(0xFFFF3B30);
                  return Marker(
                    point: LatLng(listing.coordinates!.lat, listing.coordinates!.lng),
                    width:  isSelected ? 92 : 82,
                    height: isSelected ? 40 : 34,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedListing = listing);
                        _mapController.move(
                          LatLng(listing.coordinates!.lat, listing.coordinates!.lng),
                          14,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8, offset: const Offset(0, 3),
                          )],
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.border,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(
                                  color: statusColor.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                )],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '\$${listing.price >= 1000 ? '${(listing.price / 1000).toStringAsFixed(listing.price % 1000 == 0 ? 0 : 1)}k' : listing.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Top bar ───────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2))],
                    ),
                    child: Row(children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category != null && category.isNotEmpty ? category : 'All listings',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${validListings.length}',
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),

          // ── Selected listing card ─────────────────────────────
          if (_selectedListing != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _ListingPreviewCard(
                listing: _selectedListing!,
                onClose: () => setState(() => _selectedListing = null),
                onTap: () => context.push('/listings/${_selectedListing!.id}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListingPreviewCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onClose;
  final VoidCallback onTap;

  const _ListingPreviewCard({required this.listing, required this.onClose, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, -4))],
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 100, height: 90,
                child: listing.mainImage.isNotEmpty
                    ? CachedNetworkImage(imageUrl: listing.mainImage, fit: BoxFit.cover)
                    : Container(color: AppTheme.bgElevated,
                        child: const Icon(Icons.home_rounded, color: AppTheme.textLight)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\$${listing.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${listing.category} · ${listing.condition}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(children: [
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close_rounded, color: AppTheme.textLight, size: 20),
                ),
                const SizedBox(height: 16),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.primary, size: 22),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
