import 'package:flutter/material.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:game_kit/template_game.dart';

/// 게임 진입 직전에 캐시를 검증하고, 다운로드 게임이면 사용자 진입 동작을
/// 계기로 필요한 파일을 설치한 뒤 다시 검증합니다.
Future<void> prepareGameAssetsForPlay(TemplateGame game) async {
  final store = GameAssetStore.instance;
  try {
    await store.prepareGame(game.id);
    return;
  } catch (_) {
    if (game.requiredAssetVersion <= 0) rethrow;
  }

  await store.downloadGame(game.id);
  await store.prepareGame(game.id);
}

/// Recovery uses verified cached assets. Only proven missing/corrupt files offer repair.
Future<bool> prepareGameAssetsForRecovery(
  TemplateGame game,
  BuildContext context,
) async {
  final store = GameAssetStore.instance;
  try {
    await store.prepareGame(game.id);
    return true;
  } catch (error) {
    if (game.requiredAssetVersion <= 0 ||
        error is! StateError ||
        error.message != '게임 에셋을 먼저 다운로드해야 합니다.') {
      rethrow;
    }
  }
  if (!context.mounted) return false;
  final repair = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x8C0E0A3D),
    builder: (context) => _AssetRepairDialog(gameId: game.id),
  );
  if (repair != true || !context.mounted) return false;
  await store.downloadGame(game.id);
  await store.prepareGame(game.id);
  return true;
}

/// 게임 파일 복구 확인 창입니다(시안 08-B).
///
/// 왼쪽은 게임 색 바탕에 표지, 오른쪽은 설명과 버튼입니다. `true`를 돌려주면
/// 파일을 다시 받고, `false`면 게임과 그룹에서 나갑니다.
class _AssetRepairDialog extends StatelessWidget {
  const _AssetRepairDialog({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    final ground = MosiGameArt.of(gameId).shelfTheme.ground;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: MosiColors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: MosiColors.ink, width: 4),
            boxShadow: const [
              BoxShadow(color: MosiColors.navy, offset: Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            // 왼쪽 게임 색 판은 오른쪽 글 높이에 맞춰 늘어나도록 뒤에 깝니다.
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 224,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ground,
                      border: const Border(
                        right: BorderSide(color: MosiColors.ink, width: 4),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 224,
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: ExcludeSemantics(
                          child: Center(
                            child: MosiGameCover(gameId: gameId, width: 140),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 30, 32, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: MosiColors.sun,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: MosiColors.ink,
                                  width: 2.5,
                                ),
                              ),
                              child: Text(
                                GameLocale.select(
                                  ko: '파일 확인 필요',
                                  en: 'Files need attention',
                                  zhHans: '需要检查文件',
                                  zhHant: '需要檢查檔案',
                                ),
                                style: MosiFonts.sans(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: MosiColors.ink,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              GameLocale.select(
                                ko: '게임 파일을 복구할까요?',
                                en: 'Recover the game files?',
                                zhHans: '要修复游戏文件吗？',
                                zhHant: '要修復遊戲檔案嗎？',
                              ),
                              style: MosiFonts.sans(
                                size: 26,
                                weight: FontWeight.w700,
                                color: MosiColors.navy,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              GameLocale.select(
                                ko: '필요한 게임 파일이 없거나 손상되었습니다. 파일을 다시 받으면 하던 게임으로 바로 돌아가요.',
                                en: 'Required game files are missing or damaged. Download them again to go straight back to your game.',
                                zhHans: '所需的游戏文件缺失或损坏。重新下载后即可回到刚才的游戏。',
                                zhHant: '所需的遊戲檔案缺失或損壞。重新下載後即可回到剛才的遊戲。',
                              ),
                              style: MosiFonts.sans(
                                size: 16,
                                color: MosiColors.muted,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: MosiButton(
                                    label: GameLocale.select(
                                      ko: '파일 복구',
                                      en: 'Recover files',
                                      zhHans: '修复文件',
                                      zhHant: '修復檔案',
                                    ),
                                    expand: true,
                                    height: 58,
                                    fontSize: 18,
                                    radius: 14,
                                    shadowOffset: 5,
                                    background: MosiColors.lime,
                                    foreground: MosiColors.ink,
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 6,
                                  child: MosiButton(
                                    label: GameLocale.select(
                                      ko: '게임과 그룹 나가기',
                                      en: 'Leave game and room',
                                      zhHans: '退出游戏和房间',
                                      zhHant: '退出遊戲和房間',
                                    ),
                                    expand: true,
                                    height: 58,
                                    fontSize: 15,
                                    radius: 14,
                                    shadowOffset: 5,
                                    background: MosiColors.white,
                                    foreground: MosiColors.red,
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
