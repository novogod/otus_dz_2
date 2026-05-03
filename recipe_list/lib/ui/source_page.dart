import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../i18n.dart';
import 'app_bottom_nav_bar.dart';
import 'app_theme.dart';
import 'lang_icon_button.dart';
import 'login_page.dart';

/// Внутристраничный читатель внешнего источника рецепта.
///
/// Открывается по кнопке `Source` на экране деталей. Сам контент
/// (страница `recipe.sourceUrl`) рендерится через [WebViewWidget]
/// в полосе между [AppBar] и [AppBottomNavBar]. AppBar имеет
/// заголовок `Source` (см. [S.source]) и chevron-кнопку назад.
class SourcePage extends StatefulWidget {
  final String url;

  const SourcePage({super.key, required this.url});

  @override
  State<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<SourcePage> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _loading = true;
  String _currentUrl = '';

  /// Многие кулинарные сайты отдают мобильному WKWebView без UA
  /// редирект на главную. Подставляем строку Safari/iOS, чтобы
  /// получать тот же ответ, что и реальный мобильный браузер.
  static const String _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
      'Mobile/15E148 Safari/604.1';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.surface)
      ..setUserAgent(_userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onPageStarted: (u) => setState(() {
            _loading = true;
            _currentUrl = u;
          }),
          onPageFinished: (u) => setState(() {
            _loading = false;
            _currentUrl = u;
          }),
          onUrlChange: (c) {
            final u = c.url;
            if (u != null) setState(() => _currentUrl = u);
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.url),
        headers: const {
          // Часть CDN отдают главную, если Accept не указан явно.
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,'
              'image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9,ru;q=0.8',
        },
      );
  }

  String get _hostLabel {
    final u = Uri.tryParse(_currentUrl);
    return u?.host ?? _currentUrl;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + (_loading ? 2 : 0)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primaryDark,
            leading: IconButton(
              tooltip: s.back,
              icon: const Icon(
                Icons.chevron_left,
                color: AppColors.primaryDark,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.source,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 20,
                    height: 23 / 20,
                    color: AppColors.primaryDark,
                  ),
                ),
                if (_hostLabel.isNotEmpty)
                  Text(
                    _hostLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                      height: 13 / 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            centerTitle: true,
            actions: const [LangIconButton()],
            bottom: _loading
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(2),
                    child: LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress,
                      minHeight: 2,
                      backgroundColor: AppColors.surfaceMuted,
                    ),
                  )
                : null,
          ),
        ),
      ),
      body: WebViewWidget(controller: _controller),
      bottomNavigationBar: AppBottomNavBar(
        current: AppNavTab.recipes,
        onTap: (tab) {
          if (tab == AppNavTab.profile) {
            openLoginPage(context);
            return;
          }
          Navigator.of(context).maybePop();
        },
      ),
    );
  }
}
