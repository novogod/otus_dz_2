import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api/recipe_api.dart';
import '../data/repository/recipe_repository.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import '../utils/imgproxy.dart';
import 'app_bottom_nav_bar.dart';
import 'app_page_bar.dart';
import 'app_theme.dart';
import 'recipe_card.dart' show FavoriteBadge;
import 'source_page.dart';

/// Глобальный счётчик активных страниц деталей рецепта.
///
/// Поднимается в `initState`, опускается в `dispose`. Используется
/// `RecipeListLoader._onLangChanged`, чтобы не запускать тяжёлый
/// `_retranslate` всей ленты, пока пользователь сидит на экране
/// деталей и не видит список — это разгружает сервер и оставляет
/// пропускную способность для одного фокусного `/lookup` со страницы
/// деталей. См. docs/details-lang-cycle-504.md.
final ValueNotifier<int> activeDetailsCount = ValueNotifier<int>(0);

/// Экран деталей рецепта. Реализует разметку из `docs/design_system.md`
/// §9l: белый фон, hero-фото 396×220, заголовок страницы 24/#000,
/// секционные подзаголовки 16/#165932, белый блок ингредиентов с
/// обводкой `#797676` и колонками qty/name.
///
/// Лист подписан на [appLang] и при смене языка перезапрашивает
/// рецепт через [RecipeApi.lookup] — иначе на детали остаётся
/// «замороженный» рецепт того языка, который был активен в момент
/// перехода со списка, и кнопка флага кажется «неработающей».
class RecipeDetailsPage extends StatefulWidget {
  final Recipe recipe;
  final RecipeApi? api;
  final RecipeRepository? repository;

  const RecipeDetailsPage({
    super.key,
    required this.recipe,
    this.api,
    this.repository,
  });

  @override
  State<RecipeDetailsPage> createState() => _RecipeDetailsPageState();
}

class _RecipeDetailsPageState extends State<RecipeDetailsPage> {
  late Recipe _recipe;
  AppLang _renderedLang = appLang.value;

  /// `true`, пока идёт повторный fetch на смену языка. Поверх контента
  /// показываем непрозрачный лоадер, чтобы пользователь не видел
  /// «застывший» текст на старом языке и понимал, что переключение
  /// действительно идёт. Гасим только когда рецепт реально пришёл
  /// на новом языке (или ретраи исчерпаны).
  bool _translating = false;

