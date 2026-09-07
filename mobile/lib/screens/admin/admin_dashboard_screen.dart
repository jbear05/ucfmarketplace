import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/listing_status.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _api = ApiService();

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _listings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.get('/admin/stats'),
        _api.get('/admin/users', params: {'limit': 100}),
        _api.get('/admin/listings', params: {'limit': 100}),
      ]);
      setState(() {
        _stats    = results[0].data['data'];
        _users    = List<Map<String, dynamic>>.from(results[1].data['data']['users']);
        _listings = List<Map<String, dynamic>>.from(results[2].data['data']['listings']);
      });
    } catch (e) {
      setState(() => _error = 'Failed to load admin data');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleBlock(Map<String, dynamic> user) async {
    final id = user['_id'];
    final newValue = !(user['isBlocked'] ?? false);
    setState(() => user['isBlocked'] = newValue); // optimistic
    try {
      await _api.patch('/admin/users/$id', data: {'isBlocked': newValue});
    } catch (_) {
      if (mounted) {
        setState(() => user['isBlocked'] = !newValue); // revert
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update user')),
        );
      }
    }
  }

  Future<void> _toggleBoost(Map<String, dynamic> listing) async {
    final id = listing['_id'];
    try {
      final res = await _api.patch('/admin/listings/$id/boost');
      setState(() {
        listing['boostedUntil'] = res.data['data']['listing']['boostedUntil'];
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update boost')),
        );
      }
    }
  }

  bool _isBoosted(Map<String, dynamic> listing) {
    final until = listing['boostedUntil'];
    if (until == null) return false;
    final date = DateTime.tryParse(until);
    return date != null && date.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Users'),
            Tab(text: 'Listings'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)))
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _loadAll,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _OverviewTab(stats: _stats),
                      _UsersTab(users: _users, onToggleBlock: _toggleBlock),
                      _ListingsTab(listings: _listings, isBoosted: _isBoosted, onToggleBoost: _toggleBoost),
                    ],
                  ),
                ),
    );
  }
}

// ── Overview ─────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic>? stats;
  const _OverviewTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const SizedBox();
    final users    = stats!['users'] as Map<String, dynamic>;
    final listings = stats!['listings'] as Map<String, dynamic>;
    final chat     = stats!['chat'] as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionLabel('Users'),
        _StatGrid(items: [
          _Stat('Total', '${users['total']}'),
          _Stat('Verified Students', '${users['verifiedStudents']}'),
          _Stat('Blocked', '${users['blocked']}'),
          _Stat('Active (7d)', '${users['activeLast7Days']}'),
          _Stat('New (7d)', '${users['newLast7Days']}'),
        ]),
        const SizedBox(height: 24),
        const _SectionLabel('Listings'),
        _StatGrid(items: [
          _Stat('Total', '${listings['total']}'),
          _Stat('Active', '${listings['active']}'),
          _Stat('Meetup Scheduled', '${listings['pending']}'),
          _Stat('Sold', '${listings['sold']}'),
          _Stat('Boosted', '${listings['boosted']}'),
        ]),
        const SizedBox(height: 24),
        const _SectionLabel('Chat'),
        _StatGrid(items: [
          _Stat('Threads', '${chat['threads']}'),
          _Stat('Messages', '${chat['messages']}'),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
  );
}

class _Stat {
  final String label;
  final String value;
  _Stat(this.label, this.value);
}

class _StatGrid extends StatelessWidget {
  final List<_Stat> items;
  const _StatGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: items.map((s) => Container(
        width: (MediaQuery.of(context).size.width - 32 - 10) / 2,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primary)),
            const SizedBox(height: 4),
            Text(s.label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      )).toList(),
    );
  }
}

// ── Users ────────────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final Function(Map<String, dynamic>) onToggleBlock;
  const _UsersTab({required this.users, required this.onToggleBlock});

  String _relativeTime(String? iso) {
    if (iso == null) return 'never';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'never';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('No users yet', style: TextStyle(color: AppTheme.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final u = users[i];
        final isBlocked = u['isBlocked'] ?? false;
        final isAdmin   = u['role'] == 'admin';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(u['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Admin', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                        ),
                      ],
                      if (u['isVerifiedStudent'] == true) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, size: 14, color: AppTheme.primary),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(u['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Last active: ${_relativeTime(u['lastActiveAt'])}', style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                  ],
                ),
              ),
              if (!isAdmin)
                Column(
                  children: [
                    Switch(
                      value: !isBlocked,
                      onChanged: (_) => onToggleBlock(u),
                      activeThumbColor: AppTheme.primary,
                    ),
                    Text(isBlocked ? 'Blocked' : 'Active',
                        style: TextStyle(fontSize: 10, color: isBlocked ? AppTheme.error : AppTheme.success)),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Listings ─────────────────────────────────────────────────────────────────

class _ListingsTab extends StatelessWidget {
  final List<Map<String, dynamic>> listings;
  final bool Function(Map<String, dynamic>) isBoosted;
  final Function(Map<String, dynamic>) onToggleBoost;
  const _ListingsTab({required this.listings, required this.isBoosted, required this.onToggleBoost});

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return const Center(child: Text('No listings yet', style: TextStyle(color: AppTheme.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: listings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final l = listings[i];
        final boosted = isBoosted(l);
        final status = l['status'] ?? 'active';
        final owner = l['owner'] is Map ? l['owner']['name'] : null;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('\$${l['price']} · ${owner ?? 'unknown owner'}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: listingStatusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                        child: Text(listingStatusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: listingStatusColor(status))),
                      ),
                      if (boosted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                          child: const Text('⚡ Boosted', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onToggleBoost(l),
                child: Text(boosted ? 'Remove Boost' : 'Boost',
                    style: TextStyle(color: boosted ? AppTheme.error : AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }
}
