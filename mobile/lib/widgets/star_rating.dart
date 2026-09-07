import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Read-only star display — e.g. "★★★★☆ 4.2 (18)" next to a seller's name.
class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final int count;
  final double size;

  const StarRatingDisplay({super.key, required this.rating, required this.count, this.size = 14});

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Text('No ratings yet', style: TextStyle(fontSize: size - 1, color: AppTheme.textLight));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ...List.generate(5, (i) => Icon(
        i < rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
        size: size,
        color: AppTheme.primary,
      )),
      const SizedBox(width: 4),
      Text('${rating.toStringAsFixed(1)} ($count)',
          style: TextStyle(fontSize: size - 1, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
    ]);
  }
}

/// Interactive 1-5 star picker used in the "rate this exchange" dialog.
class StarRatingInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const StarRatingInput({super.key, required this.value, required this.onChanged, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        return GestureDetector(
          onTap: () => onChanged(starIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              starIndex <= value ? Icons.star_rounded : Icons.star_border_rounded,
              size: size,
              color: AppTheme.primary,
            ),
          ),
        );
      }),
    );
  }
}