  /// Монотонный счётчик запросов перевода — нужен, чтобы поздний
  /// ответ от старого языка не перезаписал результат нового.
  int _translateSeq = 0;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    appLang.addListener(_onLangChanged);
    activeDetailsCount.value = activeDetailsCount.value + 1;
  }

  @override
  void dispose() {
    appLang.removeListener(_onLangChanged);
    activeDetailsCount.value = activeDetailsCount.value - 1;
    super.dispose();
  }

  Future<void> _onLangChanged() async {
    final lang = appLang.value;
    if (lang == _renderedLang) return;
    _renderedLang = lang;
    final api = widget.api;
    if (api == null) return; // тесты без сети
    final seq = ++_translateSeq;
    if (mounted) setState(() => _translating = true);
    // Per docs/translation-pipeline.md: server-side `_isEchoTranslation`
    // + `evaluateCandidate` are authoritative. The client makes a
    // single `/lookup` call per language switch; the loader stays on
    // screen until that one call resolves. If the call fails, the
    // previous-language copy stays visible (doc §"What the contract
    // guarantees" → "Offline tolerance").
    //
    // Exception: when the target-lang lookup throws (typically a 504
    // when the server is saturated by a concurrent list-page
    // _retranslate — see docs/details-lang-cycle-504.md), retry once
    // in English so the page reflects the new flag with coherent
    // content rather than leaving stale Italian/etc. residue under a
    // Turkish UI. Mirrors the loader fallback added in 47c942c.
    Recipe? fetched;
    try {
      fetched = await api.lookup(
        _recipe.id,
        lang: lang,
        timeout: const Duration(seconds: 120),
      );
    } on Object catch (e) {
      // ignore: avoid_print
      print('[lang] details lookup failed: $e');
      fetched = null;
    }
    if (fetched == null && lang != AppLang.en) {
      try {
        fetched = await api.lookup(
          _recipe.id,
          lang: AppLang.en,
          timeout: const Duration(seconds: 30),
        );
      } on Object catch (e) {
        // ignore: avoid_print
        print('[lang] details EN fallback failed: $e');
        fetched = null;
      }
    }
    if (!mounted || seq != _translateSeq) return;
    final got = fetched;
    setState(() {
      if (got != null) _recipe = got;
      _translating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final recipe = _recipe;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppPageBar(
        title: Text(
          s.recipeTitle,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 20,
            height: 23 / 20,
            color: AppColors.primaryDark,
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        current: AppNavTab.recipes,
        onTap: (_) => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadii.cardAll,
                    child: AspectRatio(
                      aspectRatio: 396 / 220,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              // Hero отдаём больше пикселей чем в карточке (1200x675).
                              _detailsThumb(recipe.photo),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppColors.surfaceMuted,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.restaurant,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          // Бейдж избранного — top-right, симметрично
                          // карточке списка (chunk C todo/15).
                          Positioned(
                            top: AppSpacing.sm,
                            right: AppSpacing.sm,
                            child: FavoriteBadge(recipeId: recipe.id),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding,
                    AppSpacing.lg,
                    AppSpacing.pagePadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.name, style: AppTextStyles.pageTitle),
                      if (recipe.category != null || recipe.area != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            if (recipe.category != null)
                              _Badge(recipe.category!),
                            if (recipe.area != null) _Badge(recipe.area!),
                          ],
                        ),
                      ],
                      if (recipe.tags.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          recipe.tags.map((t) => '#$t').join('  '),
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            height: 23 / 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (recipe.ingredients.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          s.ingredientsHeader,
                          style: AppTextStyles.sectionTitle,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _IngredientsBlock(items: recipe.ingredients),
                      ],
                      if (recipe.instructions != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          s.instructionsHeader,
                          style: AppTextStyles.sectionTitle,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          recipe.instructions!,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                            height: 23 / 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ] else if (widget.repository != null) ...[
                        // todo/12: when the recipe came from the cache,
                        // its `instructions` field is null. Lazy-load
                        // it from `recipe_bodies`. While loading, show
                        // a slim shimmer block so the page height
                        // stays stable.
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          s.instructionsHeader,
                          style: AppTextStyles.sectionTitle,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FutureBuilder<String?>(
                          future: widget.repository!.getInstructions(
                            recipe.id,
                            _renderedLang,
                          ),
                          builder: (ctx, snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return Container(
                                key: const ValueKey('instructions-shimmer'),
                                height: 92,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: AppRadii.cardAll,
                                ),
                              );
                            }
                            final body = snap.data;
                            if (body == null || body.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              body,
                              style: const TextStyle(
                                fontFamily: AppTextStyles.fontFamily,
                                fontWeight: FontWeight.w400,
                                fontSize: 16,
                                height: 23 / 16,
                                color: AppColors.textPrimary,
                              ),
                            );
                          },
                        ),
                      ],
                      if (recipe.youtubeUrl != null ||
                          recipe.sourceUrl != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            if (recipe.youtubeUrl != null)
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  foregroundColor: AppColors.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.button,
                                    ),
                                  ),
                                ),
                                onPressed: () => _open(recipe.youtubeUrl!),
                                icon: const Icon(Icons.play_arrow),
                                label: Text(s.youtube),
                              ),
                            if (recipe.sourceUrl != null)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryDark,
                                  side: const BorderSide(
                                    color: AppColors.primaryDark,
                                    width: 3,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.button,
                                    ),
                                  ),
                                ),
                                onPressed: () =>
                                    _openSource(context, recipe.sourceUrl!),
                                icon: const Icon(Icons.link),
                                label: Text(s.source),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_translating)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xCCFFFFFF),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static void _openSource(BuildContext context, String url) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => SourcePage(url: url)));
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 13,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

/// Блок ингредиентов: белый контейнер с обводкой `#797676` шириной 3 и
/// двумя колонками — мера слева, название справа. См. §9l.
class _IngredientsBlock extends StatelessWidget {
  final List<RecipeIngredient> items;

  const _IngredientsBlock({required this.items});

  @override
  Widget build(BuildContext context) {
    final metrics = AppMetrics.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardAll,
        border: Border.all(color: AppColors.textSecondary, width: 3),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final ing in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: metrics.measureColumnWidth,
                    child: Text(
                      ing.measure,
                      style: AppTextStyles.ingredientQty,
                      softWrap: true,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '   ${ing.name}',
                      style: AppTextStyles.ingredientName,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Hero-thumbnail для details page. Для recipe-photos в mahallem
/// идём через imgproxy (1200×675 ≈ 250 КБ JPEG); для TheMealDB
/// возвращаем оригинал — там и так уже 50–100 КБ.
String _detailsThumb(String url) {
  if (url.startsWith('/storage/') || url.contains('/recipe-photos/')) {
    return imgproxyUrl(url, 1200, 675);
  }
  return url;
}
