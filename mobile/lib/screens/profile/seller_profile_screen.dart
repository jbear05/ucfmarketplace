import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/listing.dart';
import '../../services/api_service.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/star_rating.dart';

class SellerProfileScreen extends StatefulWidget {
  final String userId;
  const SellerProfileScreen({super.key, required this.userId});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  List<Listing> _listings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/users/${widget.userId}');
      final data = res.data['data'];
      setState(() {
        _profile  = data['profile'];
        _listings = (data['listings'] as List).map((e) => Listing.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Text('Profile not found', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    final p = _profile!;
    final name              = p['name'] ?? '';
    final avatarUrl         = p['avatarUrl'] as String?;
    final isVerifiedStudent = p['isVerifiedStudent'] ?? false;
    final classYear         = p['classYear'] as String?;
    final salesCount        = p['salesCount'] ?? 0;
    final ratingAvg         = (p['ratingAvg'] ?? 0).toDouble();
    final ratingCount       = p['ratingCount'] ?? 0;
    final createdAt         = DateTime.tryParse(p['createdAt'] ?? '');

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryLight,
                radius: 32,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl != null
                    ? null
                    : Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 24),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (isVerifiedStudent) ...[
                        Icon(Icons.verified_rounded, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text('Verified Knight',
                            style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                      ],
                      if (classYear != null && classYear.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text('Class of $classYear',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    StarRatingDisplay(rating: ratingAvg, count: ratingCount),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatTile(label: 'Sales', value: '$salesCount'),
              const SizedBox(width: 12),
              _StatTile(label: 'Rating', value: ratingCount > 0 ? ratingAvg.toStringAsFixed(1) : '—'),
              const SizedBox(width: 12),
              _StatTile(
                label: 'Member since',
                value: createdAt != null ? '${_month(createdAt.month)} ${createdAt.year}' : '—',
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Active Listings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          if (_listings.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No active listings right now', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ..._listings.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListingCard(listing: l),
            )),
        ],
      ),
    );
  }

  static String _month(int m) => const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][m - 1];
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
