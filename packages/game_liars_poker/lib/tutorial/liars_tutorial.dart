// [liars_tutorial.dart] 라이어스 첫 플레이 튜토리얼(태블릿 + 휴대폰)이다.
//
// 자리 배치가 끝난 뒤 실제 자리·캐릭터로 한 판을 따라 하며 규칙을 배웁니다.
// 진행(모두 확인·모두 연습·모두 건너뛰기·끝 선택)은 game_kit의
// [GameTutorialTabletHost]·[GameTutorialPhoneGate]가 맡고, 이 파일은 단계별
// 화면만 그립니다. 카드·버튼·테이블은 실제 게임 위젯을 그대로 씁니다.
//
// 단계
//  0 시작        · 안내
//  1 이번 판 카드 · 안내
//  2 분배        · 안내
//  3 카드 내기    · 연습(1~3장, 모두 동시에)
//  4 LIAR는 언제? · 안내
//  5 LIAR 눌러 보기 · 연습 → 성공·실패 연출(장면 1, 안내)
//  6 정리        · 안내
//  7 룰렛        · 안내
//  8 FOLD        · 연습
//  9 끝          · 게임 시작 / 다시 보기

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/penalty/roulette.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';
import 'package:game_kit/tutorial/game_tutorial.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/game_theme.dart';
import 'package:game_liars_poker/phone/widgets/truth_count_hint.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_liars_poker/shared/widgets/card_face_view.dart';
import 'package:game_liars_poker/shared/widgets/pressable_button.dart';
import 'package:game_liars_poker/shared/widgets/wood_table_background.dart';

part 'liars_quick_tutorial.dart';

// ============================================================

String _t(String ko, String en, String zhHans, String zhHant) =>
    GameLocale.select(ko: ko, en: en, zhHans: zhHans, zhHant: zhHant);

const _ink = Color(0xFF17110F);
const _bone = Color(0xFFF2EADB);
const _gold = Color(0xFFE2C27E);
const _truth = Color(0xFF2E6B4E);
const _lie = Color(0xFFB8262B);
const _lime = Color(0xFFA4D65E);
const _sun = Color(0xFFF2E14C);

/// 플레이어마다 받는 손패 5장(진실 t · 거짓 l)입니다. 인원이 많으면 돌려 씁니다.
const _hands = ['ttltl', 'ltllt', 'tlltt', 'lltlt', 'tltll', 'lttll'];

LiarsCardFace _face(String c) =>
    c == 't' ? LiarsCardFace.truth : LiarsCardFace.lie;

String _handOf(int index) => _hands[index % _hands.length];

/// `0,2` 같은 값을 카드 번호 목록으로 바꿉니다.
List<int> _picksOf(String value) => [
  for (final part in value.split(','))
    if (int.tryParse(part) != null) int.parse(part),
];

class LiarsPokerTutorial extends GameTutorial {
  const LiarsPokerTutorial();

  static const _submitStep = 3;
  static const _liarStep = 5;
  static const _foldStep = 8;

  @override
  String get gameId => 'liars_poker';

  @override
  String get title =>
      GameLocale.select(ko: '라이어스', en: 'Liars', zhHans: '说谎者', zhHant: '說謊者');

  @override
  int get stepCount => 10;

  @override
  int phaseCount(int step) => step == _liarStep ? 2 : 1;

  @override
  bool isInfo(int step, int phase) => switch (step) {
    _submitStep || _foldStep => false,
    _liarStep => phase == 1,
    _ => true,
  };

  @override
  Widget buildTabletBackground(BuildContext context) =>
      const LiarsPokerWoodTableBackground();

  @override
  Widget buildPhoneBackground(BuildContext context) =>
      const LiarsPokerWoodTableBackground();

  @override
  Widget buildTablet(BuildContext context, TutorialTabletView view) =>
      _LiarsTablet(view: view, tutorial: this);

  @override
  Widget buildPhone(BuildContext context, TutorialPhoneView view) =>
      _LiarsPhone(
        key: ValueKey('liars-phone-${view.step}-${view.phase}'),
        view: view,
        tutorial: this,
      );

