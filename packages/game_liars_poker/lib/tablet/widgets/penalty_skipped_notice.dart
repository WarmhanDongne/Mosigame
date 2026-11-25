// [penalty_skipped_notice.dart] 는 LIAR 판정으로 정해진 벌칙 대상이 이미
// 강퇴·퇴장해서 룰렛 없이 넘어갈 때 태블릿 가운데에 띄우는 안내 파일이다.
//
// 잠깐 보여 준 뒤 [onShown]을 한 번 불러 서버에 "건너뜀"을 확정합니다.
// 최종 디자인이 정해지면 이 위젯의 모양만 바꾸면 됩니다.

// ========================[ import ]==========================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

class LiarsPokerPenaltySkippedNotice extends StatefulWidget {
  const LiarsPokerPenaltySkippedNotice({
    super.key,
    required this.nickname,
    required this.onShown,
  });

  final String nickname;

  /// 안내를 [hold]만큼 보여 준 뒤 한 번 호출합니다.
  final VoidCallback onShown;

  /// 안내를 보여 주는 시간입니다.
  static const hold = Duration(milliseconds: 2600);

  @override
  State<LiarsPokerPenaltySkippedNotice> createState() =>
      _LiarsPokerPenaltySkippedNoticeState();
}

class _LiarsPokerPenaltySkippedNoticeState
    extends State<LiarsPokerPenaltySkippedNotice> {
  static const _ink = Color(0xFF17110F);
  static const _bone = Color(0xFFF2EADB);
  static const _gold = Color(0xFFB9A782);
  static const _lie = Color(0xFFB8262B);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(LiarsPokerPenaltySkippedNotice.hold, () {
      if (mounted) widget.onShown();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = GameLocale.select(
      ko: '벌칙 건너뜀',
      en: 'PENALTY SKIPPED',
      zhHans: '跳过惩罚',
      zhHant: '跳過懲罰',
    );
    final body = GameLocale.select(
      ko: '${widget.nickname}님이 게임에서 나가\n룰렛 없이 다음 라운드로 넘어갑니다',
      en: '${widget.nickname} left the game.\nMoving on without the roulette.',
      zhHans: '${widget.nickname} 已离开游戏\n不转轮盘，直接进入下一回合',
      zhHant: '${widget.nickname} 已離開遊戲\n不轉輪盤，直接進入下一回合',
    );
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.fromLTRB(36, 28, 36, 30),
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _gold, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x88000000), blurRadius: 24),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _lie,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _bone, width: 2),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'BlackHanSans',
                    fontSize: 26,
                    color: _bone,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: _bone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
