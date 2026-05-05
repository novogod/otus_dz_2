// Chunk F of docs/user-card-and-social-signals.md.
//
// "Added by" footer rendered on the recipe details page when a
// recipe was uploaded by an end user (id ≥ 1_000_000) and the
// server has projected creator metadata. Hidden completely when
// [name] is null — that's the signal "no creator info, don't show
// the row at all".

import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../utils/imgproxy.dart';
import '../app_theme.dart';

/// Stateless display of "added by ${name} — ${count} recipes".
///
/// Pass [name] = null to render nothing (returns
/// [SizedBox.shrink]). [recipesAdded] = null hides the count line
/// only; the avatar + name still render.
class AddedByRow extends StatelessWidget {
  const AddedByRow({
    super.key,
    required this.name,
    required this.avatarPath,
    required this.recipesAdded,
  });

  final String? name;
  final String? avatarPath;
  final int? recipesAdded;

  @override
  Widget build(BuildContext context) {
    final n = name;
    if (n == null) return const SizedBox.shrink();

    final s = S.of(context);
    final avatar = _buildAvatar(avatarPath);
    final added = recipesAdded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          avatar,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${s.recipeAddedByPrefix} $n',
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 22 / 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (added != null && added > 0)
                  Text(
                    s.recipeAuthorRecipes(added),
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
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? path) {
    const size = 64.0;
    final clip = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: path == null
            ? const ColoredBox(
                color: AppColors.surfaceMuted,
                child: Icon(
                  Icons.person,
                  size: 36,
                  color: AppColors.textSecondary,
                ),
              )
            : Image.network(
                imgproxyUrl(path, 64, 64),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: AppColors.surfaceMuted,
                  child: Icon(
                    Icons.person,
                    size: 36,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
      ),
    );
    return clip;
  }
}
