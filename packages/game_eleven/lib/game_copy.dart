// [game_copy.dart] 는 ELEVEN에서만 쓰는 화면 문구를 모아 두는 파일이다.
//
// - [Package] : ELEVEN
// - [Copy] : 게임 화면 문구의 번역 키(getter)
//
// 노션 개발 계획 S4·Q64: 다국어 구조와 키는 앱 골격에서 만들고, 화면은 한국어
// 임시 문구로 완성한다. en·zh-Hans·zh-Hant 번역은 UI가 안정된 뒤 S7에서 일괄
// 적용한다(이때 [_ko]를 GameLocale.select로 바꾼다). 게임 이름만 계약 1절의
// ko·en 확정값을 쓰고, zh 이름은 미정이라 계약의 제안값(ELEVEN)을 둔다.
// 공통 문구(GAME START, 인원 부족 등)는 game_kit의 GameFlowCopy를 쓴다.

// ========================[ import ]==========================
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

/// S7 번역 전까지 모든 locale에 한국어를 보여 주는 임시 표시입니다.
String _ko(String text) => text;

abstract final class ElevenCopy {
  static String get title => GameLocale.select(
    ko: '일레븐',
    en: 'ELEVEN',
    zhHans: 'ELEVEN',
    zhHant: 'ELEVEN',
  );

  static String round(int round) => _ko('$round / 11 라운드');

  static String get firstPlayerDraw => _ko('선공 뽑기');

  static String get tieDraw => _ko('동점 · 최종 뽑기');

  static String pickTurn(String nickname) => _ko('$nickname 님이 타일을 고르세요');

  static String drawWinnerFirst(String nickname) => _ko('$nickname 님이 선공입니다');

  static String choosing(String nickname) => _ko('$nickname 님이 고르는 중');

  static String get first => _ko('선공');
  static String get second => _ko('후공');

  static String roundWinner(String nickname) => _ko('$nickname 님 승리');

  static String get roundTie => _ko('동점');

  static String get autoSubmitted => _ko('시간 초과 · 자동 제출');

  static String winner(String nickname) => _ko('$nickname 님 최종 승리');

  static String earlyEnd(int remaining, int gap) =>
      _ko('남은 $remaining라운드보다 점수 차($gap)가 커 조기 종료');

  static String get waitingDraw => _ko('태블릿에서 타일을 뽑고 있습니다');

  static String get yourTurn => _ko('낼 타일을 고르세요');

  static String get preselect => _ko('선공이 고르는 중 · 미리 골라 둘 수 있어요');

  static String firstColor(String color) => _ko('선공은 $color 타일을 냈습니다');

  static String get black => _ko('흑');
  static String get white => _ko('백');

  static String get submit => _ko('제출');

  static String get submitted => _ko('제출 완료 · 상대를 기다리는 중');

  static String get lastTile => _ko('마지막 타일입니다');

  static String get roundResultPhone => _ko('태블릿에서 결과를 확인하세요');

  static String get youWin => _ko('승리!');
  static String get youLose => _ko('패배');

  static String get restart => _ko('다시 하기');
  static String get toLobby => _ko('대기실로');
  static String get endGame => _ko('게임 종료');
  static String get retry => _ko('다시 시도');
}
