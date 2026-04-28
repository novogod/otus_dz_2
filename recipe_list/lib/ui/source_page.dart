import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../i18n.dart';
import 'app_bottom_nav_bar.dart';
import 'app_theme.dart';
import 'lang_icon_button.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.surface)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, color: AppColors.primaryDark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          s.source,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 20,
            height: 23 / 20,
            color: AppColors.primaryDark,
          ),
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
      body: WebViewWidget(controller: _controller),
      bottomNavigationBar: const AppBottomNavBar(current: AppNavTab.recipes),
    );
  }
}
