// [noir_motion.dart] 는 ELEVEN 시안 A 연출의 시작 시점·길이·곡선 상수 파일이다.
//
// - [Package] : ELEVEN
// - [Design] : docs/design/eleven/motion.md (MotionKitNoir 확정값 우선, S5-0b 결정 1–9)
//
// 공통 규칙(MotionKit 칸 10 원문):
// - 튐 곡선 cubic-bezier(.3,1.3,.6,1), 튐 폭 1.02–1.04배. 퇴장과 색 변화는 ease-out.
// - 기본 길이: 등장 0.3초 · 퇴장 0.2초 (토스트는 0.2 / 0.2).
// - 실제 앱에서는 상태가 바뀔 때 한 번만 재생. 재접속하면 애니메이션 없이 최종 상태.
// - 동작 줄이기 설정이면 이동·확대·흔들림 없이 색과 투명도만.
// - 진동은 차례 전환 때 1회만.
//
// 시점(`...At`)은 그 연출이 시작된 순간 기준 ms다. 프로토타입 한 바퀴의 대기 시간은
// 실제 게임 시간이 아니므로 연출 자체의 길이만 옮긴다(README 한계).

// ========================[ import ]==========================
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:game_eleven/shared/noir/noir_tokens.dart';

// ============================================================

/// CSS 곡선을 Flutter [Cubic]으로 옮긴 값입니다.
abstract final class ElevenCurves {
  /// 튐 `cubic-bezier(.3,1.3,.6,1)`.
  static const bounce = Cubic(0.3, 1.3, 0.6, 1);

  /// CSS `ease-out` `cubic-bezier(0,0,.58,1)`. 퇴장·색 변화.
  static const easeOut = Cubic(0, 0, 0.58, 1);

  /// CSS `ease` `cubic-bezier(.25,.1,.25,1)`.
  static const ease = Cubic(0.25, 0.1, 0.25, 1);

  /// 왕관 낙하 `cubic-bezier(.5,0,1,1)`.
  static const fall = Cubic(0.5, 0, 1, 1);

  /// 선형. 시간 바와 프로토타입 키프레임 사이 보간.
  static const linear = Cubic(0, 0, 1, 1);
}

/// 토스트 유지 시간 종류(MotionKit 칸 1 확정표 + 정적 화면 `tq*` 주석).
enum ElevenToastHold {
  /// “숫자 공개”·“타일 공개” 공개 신호 0.5초.
  reveal(Duration(milliseconds: 500)),

  /// “제출 완료” 0.6초 · 최종 동점 “동점” 0.6초.
  short(Duration(milliseconds: 600)),

  /// “타일 선택” 행동 안내 0.7초.
  action(Duration(milliseconds: 700)),

  /// “1라운드”·“게임 조기 종료”·“게임 종료”·“최종 승부” 0.8초.
  round(Duration(milliseconds: 800)),

  /// “타일 자동 제출”(결정 5)·라운드 결과 “A 승리”/“동점” 0.9초.
  roundResult(Duration(milliseconds: 900)),

  /// “A 선공”(뽑기 결과)·“6라운드 / A 선공”(T09) 1.0초.
  announce(Duration(milliseconds: 1000)),

  /// 게임 승패 “승자 / A”·“B 승리” 1.5초.
  gameResult(Duration(milliseconds: 1500));

  const ElevenToastHold(this.duration);

  final Duration duration;
}

/// 토스트: 아래에서 8px 떠오르며 등장, 유지, 투명도로 퇴장(결정 1, `kNToast`).
abstract final class ElevenToastMotion {
  static const enter = Duration(milliseconds: 200);
  static const exit = Duration(milliseconds: 200);

  /// 여러 단계 토스트 사이 공백.
  static const gap = Duration(milliseconds: 200);

  /// 등장 시작 위치(아래로 8px).
  static const enterOffsetY = 8.0;
  static const enterCurve = ElevenCurves.easeOut;
  static const exitCurve = ElevenCurves.easeOut;

  /// 한 단계 전체 길이.
  static Duration total(ElevenToastHold hold) => enter + hold.duration + exit;

  /// 여러 단계를 공백 포함 이어 붙인 길이.
  static Duration sequence(List<ElevenToastHold> holds) {
    var sum = Duration.zero;
    for (var i = 0; i < holds.length; i++) {
      sum += total(holds[i]);
      if (i < holds.length - 1) sum += gap;
    }
    return sum;
  }
}

