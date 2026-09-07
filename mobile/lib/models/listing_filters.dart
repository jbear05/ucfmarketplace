class ListingFilters {
  final String? search;
  final String? category;
  final String? condition;
  final int?    minPrice;
  final int?    maxPrice;

  const ListingFilters({
    this.search,
    this.category,
    this.condition,
    this.minPrice,
    this.maxPrice,
  });

  static const empty = ListingFilters();

  int get activeFilterCount {
    int count = 0;
    if (category  != null && category!.isNotEmpty)  count++;
    if (condition != null && condition!.isNotEmpty) count++;
    if (minPrice  != null) count++;
    if (maxPrice  != null) count++;
    return count;
  }

  ListingFilters copyWith({
    String? search, String? category, String? condition,
    int? minPrice, int? maxPrice,
  }) => ListingFilters(
    search:    search    ?? this.search,
    category:  category  ?? this.category,
    condition: condition ?? this.condition,
    minPrice:  minPrice  ?? this.minPrice,
    maxPrice:  maxPrice  ?? this.maxPrice,
  );

  Map<String, dynamic> toQueryParams() => {
    if (search    != null && search!.isNotEmpty)    'search':    search,
    if (category  != null && category!.isNotEmpty)  'category':  category,
    if (condition != null && condition!.isNotEmpty) 'condition': condition,
    if (minPrice  != null) 'minPrice': minPrice,
    if (maxPrice  != null) 'maxPrice': maxPrice,
  };
}
