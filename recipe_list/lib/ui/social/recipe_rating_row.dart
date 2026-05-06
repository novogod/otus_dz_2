// Chunk G of docs/user-card-and-social-signals.md.
//
// "Rate this recipe" row rendered on the details page below the
// AddedByRow (when present) and above the instructions block.
// Five 24dp stars: outline + textSecondary by default, filled +
// primary for the user's vote (or hover-preview while choosing).
// Right of the stars: the average rating (`X.X / 5`) and the
// total vote count.
//
// Anonymous users see the row but tapping a star surfaces the
// registration-required snackbar instead of voting. Authenticated
// users tap to set their vote; the optimistic update flows back
// from [RatingStore], the toast confirms.

import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../app_theme.dart';
import '../registration_required_snackbar.dart';

/// Stateless rating row. Holds no state — all UI changes flow
/// from the [ValueListenable<RecipeRatingSnapshot>] produced by
/// [RatingStore.watch] in the parent.
///
/// [count] / [sum] / [my] / [onRate] are passed in. [onRate] is
/// `null` when the row is read-only (used by the recipe card,
/// where the row is informational and not interactive).
class RecipeRatingRow extends StatelessWidget {
  const RecipeRatingRow({
    super.key,
    required this.count,
    required this.sum,
    required this.my,
    required this.onRate,
    this.compact = false,
  });

  /// Number of votes recorded.
  final int count;

  /// Sum of all votes (1..5 each). `avg = sum / count` when
  /// `count > 0`, otherwise 0.
  final int sum;

  /// Current user's vote (1..5) or null if not yet rated /
  /// anonymous.
  final int? my;

  /// Tap handler. `null` makes the row read-only (no ripple,
  /// fixed star color). When non-null, the widget calls it with
  /// the chosen star value (1..5) on tap.
  final ValueChanged<int>? onRate;

  /// Compact variant for the recipe list card: smaller stars, no
  /// numeric label. Always read-only — interactivity belongs to
  /// the details page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final avg = count > 0 ? sum / count : 0.0;
    final highlighted = my ?? 0;
    final starSize = compact ? 16.0 : 24.0;

    final stars = List<Widget>.generate(5, (i) {
      final value = i + 1;
      final isOn = value <= highlighted;
      final icon = Icon(
        isOn ? Icons.star_rounded : Icons.star_outline_rounded,
        size: starSize,
        color: isOn ? AppColors.primary : AppColors.textSecondary,
      );
      if (onRate == null || compact) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 2),
          child: icon,
        );
      }
      return Semantics(
        button: true,
        label: '${s.recipeRateTooltip} ($value)',
        child: InkResponse(
          onTap: () => onRate!(value),
          radius: starSize,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: icon,
          ),
        ),
      );
    });

    if (compact) {
      // Card variant per docs/user-card-and-social-signals.md §4.2:
      // "we render only the average + count, no interactive
      // stars". Show a single filled star + avg + count.
      if (count == 0) return const SizedBox.shrink();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 2),
          Text(
            avg.toStringAsFixed(1),
            style: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontWeight: FontWeight.w500,
              fontSize: 12,
              height: 16 / 12,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 16 / 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...stars,
          const SizedBox(width: AppSpacing.md),
          if (count > 0) ...[
            Text(
              s.recipeRatingAvg(avg: avg.toStringAsFixed(1)),
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                height: 22 / 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              s.recipeVotesCount(n: count),
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 20 / 14,
                color: AppColors.textSecondary,
              ),
            ),
          ] else
            Text(
              s.recipeRateTooltip,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 20 / 14,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Convenience handler for tapped stars on the details page —
/// shared between code paths so we always do the same thing on
/// "logged out" taps (snackbar, no exception).
Future<void> handleRatingTapWhenAnonymous(BuildContext context) async {
  showRegistrationRequiredSnackBar(context);
}
