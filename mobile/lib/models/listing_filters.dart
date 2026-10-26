class ListingFilters {
  final String? search;
  final String? category;
  final String? condition;
  final String? campus;
  final int?    minPrice;
  final int?    maxPrice;
  final String  sortBy;
  final bool    hideAiGenerated;

  const ListingFilters({
    this.search,
    this.category,
    this.condition,
    this.campus,
    this.minPrice,
    this.maxPrice,
    this.sortBy = 'newest',
    this.hideAiGenerated = false,
  });

  static const empty = ListingFilters();

  int get activeFilterCount {
    int count = 0;
    if (category  != null && category!.isNotEmpty)  count++;
    if (condition != null && condition!.isNotEmpty) count++;
    if (campus    != null && campus!.isNotEmpty)    count++;
    if (minPrice  != null) count++;
    if (maxPrice  != null) count++;
    if (sortBy != 'newest') count++;
    if (hideAiGenerated) count++;
    return count;
  }

  ListingFilters copyWith({
    String? search, String? category, String? condition, String? campus,
    int? minPrice, int? maxPrice, String? sortBy, bool? hideAiGenerated,
  }) => ListingFilters(
    search:    search    ?? this.search,
    category:  category  ?? this.category,
    condition: condition ?? this.condition,
    campus:    campus    ?? this.campus,
    minPrice:  minPrice  ?? this.minPrice,
    maxPrice:  maxPrice  ?? this.maxPrice,
    sortBy:    sortBy    ?? this.sortBy,
    hideAiGenerated: hideAiGenerated ?? this.hideAiGenerated,
  );

  /// Location for the 'closest' sort is added by ListingsProvider, not here.
  Map<String, dynamic> toQueryParams() => {
    if (search    != null && search!.isNotEmpty)    'search':    search,
    if (category  != null && category!.isNotEmpty)  'category':  category,
    if (condition != null && condition!.isNotEmpty) 'condition': condition,
    if (campus    != null && campus!.isNotEmpty)    'campus':    campus,
    if (minPrice  != null) 'minPrice': minPrice,
    if (maxPrice  != null) 'maxPrice': maxPrice,
    if (sortBy != 'newest') 'sortBy': sortBy,
    if (hideAiGenerated) 'hideAiGenerated': 'true',
  };

  /// Saved searches only store what can be matched against a new listing —
  /// sort order doesn't apply to an email alert.
  Map<String, dynamic> toSavedSearchJson() => {
    if (search    != null && search!.isNotEmpty)    'search':    search,
    if (category  != null && category!.isNotEmpty)  'category':  category,
    if (condition != null && condition!.isNotEmpty) 'condition': condition,
    if (campus    != null && campus!.isNotEmpty)    'campus':    campus,
    if (minPrice  != null) 'minPrice': minPrice,
    if (maxPrice  != null) 'maxPrice': maxPrice,
    if (hideAiGenerated) 'hideAiGenerated': true,
  };

  factory ListingFilters.fromJson(Map<String, dynamic> json) => ListingFilters(
    search:    json['search'],
    category:  json['category'],
    condition: json['condition'],
    campus:    json['campus'],
    minPrice:  (json['minPrice'] as num?)?.toInt(),
    maxPrice:  (json['maxPrice'] as num?)?.toInt(),
    hideAiGenerated: json['hideAiGenerated'] ?? false,
  );
}
