import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../models/listing.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final _api = ApiService();

  /// Extracts a human-readable error from a failed API response — prefers the
  /// specific validation `errors` list (e.g. "Password must be at least 8
  /// characters") over the generic top-level `message` ("Validation failed").
  static String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    final errors = data?['errors'];
    if (errors is List && errors.isNotEmpty) {
      return errors.join('\n');
    }
    return data?['message'] ?? fallback;
  }

  User?          _user             = null;
  bool           _isLoading        = false;
  List<Listing>  _favoriteListings = [];

  User?         get user             => _user;
  bool          get isLoading        => _isLoading;
  bool          get isAuthenticated  => _user != null;
  bool          get isAdmin          => _user?.isAdmin ?? false;
  List<Listing> get favoriteListings => _favoriteListings;

  Future<void> tryRestoreSession() async {
    final token = await _api.getToken();
    if (token == null) return;
    try {
      final res = await _api.get('/auth/me');
      final userData = res.data['data'] as Map<String, dynamic>;
      _user = User.fromJson(userData);
      _favoriteListings = _parseFavoriteListings(userData['favorites']);
      notifyListeners();
    } catch (_) {
      await _api.clearToken();
    }
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.post('/auth/login', data: {'email': email, 'password': password});
      final data = res.data['data'];
      await _api.saveToken(data['token']);
      _user = User.fromJson(data['user']);
      // After login, fetch /auth/me to get populated favorites
      try {
        final meRes = await _api.get('/auth/me');
        final userData = meRes.data['data'] as Map<String, dynamic>;
        _favoriteListings = _parseFavoriteListings(userData['favorites']);
      } catch (_) {}
      return null;
    } on DioException catch (e) {
      return _extractError(e, 'Login failed');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> register({required String name, required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _api.post('/auth/register', data: {'name': name, 'email': email, 'password': password});
      return null;
    } on DioException catch (e) {
      return _extractError(e, 'Registration failed');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> forgotPassword(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _api.post('/auth/forgot-password', data: {'email': email});
      return null;
    } on DioException catch (e) {
      return _extractError(e, 'Request failed');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resendVerification(String email) async {
    await _api.post('/auth/resend-verification', data: {'email': email});
  }

  List<Listing> _parseFavoriteListings(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).whereType<Map>().map((f) => Listing.fromJson(f as Map<String, dynamic>)).toList();
  }

  bool isFavorited(String listingId) => _user?.favorites.contains(listingId) ?? false;

  Future<void> toggleFavorite(String listingId) async {
    if (_user == null) return;
    final wasFavorited = _user!.favorites.contains(listingId);

    // Optimistic flip for instant feedback
    final optimistic = List<String>.from(_user!.favorites);
    wasFavorited ? optimistic.remove(listingId) : optimistic.add(listingId);
    _user = _user!.copyWith(favorites: optimistic);
    notifyListeners();

    try {
      final res = await _api.post('/listings/$listingId/favorite');
      // Reconcile against what the server actually did — never trust the
      // optimistic guess alone, or a lost/retried request can permanently
      // desync the client from the server's real favorited state.
      final isFavorited = res.data['data']['isFavorited'] ?? !wasFavorited;
      final reconciled = List<String>.from(_user!.favorites)..remove(listingId);
      if (isFavorited) reconciled.add(listingId);
      _user = _user!.copyWith(favorites: reconciled);

      // Refresh favorites list from server to get full listing objects
      final meRes = await _api.get('/auth/me');
      final userData = meRes.data['data'] as Map<String, dynamic>;
      _favoriteListings = _parseFavoriteListings(userData['favorites']);
      notifyListeners();
    } catch (_) {
      // revert to the pre-toggle state
      final reverted = List<String>.from(_user!.favorites)..remove(listingId);
      if (wasFavorited) reverted.add(listingId);
      _user = _user!.copyWith(favorites: reverted);
      notifyListeners();
    }
  }

  void updateFavorites(List<String> favorites) {
    if (_user != null) {
      _user = _user!.copyWith(favorites: favorites);
      notifyListeners();
    }
  }

  Future<String?> updateName(String name) async {
    if (_user == null) return 'Not logged in';
    try {
      final res = await _api.put('/auth/me', data: {'name': name});
      final updated = User.fromJson(res.data['data']['user'] ?? res.data['data']);
      _user = updated;
      notifyListeners();
      return null;
    } on DioException catch (e) {
      return _extractError(e, 'Failed to save name');
    } catch (e) {
      return e.toString();
    }
  }

  void updateAvatar(String avatarKey) {
    if (_user == null) return;
    _user = _user!.copyWith(avatarKey: avatarKey);
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.clearToken();
    _user = null;
    _favoriteListings = [];
    notifyListeners();
  }
}
