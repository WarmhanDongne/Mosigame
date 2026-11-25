// [timeout_alarm.dart] 는 내 차례 시간이 다 됐을 때 오른쪽 조작 패널을
// 노란 "시간 끝!" 안내로 잠깐 덮는 파일이다.
//
// 디자인: Claude Design '시간 초과 턴 넘김 안내' 파이널콜 A안.
// 서버가 남긴 lastTimeout.kind에 따라 무엇이 자동으로 처리됐는지 알려 줍니다.
// 안내는 화면 표시만 하고 누름을 막지 않습니다(IgnorePointer).

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

/// 시간 초과로 서버가 대신 처리한 일입니다. 서버 `lastTimeout.kind` 값과 같습니다.
enum FinalCallTimeoutKind {
  discardDeck,
  discardDrawn,
  lastSwapSubmit,
  finalSubmit,
  deckEmpty;

  static FinalCallTimeoutKind? fromWire(String? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }

  String get message => switch (this) {
    FinalCallTimeoutKind.discardDeck => GameLocale.select(
      ko: '덱 맨 위 카드를\n자동으로 버렸어요',
      en: 'The top deck card\nwas discarded for you',
      zhHans: '已自动弃掉\n牌堆顶部的牌',
      zhHant: '已自動棄掉\n牌堆頂部的牌',
    ),
    FinalCallTimeoutKind.discardDrawn => GameLocale.select(
      ko: '새 카드는\n자동으로 버렸어요',
      en: 'Your new card\nwas discarded',
      zhHans: '新牌已\n自动弃掉',
      zhHant: '新牌已\n自動棄掉',
    ),
    FinalCallTimeoutKind.lastSwapSubmit => GameLocale.select(
      ko: '새 카드는 버리고\n가장 높은 조합을 냈어요',
      en: 'New card discarded,\nbest set submitted',
      zhHans: '已弃掉新牌\n并提交最高组合',
      zhHant: '已棄掉新牌\n並提交最高組合',
    ),
    FinalCallTimeoutKind.finalSubmit => GameLocale.select(
      ko: '가장 높은 조합을\n자동으로 제출했어요',
      en: 'Your best set\nwas submitted',
      zhHans: '已自动提交\n最高组合',
      zhHant: '已自動提交\n最高組合',
    ),
    FinalCallTimeoutKind.deckEmpty => GameLocale.select(
      ko: '덱이 다 떨어져서\n이번 라운드를 바로 끝내요',
      en: 'The deck is empty,\nso the round ends now',
      zhHans: '牌堆已空\n本局立即结束',
      zhHant: '牌堆已空\n本局立即結束',
    ),
  };
}

class FinalCallTimeoutAlarm extends StatefulWidget {
  const FinalCallTimeoutAlarm({super.key, required this.kind});

  final FinalCallTimeoutKind kind;

  /// 안내가 머무는 시간입니다. 상위 화면이 이 시간 뒤에 지웁니다.
  static const visibleFor = Duration(milliseconds: 2400);

  @override
  State<FinalCallTimeoutAlarm> createState() => _FinalCallTimeoutAlarmState();
}

class _FinalCallTimeoutAlarmState extends State<FinalCallTimeoutAlarm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final title = GameLocale.select(
      ko: '시간 끝!',
      en: "Time's up!",
      zhHans: '时间到！',
      zhHant: '時間到！',
    );
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: '$title ${widget.kind.message.replaceAll('\n', ' ')}',
        child: ExcludeSemantics(
          child: ColoredBox(
            color: FinalCallColors.yellow,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = reduceMotion ? 1.0 : _controller.value;
                final pop = Curves.easeOutBack.transform(
                  (t / .45).clamp(0.0, 1.0),
                );
                // 알람시계가 따르릉 흔들리다 멈춥니다.
                final ring = reduceMotion || t > .8
                    ? 0.0
                    : math.sin(t * math.pi * 10) * (1 - t / .8) * .28;
                return Center(
                  child: Transform.scale(
                    scale: .6 + .4 * pop,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.rotate(
                              angle: ring,
                              child: const Icon(
                                Icons.alarm_rounded,
                                size: 54,
                                color: FinalCallColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: finalCallPopText(30, height: 1.05),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.kind.message,
                              textAlign: TextAlign.center,
                              style: finalCallPopText(14, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
