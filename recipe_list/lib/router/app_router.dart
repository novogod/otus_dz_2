import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/admin_session.dart';
import '../data/app_services.dart';
import '../i18n.dart';
import '../main.dart' show splashAndRecipesKey;
import '../models/recipe.dart';
import '../ui/add_recipe_page.dart';
import '../ui/admin_after_login_page.dart';
import '../ui/app_shell.dart';
import '../ui/app_theme.dart' show AppDurations;
import '../ui/favorites_page.dart';
import '../ui/login_page.dart';
import '../ui/recipe_details_page.dart';
import '../ui/source_page.dart';
import '../ui/splash_and_recipes.dart';
import '../ui/user_card_page.dart';
import 'routes.dart';

/// Корневой [GlobalKey] для root-навигатора `GoRouter`.
///
/// Передаётся в `parentNavigatorKey:` тех роутов, которые
/// должны рендериться **поверх** shell-навбара (login/admin).
/// Без этого они открывались бы внутри ветки профиля, и
/// `AppBottomNavBar` оставался бы видимым под ними — пользователь
/// видел экран авторизации с навбаром снизу. См. issue
/// «Splash and login/signup are below the bottom navbar».
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Глобальный [GoRouter] приложения.
///
/// Стратегия (см. `docs/go-router-shell-refactor.md`):
/// * `StatefulShellRoute.indexedStack` — корневой shell с
///   `AppBottomNavBar` в [AppShell]. На чанке A определена
///   единственная реальная ветка `recipes`; остальные вкладки
///   (`fridge`, `favorites`, `profile`) — placeholder-ы, которые
///   будут заменены в чанках B/C.
/// * Внутри recipes-ветки рендерится связка `splash → recipe list`
///   (тот же [_AppRoot], что был раньше внутри `MaterialApp.home`).
/// * Анимация slide-up сохраняется, потому что [SplashAndRecipes]
///   живёт в `pageBuilder` ветки и его state кэшируется
///   `IndexedStack`-ом shell-а.
final GoRouter appRouter = GoRouter(
  initialLocation: Routes.recipes,
  navigatorKey: rootNavigatorKey,
  // Перерисовываем редиректы при смене auth-состояния: после
  // успешного логина `/profile/login` должен автоматически
  // переехать на `/profile/admin`, а после `logout` — обратно
  // (см. `_profileRedirect` ниже). Без `refreshListenable`
  // редиректы запускались бы только на явных навигациях.
  refreshListenable: Listenable.merge(<Listenable>[
    adminLoggedInNotifier,
    userLoggedInNotifier,
    currentRecipeAdminTokenNotifier,
    currentUserLoginNotifier,
  ]),
  redirect: _profileRedirect,
  routes: <RouteBase>[
    // ── todo/20 chunk D + F: locale-prefix routing ──
    // Pre-rendered URLs из sitemap.xml вида `/<lang>/recipes/<id>`
    // (а также `/<lang>/recipes`) перенаправляются внутрь SPA-shell.
    // Локаль захватывается query-параметром `?lang=`, и заодно
    // переключаем глобальный `appLang` ДО редиректа, чтобы детали
    // (и chunk-F SEO-инжекция в head) сразу рендерились на нужном
    // языке без дополнительного networkidle ожидания.
    // Старые share-link'и `/recipes/details/<id>` остаются рабочими.
    GoRoute(
      path: '/:lang(${Routes.localePathPattern})/recipes/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final lang = state.pathParameters['lang'] ?? '';
        _applyLocaleFromPath(lang);
        return '${Routes.recipes}/details/$id?lang=$lang';
      },
    ),
    GoRoute(
      path: '/:lang(${Routes.localePathPattern})/recipes',
      redirect: (context, state) {
        final lang = state.pathParameters['lang'] ?? '';
        _applyLocaleFromPath(lang);
        return '${Routes.recipes}?lang=$lang';
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navShell) {
        return AppShell(navShell: navShell);
      },
      branches: <StatefulShellBranch>[
        // [0] Recipes — реальный экран ленты + splash.
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.recipes,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                child: SplashAndRecipes(key: splashAndRecipesKey),
              ),
              routes: <RouteBase>[
                GoRoute(
                  path: Routes.detailsSubpath,
                  builder: (context, state) =>
                      _buildDetailsPage(context, state),
                ),
                GoRoute(
                  path: Routes.addSubpath,
                  builder: (context, state) => _buildAddRecipePage(state),
                ),
                GoRoute(
                  path: Routes.editSubpath,
                  builder: (context, state) => _buildAddRecipePage(state),
                ),
                GoRoute(
                  path: Routes.sourceSubpath,
                  builder: (context, state) => _buildSourcePage(state),
                ),
              ],
            ),
          ],
        ),
        // [1] Fridge — placeholder, чанк выходит за рамки 19;
        //     показывает «coming soon» с возвратом по тапу.
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/fridge',
              pageBuilder: (context, state) =>
                  const NoTransitionPage<void>(child: _ComingSoonPage()),
            ),
          ],
        ),
        // [2] Favorites — реальный экран «Избранного». Зависимости
        //     (`api`/`repository`) забираются из [appServicesNotifier],
        //     который наполняется `RecipeListLoader`-ом при первом
        //     успешном раскладе ленты. До этого момента
        //     `FavoritesPage` корректно работает без api (FAB
        //     добавления просто не рендерится).
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.favorites,
              pageBuilder: (context, state) =>
                  const NoTransitionPage<void>(child: _FavoritesBranchRoot()),
              routes: <RouteBase>[
                GoRoute(
                  path: Routes.detailsSubpath,
                  builder: (context, state) =>
                      _buildDetailsPage(context, state),
                ),
                GoRoute(
                  path: Routes.addSubpath,
                  builder: (context, state) => _buildAddRecipePage(state),
                ),
                GoRoute(
                  path: Routes.editSubpath,
                  builder: (context, state) => _buildAddRecipePage(state),
                ),
                GoRoute(
                  path: Routes.sourceSubpath,
                  builder: (context, state) => _buildSourcePage(state),
                ),
              ],
            ),
          ],
        ),
        // [3] Profile — auth-aware ветка. Один роут `/profile`,
        //     `_ProfileBranchRoot` сам выбирает между LoginPage
        //     и AdminAfterLoginPage по auth-нотифаерам. Без
        //     subroutes /profile/login и /profile/admin —
        //     раньше они выезжали slide-up на rootNavigator и
        //     закрывались back-кнопкой, открывая ту же страницу
        //     уже без back-кнопки (двойной Profile).
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.profile,
              builder: (context, state) => const _ProfileBranchRoot(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Заглушка для ещё не реализованных вкладок (Fridge).
/// Показывает локализованный текст «скоро будет» (`tabComingSoon`)
/// крупно по центру с иконкой и заголовком вкладки в AppBar,
/// чтобы пользователь точно видел контент, а не пустой экран.
class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.tabFridge)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.construction,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                s.tabComingSoon,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Корневой виджет ветки `/profile`: рендерится, когда роутер
/// останавливается на голом `/profile` (без sub-route). По
/// auth-нотифаерам выбирает между `LoginPage` и
/// `AdminAfterLoginPage`. Подписан через
/// [ValueListenableBuilder], так что вход/выход
/// автоматически переключают экран в пределах той же ветки —
/// без дополнительных навигаций. Sub-роуты `/profile/login` и
/// `/profile/admin` остаются как slide-up overlay-варианты, но
/// эта же страница работает как fallback, если редирект не
/// успел или был отменён (видели grey-screen на не-EN
/// локалях после смены языка).
class _ProfileBranchRoot extends StatelessWidget {
  const _ProfileBranchRoot();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: adminLoggedInNotifier,
      builder: (context, _, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: userLoggedInNotifier,
          builder: (context, _, __) {
            return ValueListenableBuilder<String?>(
              valueListenable: currentRecipeAdminTokenNotifier,
              builder: (context, token, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: currentUserLoginNotifier,
                  builder: (context, login, _) {
                    final hasAdmin = adminLoggedInNotifier.value;
                    final loginTrim = login?.trim() ?? '';
                    // Только админ получает «Profile»-страницу с
                    // админ-кнопками (AdminAfterLoginPage).
                    // Обычный залогиненный юзер видит LoginPage в
                    // logout-режиме (он сам переключается по
                    // userLoggedIn && !adminLoggedIn) — это и есть
                    // «Logout screen» для regular user.
                    if (hasAdmin && loginTrim.isNotEmpty) {
                      return AdminAfterLoginPage(
                        adminLogin: loginTrim,
                        adminPassword: currentSessionAdminPassword ?? '',
                      );
                    }
                    // chunk D: regular logged-in users land on the
                    // User Card page. Optional `extra` from the
                    // signup-success redirect carries
                    // {initialEditMode, isPostSignup}.
                    final extra = GoRouterState.of(context).extra;
                    final isPostSignup = extra is Map &&
                        extra['isPostSignup'] == true;
                    final initialEditMode = (extra is Map &&
                            extra['initialEditMode'] == true) ||
                        isPostSignup;
                    if (userLoggedInNotifier.value && loginTrim.isNotEmpty) {
                      return UserCardPage(
                        initialEditMode: initialEditMode,
                        isPostSignup: isPostSignup,
                      );
                    }
                    // hasUser/hasToken без login — кейс редкий
                    // (битая сессия): пусть LoginPage предложит
                    // авторизоваться повторно.
                    return LoginPage(
                      initialLogin: loginTrim.isNotEmpty ? loginTrim : null,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Заглушка для вкладки «Избранное» на чанке A. Будет заменена
/// в чанке B на реальный `FavoritesPage` со state-сохранением
/// между переключениями вкладок.
class _FavoritesBranchRoot extends StatelessWidget {
  const _FavoritesBranchRoot();

  @override
  Widget build(BuildContext context) {
    // `FavoritesPage` ждёт `api`/`repository`, которые
    // публикуются `RecipeListLoader` через [appServicesNotifier]
    // (см. `lib/data/app_services.dart`). На холодный старт
    // notifier ещё пуст — рендерим страницу без зависимостей,
    // FAB добавления просто не появится. Когда сервисы доедут,
    // [ValueListenableBuilder] перерисует ветку с уже не-null
    // api/repo.
    return ValueListenableBuilder<AppServices?>(
      valueListenable: appServicesNotifier,
      builder: (context, services, _) {
        return FavoritesPage(
          api: services?.api,
          repository: services?.repository,
        );
      },
    );
  }
}

/// Сборка экрана деталей рецепта для go_router-веток. Полный
/// `Recipe` пробрасывается через `state.extra` (так делают
/// тапы с ленты/избранного), что позволяет открыть детали
/// без повторного fetch-а.
///
/// При deep-link / refresh-е страницы extra=null — это путь, по
/// которому приходит и пользовательский reload, и бот-pre-renderer
/// (todo/20 chunk E). В этом случае подгружаем рецепт по id через
/// `RecipeApi.lookup`; пока идёт fetch, показываем спиннер. После
/// успеха монтируется штатный [RecipeDetailsPage], который сам
/// эмитит per-recipe SEO-атомы (todo/20 chunk F) и `ssr-ready`,
/// чтобы pre-renderer мог сделать снапшот с правильным `<title>`,
/// hreflang и JSON-LD `Recipe`.
Widget _buildDetailsPage(BuildContext context, GoRouterState state) {
  final recipe = state.extra;
  if (recipe is Recipe) {
    final services = appServicesNotifier.value;
    return RecipeDetailsPage(
      recipe: recipe,
      api: services?.api,
      repository: services?.repository,
    );
  }
  final idStr = state.pathParameters['id'];
  final id = idStr == null ? null : int.tryParse(idStr);
  if (id == null || id <= 0) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && context.canPop()) context.pop();
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
  return _DeepLinkDetailsLoader(id: id);
}

/// Подгружает [Recipe] по id для прямого захода на
/// `/recipes/details/<id>` (или ребрендированный `/<lang>/recipes/<id>`
/// из chunk D). Берёт api/repository из [appServicesNotifier]: если
/// сервисы ещё не инициализированы (первый кадр после splash),
/// слушаем notifier и повторяем попытку, как только они появятся.
class _DeepLinkDetailsLoader extends StatefulWidget {
  const _DeepLinkDetailsLoader({required this.id});

  final int id;

  @override
  State<_DeepLinkDetailsLoader> createState() => _DeepLinkDetailsLoaderState();
}

class _DeepLinkDetailsLoaderState extends State<_DeepLinkDetailsLoader> {
  Recipe? _recipe;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    appServicesNotifier.addListener(_onServices);
    _fetch();
  }

  @override
  void dispose() {
    appServicesNotifier.removeListener(_onServices);
    super.dispose();
  }

  void _onServices() {
    if (_recipe == null && !_failed) _fetch();
  }

  Future<void> _fetch() async {
    final services = appServicesNotifier.value;
    final api = services?.api;
    if (api == null) return; // wait for splash → services
    try {
      final fetched = await api.lookup(
        widget.id,
        lang: appLang.value,
        timeout: const Duration(seconds: 12),
      );
      if (!mounted) return;
      if (fetched == null) {
        setState(() => _failed = true);
        return;
      }
      setState(() => _recipe = fetched);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _recipe;
    if (r != null) {
      final services = appServicesNotifier.value;
      return RecipeDetailsPage(
        recipe: r,
        api: services?.api,
        repository: services?.repository,
      );
    }
    if (_failed) {
      // Recipe missing / API error — let the user back out instead of
      // staring at a spinner. Bots get a 200 with the SPA shell, which
      // is acceptable for a 404-style URL.
      return const Scaffold(body: Center(child: Text('Not found')));
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Сборка экрана `AddRecipePage` для add- и edit-роутов.
///
/// Подхватывает api/repository из [appServicesNotifier] (так же,
/// как [_FavoritesBranchRoot]), чтобы строки на push не нужно
/// было таскать сервисы вручную через `extra`. В edit-режиме
/// полный [Recipe] прилетает через `state.extra` (callsite
/// уже знает рецепт). Если extra пустое (например, прямой
/// deep-link на `/recipes/edit/123` без preload) — выходим
/// обратно: full edit без подкачки рецепта в чанке D не
/// реализуем.
Widget _buildAddRecipePage(GoRouterState state) {
  final services = appServicesNotifier.value;
  final extra = state.extra;
  Recipe? existing;
  if (extra is Recipe) existing = extra;
  return AddRecipePage(
    api: services?.api,
    repository: services?.repository,
    existing: existing,
  );
}

/// Сборка [SourcePage] из query-параметра `url`. Если url не
/// задан — `SourcePage` всё равно отрендерится, но загрузить
/// ничего не сможет (пустая строка), поэтому в этом редком
/// случае показываем заглушку и возвращаемся.
Widget _buildSourcePage(GoRouterState state) {
  final url = state.uri.queryParameters['url'] ?? '';
  if (url.isEmpty) {
    return const Scaffold(body: Center(child: Text('source url missing')));
  }
  return SourcePage(url: url);
}

/// Auth-aware redirect для профильной ветки. На текущем шаге
/// единственный профильный роут — `/profile`, а
/// `_ProfileBranchRoot` сам выбирает между LoginPage и
/// AdminAfterLoginPage по auth-нотифаерам, поэтому redirect
/// тривиален: пропускаем всё как есть. Сохранён как hook на
/// случай возврата к sub-роутам и для совместимости с
/// `refreshListenable`-подпиской.
String? _profileRedirect(BuildContext context, GoRouterState state) => null;

/// Переводит глобальный `appLang` в локаль, пришедшую в URL
/// (`/:lang/recipes/...`). Вызывается из `redirect` chunk-D роутов
/// до того, как страница сматчится в SPA-shell ветку. Без этого
/// перехода chunk-F SEO-инжекция выдала бы атомы для устаревшей
/// локали (или для дефолтной EN при первом deep-link'е).
void _applyLocaleFromPath(String code) {
  for (final lang in AppLang.values) {
    if (lang.name == code && appLang.value != lang) {
      cycleAppLangTo(lang);
      return;
    }
  }
}

/// Slide-up `CustomTransitionPage` — общий конструктор для
/// `/profile/login` и `/profile/admin`. Параметры тayouta
/// (длительность, кривая, направление) совпадают с тем, что
/// раньше задавалось в `buildLoginRoute`/`_signUpRoute`/
/// `openPasswordRecoveryPage`, чтобы UX слайд-апа не дрейфовал
/// между «модальным» и «вкладочным» открытием.
// ignore: unused_element
CustomTransitionPage<T> _slideUpPage<T>({
  required Widget child,
  LocalKey? key,
}) {
  return CustomTransitionPage<T>(
    key: key,
    transitionDuration: AppDurations.splashTransition,
    reverseTransitionDuration: AppDurations.splashTransition,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved);
      return SlideTransition(position: slide, child: child);
    },
  );
}