/// 2 휴대폰 차례 전환: 상태 칩 크림 반전 0.5초 + ±3px 흔들림, 진동 1회,
/// 제출 버튼 흐림 → 1.04배 → 복귀(결정 2, `kNChip`·`kNPop`).
abstract final class ElevenTurnMotion {
  /// 흔들림 키프레임 x(px): 60ms 간격 −3 → +3 → −2 → 0, ease-out.
  static const shakeOffsets = [0.0, -3.0, 3.0, -2.0, 0.0];
  static const shakeStep = Duration(milliseconds: 60);
  static const shake = Duration(milliseconds: 240);

  /// 크림(#f7f0e4 바탕·#141414 글자) 유지 후 빨강(#c9242a·#f7f0e4)으로.
  static const creamHold = Duration(milliseconds: 500);
  static const colorChange = Duration(milliseconds: 160);
  static const colorCurve = ElevenCurves.easeOut;
  static const total = Duration(milliseconds: 660);

  /// 제출 버튼: 0→180ms 투명도 .5→1, 180→360ms 1→1.04배, 360→660ms 1배.
  static const popStartOpacity = 0.5;
  static const popScale = 1.04;
  static const popFadeIn = Duration(milliseconds: 180);
  static const popScaleUpAt = Duration(milliseconds: 180);
  static const popPeakAt = Duration(milliseconds: 360);
  static const popTotal = Duration(milliseconds: 660);
  static const popCurve = ElevenCurves.bounce;
}

/// 3 타일 제출(태블릿 슬롯): 아래에서 딜하듯 −4° → 0°, 0.35초, 튐(`kNDeal`).
/// 태블릿에서는 흑/백 뒷면만 보인다.
abstract final class ElevenDealMotion {
  static const duration = Duration(milliseconds: 350);

  /// MotionKit 칸 150px, 프로토타입 태블릿 측면 로컬 170px. 화면 배치 기준인 170을 쓴다.
  static const offsetY = 170.0;

  /// 시작 회전(도).
  static const startDegrees = -4.0;
  static const curve = ElevenCurves.bounce;
}

/// 4 뽑기 공개: 가로 뒤집기 0.4초, 뒤집는 순간 8px 들림·그림자 커짐(`kNFlip`).
abstract final class ElevenFlipMotion {
  static const duration = Duration(milliseconds: 400);

  /// 반쪽(scaleX 1→0) 시점. 이때 뒷면 → 앞면으로 바뀐다.
  static const half = Duration(milliseconds: 200);
  static const lift = 8.0;

  /// 평소 `drop-shadow(#141414 0 4px 0)` → 뒤집는 순간 `rgba(0,0,0,.55) 0 14px 6px`.
  static const restShadow = BoxShadow(
    color: ElevenNoirColors.ink,
    offset: Offset(0, 4),
  );
  static const liftShadow = BoxShadow(
    color: Color(0x8C000000),
    offset: Offset(0, 14),
    blurRadius: 6,
  );
}

/// 5 라운드 결과(숫자 비공개): 뜸 0.8초 → 이긴 카드 1.04배 + 빨간 테두리 3px,
/// 진 카드 밝기 60% + 2px 가라앉음(`kNWin`·`kNLose`).
abstract final class ElevenResultMotion {
  static const suspense = Duration(milliseconds: 800);
  static const emphasis = Duration(milliseconds: 300);
  static const winScale = 1.04;
  static const winOutline = 3.0;
  static const winOutlineOffset = 3.0;
  static const winCurve = ElevenCurves.bounce;
  static const loseBrightness = 0.6;
  static const loseSink = 2.0;
  static const loseCurve = ElevenCurves.ease;
}

/// 6 점수 +1: 위에서 아래로 넘어가는 카운터 0.35초, 빨간 +1 배지(`kNCount`·`kNPlus`).
abstract final class ElevenScoreMotion {
  static const counter = Duration(milliseconds: 350);
  static const counterCurve = ElevenCurves.bounce;

  /// +1 배지: 0.25초 동안 8px 아래 → 제자리, 0.625초 유지, 0.375초 동안 10px 위로 사라짐.
  static const plusEnter = Duration(milliseconds: 250);
  static const plusHold = Duration(milliseconds: 625);
  static const plusExit = Duration(milliseconds: 375);
  static const plusEnterOffsetY = 8.0;
  static const plusExitOffsetY = -10.0;
  static const plusCurve = ElevenCurves.ease;
}

