import 'listing_filters.dart';

class SavedSearch {
  final String id;
  final String label;
  final ListingFilters filters;

  SavedSearch({required this.id, required this.label, required this.filters});

  /// One-line description of the filters, e.g. "Textbooks · Main Campus · $10–$50".
  String get summary {
    final parts = <String>[
      if (filters.search    != null && filters.search!.isNotEmpty)    '"${filters.search}"',
      if (filters.category  != null && filters.category!.isNotEmpty)  filters.category!,
      if (filters.condition != null && filters.condition!.isNotEmpty) filters.condition!,
      if (filters.campus    != null && filters.campus!.isNotEmpty)    filters.campus!,
      if (filters.minPrice != null && filters.maxPrice != null)
        '\$${filters.minPrice}–\$${filters.maxPrice}'
      else if (filters.minPrice != null)
        'From \$${filters.minPrice}'
      else if (filters.maxPrice != null)
        'Up to \$${filters.maxPrice}',
      if (filters.hideAiGenerated) 'No AI-generated',
    ];
    return parts.isEmpty ? 'All listings' : parts.join(' · ');
  }

  factory SavedSearch.fromJson(Map<String, dynamic> json) => SavedSearch(
    id:      json['_id'] ?? json['id'] ?? '',
    label:   json['label'] ?? '',
    filters: ListingFilters.fromJson(Map<String, dynamic>.from(json['filters'] ?? {})),
  );
}
