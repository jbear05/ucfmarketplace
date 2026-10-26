import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/listing.dart';
import '../models/listing_filters.dart';
import '../models/saved_search.dart';
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
  String?        _locationError;
  List<SavedSearch> _savedSearches     = [];
  bool              _isLoadingSearches = false;

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
  String?        get locationError      => _locationError;
  List<SavedSearch> get savedSearches     => _savedSearches;
  bool              get isLoadingSearches => _isLoadingSearches;

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
      final params = <String, dynamic>{
        'page':  _currentPage,
        'limit': 12,
        ..._filters.toQueryParams(),
      };
      if (_filters.sortBy == 'closest') {
        final pos = await _currentPosition();
        if (pos != null) {
          params['lat'] = pos.latitude;
          params['lng'] = pos.longitude;
        }
      }
      final res = await _api.get('/listings', params: params);
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

  /// Device location for the 'closest' sort. Returns null (and sets
  /// [locationError]) when location is off or denied — the server then
  /// falls back to newest-first.
  Future<Position?> _currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationError = 'Turn on location services to sort by distance — showing newest instead';
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _locationError = 'Location permission is needed to sort by distance — showing newest instead';
        return null;
      }
      _locationError = null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
    } catch (_) {
      _locationError = 'Could not get your location — showing newest instead';
      return null;
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

  // ── Saved searches ──────────────────────────────────────────────────────────

  Future<void> fetchSavedSearches() async {
    _isLoadingSearches = true;
    notifyListeners();
    try {
      final res = await _api.get('/saved-searches');
      _savedSearches = (res.data['data']['savedSearches'] as List)
          .map((e) => SavedSearch.fromJson(e))
          .toList();
    } catch (_) {}
    _isLoadingSearches = false;
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  Future<String?> saveSearch(String label, {required ListingFilters filters}) async {
    try {
      final res = await _api.post('/saved-searches', data: {
        'label':   label,
        'filters': filters.toSavedSearchJson(),
      });
      _savedSearches = [SavedSearch.fromJson(res.data['data']['savedSearch']), ..._savedSearches];
      notifyListeners();
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message'] ?? 'Failed to save search';
    }
  }

  Future<void> deleteSavedSearch(String id) async {
    final previous = _savedSearches;
    _savedSearches = _savedSearches.where((s) => s.id != id).toList();
    notifyListeners();
    try {
      await _api.delete('/saved-searches/$id');
    } catch (_) {
      _savedSearches = previous;
      notifyListeners();
    }
  }
}
