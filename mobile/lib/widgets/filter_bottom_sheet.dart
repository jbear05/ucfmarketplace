import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/listing.dart';
import '../models/listing_filters.dart';
import '../providers/listings_provider.dart';

class FilterBottomSheet extends StatefulWidget {
  final ListingFilters initialFilters;
  final Function(ListingFilters?) onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  static void show(BuildContext context, {
    required ListingFilters initialFilters,
    required Function(ListingFilters?) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(initialFilters: initialFilters, onApply: onApply),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late final _minPriceCtrl = TextEditingController(text: widget.initialFilters.minPrice?.toString() ?? '');
  late final _maxPriceCtrl = TextEditingController(text: widget.initialFilters.maxPrice?.toString() ?? '');
  String? _category;
  String? _condition;
  String? _campus;
  late String _sortBy;
  late bool _hideAiGenerated;

  @override
  void initState() {
    super.initState();
    _category  = widget.initialFilters.category;
    _condition = widget.initialFilters.condition;
    _campus    = widget.initialFilters.campus;
    _sortBy    = widget.initialFilters.sortBy;
    _hideAiGenerated = widget.initialFilters.hideAiGenerated;
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 20),
          Text('Sort By', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kListingSortOptions.map((s) => _Chip(
              label: listingSortLabel(s), selected: _sortBy == s,
              onTap: () => setState(() => _sortBy = s),
            )).toList(),
          ),
          const SizedBox(height: 20),
          Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kListingCategories.map((c) => _Chip(
              label: c, selected: _category == c,
              onTap: () => setState(() => _category = _category == c ? null : c),
            )).toList(),
          ),
          const SizedBox(height: 20),
          Text('Campus', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kListingCampuses.map((c) => _Chip(
              label: c, selected: _campus == c,
              onTap: () => setState(() => _campus = _campus == c ? null : c),
            )).toList(),
          ),
          const SizedBox(height: 20),
          Text('Condition', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kListingConditions.map((c) => _Chip(
              label: c, selected: _condition == c,
              onTap: () => setState(() => _condition = _condition == c ? null : c),
            )).toList(),
          ),
          const SizedBox(height: 20),
          Text('Price Range', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _minPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Min'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _maxPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _hideAiGenerated,
            onChanged: (v) => setState(() => _hideAiGenerated = v),
            contentPadding: EdgeInsets.zero,
            title: Text('Hide AI-generated', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onApply(null);
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(ListingFilters(
                      category:  _category,
                      condition: _condition,
                      campus:    _campus,
                      minPrice:  int.tryParse(_minPriceCtrl.text),
                      maxPrice:  int.tryParse(_maxPriceCtrl.text),
                      sortBy:    _sortBy,
                      hideAiGenerated: _hideAiGenerated,
                    ));
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
          if (_category != null || _condition != null || _campus != null ||
              _minPriceCtrl.text.isNotEmpty || _maxPriceCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _saveThisSearch(context),
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('Save this search — get emailed about new matches'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveThisSearch(BuildContext context) async {
    final ctrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save this search'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Cheap textbooks'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty || !context.mounted) return;

    final filters = ListingFilters(
      category:  _category,
      condition: _condition,
      campus:    _campus,
      minPrice:  int.tryParse(_minPriceCtrl.text),
      maxPrice:  int.tryParse(_maxPriceCtrl.text),
    );
    final err = await context.read<ListingsProvider>().saveSearch(label, filters: filters);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Search saved — you\'ll get an email about new matches')),
      );
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.bgInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.black : AppTheme.textSecondary)),
      ),
    );
  }
}