/// 7 전적표 행 채우기: 새 라운드 시작 때 직전 라운드 행만, 두 타일이 양쪽 바깥에서
/// 0.3초 딜 → 0.09초 뒤 결과 0.15초 페이드(`kNInL`·`kNInR`·`kNRes`).
abstract final class ElevenHistoryRowMotion {
  static const tilesIn = Duration(milliseconds: 300);
  static const tileOffsetX = 70.0;
  static const tileDegrees = 4.0;
  static const tileCurve = ElevenCurves.bounce;
  static const resultDelay = Duration(milliseconds: 90);
  static const resultFade = Duration(milliseconds: 150);
  static const resultCurve = ElevenCurves.ease;
}

/// 8 시간 바: 선형으로 줄고, 남은 10초부터 진한 빨강, 깜빡임 없음(결정 3, `kNBar`·`kNBarC`).
abstract final class ElevenTimeBarMotion {
  static const curve = ElevenCurves.linear;
  static const warnRemaining = Duration(seconds: 10);
  static const color = ElevenNoirColors.warnRed;
  static const warnColor = ElevenNoirColors.deepRed;

  /// 남은 시간에 맞는 채움 색입니다. 색은 계단식으로 바뀝니다(steps(1)).
  static Color colorFor(Duration remaining) =>
      remaining <= warnRemaining ? warnColor : color;
}

/// 9 게임 승패: 토스트가 끝난 뒤 왕관이 떨어지며 1회 튐 + 조각 6개, 진 쪽은 3px
/// 가라앉고 어두워짐. 진동 없음(`kNCrown`·`kNSp1-6`·`kNPillW`·`kNPillL`).
abstract final class ElevenGameEndMotion {
  /// 왕관(연출 시작 = 왕관 시작): 35ms 동안 나타나며 420ms 낙하(70px 위 → 0),
  /// 175ms 10px 튀어오름, 175ms 복귀.
  static const crownAppear = Duration(milliseconds: 35);
  static const crownFall = Duration(milliseconds: 420);
  static const crownFallFrom = -70.0;
  static const crownFallCurve = ElevenCurves.fall;
  static const crownBounceUp = Duration(milliseconds: 175);
  static const crownBounceDown = Duration(milliseconds: 175);
  static const crownBounceHeight = -10.0;
  static const crownBounceCurve = ElevenCurves.ease;

  /// 조각: 왕관 시작 490ms 뒤 출발해 980ms 동안 퍼지며 사라짐. 그중 처음 140ms에 나타난다.
  static const sparkDelay = Duration(milliseconds: 490);
  static const sparkFadeIn = Duration(milliseconds: 140);
  static const sparkTravel = Duration(milliseconds: 980);
  static const sparkCurve = ElevenCurves.ease;

  /// 조각 6개의 끝 위치(px)와 회전(도). 크림·빨강을 번갈아 쓴다.
  static const sparks = [
    (Offset(-44, -26), 160.0),
    (Offset(44, -26), -160.0),
    (Offset(-30, -46), 120.0),
    (Offset(30, -46), -120.0),
    (Offset(-50, 4), 90.0),
    (Offset(50, 4), -90.0),
  ];

  /// pill 연출은 왕관 시작 35ms 뒤 시작한다.
  static const pillDelay = Duration(milliseconds: 35);

  /// 승리 pill: 0.9배 → 1배, 385ms 튐.
  static const winPillFrom = 0.9;
  static const winPill = Duration(milliseconds: 385);
  static const winPillCurve = ElevenCurves.bounce;

  /// 패배 pill: 385ms 나타난 뒤 420ms 동안 3px 가라앉고 밝기 60%.
  static const losePillAppear = Duration(milliseconds: 385);
  static const losePillSink = Duration(milliseconds: 420);
  static const losePillSinkY = 3.0;
  static const losePillBrightness = 0.6;
  static const losePillCurve = ElevenCurves.ease;
}

/// 휴대폰 게임 종료(P10/P11) 등장: 프로토타입 ⑥·⑦·⑧ 휴대폰 레이어(`kEA1`·`kEPcrown`·`kEPwin`).
/// 시점은 휴대폰이 결과 화면으로 넘어가는 순간(⑥은 3.7초, `gameEndRevealed`가 true가 되는 때) 기준이다.
/// MotionKit 칸 9(`ElevenGameEndMotion`)는 태블릿 왕관·조각·pill에 쓰고, 휴대폰은 이 값을 쓴다
/// (휴대폰에는 조각이 없다).
abstract final class ElevenPhoneEndMotion {
  /// 앞 화면(G7 등) → P10/P11 교차 전환. 진 쪽(B)은 프로토타입에서 300ms.
  static const crossFade = Duration(milliseconds: 250);
  static const crossFadeLoser = Duration(milliseconds: 300);

