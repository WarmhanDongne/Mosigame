// [lobby_preview.dart] 는 로비 게임 상세의 '플레이 미리보기'와 '구성품' 그림을 그리는 파일이다.
//
// - [Package] : ELEVEN
// - [Widget] : 세 라운드 반복 연출(색 공개 → 숫자 공개 → 판정·+1),
//              숫자 타일 묶음, 공용 뽑기 카드, 판정 규칙 줄
//
// 게임 화면과 같은 시안 A 부품(타일·테이블·토큰)만 써서 로비와 게임의 모양을 맞춘다.
// 실제 게임 상태와 연결되지 않는 그림이므로 서버 값을 읽지 않는다.

// ========================[ import ]==========================
import 'package:flutter/widgets.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_eleven/shared/noir/noir_text.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';
import 'package:game_eleven/shared/widgets/noir_stage.dart';
import 'package:game_eleven/shared/widgets/noir_tile.dart';

// ============================================================

//=======================플레이 미리보기==============================
/// 미리보기 한 라운드입니다. [first]가 0이면 A가 선공입니다.
class _PreviewRound {
  const _PreviewRound({
    required this.first,
    required this.a,
    required this.b,
    required this.winner,
  });

  final int first;
  final int a;
  final int b;

  /// 0 = A 승, 1 = B 승.
  final int winner;
}

/// 세 가지 판정을 한 번씩 보여 줍니다.
/// 1R 8+3=11(10 이상 → 작은 수), 2R 1+6=7(10 미만 → 큰 수), 3R 11+9=20(11 승).
/// 다음 라운드 선공은 직전 승자입니다(계약 2절).
const _rounds = [
  _PreviewRound(first: 0, a: 8, b: 3, winner: 1),
  _PreviewRound(first: 1, a: 6, b: 1, winner: 0),
  _PreviewRound(first: 0, a: 11, b: 9, winner: 0),
];

const _roundMs = 4500;
const _firstAt = 500;
const _secondAt = 1300;
const _revealAt = 2100;
const _resultAt = 2700;

/// 미리보기 그림의 논리 크기입니다. 상자 크기에 맞춰 통째로 줄입니다.
const elevenPreviewSize = Size(694, 560);

class ElevenPlayPreview extends StatefulWidget {
  const ElevenPlayPreview({super.key});

  @override
  State<ElevenPlayPreview> createState() => _ElevenPlayPreviewState();
}

class _ElevenPlayPreviewState extends State<ElevenPlayPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _roundMs * 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 동작 줄이기를 켠 기기에서는 첫 라운드 판정 장면에 멈춰 둡니다.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller
        ..stop()
        ..value = (_resultAt + 600) / (_roundMs * 3);
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ElevenNoirStage(
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox.fromSize(
        size: elevenPreviewSize,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => ElevenPreviewFrame(
            ms: (_controller.value * _roundMs * 3).round(),
          ),
        ),
      ),
    ),
  );
}

/// [ms] 시점의 미리보기 한 장면입니다. 테스트가 시점을 정해 그릴 수 있게 공개합니다.
class ElevenPreviewFrame extends StatelessWidget {
  const ElevenPreviewFrame({super.key, required this.ms});

  final int ms;