  //==========[ 단계별 안내 문구 ]==========
  ({String title, String body}) tipOf(int step, int phase, int playerCount) {
    final deck = liarsPokerDeckCounts(playerCount);
    return switch (step) {
      0 => (
        title: _t('라이어스 튜토리얼', 'Liars tutorial', '说谎者教程', '說謊者教學'),
        body: _t(
          '함께 한 판을 따라 해 보며 규칙을 배워요. 목표는 마지막까지 살아남기!',
          'Play one round together to learn the rules. Goal: be the last one standing!',
          '一起跟着玩一局来学习规则。目标：坚持到最后！',
          '一起跟著玩一局來學習規則。目標：撐到最後！',
        ),
      ),
      1 => (
        title: _t('이번 판 카드는 이만큼', 'This round’s deck', '本局的牌', '本局的牌'),
        body: _t(
          '진실 ${deck.truth}장, 거짓 ${deck.lie}장이 섞여요. 누가 어떤 카드를 받았는지는 아무도 몰라요.',
          '${deck.truth} truth and ${deck.lie} lie cards are shuffled. Nobody knows who got what.',
          '真话牌${deck.truth}张、谎言牌${deck.lie}张混在一起。谁拿到什么牌，没人知道。',
          '真話牌${deck.truth}張、謊言牌${deck.lie}張混在一起。誰拿到什麼牌，沒人知道。',
        ),
      ),
      2 => (
        title: _t('모두 5장씩 받았어요', 'Everyone gets 5 cards', '每人拿到5张', '每人拿到5張'),
        body: _t(
          '내 카드는 내 휴대폰에만 보여요. 옆 사람에게 들키지 마세요!',
          'Your cards show only on your phone. Keep them hidden!',
          '你的牌只显示在自己的手机上。别让旁边的人看到！',
          '你的牌只顯示在自己的手機上。別讓旁邊的人看到！',
        ),
      ),
      3 => (
        title: _t(
          '카드 내기 · 모두 동시에',
          'Play cards · all together',
          '出牌 · 大家一起',
          '出牌 · 大家一起',
        ),
        body: _t(
          '낸 카드는 테이블 가운데에 뒷면으로 놓여요. 예시로 한 사람 카드만 크게 보여 줘요.',
          'Played cards go face down in the middle. One player’s pile is shown as an example.',
          '出的牌会背面朝上放在桌子中间。这里放大展示一个人的牌作为例子。',
          '出的牌會背面朝上放在桌子中間。這裡放大展示一個人的牌作為例子。',
        ),
      ),
      4 => (
        title: _t(
          '그럼 LIAR는 언제?',
          'So when do you call LIAR?',
          '那什么时候喊 LIAR？',
          '那什麼時候喊 LIAR？',
        ),
        body: _t(
          '진실은 ${deck.truth}장뿐이에요. 내 손의 진실을 빼면 남들 몫이 나와요. 남들이 그보다 많이 “진실”이라고 하면 누군가 거짓말이에요.',
          'There are only ${deck.truth} truth cards. Subtract yours to see what’s left for others. If they claim more truths than that, someone is lying.',
          '真话牌只有${deck.truth}张。减去自己手里的，就是别人的份。别人声称的真话比这还多，就有人在说谎。',
          '真話牌只有${deck.truth}張。減去自己手裡的，就是別人的份。別人宣稱的真話比這還多，就有人在說謊。',
        ),
      ),
      5 when phase == 0 => (
        title: _t('LIAR 눌러 보기', 'Try LIAR', '试着按 LIAR', '試著按 LIAR'),
        body: _t(
          '모두 휴대폰에서 LIAR를 눌러 봐요. 누르면 가운데 뒷면 카드를 뒤집어 확인해요.',
          'Everyone tap LIAR on your phone. It flips the face-down cards in the middle.',
          '大家在手机上按 LIAR。按下后会翻开中间背面朝上的牌。',
          '大家在手機上按 LIAR。按下後會翻開中間背面朝上的牌。',
        ),
      ),
      5 => (
        title: _t(
          'LIAR 성공 · 실패',
          'LIAR: hit or miss',
          'LIAR 成功 · 失败',
          'LIAR 成功 · 失敗',
        ),
        body: _t(
          '거짓이 1장이라도 있으면 → 카드를 낸 사람이 룰렛. 전부 진실이면 → LIAR를 외친 사람이 룰렛.',
          'Any lie card → the player who played spins the roulette. All truth → the caller spins.',
          '只要有1张谎言牌 → 出牌的人转轮盘。全是真话 → 喊 LIAR 的人转轮盘。',
          '只要有1張謊言牌 → 出牌的人轉輪盤。全是真話 → 喊 LIAR 的人轉輪盤。',
        ),
      ),
      6 => (
        title: _t(
          'LIAR는 언제 외칠까?',
          'When to call LIAR?',
          '什么时候喊 LIAR？',
          '什麼時候喊 LIAR？',
        ),
        body: _t(
          '거짓이 확실할 때만! 진실 카드 수가 안 맞으면 기회예요. 틀리면 외친 내가 룰렛을 돌려요.',
          'Only when you’re sure! A mismatch in truth counts is your chance. If you’re wrong, you spin.',
          '只在确定有谎言时！真话牌数量对不上就是机会。喊错了就是自己转轮盘。',
          '只在確定有謊言時！真話牌數量對不上就是機會。喊錯了就是自己轉輪盤。',
        ),
      ),
      7 => (
        title: _t(
          '살아남아도 점점 위험해져요',
          'It gets riskier',
          '活下来也越来越危险',
          '活下來也越來越危險',
        ),
        body: _t(
          '태블릿 룰렛을 손가락으로 휙 돌려요. 돌릴 때마다 빨간 탈락 칸이 늘어나요(4/16 → 5/15 → 11/12). 룰렛을 피하는 게 최고예요.',
          'Flick the wheel on the tablet to spin. Each spin adds more red slots (4/16 → 5/15 → 11/12). Best to avoid it.',
          '用手指在平板上甩动轮盘。每转一次，红色淘汰格就会变多（4/16 → 5/15 → 11/12）。最好别转。',
          '用手指在平板上甩動輪盤。每轉一次，紅色淘汰格就會變多（4/16 → 5/15 → 11/12）。最好別轉。',
        ),
      ),
      8 => (
        title: _t(
          '내 차례인데 낼 카드가 없다면',
          'Your turn, but you can’t play',
          '轮到我却不能出牌',
          '輪到我卻不能出牌',
        ),
        body: _t(
          '다른 사람이 모두 마지막 카드까지 냈어요. 이때는 LIAR 아니면 FOLD! 휴대폰에서 각자 FOLD를 눌러 봐요.',
          'Everyone else has played their last cards. Now it’s LIAR or FOLD! Tap FOLD on your phone.',
          '其他人都出完了最后的牌。这时只能 LIAR 或 FOLD！在手机上按 FOLD 试试。',
          '其他人都出完了最後的牌。這時只能 LIAR 或 FOLD！在手機上按 FOLD 試試。',
        ),
      ),
      _ => (title: '', body: ''),
    };
  }

  String allAck(int step) => step == 0
      ? _t(
          '모두 휴대폰에서 “튜토리얼 시작”을 눌러요',
          'Everyone tap “Start tutorial” on your phone',
          '大家在手机上按“开始教程”',
          '大家在手機上按「開始教學」',
        )
      : _t(
          '모두 휴대폰에서 “이해했어요”를 눌러요',
          'Everyone tap “Got it” on your phone',
          '大家在手机上按“明白了”',
          '大家在手機上按「明白了」',
        );
}

//======================================================================
// 태블릿
//======================================================================
class _LiarsTablet extends StatelessWidget {
  const _LiarsTablet({required this.view, required this.tutorial});

  final TutorialTabletView view;
  final LiarsPokerTutorial tutorial;

  /// 화면 비율에 맞춰 늘어난 그림 영역입니다(태블릿 전체 화면).
  Size get _size => view.size;
  Offset get _center => _size.center(Offset.zero);

  List<Offset> get _seatCenters {
    final n = math.max(1, view.playerCount);
    final normalized = normalizedPlayerCenters(n);
    return [
      for (final player in view.players)
        Offset(
          normalized[player.seatIndex.clamp(0, n - 1)].dx * _size.width,
          normalized[player.seatIndex.clamp(0, n - 1)].dy * _size.height,
        ),
    ];
  }

  /// 자리에서 테이블 가운데를 바라보도록 돌리는 각도입니다(아래 자리 0°).
  double _facing(Offset seat) {
    final d = seat - _center;
    return math.atan2(d.dy, d.dx) - math.pi / 2;
  }

  /// 안내 카드를 아래쪽 세 자리(왼쪽·가운데·오른쪽) 중 좌석과 가장 먼 곳에 둡니다.
  double _tipLeft(List<Offset> seats) {
    final candidates = [24.0, _size.width / 2 - 190, _size.width - 404];
    var best = candidates.first;
    var bestDistance = -1.0;
    for (final left in candidates) {
      final center = Offset(left + 190, _size.height - 24 - 120);
      var nearest = double.infinity;
      for (final seat in seats) {
        nearest = math.min(nearest, (seat - center).distance);
      }
      if (nearest > bestDistance) {
        bestDistance = nearest;
        best = left;
      }
    }
    return best;
  }

