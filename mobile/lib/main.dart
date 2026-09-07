import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/listings_provider.dart';
import 'providers/chat_provider.dart';
import 'package:go_router/go_router.dart';

void main() {
  runApp(const KnightMarketApp());
}

class KnightMarketApp extends StatefulWidget {
  const KnightMarketApp({super.key});

  @override
  State<KnightMarketApp> createState() => _KnightMarketAppState();
}

class _KnightMarketAppState extends State<KnightMarketApp> {
  late final AuthProvider     _auth;
  late final ListingsProvider _listings;
  late final ChatProvider     _chat;
  late final GoRouter         _router;

  @override
  void initState() {
    super.initState();
    _auth     = AuthProvider();
    _listings = ListingsProvider();
    _chat     = ChatProvider();
    _router   = createRouter(_auth);

    _auth.tryRestoreSession().then((_) {
      if (_auth.isAuthenticated) {
        _chat.initSocketListeners(userId: _auth.user?.id);
        _chat.fetchUnreadCount();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _listings),
        ChangeNotifierProvider.value(value: _chat),
      ],
      child: MaterialApp.router(
        title:           'KnightMarket',
        debugShowCheckedModeBanner: false,
        theme:           AppTheme.darkTheme,
        routerConfig:    _router,
      ),
    );
  }
}
