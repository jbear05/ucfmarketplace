import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/app_theme.dart';
import '../../models/listing.dart';
import '../../providers/listings_provider.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/filter_bottom_sheet.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  DateTime? _lastSearch;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ListingsProvider>().fetchListings(reset: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<ListingsProvider>().fetchListings();
    }
  }

  void _onSearchChanged(String q) {
    final now = DateTime.now();
    _lastSearch = now;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (_lastSearch != now || !mounted) return;
      context.read<ListingsProvider>().setSearch(q.isEmpty ? null : q);
    });
  }

  void _toggleCategory(String category) {
    final provider = context.read<ListingsProvider>();
    final current   = provider.filters.category;
    provider.setFilters(provider.filters.copyWith(
      category: current == category ? '' : category,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider    = context.watch<ListingsProvider>();
    final filterCount = provider.filters.activeFilterCount;
    final selectedCategory = provider.filters.category;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────
            Container(
              color: AppTheme.bgCard,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Row(children: [
                    const Text('KnightMarket',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                            color: AppTheme.primary, letterSpacing: -0.5)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/map'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.bgInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Row(children: [
                          Icon(Icons.map_outlined, size: 16, color: AppTheme.primary),
                          SizedBox(width: 4),
                          Text('Map', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.bgInput,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(Icons.search_rounded, color: AppTheme.textLight, size: 20),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Search items...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                hintStyle: TextStyle(color: AppTheme.textLight, fontSize: 14),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        final provider = context.read<ListingsProvider>();
                        FilterBottomSheet.show(context,
                          initialFilters: provider.filters,
                          onApply: (f) => provider.setFilters(f),
                        );
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: filterCount > 0 ? AppTheme.primaryLight : AppTheme.bgInput,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: filterCount > 0 ? AppTheme.primary : AppTheme.border),
                            ),
                            child: Icon(Icons.tune_rounded,
                                color: filterCount > 0 ? AppTheme.primary : AppTheme.textSecondary, size: 20),
                          ),
                          if (filterCount > 0)
                            Positioned(
                              top: -4, right: -4,
                              child: Container(
                                width: 16, height: 16,
                                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text('$filterCount',
                                    style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kListingCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = kListingCategories[i];
                        final selected = selectedCategory == cat;
                        return GestureDetector(
                          onTap: () => _toggleCategory(cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? AppTheme.primary : AppTheme.bgInput,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
                            ),
                            child: Text(cat,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                    color: selected ? Colors.black : AppTheme.textSecondary)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Listings ─────────────────────────────────────────
            Expanded(child: _ListingsBody(scrollController: _scrollController)),
          ],
        ),
      ),
    );
  }
}

class _ListingsBody extends StatelessWidget {
  final ScrollController scrollController;
  const _ListingsBody({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingsProvider>();

    if (provider.isLoading) return _ShimmerGrid();

    if (provider.error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.textLight),
        const SizedBox(height: 12),
        Text(provider.error!, style: const TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => context.read<ListingsProvider>().fetchListings(reset: true),
          child: const Text('Try Again'),
        ),
      ]));
    }

    if (provider.listings.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.sell_outlined, size: 48, color: AppTheme.textLight),
        SizedBox(height: 12),
        Text('No listings found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        SizedBox(height: 4),
        Text('Try a different search or adjust filters', style: TextStyle(color: AppTheme.textSecondary)),
      ]));
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          Text('${provider.totalCount} listing${provider.totalCount == 1 ? '' : 's'} found',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        ]),
      ),
      Expanded(child: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () => context.read<ListingsProvider>().fetchListings(reset: true),
        child: GridView.builder(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1, mainAxisSpacing: 12, childAspectRatio: 1.1,
        ),
        itemCount: provider.listings.length + (provider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == provider.listings.length) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
            ));
          }
          final listing = provider.listings[index];
          return ListingCard(key: ValueKey(listing.id), listing: listing);
        },
      ))),
    ]);
  }
}

class _ShimmerGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.bgCard,
      highlightColor: AppTheme.bgElevated,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 300,
          decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
