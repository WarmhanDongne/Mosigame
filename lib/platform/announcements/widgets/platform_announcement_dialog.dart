import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/announcements/models/platform_announcement.dart';

Future<void> showPlatformAnnouncementDialog({
  required BuildContext context,
  required PlatformAnnouncement announcement,
  VoidCallback? onOpenStore,
}) {
  final maintenance = announcement.kind == PlatformAnnouncementKind.maintenance;
  return showDialog<void>(
    context: context,
    barrierDismissible: !maintenance,
    builder: (dialogContext) => PopScope(
      canPop: !maintenance,
      child: _PlatformAnnouncementDialog(
        announcement: announcement,
        onOpenStore: onOpenStore,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    ),
  );
}

class _PlatformAnnouncementDialog extends StatelessWidget {
  const _PlatformAnnouncementDialog({
    required this.announcement,
    required this.onDismiss,
    this.onOpenStore,
  });

  final PlatformAnnouncement announcement;
  final VoidCallback onDismiss;
  final VoidCallback? onOpenStore;

  @override
  Widget build(BuildContext context) {
    final maintenance =
        announcement.kind == PlatformAnnouncementKind.maintenance;
    final copy = announcement.copyFor(Localizations.localeOf(context));
    final title = copy.title.isEmpty
        ? (maintenance
              ? GameLocale.select(
                  ko: '서버 점검 안내',
                  en: 'Maintenance notice',
                  zhHans: '服务器维护通知',
                  zhHant: '伺服器維護通知',
                )
              : GameLocale.select(
                  ko: '새 소식',
                  en: 'What’s new',
                  zhHans: '最新消息',
                  zhHant: '最新消息',
                ))
        : copy.title;
    final body = copy.body;
    final period = announcement.maintenancePeriod;
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.none,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(28, 58, 28, 25),
              decoration: BoxDecoration(
                color: MosiColors.white,
                border: Border.all(color: MosiColors.ink, width: 3),
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(color: MosiColors.navy, offset: Offset(8, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: maintenance ? MosiColors.sun : MosiColors.coral,
                      border: Border.all(color: MosiColors.ink, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      maintenance ? 'MAINTENANCE' : 'NOTICE',
                      style: MosiFonts.sans(
                        size: 11,
                        weight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: MosiFonts.sans(size: 23, weight: FontWeight.w900),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: MosiFonts.sans(
                        size: 15,
                        color: MosiColors.muted,
                        height: 1.55,
                      ),
                    ),
                  ],
                  if (maintenance && period != null && period.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: MosiColors.navy,
                        border: Border.all(color: MosiColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            GameLocale.select(
                              ko: '점검 시간',
                              en: 'Maintenance window',
                              zhHans: '维护时间',
                              zhHant: '維護時間',
                            ),
                            style: MosiFonts.sans(
                              size: 12,
                              color: MosiColors.white.withValues(alpha: .76),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            period,
                            textAlign: TextAlign.center,
                            style: MosiFonts.sans(
                              size: 18,
                              weight: FontWeight.w900,
                              color: MosiColors.sun,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!maintenance) ...[
                    const SizedBox(height: 21),
                    _buildNoticeActions(isPhone: isPhone),
                  ],
                ],
              ),
            ),
            // 둥근 모서리는 남기되 아이콘 높이를 가로지르는 카드 윗선은
            // 공지·점검 모두 흰색으로 덮어 보이지 않게 합니다.
            Positioned(
              key: const Key('platform-announcement-top-rule-mask'),
              top: -1,
              left: 25,
              right: 25,
              child: Container(height: 5, color: MosiColors.white),
            ),
            Positioned(
              top: -44,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: maintenance ? MosiColors.coral : MosiColors.sun,
                    border: Border.all(color: MosiColors.ink, width: 3),
                    boxShadow: const [
                      BoxShadow(color: MosiColors.navy, offset: Offset(4, 4)),
                    ],
                  ),
                  child: Icon(
                    maintenance
                        ? Icons.construction_rounded
                        : Icons.campaign_rounded,
                    color: MosiColors.ink,
                    size: 38,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeActions({required bool isPhone}) {
    final close = GameLocale.select(
      ko: '닫기',
      en: 'Close',
      zhHans: '关闭',
      zhHant: '關閉',
    );
    if (isPhone || onOpenStore == null) {
      return MosiButton(
        label: close,
        height: 51,
        expand: true,
        onPressed: onDismiss,
      );
    }
    return Row(
      children: [
        Expanded(
          child: MosiButton(
            label: close,
            variant: MosiButtonVariant.outline,
            height: 51,
            onPressed: onDismiss,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MosiButton(
            label: GameLocale.select(
              ko: '상점으로',
              en: 'Go to store',
              zhHans: '前往商店',
              zhHant: '前往商店',
            ),
            height: 51,
            onPressed: () {
              onDismiss();
              onOpenStore?.call();
            },
          ),
        ),
      ],
    );
  }
}
