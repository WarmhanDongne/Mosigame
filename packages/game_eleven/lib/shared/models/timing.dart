// [timing.dart] 는 ELEVEN 클라이언트 연출 시간을 모아 두는 파일이다.
//
// 계약 6절의 시험용 값이었고, S5-0b(2026-11-25)에서 docs/design/eleven/motion.md
// 프로토타입 흐름 기준으로 바꿨다. 각 값은 shared/noir/noir_motion.dart의 시점에서
// 계산한다. 서버 제출 제한(60초)은 서버 계약이라 여기에 두지 않고, 서버가 내려준
// `turnDeadlineAt`만 사용한다. 연출 시간은 서버 deadline을 늦추지 않는다(계약 3절).
//
// S5-0b 변경 기록(이전 → 현재, 근거):
// - roundResult 2000ms → 3200ms: 프로토타입 ④ 0 뜸 → 3.2s 새 라운드 전환.
// - drawReveal 600ms → 4700ms: 프로토타입 ①·⑧ 두 번째 선택(5.0s) → 판 전환(9.7s).
// - roundIntro 800ms → 1400ms: T09 토스트 0.2 등장 + 1.0 유지 + 0.2 퇴장.
// - submit 300ms → 350ms: MotionKit 3 타일 제출 딜 0.35s.
// - finalWin 1500ms: 게임 승패 토스트 유지 1.5s와 같아 그대로.

// ========================[ import ]==========================
import 'package:game_eleven/shared/noir/noir_motion.dart';

// ============================================================

abstract final class ElevenTiming {
  /// 제출된 타일이 태블릿 슬롯에 딜되는 시간.
  static const submit = ElevenDealMotion.duration;

  /// 태블릿 라운드 결과(T07/T08) 진입부터 `complete_phase`까지.
  static const roundResult = ElevenRoundFlowMotion.nextRoundAt;

  /// 새 라운드 안내(T09) 토스트 전체. 서버 deadline을 늦추지 않는 겹침 표시다.
  static final roundIntro = ElevenToastMotion.total(ElevenToastHold.announce);

  /// 뽑기 공개(T03/T12) 진입부터 `complete_phase`까지.
  static const drawReveal = ElevenDrawMotion.boardMorphAt;

  /// 최종 승리 토스트 유지.
  static final finalWin = ElevenToastHold.gameResult.duration;

  /// 태블릿이 마감 뒤 `timeout_turn`을 보내기까지의 여유(계약 5절 "약 1초").
  static const controllerTimeoutGrace = Duration(seconds: 1);

  /// 승부 없이 끝난 뒤(퇴장·수동 종료·인원 부족) 태블릿이 안내를 보여 주고
  /// 게임 화면을 닫기까지의 시간. 파이널콜 태블릿과 같은 1초.
  static const closingRouteDelay = Duration(seconds: 1);

  /// 휴대폰 예비 `timeout_turn` 여유. 태블릿이 먼저 처리하도록 더 늦게 보낸다.
  static const playerTimeoutGrace = Duration(seconds: 3);
}
