import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listings_provider.dart';
import '../../widgets/listing_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ListingsProvider>().fetchSavedSearches();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(title: const Text('Saved'), centerTitle: false),
        body: Center(
          child: Text('Log in to see your saved listings',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Saved'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: 'Items'), Tab(text: 'Searches')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_SavedItemsTab(), _SavedSearchesTab()],
      ),
    );
  }
}

class _SavedItemsTab extends StatelessWidget {
  const _SavedItemsTab();

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<AuthProvider>().favoriteListings;

    if (favorites.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.favorite_border_rounded, size: 52, color: AppTheme.textLight),
          SizedBox(height: 16),
          Text('No saved listings yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          SizedBox(height: 6),
          Text('Tap the heart on any listing to save it',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        ]),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => context.read<AuthProvider>().tryRestoreSession(),
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: favorites.length,
        itemBuilder: (_, i) => ListingCard(key: ValueKey(favorites[i].id), listing: favorites[i]),
      ),
    );
  }
}

class _SavedSearchesTab extends StatelessWidget {
  const _SavedSearchesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingsProvider>();

    if (provider.isLoadingSearches && provider.savedSearches.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (provider.savedSearches.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_rounded, size: 52, color: AppTheme.textLight),
            SizedBox(height: 16),
            Text('No saved searches yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            SizedBox(height: 6),
            Text('Apply filters on Home, then tap "Save this search" to get emailed when a new listing matches',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          ]),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 100),
      itemCount: provider.savedSearches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = provider.savedSearches[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(s.summary, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.textLight),
                onPressed: () => context.read<ListingsProvider>().deleteSavedSearch(s.id),
              ),
            ],
          ),
        );
      },
    );
  }
}