  /// 왕관: 100ms 뒤 50ms 동안 나타나고, 250ms 낙하(70px 위 → 0), 100ms 8px 튀어오름, 100ms 복귀.
  static const crownDelay = Duration(milliseconds: 100);
  static const crownAppear = Duration(milliseconds: 50);
  static const crownFall = Duration(milliseconds: 250);
  static const crownFallFrom = -70.0;
  static const crownBounceUp = Duration(milliseconds: 100);
  static const crownBounceDown = Duration(milliseconds: 100);
  static const crownBounceHeight = -8.0;

  /// WINNER: 400ms 뒤 0.9배·투명 → 250ms에 1.04배 → 100ms에 1배.
  static const winnerDelay = Duration(milliseconds: 400);
  static const winnerGrow = Duration(milliseconds: 250);
  static const winnerSettle = Duration(milliseconds: 100);
  static const winnerFrom = 0.9;
  static const winnerPeak = 1.04;

  /// 프로토타입 키프레임 사이 보간은 선형이다(motion.md 읽는 법).
  static const curve = ElevenCurves.linear;

  /// 전체 길이.
  static Duration get total => winnerDelay + winnerGrow + winnerSettle;
}

/// 프로토타입 ①·⑧ 공용 뽑기(9장) 연출.
abstract final class ElevenDrawMotion {
  /// 9장 딜: 카드당 30ms 간격, 각 260ms(위 24px·0.6배 → 3px·1.04배(180ms) → 제자리).
  static const dealStagger = Duration(milliseconds: 30);
  static const dealCard = Duration(milliseconds: 260);
  static const dealOvershootAt = Duration(milliseconds: 180);
  static const dealFromY = -24.0;
  static const dealFromScale = 0.6;
  static const dealOvershootY = 3.0;
  static const dealOvershootScale = 1.04;

  /// 9장 딜 전체 길이.
  static Duration get dealAll => dealStagger * 8 + dealCard;

  /// 카드 집기: 120ms 동안 10px 들리며 1.15배, 80ms 유지, 100ms 동안 0.8배로 사라짐.
  static const pickLift = Duration(milliseconds: 120);
  static const pickHold = Duration(milliseconds: 80);
  static const pickLeave = Duration(milliseconds: 100);
  static const pickLiftY = -10.0;
  static const pickScale = 1.15;
  static const pickLeaveScale = 0.8;

  /// 공개: 두 번째 선택 반영 시점(drawReveal 진입) 기준.
  /// 1100ms “숫자/타일 공개” 토스트(0.5초) → 뜸 0.8초 → 1900ms 동시 뒤집기(0.4초)
  /// → 2900ms 결과 토스트(“A 선공” 1.0초 / “B 승리” 1.5초) → 4700ms 판 전환.
  static const revealToastAt = Duration(milliseconds: 1100);
  static const flipAt = Duration(milliseconds: 1900);
  static const resultToastAt = Duration(milliseconds: 2900);
  static const boardMorphAt = Duration(milliseconds: 4700);

  /// 판 모핑(뽑기판 ↔ 전적판) 300ms, 이어서 100ms 페이드.
  static const boardMorph = Duration(milliseconds: 300);
  static const boardFade = Duration(milliseconds: 100);
}

/// 프로토타입 ④·⑤ 라운드 결과 흐름(roundResult 진입 기준).
/// 0 뜸 → 800ms 결과 강조 → 1400ms 토스트 “A 승리”/“동점”(0.9초)·점수 넘김
/// → 3200ms 새 라운드 전환(전적행 채우기) → 3700ms “n라운드 / X 선공” 토스트.
abstract final class ElevenRoundFlowMotion {
  static const emphasisAt = Duration(milliseconds: 800);
  static const toastAt = Duration(milliseconds: 1400);
  static const nextRoundAt = Duration(milliseconds: 3200);
  static const roundIntroAt = Duration(milliseconds: 3700);
}

/// 프로토타입 ⑥·⑦ 게임 종료 흐름(finished 진입 기준).
/// 0 “게임 조기 종료”/“게임 종료”(0.8초) → 1400ms “승자 / A”(1.5초)
/// → 3300ms 최종 화면(T13) 전환 → 3700ms 왕관 낙하(9).
abstract final class ElevenGameEndFlowMotion {
  static const winnerToastAt = Duration(milliseconds: 1400);
  static const finalScreenAt = Duration(milliseconds: 3300);
  static const crownAt = Duration(milliseconds: 3700);
}

/// 휴대폰 화면 레이어 교차 전환(`.lay` opacity) 200ms.
abstract final class ElevenPhoneLayerMotion {
  static const crossFade = Duration(milliseconds: 200);
}