  /// 예시 카드의 주인입니다(자리 배치 첫 번째 플레이어).
  int get _owner => 0;

  List<int> _ownerPicks() {
    if (view.players.isEmpty) return const [];
    final picks = _picksOf(view.memoOf(view.players[_owner].uid));
    return picks.isEmpty && view.step > LiarsPokerTutorial._submitStep
        ? const [0, 2]
        : picks;
  }

  int _remaining(int index) {
    final step = view.step;
    if (step < 2) return -1;
    if (step >= LiarsPokerTutorial._foldStep) return index == _owner ? 2 : 0;
    final submitted = _picksOf(view.memoOf(view.players[index].uid)).length;
    return 5 - submitted;
  }

  @override
  Widget build(BuildContext context) {
    final seats = _seatCenters;
    final step = view.step;
    final phase = view.phase;
    final endMode = view.ended || step >= tutorial.endStep;
    final tip = tutorial.tipOf(step, phase, view.playerCount);
    final practice = !endMode && !tutorial.isInfo(step, phase);
    final delay = switch (step) {
      2 => const Duration(milliseconds: 2400),
      5 when phase == 1 => const Duration(milliseconds: 6000),
      7 => const Duration(milliseconds: 3400),
      8 => const Duration(milliseconds: 2200),
      _ => Duration.zero,
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 좌석
        for (var i = 0; i < view.players.length; i++)
          Positioned(
            left: seats[i].dx - 60,
            top: seats[i].dy - 70,
            width: 120,
            height: 140,
            child: Transform.rotate(
              angle: _facing(seats[i]),
              child: _TabletSeat(
                player: view.players[i],
                remaining: _remaining(i),
                lit: practice && view.isDone(view.players[i].uid),
                turn: step == LiarsPokerTutorial._foldStep && i == _owner,
                crown: endMode && !view.ended && i == _owner,
                faded: endMode && !view.ended && i != _owner,
              ),
            ),
          ),
        if (!endMode || !view.ended) ..._middle(context, seats),
        if (!endMode && tip.title.isNotEmpty)
          Positioned(
            left: _tipLeft(seats),
            bottom: 24,
            child: TutorialCoachTip(
              badge: '${step + 1}/${tutorial.stepCount}',
              title: tip.title,
              body: tip.body,
              action: practice
                  ? (step == LiarsPokerTutorial._liarStep
                        ? _t(
                            '휴대폰에서 LIAR를 눌러요',
                            'Tap LIAR on your phone',
                            '在手机上按 LIAR',
                            '在手機上按 LIAR',
                          )
                        : _t(
                            '모두 해 보면 다음으로 넘어가요',
                            'Moves on once everyone tries',
                            '大家都试过后进入下一步',
                            '大家都試過後進入下一步',
                          ))
                  : tutorial.allAck(step),
              width: 380,
              scale: 1.25,
              delay: delay,
            ),
          ),
      ],
    );
  }

  List<Widget> _middle(BuildContext context, List<Offset> seats) {
    final step = view.step;
    final phase = view.phase;
    final endMode = view.ended || step >= tutorial.endStep;
    if (endMode) {
      return [
        Positioned.fill(
          child: Center(
            child: TutorialAppear(
              fromScale: .6,
              offset: Offset.zero,
              child: Text(
                'WINNER',
                style: LiarsPokerFonts.western(
                  size: 92,
                  color: _sun,
                  shadows: const [Shadow(color: _ink, offset: Offset(0, 6))],
                ),
              ),
            ),
          ),
        ),
      ];
    }
    switch (step) {
      case 0:
        return [
          Positioned.fill(
            child: Center(
              child: TutorialAppear(
                fromScale: .6,
                offset: Offset.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Bob(
                          child: Transform.rotate(
                            angle: -.14,
                            child: const LiarsPokerCardView(
                              face: LiarsCardFace.truth,
                              width: 104,
                              rounded: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _Bob(
                          delay: const Duration(milliseconds: 300),
                          child: Transform.rotate(
                            angle: .14,
                            child: const LiarsPokerCardView(
                              face: LiarsCardFace.lie,
                              width: 104,
                              rounded: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'LIARS',
                      style: LiarsPokerFonts.western(
                        size: 96,
                        color: _bone,
                        letterSpacing: 8,
                        shadows: const [
                          Shadow(color: _ink, offset: Offset(0, 7)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];
      case 1:
        final deck = liarsPokerDeckCounts(view.playerCount);
        return [
          Positioned.fill(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TutorialAppear(
                    child: _DeckStack(
                      face: LiarsCardFace.truth,
                      count: deck.truth,
                      color: _truth,
                    ),
                  ),
                  const SizedBox(width: 70),
                  TutorialAppear(
                    delay: const Duration(milliseconds: 200),
                    child: _DeckStack(
                      face: LiarsCardFace.lie,
                      count: deck.lie,
                      color: _lie,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      case 2:
        return [
          Positioned(
            left: _center.dx - 36,
            top: _center.dy - 58,
            child: const LiarsPokerCardView(
              face: LiarsCardFace.back,
              width: 72,
              rounded: true,
            ),
          ),
          for (var k = 0; k < view.players.length * 5; k++)
            _Fly(
              from: _center,
              to: _center + (seats[k % view.players.length] - _center) * .82,
              fromAngle: 0,
              toAngle: _facing(seats[k % view.players.length]),
              delay: Duration(milliseconds: 300 + k * 80),
              duration: const Duration(milliseconds: 460),
              child: const LiarsPokerCardView(
                face: LiarsCardFace.back,
                width: 64,
                rounded: true,
              ),
            ),
        ];
      case 3:
      case 4:
      case 6:
        return _pile(seats, open: step == 6);
      case 5:
        if (phase == 0) return _pile(seats, open: false);
        return [
          Positioned.fill(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Scene(
                    lie: true,
                    delay: Duration.zero,
                    players: view.players,
                    owner: _owner,
                  ),
                  const SizedBox(width: 40),
                  _Scene(
                    lie: false,
                    delay: const Duration(milliseconds: 3200),
                    players: view.players,
                    owner: _owner,
                  ),
                ],
              ),
            ),
          ),
        ];
      case 7:
        return [
          Positioned.fill(
            child: Center(
              child: TutorialAppear(
                fromScale: .6,
                offset: Offset.zero,
                // 실제 게임의 벌칙 룰렛을 그대로 씁니다. 태블릿에서 손가락으로 돌려
                // 볼 수 있고, 튜토리얼에서는 항상 생존으로 멈춥니다.
                child: SizedBox.square(
                  dimension: 480,
                  child: PenaltyRoulette(
                    attemptCount: 0,
                    centerCharacterId: view.players.isEmpty
                        ? null
                        : view.players[_owner].characterId,
                    onPrepareResult: () async => RouletteResult.safe,
                    onResult: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ];
      case 8:
        final others = [
          for (var i = 0; i < view.players.length; i++)
            if (i != _owner) i,
        ];
        return [
          for (var j = 0; j < others.length; j++)
            for (var c = 0; c < 2; c++)
              _Fly(
                from: seats[others[j]],
                to: _center + Offset(-40 + c * 26.0 + j * 10, -8.0 * j),
                fromAngle: _facing(seats[others[j]]),
                toAngle: (c - .5) * .3,
                delay: Duration(milliseconds: 200 + (j * 2 + c) * 160),
                duration: const Duration(milliseconds: 520),
                child: const LiarsPokerCardView(
                  face: LiarsCardFace.back,
                  width: 70,
                  rounded: true,
                ),
              ),
          Positioned(
            left: _center.dx - 170,
            top: _center.dy + 74,
            width: 340,
            child: TutorialAppear(
              delay: Duration(milliseconds: 400 + others.length * 320),
              child: const _FoldPanel(),
            ),
          ),
        ];
    }
    return const [];
  }

  /// 예시 한 사람(주인)의 카드를 가운데에 크게 놓습니다.
  List<Widget> _pile(List<Offset> seats, {required bool open}) {
    final picks = _ownerPicks();
    final hand = _handOf(_owner);
    final step = view.step;
    final label = step == 3
        ? _t(
            '가운데에 뒷면으로 낸 사람 ${view.doneCount}/${view.playerCount}',
            'Played face down ${view.doneCount}/${view.playerCount}',
            '已背面出牌 ${view.doneCount}/${view.playerCount}',
            '已背面出牌 ${view.doneCount}/${view.playerCount}',
          )
        : step == 5
        ? _t(
            'LIAR 누른 사람 ${view.doneCount}/${view.playerCount}',
            'Called LIAR ${view.doneCount}/${view.playerCount}',
            '已按 LIAR ${view.doneCount}/${view.playerCount}',
            '已按 LIAR ${view.doneCount}/${view.playerCount}',
          )
        : null;
    final owner = view.players.isEmpty ? null : view.players[_owner];
    return [
      Positioned(
        left: _center.dx - 220,
        top: _center.dy - 150,
        width: 440,
        height: 300,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: _gold.withValues(alpha: .35), width: 3),
            ),
          ),
        ),
      ),
      if (picks.isEmpty)
        Positioned.fill(
          child: Center(
            child: Text(
              _t(
                '${owner?.nickname ?? ''}의 카드를 기다려요',
                'Waiting for ${owner?.nickname ?? ''}’s cards',
                '等待${owner?.nickname ?? ''}的牌',
                '等待${owner?.nickname ?? ''}的牌',
              ),
              style: LiarsPokerFonts.text(
                size: 22,
                color: _gold,
                weight: FontWeight.w700,
              ),
            ),
          ),
        )
      else
        Positioned.fill(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (owner != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _bone,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: _ink, width: 2.5),
                    ),
                    child: Text(
                      _t(
                        '${owner.nickname}: “진실 ${picks.length}장!”',
                        '${owner.nickname}: “${picks.length} truth!”',
                        '${owner.nickname}：“真话${picks.length}张！”',
                        '${owner.nickname}：「真話${picks.length}張！」',
                      ),
                      style: LiarsPokerFonts.text(
                        size: 20,
                        color: _ink,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var k = 0; k < picks.length; k++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: TutorialAppear(
                          delay: Duration(
                            milliseconds: step == 3 ? 120 * k : 0,
                          ),
                          offset: step == 3
                              ? const Offset(0, 160)
                              : Offset.zero,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          child: open
                              ? _Flip(
                                  delay: Duration(milliseconds: 300 + k * 200),
                                  face: _face(hand[picks[k].clamp(0, 4)]),
                                  width: 110,
                                )
                              : const LiarsPokerCardView(
                                  face: LiarsCardFace.back,
                                  width: 110,
                                  rounded: true,
                                ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (label != null)
        Positioned(
          left: 0,
          right: 0,
          top: _center.dy - 200,
          child: Center(child: _Chip(text: label)),
        ),
    ];
  }
}

class _TabletSeat extends StatelessWidget {
  const _TabletSeat({
    required this.player,
    required this.remaining,
    required this.lit,
    required this.turn,
    required this.crown,
    required this.faded,
  });

  final TutorialPlayer player;
  final int remaining;
  final bool lit;
  final bool turn;
  final bool crown;
  final bool faded;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: faded ? .35 : 1,
    duration: const Duration(milliseconds: 400),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: turn
                      ? _sun
                      : lit
                      ? _lime
                      : _ink,
                  width: 5,
                ),
                boxShadow: [
                  if (turn)
                    BoxShadow(
                      color: _sun.withValues(alpha: .6),
                      blurRadius: 26,
                      spreadRadius: 6,
                    ),
                  if (lit) const BoxShadow(color: _ink, spreadRadius: 3),
                ],
              ),
              child: ClipOval(
                child: MosiFace(characterId: player.characterId, size: 78),
              ),
            ),
            if (crown)
              const Positioned(
                left: 18,
                top: -40,
                child: TutorialAppear(
                  delay: Duration(milliseconds: 300),
                  offset: Offset(0, -30),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: _sun,
                    size: 52,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (remaining >= 0)
          Text(
            _t('$remaining장', '$remaining', '$remaining张', '$remaining張'),
            style: LiarsPokerFonts.text(
              size: 19,
              color: _gold,
              weight: FontWeight.w800,
            ),
          ),
      ],
    ),
  );
}

class _DeckStack extends StatelessWidget {
  const _DeckStack({
    required this.face,
    required this.count,
    required this.color,
  });
  final LiarsCardFace face;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 170,
        height: 240,
        child: Stack(
          children: [
            Positioned(
              left: 14,
              top: 10,
              child: Transform.rotate(
                angle: .1,
                child: LiarsPokerCardView(
                  face: face,
                  width: 140,
                  rounded: true,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: LiarsPokerCardView(face: face, width: 140, rounded: true),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: _ink, width: 4),
        ),
        child: Text(
          '$count',
          style: LiarsPokerFonts.headline(size: 34, color: _bone),
        ),
      ),
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    decoration: BoxDecoration(
      color: _ink.withValues(alpha: .85),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: _gold, width: 2.5),
    ),
    child: Text(
      text,
      style: LiarsPokerFonts.text(
        size: 20,
        color: _bone,
        weight: FontWeight.w800,
      ),
    ),
  );
}

/// LIAR 성공·실패를 한 번씩 보여 주는 장면입니다.
class _Scene extends StatelessWidget {
  const _Scene({
    required this.lie,
    required this.delay,
    required this.players,
    required this.owner,
  });

  final bool lie;
  final Duration delay;
  final List<TutorialPlayer> players;
  final int owner;

  @override
  Widget build(BuildContext context) {
    final submitter = players.isEmpty ? null : players[owner];
    final caller = players.length < 2
        ? submitter
        : players[(owner + 1) % players.length];
    final loser = lie ? submitter : caller;
    final faces = lie ? 'tl' : 'tt';
    final ms = delay.inMilliseconds;
    return TutorialAppear(
      delay: delay,
      fromScale: .7,
      offset: Offset.zero,
      child: Container(
        width: 330,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: _bone,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _ink, width: 4),
          boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lie
                  ? _t('LIAR 성공', 'LIAR hits', 'LIAR 成功', 'LIAR 成功')
                  : _t('LIAR 실패', 'LIAR misses', 'LIAR 失败', 'LIAR 失敗'),
              style: LiarsPokerFonts.headline(
                size: 28,
                color: lie ? _truth : _lie,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var k = 0; k < faces.length; k++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _Flip(
                      delay: Duration(milliseconds: ms + 700 + k * 250),
                      face: _face(faces[k]),
                      width: 84,
                      highlight: faces[k] == 'l',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TutorialAppear(
              delay: Duration(milliseconds: ms + 1600),
              child: Text(
                lie
                    ? _t(
                        '거짓 발견! 낸 사람이 룰렛',
                        'A lie! The player spins',
                        '发现谎言！出牌的人转轮盘',
                        '發現謊言！出牌的人轉輪盤',
                      )
                    : _t(
                        '전부 진실! 외친 사람이 룰렛',
                        'All truth! The caller spins',
                        '全是真话！喊的人转轮盘',
                        '全是真話！喊的人轉輪盤',
                      ),
                textAlign: TextAlign.center,
                style: LiarsPokerFonts.text(
                  size: 18,
                  color: _ink,
                  weight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TutorialAppear(
              delay: Duration(milliseconds: ms + 2100),
              fromScale: .4,
              offset: Offset.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loser != null)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _lie, width: 4),
                      ),
                      child: ClipOval(
                        child: MosiFace(
                          characterId: loser.characterId,
                          size: 44,
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  const _Roulette(size: 54, spin: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoldPanel extends StatelessWidget {
  const _FoldPanel();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(
      color: _bone,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _ink, width: 3),
      boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 6))],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _t('제출', 'Play', '出牌', '出牌'),
          style:
              LiarsPokerFonts.text(
                size: 20,
                color: _ink,
                weight: FontWeight.w800,
              ).copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: _lie,
                decorationThickness: 3,
              ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.arrow_forward_rounded, color: _ink),
        const SizedBox(width: 10),
        Text('LIAR', style: LiarsPokerFonts.western(size: 24, color: _lie)),
        const SizedBox(width: 8),
        Text('/', style: LiarsPokerFonts.text(size: 20, color: _ink)),
        const SizedBox(width: 8),
        Text('FOLD', style: LiarsPokerFonts.western(size: 24, color: _truth)),
      ],
    ),
  );
}

//==========[ 연출 조각 ]==========
/// 위아래로 살짝 떠다닙니다.
class _Bob extends StatefulWidget {
  const _Bob({required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -10 * Curves.easeInOut.transform(_c.value)),
      child: child,
    ),
  );
}

/// 카드가 한 점에서 다른 점으로 날아갑니다. 중심 좌표 기준입니다.
class _Fly extends StatefulWidget {
  const _Fly({
    required this.from,
    required this.to,
    required this.child,
    this.fromAngle = 0,
    this.toAngle = 0,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
  });

  final Offset from;
  final Offset to;
  final double fromAngle;
  final double toAngle;
  final Duration delay;
  final Duration duration;
  final Widget child;

  @override
  State<_Fly> createState() => _FlyState();
}

class _FlyState extends State<_Fly> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(_c.value);
      final p = Offset.lerp(widget.from, widget.to, t)!;
      return Positioned(
        left: p.dx,
        top: p.dy,
        child: FractionalTranslation(
          translation: const Offset(-.5, -.5),
          child: Opacity(
            opacity: _c.value == 0 ? 0 : 1,
            child: Transform.rotate(
              angle: widget.fromAngle + (widget.toAngle - widget.fromAngle) * t,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// 뒷면에서 앞면으로 뒤집힙니다.
class _Flip extends StatefulWidget {
  const _Flip({
    required this.face,
    required this.width,
    this.delay = Duration.zero,
    this.highlight = false,
  });

  final LiarsCardFace face;
  final double width;
  final Duration delay;
  final bool highlight;

  @override
  State<_Flip> createState() => _FlipState();
}

class _FlipState extends State<_Flip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final v = Curves.easeInOut.transform(_c.value);
      final front = v >= .5;
      final angle = front ? math.pi * (1 - v) : math.pi * v;
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0015)
          ..rotateY(angle),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.width * .08),
            boxShadow: [
              if (front && widget.highlight)
                const BoxShadow(color: _sun, spreadRadius: 4),
            ],
          ),
          child: LiarsPokerCardView(
            face: front ? widget.face : LiarsCardFace.back,
            width: widget.width,
            rounded: true,
          ),
        ),
      );
    },
  );
}

/// 탈락 칸(빨강) 4개가 있는 16칸 룰렛입니다.
class _Roulette extends StatefulWidget {
  const _Roulette({required this.size, this.spin = true});
  final double size;
  final bool spin;

  @override
  State<_Roulette> createState() => _RouletteState();
}

class _RouletteState extends State<_Roulette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spin) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Transform.rotate(
            angle: Curves.easeOutCubic.transform(_c.value) * math.pi * 2 * 4.25,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: const _RoulettePainter(),
            ),
          ),
        ),
        if (widget.size > 100)
          Positioned(
            top: -6,
            child: Icon(
              Icons.arrow_drop_down_rounded,
              color: _sun,
              size: widget.size * .2,
            ),
          ),
      ],
    ),
  );
}

/// 실제 게임 벌칙 룰렛(금테 · 보랏빛 칸 · 빨간 탈락 칸 · 금색 축)을 작게 그립니다.
class _RoulettePainter extends CustomPainter {
  const _RoulettePainter();

  static const _gold = Color(0xFFC9A25B);
  static const _goldLight = Color(0xFFF6DE9A);
  static const _abyss = Color(0xFF0D0912);
  static const _red = Color(0xFFE0243A);
  static const _plumA = Color(0xFF24152E);
  static const _plumB = Color(0xFF34204A);
  static const _ivory = Color(0xFFF3EEE6);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rim = Rect.fromCircle(center: c, radius: r);
    final goldShader = const RadialGradient(
      center: Alignment(-.3, -.4),
      radius: .9,
      colors: [_goldLight, _gold, Color(0xFF7A5A22)],
      stops: [0, .45, 1],
    ).createShader(rim);
    canvas.drawCircle(c, r, Paint()..shader = goldShader);
    canvas.drawCircle(c, r * .975, Paint()..color = _abyss);
    const slots = 16;
    const bad = {0, 4, 8, 12};
    final inner = r * .908;
    final sweep = 2 * math.pi / slots;
    for (var i = 0; i < slots; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: inner),
        -math.pi / 2 + i * sweep,
        sweep,
        true,
        Paint()..color = bad.contains(i) ? _red : (i.isEven ? _plumA : _plumB),
      );
    }
    final divider = Paint()
      ..color = _ivory.withValues(alpha: .35)
      ..strokeWidth = math.max(.6, r * .012);
    for (var i = 0; i < slots; i++) {
      final a = -math.pi / 2 + i * sweep;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * inner, divider);
    }
    // 가장자리를 살짝 어둡게 해 입체감을 줍니다.
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: .45)],
          stops: const [.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: inner)),
    );
    canvas.drawCircle(c, r * .21, Paint()..color = _abyss);
    canvas.drawCircle(
      c,
      r * .21,
      Paint()
        ..shader = goldShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * .03),
    );
    canvas.drawCircle(c, r * .085, Paint()..shader = goldShader);
    // 위쪽 포인터입니다.
    final pointer = Path()
      ..moveTo(c.dx, c.dy - r * .84)
      ..lineTo(c.dx - r * .09, c.dy - r * 1.03)
      ..quadraticBezierTo(
        c.dx,
        c.dy - r * 1.11,
        c.dx + r * .09,
        c.dy - r * 1.03,
      )
      ..close();
    canvas.drawPath(pointer, Paint()..color = _ivory);
    canvas.drawPath(
      pointer,
      Paint()
        ..color = _abyss
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * .02),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//======================================================================
// 휴대폰
//======================================================================
class _LiarsPhone extends StatefulWidget {
  const _LiarsPhone({super.key, required this.view, required this.tutorial});

