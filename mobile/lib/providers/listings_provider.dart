import 'package:flutter/foundation.dart';
import '../models/listing.dart';
import '../models/listing_filters.dart';
import '../services/api_service.dart';

class ListingsProvider extends ChangeNotifier {
  final _api = ApiService();

  List<Listing>  _listings       = [];
  List<Listing>  _myListings     = [];
  List<Listing>  _favorites      = [];
  List<Listing>  _mapListings    = [];
  ListingFilters _filters        = ListingFilters.empty;
  bool           _isLoading      = false;
  bool           _isLoadingMore  = false;
  bool           _hasMore        = true;
  int            _currentPage    = 1;
  int            _totalCount     = 0;
  String?        _error;

  List<Listing>  get listings           => _listings;
  List<Listing>  get myListings         => _myListings;
  List<Listing>  get favorites          => _favorites;
  List<Listing>  get mapListings        => _mapListings;
  ListingFilters get filters            => _filters;
  bool           get isLoading          => _isLoading;
  bool           get isLoadingMore      => _isLoadingMore;
  bool           get hasMore            => _hasMore;
  int            get totalCount         => _totalCount;
  String?        get error              => _error;

  void setFilters(ListingFilters? filters) {
    _filters = filters ?? ListingFilters.empty;
    fetchListings(reset: true);
    fetchMapListings();
  }

  void setSearch(String? search) {
    _filters = _filters.copyWith(search: search);
    fetchListings(reset: true);
  }

  Future<void> fetchListings({bool reset = false}) async {
    if (reset) {
      _listings    = [];
      _currentPage = 1;
      _hasMore     = true;
      _error       = null;
      _isLoading   = true;
      notifyListeners();
    } else {
      if (_isLoading || _isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final res = await _api.get('/listings', params: {
        'page':  _currentPage,
        'limit': 12,
        ..._filters.toQueryParams(),
      });
      final data     = res.data['data'];
      final newItems = (data['listings'] as List).map((e) => Listing.fromJson(e)).toList();
      _listings.addAll(newItems);
      _totalCount = data['pagination']?['total'] ?? _listings.length;
      _hasMore    = data['pagination']?['hasMore'] ?? newItems.length == 12;
      if (_hasMore) _currentPage++;
    } catch (_) {
      _error = 'Failed to load listings';
    } finally {
      _isLoading     = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<Listing?> fetchListingById(String id) async {
    try {
      final res = await _api.get('/listings/$id');
      return Listing.fromJson(res.data['data']);
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchMyListings() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get('/listings/mine');
      _myListings = (res.data['data']['listings'] as List).map((e) => Listing.fromJson(e)).toList();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchFavorites(List<String> favoriteIds) async {
    if (favoriteIds.isEmpty) {
      _favorites = [];
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    final results = await Future.wait(
      favoriteIds.map((id) => fetchListingById(id)),
    );
    _favorites = results.whereType<Listing>().toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMapListings() async {
    try {
      final params = <String, dynamic>{};
      if (_filters.category != null && _filters.category!.isNotEmpty) {
        params['category'] = _filters.category;
      }
      // Use /listings/map — lightweight endpoint (matches web app)
      final res = await _api.get('/listings/map', params: params);
      _mapListings = (res.data['data']['pins'] as List).map((e) => Listing.fromJson(e)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> toggleFavorite(String listingId, List<String> currentFavorites) async {
    try {
      final res = await _api.post('/listings/$listingId/favorite');
      return res.data['data']['isFavorited'] ?? false;
    } catch (_) {
      return currentFavorites.contains(listingId);
    }
  }

  Future<bool> updateListingStatus(String listingId, String status) async {
    try {
      await _api.patch('/listings/$listingId/status', data: {'status': status});
      final idx = _myListings.indexWhere((l) => l.id == listingId);
      if (idx != -1) {
        _myListings[idx] = _myListings[idx].copyWith(status: status);
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteMyListing(String listingId) async {
    try {
      await _api.delete('/listings/$listingId');
      _myListings.removeWhere((l) => l.id == listingId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
