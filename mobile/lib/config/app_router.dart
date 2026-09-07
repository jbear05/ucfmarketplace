import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/explore/explore_screen.dart';
import '../screens/listings/listing_detail_screen.dart';
import '../screens/listings/create_listing_screen.dart';
import '../screens/listings/edit_listing_screen.dart';
import '../screens/listings/my_listings_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/map/meetup_picker_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_thread_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../widgets/main_shell.dart';

final _rootNavigatorKey    = GlobalKey<NavigatorState>();
final _shellNavigatorKey   = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider auth) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: auth,
  redirect: (context, state) {
    final isAuth = auth.isAuthenticated;
    final protectedRoutes = [
      '/create', '/my-listings', '/messages', '/favorites',
    ];
    final isProtected = protectedRoutes.any((r) => state.matchedLocation.startsWith(r));
    if (!isAuth && isProtected) return '/';
    if (state.matchedLocation.startsWith('/admin') && !auth.isAdmin) return '/';
    return null;
  },
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/',         builder: (c, s) => const ExploreScreen()),
        GoRoute(path: '/map',      builder: (c, s) => const MapScreen()),
        GoRoute(path: '/messages', builder: (c, s) => const ChatListScreen()),
        GoRoute(path: '/favorites',builder: (c, s) => const FavoritesScreen()),
        GoRoute(path: '/profile',  builder: (c, s) => const ProfileScreen()),
        GoRoute(path: '/my-listings', builder: (c, s) => const MyListingsScreen()),
      ],
    ),
    GoRoute(path: '/login',           builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/register',        builder: (c, s) => const RegisterScreen()),
    GoRoute(path: '/forgot-password', builder: (c, s) => const ForgotPasswordScreen()),
    GoRoute(path: '/create',          builder: (c, s) => const CreateListingScreen()),
    GoRoute(
      path: '/listings/:id',
      builder: (c, s) => ListingDetailScreen(listingId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/listings/:id/edit',
      builder: (c, s) => EditListingScreen(listingId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/messages/:threadId',
      builder: (c, s) => ChatThreadScreen(threadId: s.pathParameters['threadId']!),
    ),
    GoRoute(
      path: '/messages/:threadId/meetup',
      builder: (c, s) => const MeetupPickerScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (c, s) => const AdminDashboardScreen(),
    ),
  ],
);
