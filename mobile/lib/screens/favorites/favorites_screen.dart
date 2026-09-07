import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/listing_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(title: const Text('Saved'), centerTitle: false),
        body: const Center(
          child: Text('Log in to see your saved listings',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    final favorites = auth.favoriteListings;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text('Saved (${favorites.length})'),
        centerTitle: false,
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.favorite_border_rounded, size: 52, color: AppTheme.textLight),
                SizedBox(height: 16),
                Text('No saved listings yet',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                SizedBox(height: 6),
                Text('Tap the heart on any listing to save it',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              ]),
            )
          : RefreshIndicator(
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
            ),
    );
  }
}