  @override
  Widget build(BuildContext context) {
    final index = (ms ~/ _roundMs).clamp(0, _rounds.length - 1);
    final local = ms - index * _roundMs;
    final round = _rounds[index];
    final resolved = local >= _resultAt;

    // 이번 라운드 판정 전 점수입니다.
    final scores = [0, 0];
    for (final done in _rounds.take(index)) {
      scores[done.winner]++;
    }
    if (resolved) scores[round.winner]++;

    int playedAt(int seat) => seat == round.first ? _firstAt : _secondAt;
    Widget slot(int seat) {
      final value = seat == 0 ? round.a : round.b;
      final submitted = local >= playedAt(seat);
      final revealed = local >= _revealAt;
      final state = !resolved
          ? ElevenTileState.normal
          : (seat == round.winner ? ElevenTileState.win : ElevenTileState.lose);
      final tile = ElevenNoirTile(
        face: submitted ? ElevenTileFace.ofValue(value) : ElevenTileFace.empty,
        spec: ElevenTileSpec.tabletSlot,
        // 태블릿 게임처럼 먼저 색만 보이고, 둘 다 낸 뒤 숫자를 공개합니다.
        value: revealed ? value : null,
        state: state,
      );
      final pop = submitted
          ? Curves.easeOutBack.transform(
              ((local - playedAt(seat)) / 260).clamp(0.0, 1.0),
            )
          : 1.0;
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Transform.scale(scale: 0.85 + 0.15 * pop, child: tile),
          if (seat == round.first)
            Positioned(top: -16, child: _FirstBadge(label: _copyFirst)),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 26,
          left: 0,
          right: 0,
          child: Center(child: _RoundPill(round: index + 1)),
        ),
        for (final seat in [0, 1])
          Positioned(
            top: 150,
            left: seat == 0 ? 30 : null,
            right: seat == 1 ? 36 : null,
            child: _ScoreColumn(
              mark: seat == 0 ? 'A' : 'B',
              score: scores[seat],
              plus: resolved && round.winner == seat,
            ),
          ),
        Positioned(
          top: 112,
          left: 0,
          right: 0,
          // 슬롯을 게임 태블릿보다 조금 크게 그려 상자 가운데를 채웁니다.
          child: Transform.scale(
            scale: 1.22,
            alignment: Alignment.topCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                slot(0),
                SizedBox(
                  width: 84,
                  child: Center(
                    child: Text('vs', style: ElevenNoirText.versus(size: 26)),
                  ),
                ),
                slot(1),
              ],
            ),
          ),
        ),
        Positioned(
          left: 72,
          right: 72,
          bottom: 40,
          child: _Caption(round: round, stepMs: local),
        ),
      ],
    );
  }
}

String get _copyFirst =>
    GameLocale.select(ko: '선', en: '1st', zhHans: '先', zhHant: '先');

class _RoundPill extends StatelessWidget {
  const _RoundPill({required this.round});

  final int round;

  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    padding: ElevenNoirSpacing.pillPadding,
    decoration: BoxDecoration(
      color: ElevenNoirColors.cream,
      borderRadius: BorderRadius.circular(ElevenNoirRadius.pill),
      border: Border.all(
        color: ElevenNoirColors.ink,
        width: ElevenNoirBorder.regular,
      ),
      boxShadow: ElevenNoirShadow.regular,
    ),
    // 알약이 글자 폭만큼만 차지하도록 가로로는 늘리지 않습니다.
    child: Center(
      widthFactor: 1,
      child: Text(
        GameLocale.select(
          ko: '$round라운드 / 11',
          en: 'Round $round / 11',
          zhHans: '第 $round 回合 / 11',
          zhHant: '第 $round 回合 / 11',
        ),
        style: ElevenNoirText.pill(size: 22),
      ),
    ),
  );
}

