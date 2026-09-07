import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../config/app_theme.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listings_provider.dart';
import '../../providers/chat_provider.dart';
import '../../utils/listing_status.dart';
import '../../widgets/star_rating.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  Listing? _listing;
  bool _isLoading = true;
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  Future<void> _loadListing() async {
    final listing = await context
        .read<ListingsProvider>()
        .fetchListingById(widget.listingId);
    if (mounted) setState(() {
      _listing = listing;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _contactLister() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    if (_listing!.owner?.id == auth.user?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This is your own listing")),
      );
      return;
    }

    final chat = context.read<ChatProvider>();
    final thread = await chat.createThread(_listing!.id);
    if (thread != null && mounted) {
      context.push('/messages/${thread.id}',
          extra: {'thread': thread, 'listing': _listing});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listing')),
        body: const Center(
          child: Text('Listing not found', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    final listing = _listing!;
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.user?.id == listing.owner?.id;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        slivers: [
          // Photo gallery
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppTheme.bgDark,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: AppTheme.bgCard,
                radius: 18,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  onPressed: () => context.pop(),
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: AppTheme.bgCard,
                  radius: 18,
                  child: IconButton(
                    icon: Icon(
                      auth.isFavorited(listing.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: auth.isFavorited(listing.id)
                          ? AppTheme.error
                          : AppTheme.textPrimary,
                    ),
                    onPressed: () {
                      if (!auth.isAuthenticated) {
                        context.push('/login');
                        return;
                      }
                      // handled by auth
                      auth.toggleFavorite(listing.id);
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: listing.images.isEmpty
                  ? Container(
                      color: AppTheme.divider,
                      child: const Icon(Icons.home_rounded,
                          size: 60, color: AppTheme.textLight),
                    )
                  : Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: listing.images.length,
                          onPageChanged: (i) =>
                              setState(() => _currentPage = i),
                          itemBuilder: (_, i) => CachedNetworkImage(
                            imageUrl: listing.images[i],
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                        if (listing.images.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: AnimatedSmoothIndicator(
                                activeIndex: _currentPage,
                                count: listing.images.length,
                                effect: const WormEffect(
                                  dotWidth: 6,
                                  dotHeight: 6,
                                  activeDotColor: Colors.white,
                                  dotColor: Colors.white54,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price and status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${listing.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -1),
                      ),
                      const Spacer(),
                      _buildStatusBadge(listing.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    listing.title,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 6),
                  // Meetup area
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.meetupArea,
                          style: const TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Key details grid
                  const Text('Item Details',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _DetailChip(
                          icon: Icons.category_rounded,
                          label: listing.category,
                          sublabel: 'Category'),
                      const SizedBox(width: 12),
                      _DetailChip(
                          icon: Icons.grade_rounded,
                          label: listing.condition,
                          sublabel: 'Condition',
                          color: AppTheme.primary),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Description
                  const Text('About this place',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    listing.description,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.6),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Lister info
                  if (listing.owner != null) ...[
                    const Text('Listed by',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryLight,
                          radius: 24,
                          child: Text(
                            listing.owner!.name.isNotEmpty
                                ? listing.owner!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.owner!.name,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary),
                            ),
                            if (listing.owner!.isVerifiedStudent)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.verified_rounded,
                                        size: 14, color: AppTheme.primary),
                                    SizedBox(width: 4),
                                    Text('Verified Student',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            StarRatingDisplay(
                              rating: listing.owner!.ratingAvg,
                              count: listing.owner!.ratingCount,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],

                  // Owner actions
                  if (isOwner) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text('Manage Listing',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/listings/${listing.id}/edit'),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _changeStatus(listing),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                            label: const Text('Change Status'),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Bottom padding for FAB
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // Contact button
      bottomNavigationBar: isOwner
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed:
                        listing.status == 'active' ? _contactLister : null,
                    icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                    label: Text(
                      listing.status == 'active'
                          ? 'Contact Seller'
                          : 'Not Available',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = listingStatusColor(status);
    final label = listingStatusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  void _changeStatus(Listing listing) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            for (final status in ['active', 'pending', 'offMarket'])
              ListTile(
                leading: Icon(
                  status == 'active'
                      ? Icons.check_circle_rounded
                      : status == 'pending'
                          ? Icons.hourglass_empty_rounded
                          : Icons.block_rounded,
                  color: listingStatusColor(status),
                ),
                title: Text(listingStatusLabel(status)),
                selected: listing.status == status,
                onTap: () async {
                  Navigator.pop(context);
                  await context
                      .read<ListingsProvider>()
                      .updateListingStatus(listing.id, status);
                  await _loadListing();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color? color;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: c)),
            Text(sublabel,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
