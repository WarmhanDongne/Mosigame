// [timing.dart] 는 ELEVEN 클라이언트 연출 시간을 모아 두는 파일이다.
//
// 계약 6절의 시험용 값이다. 서버 제출 제한(60초)은 서버 계약이라 여기에 두지 않고,
// 서버가 내려준 `turnDeadlineAt`만 사용한다.

abstract final class ElevenTiming {
  /// 휴대폰 제출 표시.
  static const submit = Duration(milliseconds: 300);

  /// 태블릿 라운드 결과 유지(T07/T08) 뒤 `complete_phase`.
  static const roundResult = Duration(seconds: 2);

  /// 새 라운드 안내(T09). 서버 deadline을 늦추지 않는 겹침 표시다.
  static const roundIntro = Duration(milliseconds: 800);

  /// 뽑기 공개(T03/T12) 뒤 `complete_phase`.
  static const drawReveal = Duration(milliseconds: 600);

  /// 최종 승리 연출.
  static const finalWin = Duration(milliseconds: 1500);

  /// 태블릿이 마감 뒤 `timeout_turn`을 보내기까지의 여유(계약 5절 "약 1초").
  static const controllerTimeoutGrace = Duration(seconds: 1);

  /// 승부 없이 끝난 뒤(퇴장·수동 종료·인원 부족) 태블릿이 안내를 보여 주고
  /// 게임 화면을 닫기까지의 시간. 파이널콜 태블릿과 같은 1초.
  static const closingRouteDelay = Duration(seconds: 1);

  /// 휴대폰 예비 `timeout_turn` 여유. 태블릿이 먼저 처리하도록 더 늦게 보낸다.
  static const playerTimeoutGrace = Duration(seconds: 3);
}
