import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/listing.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/listing_status.dart';

class ListingCard extends StatefulWidget {
  final Listing listing;
  const ListingCard({super.key, required this.listing});

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  bool _loading = false;
  int  _favCount = 0;

  @override
  void initState() {
    super.initState();
    _favCount = widget.listing.favoriteCount;
  }

  @override
  void didUpdateWidget(covariant ListingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync if this widget now represents a different (or freshly-refetched) listing
    if (oldWidget.listing.id != widget.listing.id) {
      _favCount = widget.listing.favoriteCount;
    }
  }

  Future<void> _toggleFavorite(AuthProvider auth) async {
    if (!auth.isAuthenticated) { context.push('/login'); return; }
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await auth.toggleFavorite(widget.listing.id);
      if (mounted) {
        final nowFav = auth.isFavorited(widget.listing.id);
        setState(() {
          _favCount = nowFav ? _favCount + 1 : (_favCount - 1).clamp(0, 9999);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth       = context.watch<AuthProvider>();
    final isOwn      = auth.user?.id == widget.listing.owner?.id;
    final isFavorited = auth.isFavorited(widget.listing.id);

    return GestureDetector(
      onTap: () => context.push('/listings/${widget.listing.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image + overlays ───────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: widget.listing.mainImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.listing.mainImage,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: AppTheme.bgElevated),
                            errorWidget: (_, __, ___) => Container(
                              color: AppTheme.bgElevated,
                              child: const Icon(Icons.home_rounded, color: AppTheme.textMuted, size: 40),
                            ),
                          )
                        : Container(
                            color: AppTheme.bgElevated,
                            child: const Icon(Icons.home_rounded, color: AppTheme.textMuted, size: 40),
                          ),
                  ),

                  // Featured ribbon
                  if (widget.listing.isBoosted)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.warning,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('⚡ Featured',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87)),
                      ),
                    ),

                  // Heart — top right
                  // AbsorbPointer on the whole positioned area so tapping the
                  // heart never bubbles up to the card's GestureDetector
                  Positioned(
                    top: 8, right: 8,
                    child: AbsorbPointer(
                      absorbing: false, // we handle taps ourselves below
                      child: GestureDetector(
                        // Stop tap from reaching the card's GestureDetector
                        onTap: () {
                          if (!isOwn) _toggleFavorite(auth);
                          // own listing: tap does nothing (absorbed here)
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: isOwn
                              // Owner: show fav count, no interaction
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.favorite_rounded, size: 12, color: AppTheme.error),
                                    const SizedBox(width: 2),
                                    Text('$_favCount',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                                  ],
                                )
                              : _loading
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(
                                      isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      size: 18,
                                      color: isFavorited ? AppTheme.error : Colors.white.withValues(alpha: 0.8),
                                    ),
                        ),
                      ),
                    ),
                  ),

                  // Verified student badge
                  if (widget.listing.ownerVerified)
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('✓ Student',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      ),
                    ),
                ],
              ),
            ),

            // ── Info ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('\$${widget.listing.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                      const Spacer(),
                      _StatusDot(status: widget.listing.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(widget.listing.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(widget.listing.meetupArea,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: [
                      _tag(widget.listing.category),
                      _tag(widget.listing.condition),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
  );
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = listingStatusColor(status);
    final label = listingStatusLabel(status);

    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
    ]);
  }
}