class _FirstBadge extends StatelessWidget {
  const _FirstBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(
      color: ElevenNoirColors.red,
      borderRadius: BorderRadius.circular(ElevenNoirRadius.firstBadge),
      border: Border.all(
        color: ElevenNoirColors.ink,
        width: ElevenNoirBorder.thin,
      ),
    ),
    child: Text(label, style: ElevenNoirText.firstBadge()),
  );
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({
    required this.mark,
    required this.score,
    required this.plus,
  });

  final String mark;
  final int score;
  final bool plus;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 116,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ElevenNoirColors.red,
            shape: BoxShape.circle,
            border: Border.all(
              color: ElevenNoirColors.ink,
              width: ElevenNoirBorder.regular,
            ),
          ),
          child: Text(
            mark,
            style: ElevenNoirText.body(
              22,
              weight: FontWeight.w900,
              color: ElevenNoirColors.cream,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          GameLocale.select(ko: '점수', en: 'Score', zhHans: '分数', zhHant: '分數'),
          style: ElevenNoirText.tabletScoreLabel(
            color: ElevenNoirColors.greyBeige,
          ),
        ),
        const SizedBox(height: 4),
        // 큰 글자·다른 글꼴에서도 칸을 넘지 않게 점수 줄을 통째로 줄입니다.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score', style: ElevenNoirText.tabletScore()),
              const SizedBox(width: ElevenNoirSpacing.scorePlusGap),
              Opacity(
                opacity: plus ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: ElevenNoirColors.accentRed,
                    borderRadius: BorderRadius.circular(
                      ElevenNoirRadius.plusBadge,
                    ),
                    border: Border.all(
                      color: ElevenNoirColors.ink,
                      width: ElevenNoirBorder.thin,
                    ),
                  ),
                  child: Text(
                    '+1',
                    style: ElevenNoirText.plusBadge().copyWith(
                      color: ElevenNoirColors.cream,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 아래 크림 카드: 지금 단계 안내 → 판정식과 규칙.
class _Caption extends StatelessWidget {
  const _Caption({required this.round, required this.stepMs});

  final _PreviewRound round;
  final int stepMs;

  @override
  Widget build(BuildContext context) {
    final first = round.first == 0 ? 'A' : 'B';
    final second = round.first == 0 ? 'B' : 'A';
    final sum = round.a + round.b;
    final String headline;
    final String detail;
    if (stepMs < _secondAt) {
      headline = GameLocale.select(
        ko: '$first 선공: 타일 한 장',
        en: '$first leads: one tile',
        zhHans: '$first 先手：出一张牌',
        zhHant: '$first 先手：出一張牌',
      );
      detail = GameLocale.select(
        ko: '상대에게는 색(흑·백)만 보여요',
        en: 'The opponent sees only the color',
        zhHans: '对手只能看到颜色（黑·白）',
        zhHant: '對手只能看到顏色（黑·白）',
      );
    } else if (stepMs < _revealAt) {
      headline = GameLocale.select(
        ko: '$second 후공: 색을 보고 응수',
        en: '$second answers after seeing the color',
        zhHans: '$second 后手：看颜色应对',
        zhHant: '$second 後手：看顏色應對',
      );
      detail = GameLocale.select(
        ko: '흑 0·2·4·6·8·11 / 백 1·3·5·7·9',
        en: 'Black 0·2·4·6·8·11 / White 1·3·5·7·9',
        zhHans: '黑 0·2·4·6·8·11 / 白 1·3·5·7·9',
        zhHant: '黑 0·2·4·6·8·11 / 白 1·3·5·7·9',
      );
    } else {
      final low = round.a < round.b ? round.a : round.b;
      final high = round.a < round.b ? round.b : round.a;
      headline = '$low + $high = $sum';
      detail = sum == 20
          ? GameLocale.select(
              ko: '9와 11이면 11이 이겨요',
              en: '9 against 11: 11 wins',
              zhHans: '9 对 11：11 获胜',
              zhHant: '9 對 11：11 獲勝',
            )
          : sum < 10
          ? GameLocale.select(
              ko: '합이 10 미만이면 큰 수 승',
              en: 'Sum under 10: higher wins',
              zhHans: '和小于 10：大数获胜',
              zhHant: '和小於 10：大數獲勝',
            )
          : GameLocale.select(
              ko: '합이 10 이상이면 작은 수 승',
              en: 'Sum 10 or more: lower wins',
              zhHans: '和大于等于 10：小数获胜',
              zhHant: '和大於等於 10：小數獲勝',
            );
    }
    final judged = stepMs >= _revealAt;
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: ElevenNoirColors.creamCard,
        borderRadius: BorderRadius.circular(ElevenNoirRadius.tabletButton),
        border: Border.all(
          color: ElevenNoirColors.ink,
          width: ElevenNoirBorder.heavy,
        ),
        boxShadow: ElevenNoirShadow.raised,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              headline,
              maxLines: 1,
              style: judged
                  ? ElevenNoirText.number(34, height: 1.1)
                  : ElevenNoirText.body(24, weight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              detail,
              maxLines: 1,
              style: ElevenNoirText.body(
                17,
                weight: FontWeight.w700,
                color: judged
                    ? ElevenNoirColors.red
                    : ElevenNoirColors.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//=======================구성품 그림==============================
/// 한 사람의 숫자 타일 11장: 윗줄 흑 6장, 아랫줄 백 5장.
class ElevenTileSetArt extends StatelessWidget {
  const ElevenTileSetArt({super.key});

  static const _black = [0, 2, 4, 6, 8, 11];
  static const _white = [1, 3, 5, 7, 9];

  @override
  Widget build(BuildContext context) {
    Widget row(List<int> values) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, value) in values.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          ElevenNoirTile(
            face: ElevenTileFace.ofValue(value),
            spec: ElevenTileSpec.phoneHand,
            value: value,
          ),
        ],
      ],
    );
    return Semantics(
      image: true,
      label: GameLocale.select(
        ko: '흑 타일 0, 2, 4, 6, 8, 11과 백 타일 1, 3, 5, 7, 9',
        en: 'Black tiles 0, 2, 4, 6, 8, 11 and white tiles 1, 3, 5, 7, 9',
        zhHans: '黑牌 0、2、4、6、8、11 与白牌 1、3、5、7、9',
        zhHant: '黑牌 0、2、4、6、8、11 與白牌 1、3、5、7、9',
      ),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [row(_black), const SizedBox(height: 16), row(_white)],
        ),
      ),
    );
  }
}

/// 첫 선공·최종 동점 뽑기에 쓰는 공용 카드 9장(뒷면, 3×3).
class ElevenDrawDeckArt extends StatelessWidget {
  const ElevenDrawDeckArt({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: GameLocale.select(
      ko: '뒷면 뽑기 카드 9장',
      en: 'Nine face-down draw cards',
      zhHans: '9 张背面抽牌',
      zhHant: '9 張背面抽牌',
    ),
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < 3; r++) ...[
            if (r > 0) const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < 3; c++) ...[
                  if (c > 0) const SizedBox(width: 10),
                  const ElevenNoirTile(
                    face: ElevenTileFace.back,
                    spec: ElevenTileSpec.drawCard,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

/// 규칙 아래 '카드 예시' 줄: 네 가지 판정을 타일 예시와 함께 보여 줍니다.
class ElevenJudgeStrip extends StatelessWidget {
  const ElevenJudgeStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final cases = [
      (
        a: 3,
        b: 5,
        win: 5,
        title: GameLocale.select(
          ko: '합 10 미만',
          en: 'Sum < 10',
          zhHans: '和 < 10',
          zhHant: '和 < 10',
        ),
        body: GameLocale.select(
          ko: '큰 수 승',
          en: 'Higher wins',
          zhHans: '大数胜',
          zhHant: '大數勝',
        ),
      ),
      (
        a: 4,
        b: 7,
        win: 4,
        title: GameLocale.select(
          ko: '합 10 이상',
          en: 'Sum ≥ 10',
          zhHans: '和 ≥ 10',
          zhHant: '和 ≥ 10',
        ),
        body: GameLocale.select(
          ko: '작은 수 승',
          en: 'Lower wins',
          zhHans: '小数胜',
          zhHant: '小數勝',
        ),
      ),
      (
        a: 9,
        b: 11,
        win: 11,
        title: '9 + 11',
        body: GameLocale.select(
          ko: '11 승',
          en: '11 wins',
          zhHans: '11 胜',
          zhHant: '11 勝',
        ),
      ),
      (
        a: 6,
        b: 6,
        win: null,
        title: GameLocale.select(
          ko: '같은 수',
          en: 'Same',
          zhHans: '相同',
          zhHant: '相同',
        ),
        body: GameLocale.select(
          ko: '동점·0점',
          en: 'Tie · 0 pts',
          zhHans: '平局·0 分',
          zhHant: '平局·0 分',
        ),
      ),
    ];
    return Semantics(
      container: true,
      label: GameLocale.select(
        ko: '판정 규칙',
        en: 'How a round is judged',
        zhHans: '判定规则',
        zhHant: '判定規則',
      ),
      child: Container(
        key: const Key('eleven-judge-strip'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ElevenNoirColors.blackTile,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ElevenNoirColors.greyBeige,
            width: ElevenNoirBorder.thin,
          ),
        ),
        child: Row(
          children: [
            // 시안: 왼쪽에 '카드 예시' 라벨을 둡니다.
            Text(
              GameLocale.select(
                ko: '카드\n예시',
                en: 'CARD\nEXAMPLES',
                zhHans: '牌例',
                zhHant: '牌例',
              ),
              style: ElevenNoirText.body(
                13,
                weight: FontWeight.w700,
                color: ElevenNoirColors.greyBeige,
                height: 1.3,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 12),
            for (final (i, item) in cases.indexed) ...[
              if (i > 0)
                Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: ElevenNoirColors.mutedText,
                ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (j, value) in [item.a, item.b].indexed) ...[
                        if (j > 0) const SizedBox(width: 6),
                        ElevenNoirTile(
                          face: ElevenTileFace.ofValue(value),
                          spec: ElevenTileSpec.phoneGuide,
                          value: value,
                          state: item.win == null
                              ? ElevenTileState.normal
                              : (value == item.win
                                    ? ElevenTileState.guideWin
                                    : ElevenTileState.guideLose),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            style: ElevenNoirText.body(
                              17,
                              weight: FontWeight.w900,
                              color: ElevenNoirColors.cream,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.body,
                            maxLines: 1,
                            style: ElevenNoirText.body(
                              17,
                              weight: FontWeight.w900,
                              color: ElevenNoirColors.accentRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