  final TutorialPhoneView view;
  final LiarsPokerTutorial tutorial;

  @override
  State<_LiarsPhone> createState() => _LiarsPhoneState();
}

class _LiarsPhoneState extends State<_LiarsPhone> {
  final List<int> _picked = [];
  bool _tooMany = false;
  bool _foldWarn = false;

  TutorialPhoneView get view => widget.view;
  LiarsPokerTutorial get tutorial => widget.tutorial;

  String get _hand => _handOf(view.myIndex);

  /// 지금 손에 남은 카드 번호입니다.
  List<int> get _cards {
    final step = view.step;
    if (step <= 1) return const [];
    if (step >= LiarsPokerTutorial._foldStep) return const [0, 1];
    if (step > LiarsPokerTutorial._submitStep) {
      final submitted = _picksOf(view.memo);
      return [
        for (var i = 0; i < 5; i++)
          if (!submitted.contains(i)) i,
      ];
    }
    return const [0, 1, 2, 3, 4];
  }

  void _toggle(int index) {
    if (view.step != LiarsPokerTutorial._submitStep || view.done) return;
    setState(() {
      if (_picked.contains(index)) {
        _picked.remove(index);
        _tooMany = false;
      } else if (_picked.length < 3) {
        _picked.add(index);
        _tooMany = false;
      } else {
        _tooMany = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = view.step;
    final phase = view.phase;
    final endMode = view.ended || step >= tutorial.endStep;
    final info = !endMode && tutorial.isInfo(step, phase);
    final badge = '${step + 1}/${tutorial.stepCount}';
    final showHand =
        !endMode &&
        (step == 2 ||
            (step == LiarsPokerTutorial._submitStep && !view.done) ||
            step == 4 ||
            (step == LiarsPokerTutorial._foldStep && !view.done));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 내 이름
        Positioned(
          left: 14,
          top: 10,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            decoration: BoxDecoration(
              color: _ink.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: _gold.withValues(alpha: .6),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: MosiFace(characterId: view.me.characterId, size: 26),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  view.me.nickname,
                  style: LiarsPokerFonts.text(
                    size: 15,
                    color: _bone,
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showHand)
          Positioned(
            left: 0,
            right: 0,
            top: 250,
            height: 300,
            child: _HandFan(
              faces: _hand,
              cards: _cards,
              picked: step == LiarsPokerTutorial._submitStep
                  ? _picked
                  : const [],
              dealIn: step == 2,
              onTap: _toggle,
            ),
          )
        else if (!endMode)
          Positioned(
            left: 24,
            right: 24,
            top: 290,
            child: _PhoneMessage(view: view, step: step, phase: phase),
          ),
        // 코치마크
        if (!endMode) ..._coach(info, badge),
        // 연습 버튼
        if (!endMode && !info)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: _actions()),
          ),
      ],
    );
  }

  List<Widget> _coach(bool info, String badge) {
    final step = view.step;
    final phase = view.phase;
    const top = 56.0;
    const width = 358.0;
    final tip = tutorial.tipOf(step, phase, view.playerCount);
    final deck = liarsPokerDeckCounts(view.playerCount);
    if (info) {
      return [
        Positioned(
          left: 16,
          top: top,
          child: TutorialCoachTip(
            badge: badge,
            title: tip.title,
            body: step == 4 ? _liarHint(deck.truth) : tip.body,
            width: width,
            delay: switch (step) {
              2 => const Duration(milliseconds: 2400),
              5 => const Duration(milliseconds: 6000),
              7 => const Duration(milliseconds: 3400),
              _ => Duration.zero,
            },
            action: _t(
              '이해했으면 아래 버튼을 눌러요',
              'Tap the button below when ready',
              '明白了就按下面的按钮',
              '明白了就按下面的按鈕',
            ),
          ),
        ),
      ];
    }
    if (step == LiarsPokerTutorial._submitStep) {
      if (view.done) {
        final n = _picksOf(view.value).length;
        return [
          Positioned(
            left: 16,
            top: top,
            child: TutorialCoachTip(
              badge: badge,
              title: _t('태블릿을 봐요!', 'Look at the tablet!', '看平板！', '看平板！'),
              body: _t(
                '내 카드 $n장이 가운데에 뒷면으로 놓였어요. 다른 사람은 “진실 $n장”이라는 말만 들어요. 앞면은 나만 알아요!',
                'Your $n cards are face down in the middle. Others only hear “$n truth”. Only you know the faces!',
                '你的$n张牌背面朝上放在中间。别人只听到“真话$n张”。只有你知道正面！',
                '你的$n張牌背面朝上放在中間。別人只聽到「真話$n張」。只有你知道正面！',
              ),
              width: width,
            ),
          ),
        ];
      }
      return [
        TutorialSpot(rect: const Rect.fromLTWH(16, 240, 358, 320)),
        Positioned(
          left: 16,
          top: top,
          child: TutorialCoachTip(
            badge: badge,
            warning: _tooMany,
            title: _tooMany
                ? _t('최대 3장까지만 낼 수 있어요', 'Up to 3 cards', '最多只能出3张', '最多只能出3張')
                : _picked.isEmpty
                ? _t('카드 1~3장 고르기', 'Pick 1–3 cards', '选1~3张牌', '選1~3張牌')
                : _t(
                    '${_picked.length}장 골랐어요',
                    '${_picked.length} picked',
                    '已选${_picked.length}张',
                    '已選${_picked.length}張',
                  ),
            body: _tooMany
                ? _t(
                    '다른 카드를 내고 싶으면 고른 카드를 한 번 더 눌러 빼요.',
                    'Tap a picked card again to remove it.',
                    '想换牌就再点一次已选的牌取消。',
                    '想換牌就再點一次已選的牌取消。',
                  )
                : _t(
                    '진실만 내도 되고, 거짓을 섞어 속여도 돼요. 낸 카드는 모두 “진실”이라고 주장해요.',
                    'Play only truths or sneak in lies. Every card you play is claimed as truth.',
                    '可以只出真话，也可以混入谎言骗人。出的牌都声称是真话。',
                    '可以只出真話，也可以混入謊言騙人。出的牌都宣稱是真話。',
                  ),
            action: _picked.isEmpty
                ? _t('카드를 눌러 골라요', 'Tap cards to pick', '点牌来选择', '點牌來選擇')
                : _t(
                    '더 고르거나 제출을 눌러요',
                    'Pick more or tap Submit',
                    '再选或按提交',
                    '再選或按提交',
                  ),
            width: width,
          ),
        ),
        if (_picked.isEmpty) const TutorialHand(at: Offset(210, 400)),
        if (_picked.isNotEmpty) const TutorialHand(at: Offset(240, 760)),
      ];
    }
    if (step == LiarsPokerTutorial._liarStep) {
      return [
        Positioned(
          left: 16,
          top: top,
          child: TutorialCoachTip(
            badge: badge,
            title: view.done
                ? 'LIAR!'
                : _t(
                    '“진실”이라는데 정말일까?',
                    '“Truth”… really?',
                    '“真话”……真的吗？',
                    '「真話」……真的嗎？',
                  ),
            body: view.done
                ? _t(
                    '모두 누르면 태블릿 가운데에서 LIAR 성공·실패 장면이 나와요. 태블릿을 봐요!',
                    'When everyone taps, the tablet shows a hit and a miss. Watch the tablet!',
                    '大家都按下后，平板中间会展示成功和失败的场景。看平板！',
                    '大家都按下後，平板中間會展示成功和失敗的場景。看平板！',
                  )
                : _t(
                    'LIAR는 가운데 뒷면 카드를 뒤집어 확인하는 버튼이에요. 모두 눌러 봐요.',
                    'LIAR flips the face-down cards in the middle. Everyone try it.',
                    'LIAR 是翻开中间背面牌来确认的按钮。大家都试试。',
                    'LIAR 是翻開中間背面牌來確認的按鈕。大家都試試。',
                  ),
            action: view.done
                ? null
                : _t('LIAR를 눌러 봐요', 'Tap LIAR', '按 LIAR 试试', '按 LIAR 試試'),
            width: width,
          ),
        ),
        if (!view.done) const TutorialHand(at: Offset(232, 730)),
      ];
    }
    if (step == LiarsPokerTutorial._foldStep) {
      if (view.done) {
        final fold = view.value == 'fold';
        return [
          Positioned(
            left: 16,
            top: top,
            child: TutorialCoachTip(
              badge: badge,
              warning: !fold,
              title: fold
                  ? _t('FOLD 했어요', 'You folded', '你 FOLD 了', '你 FOLD 了')
                  : _t(
                      'LIAR! 그런데 전부 진실',
                      'LIAR! But all truth',
                      'LIAR！但全是真话',
                      'LIAR！但全是真話',
                    ),
              body: fold
                  ? _t(
                      '앞사람 말을 믿고 의심을 접었어요. 내가 벌칙 룰렛을 돌려요.',
                      'You trusted the claim and folded. You spin the roulette.',
                      '你相信了上家的话，放弃怀疑。由你转惩罚轮盘。',
                      '你相信了上家的話，放棄懷疑。由你轉懲罰輪盤。',
                    )
                  : _t(
                      '앞사람 카드는 진실이었어요. 틀려서 내가 룰렛을 돌려요. 증거가 없을 땐 FOLD를 골라요.',
                      'The cards were true, so you spin. Without proof, choose FOLD.',
                      '上家的牌是真话。喊错了，由你转轮盘。没有证据时就选 FOLD。',
                      '上家的牌是真話。喊錯了，由你轉輪盤。沒有證據時就選 FOLD。',
                    ),
              width: width,
            ),
          ),
        ];
      }
      return [
        TutorialSpot(rect: const Rect.fromLTWH(95, 560, 200, 110), radius: 18),
        Positioned(
          left: 16,
          top: top,
          child: TutorialCoachTip(
            badge: badge,
            warning: _foldWarn,
            title: _t(
              '내 차례! 그런데 낼 수가 없어요',
              'Your turn — but you can’t play',
              '轮到我！但不能出牌',
              '輪到我！但不能出牌',
            ),
            body: _t(
              '다른 사람은 마지막 카드까지 다 냈어요. 앞사람 말이 사실 같으면 FOLD(내가 룰렛), 거짓 같으면 LIAR!',
              'Everyone else is out of cards. If the claim seems true, FOLD (you spin); if not, LIAR!',
              '其他人都出完了最后的牌。觉得上家说的是真的就 FOLD（我转轮盘），觉得是假的就 LIAR！',
              '其他人都出完了最後的牌。覺得上家說的是真的就 FOLD（我轉輪盤），覺得是假的就 LIAR！',
            ),
            action: _t('FOLD를 눌러 봐요', 'Try FOLD', '按 FOLD 试试', '按 FOLD 試試'),
            width: width,
          ),
        ),
        const TutorialHand(at: Offset(250, 620)),
      ];
    }
    return const [];
  }

  String _liarHint(int truthTotal) {
    final mine = _hand.split('').where((c) => c == 't').length;
    final others = truthTotal - mine;
    return _t(
      '진실은 모두 $truthTotal장. 내 손에 진실 $mine장이 있으니 남들 몫은 최대 $others장이에요. 남들이 “진실”이라고 낸 카드가 $others장을 넘으면 누군가 거짓말!',
      'There are $truthTotal truths. You hold $mine, so others have at most $others. If others claim more than $others, someone lied!',
      '真话一共$truthTotal张。你手里有$mine张，别人最多$others张。别人声称的真话超过$others张，就有人说谎！',
      '真話一共$truthTotal張。你手裡有$mine張，別人最多$others張。別人宣稱的真話超過$others張，就有人說謊！',
    );
  }

  Widget _actions() {
    final step = view.step;
    if (view.done) {
      return _WaitingNote(
        text: _t(
          '다른 사람을 기다려요 ${view.doneCount}/${view.playerCount}',
          'Waiting for others ${view.doneCount}/${view.playerCount}',
          '等待其他人 ${view.doneCount}/${view.playerCount}',
          '等待其他人 ${view.doneCount}/${view.playerCount}',
        ),
      );
    }
    if (step == LiarsPokerTutorial._submitStep) {
      final ok = _picked.isNotEmpty && _picked.length <= 3;
      return TutorialPulse(
        enabled: ok,
        radius: 80,
        child: _ArcadeButton(
          label: GameLocale.select(
            ko: '제출',
            en: 'Submit',
            zhHans: '提交',
            zhHant: '提交',
          ),
          width: 220,
          height: 150,
          enabled: ok,
          onPressed: () {
            final picks = [..._picked]..sort();
            view.complete(picks.join(','), memo: picks.join(','));
          },
        ),
      );
    }
    if (step == LiarsPokerTutorial._liarStep) {
      return TutorialPulse(
        radius: 80,
        child: _ArcadeButton(
          label: 'Liar',
          width: 220,
          height: 150,
          onPressed: () => view.complete('liar'),
        ),
      );
    }
    if (step == LiarsPokerTutorial._foldStep) {
      // 실제 게임처럼 FOLD가 카드와 LIAR 사이(LIAR 위)에 놓입니다.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiarsPokerPressableAssetButton(
            asset: Assets.games.liarsPoker.images.button.buttonFold.game,
            width: 190,
            semanticsLabel: 'FOLD',
            onPressed: () => view.complete('fold'),
          ),
          const SizedBox(height: 6),
          _ArcadeButton(
            label: 'Liar',
            width: 160,
            height: 112,
            onPressed: () {
              if (!_foldWarn) setState(() => _foldWarn = true);
              view.complete('liar');
            },
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _HandFan extends StatelessWidget {
  const _HandFan({
    required this.faces,
    required this.cards,
    required this.picked,
    required this.dealIn,
    required this.onTap,
  });

  final String faces;
  final List<int> cards;
  final List<int> picked;
  final bool dealIn;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final n = cards.length;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        for (var k = 0; k < n; k++)
          Builder(
            builder: (context) {
              final index = cards[k];
              final mid = (n - 1) / 2;
              final on = picked.contains(index);
              final card = GestureDetector(
                onTap: () => onTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  transform: Matrix4.translationValues(
                    (k - mid) * 50,
                    on ? -34 : (k - mid).abs() * 9,
                    0,
                  )..rotateZ((k - mid) * .12),
                  transformAlignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      if (on) const BoxShadow(color: _sun, spreadRadius: 4),
                      const BoxShadow(
                        color: Color(0x73000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: LiarsPokerCardView(
                    face: _face(faces[index]),
                    width: 118,
                    rounded: true,
                  ),
                ),
              );
              if (!dealIn) return card;
              return TutorialAppear(
                delay: Duration(milliseconds: 1900 + k * 120),
                offset: const Offset(0, -160),
                curve: Curves.easeOutCubic,
                child: card,
              );
            },
          ),
      ],
    );
  }
}

class _PhoneMessage extends StatelessWidget {
  const _PhoneMessage({
    required this.view,
    required this.step,
    required this.phase,
  });

  final TutorialPhoneView view;
  final int step;
  final int phase;

  @override
  Widget build(BuildContext context) {
    final text = switch (step) {
      0 => _t('라이어스 튜토리얼', 'Liars tutorial', '说谎者教程', '說謊者教學'),
      1 => _t(
        '태블릿에서 이번 판 카드를 확인해요',
        'Check this round’s deck on the tablet',
        '在平板上查看本局的牌',
        '在平板上查看本局的牌',
      ),
      7 => _t(
        '태블릿 룰렛을 손가락으로 휙 돌려 봐요',
        'Flick the wheel on the tablet',
        '在平板上用手指甩动轮盘',
        '在平板上用手指甩動輪盤',
      ),
      _ => _t('태블릿을 봐요', 'Look at the tablet', '看平板', '看平板'),
    };
    return TutorialAppear(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _ink, width: 4),
            ),
            child: ClipOval(
              child: MosiFace(characterId: view.me.characterId, size: 86),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: LiarsPokerFonts.text(
              size: 22,
              color: _bone,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingNote extends StatelessWidget {
  const _WaitingNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => TutorialAppear(
    fromScale: .7,
    offset: Offset.zero,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: _bone,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ink, width: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _lime,
              shape: BoxShape.circle,
              border: Border.all(color: _ink, width: 2),
            ),
            child: const Icon(Icons.check_rounded, size: 16, color: _ink),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: LiarsPokerFonts.text(
              size: 16,
              color: _ink,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 실제 게임의 입체 아케이드 버튼(제출·LIAR)에 눌림 상태를 붙입니다.
class _ArcadeButton extends StatefulWidget {
  const _ArcadeButton({
    required this.label,
    required this.width,
    required this.height,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final double width;
  final double height;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<_ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<_ArcadeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.enabled,
    label: widget.label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed();
            }
          : null,
      child: AnimatedOpacity(
        opacity: widget.enabled ? 1 : .45,
        duration: const Duration(milliseconds: 180),
        child: LiarsPokerArcadeButtonSurface(
          label: widget.label,
          width: widget.width,
          height: widget.height,
          pressed: _pressed,
          enabled: widget.enabled,
        ),
      ),
    ),
  );
}
