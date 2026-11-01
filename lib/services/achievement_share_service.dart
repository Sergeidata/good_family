import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/achievement_share_card.dart';
import '../widgets/loading_dots.dart';

class AchievementShareService {
  /// Готовит картинку 1080×1920 в фоне и открывает системный диалог «Поделиться».
  /// Превью пользователю не показывается: карточка рисуется под непрозрачным
  /// слоем с индикатором загрузки.
  static Future<void> share({
    required BuildContext context,
    required AchievementShareCard card,
    required String shareText,
  }) async {
    // Логотип должен быть декодирован до снимка, иначе попадёт пустым.
    await precacheImage(
      const AssetImage(AchievementShareCard.logoAsset),
      context,
    );

    final boundaryKey = GlobalKey();
    final navigator = Navigator.of(context, rootNavigator: true);
    var overlayOpen = false;

    // не await: push завершается только при закрытии маршрута
    unawaited(navigator.push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => _PreparingLayer(
          boundaryKey: boundaryKey,
          card: card,
        ),
      ),
    ));
    overlayOpen = true;

    try {
      // Один кадр, чтобы RepaintBoundary гарантированно отрисовался.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(
        pixelRatio: AchievementShareCard.exportPixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/good_family_share.png');
      if (await file.exists()) await file.delete();
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      navigator.pop();
      overlayOpen = false;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: shareText,
        ),
      );
    } finally {
      if (overlayOpen && navigator.canPop()) navigator.pop();
    }
  }
}

/// Слой подготовки: карточка рисуется (RepaintBoundary), но перекрыта
/// непрозрачным фоном с индикатором — пользователь видит только загрузку.
class _PreparingLayer extends StatelessWidget {
  final GlobalKey boundaryKey;
  final Widget card;

  const _PreparingLayer({
    required this.boundaryKey,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Material(
        color: Colors.white,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: card,
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: const Center(child: LoadingDots()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
