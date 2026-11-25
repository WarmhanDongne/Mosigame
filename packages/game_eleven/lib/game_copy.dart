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

/// 시안 A(느와르) 화면 문구 키입니다(S5-0b). 원문은 docs/design/eleven/screens.md
/// 4절의 화면별 “문구” 열이고, 값은 그 원문 그대로입니다. 레인 A·B는 이 파일을
/// 고치지 않고 아래 키만 씁니다. 번역은 S7에서 [_ko]를 GameLocale.select로 바꿉니다.
///
/// - [who]는 화면에 보이는 사람 표시입니다. 시안은 좌석 표시 “A”/“B”로 그렸습니다.
/// - 숫자·점수·시간 자체(“7”, “6 : 2”, “0:42”)는 문구가 아니라 값이므로 키가 없습니다.
/// - 원문의 줄바꿈 `<br>`은 `\n`입니다(T09, T10 토스트).
abstract final class ElevenScreenCopy {
  // ===========================================================================
  // 태블릿 공통 (T01–T13, T13-B)
  // ===========================================================================
  /// 상태 pill: T01·T03·T04·T09·T11 “내 차례”.
  static String get pillMyTurn => _ko('내 차례');

  /// 상태 pill: T01·T03·T04·T09·T11 “상대 차례”.
  static String get pillOpponentTurn => _ko('상대 차례');

  /// 상태 pill: T02 “선택 완료”.
  static String get pillPicked => _ko('선택 완료');

  /// 상태 pill: T05 “제출 완료”.
  static String get pillSubmitted => _ko('제출 완료');

  /// 상태 pill: T06 “자동 제출”(양쪽, 자동 제출한 쪽은 pillWarn).
  static String get pillAutoSubmitted => _ko('자동 제출');

  /// 상태 pill: T07·T12·T13·T13-B “승리”.
  static String get pillWin => _ko('승리');

  /// 상태 pill: T07·T12·T13·T13-B “패배”.
  static String get pillLose => _ko('패배');

  /// 상태 pill: T08 “동점”.
  static String get pillTie => _ko('동점');

  /// 상태 pill: T10 “게임 종료”.
  static String get pillGameOver => _ko('게임 종료');

  /// 점수 라벨: T04–T12 “점수”.
  static String get scoreLabel => _ko('점수');

  /// 점수 옆 배지: T07 “+1”, T08 “+0”.
  static String scoreDelta(int delta) => _ko('+$delta');

  /// 메뉴 버튼 aria: “게임 규칙 열기”.
  static String get menuRules => _ko('게임 규칙 열기');

  /// 메뉴 버튼 aria: “게임 설정 열기”.
  static String get menuSettings => _ko('게임 설정 열기');

  /// 시간 바 aria: T04 “남은 시간 약 80%”.
  static String timeBarSemantics(int percent) => _ko('남은 시간 약 $percent%');

  /// 슬롯 aria: T02 “A가 고른 뒤집힌 타일”.
  static String slotPickedBack(String who) => _ko('$who가 고른 뒤집힌 타일');

  /// 슬롯 aria: T05–T08 “A가 낸 흑 타일”, “B가 낸 백 타일”.
  static String slotSubmitted(String who, String color) =>
      _ko('$who가 낸 $color 타일');

  /// 슬롯 aria: T06 “B가 자동 제출한 흑 타일”.
  static String slotAutoSubmitted(String who, String color) =>
      _ko('$who가 자동 제출한 $color 타일');

  /// 뽑기 카드 aria: T01–T03 “뒤집힌 타일”.
  static String get drawCardBack => _ko('뒤집힌 타일');

  /// 뽑기 카드 aria: T02 “A가 고른 타일”.
  static String drawCardPicked(String who) => _ko('$who가 고른 타일');

  /// 뽑기 카드 aria: T03 “A가 뽑은 타일 7”.
  static String drawCardRevealed(String who, int value) =>
      _ko('$who가 뽑은 타일 $value');

  /// 왕관 aria: T10·T13·T13-B·P10·P11 “왕관”.
  static String get crown => _ko('왕관');

  // --- 전적판 (T04–T09) ------------------------------------------------------
  /// 열 머리 가운데: “라운드”(양옆은 좌석 표시 A / B).
  static String get historyColumnRound => _ko('라운드');

  /// 행 가운데 라운드: “1R”.
  static String historyRound(int round) => _ko('${round}R');

  /// 행 결과: 왼쪽 승 “◀ 승”.
  static String get historyWinLeft => _ko('◀ 승');

  /// 행 결과: 오른쪽 승 “승 ▶”.
  static String get historyWinRight => _ko('승 ▶');

  /// 행 결과: “동점”.
  static String get historyTie => _ko('동점');

  /// 행 결과 동점 기호: “=”.
  static String get historyTieMark => _ko('=');

  /// 선공 칸 배지: “선”.
  static String get firstBadge => _ko('선');

  /// 행 aria: “1라운드 A 승 · A 선공”.
  static String historyRowWin(int round, String winner, String first) =>
      _ko('$round라운드 $winner 승 · $first 선공');

  /// 행 aria: “3라운드 동점 · B 선공”.
  static String historyRowTie(int round, String first) =>
      _ko('$round라운드 동점 · $first 선공');

  /// 행 aria: “1라운드 진행 중 · 결과는 라운드가 끝난 뒤 표시”.
  static String historyRowCurrent(int round) =>
      _ko('$round라운드 진행 중 · 결과는 라운드가 끝난 뒤 표시');

  /// 행 aria: “2라운드 진행 전”.
  static String historyRowUpcoming(int round) => _ko('$round라운드 진행 전');

  // --- 중앙 토스트 -------------------------------------------------------------
  /// T01·T02·T11 “타일 선택”.
  static String get toastPickTile => _ko('타일 선택');

  /// T03 “숫자 공개”.
  static String get toastRevealNumbers => _ko('숫자 공개');

  /// T03 “A 선공”.
  static String toastFirstPlayer(String who) => _ko('$who 선공');

  /// T04 “1라운드”.
  static String toastRound(int round) => _ko('$round라운드');

  /// T05 “제출 완료”.
  static String get toastSubmitted => _ko('제출 완료');

  /// T06 “타일 자동 제출”.
  static String get toastAutoSubmitted => _ko('타일 자동 제출');

  /// T07 “A 승리”, T12 “B 승리”.
  static String toastWinner(String who) => _ko('$who 승리');

  /// T08·T11 “동점”.
  static String get toastTie => _ko('동점');

  /// T09 “6라운드 / A 선공”(두 줄).
  static String toastRoundIntro(int round, String who) =>
      _ko('$round라운드\n$who 선공');

  /// T10 “게임 조기 종료”.
  static String get toastEarlyEnd => _ko('게임 조기 종료');

  /// 프로토타입 ⑦ 11라운드 정상 종료 “게임 종료”.
  static String get toastGameOver => _ko('게임 종료');

  /// T10 “승자 / A”(두 줄).
  static String toastGameWinner(String who) => _ko('승자\n$who');

  /// T11 “최종 승부”.
  static String get toastFinalBout => _ko('최종 승부');

  /// T12 “타일 공개”.
  static String get toastRevealTiles => _ko('타일 공개');

  // --- 최종 결과 (T13, T13-B) --------------------------------------------------
  /// T13 머리 라벨 “최종 점수”.
  static String get finalScoreLabel => _ko('최종 점수');

  /// T13-B 머리 라벨 “승자”.
  static String get finalWinnerLabel => _ko('승자');

  /// 버튼 “다시하기”.
  static String get restart => _ko('다시하기');

  /// 버튼 “HOME”.
  static String get home => _ko('HOME');

  /// 안내 “결과 화면은 자동으로 닫히지 않아요”.
  static String get resultStays => _ko('결과 화면은 자동으로 닫히지 않아요');

  // ===========================================================================
  // 휴대폰 공통 (P01–P11, G1–G8)
  // ===========================================================================
  /// 플레이어 칩: “나”.
  static String get me => _ko('나');

  /// 아이콘 버튼 aria: “규칙 보기”.
  static String get rules => _ko('규칙 보기');

  /// 패널 값: “흑 6”, “백 7”.
  static String tileName(String color, int value) => _ko('$color $value');

  /// 손패 선택 배지: “선택”.
  static String get selectedBadge => _ko('선택');

  /// 제출 버튼: P02·P05·P09 “제출하기”.
  static String get submit => _ko('제출하기');

  /// 안내: P02·P09 “제출하면 취소할 수 없어요”.
  static String get submitIsFinal => _ko('제출하면 취소할 수 없어요');

  /// 패널 라벨: P03·P05 “선택한 타일”.
  static String get selectedTile => _ko('선택한 타일');

  /// 배지: P04·P07 “제출 완료”.
  static String get submittedBadge => _ko('제출 완료');

  /// 패널 라벨: P04·P07 “이번 라운드에 낸 타일”.
  static String get submittedTileLabel => _ko('이번 라운드에 낸 타일');

  /// 안내: P04 “태블릿에는 흑색만 보여요”, P07 “태블릿에는 백색만 보여요”.
  static String tabletShowsColorOnly(String color) => _ko('태블릿에는 $color색만 보여요');

  /// 대시 상자·안내: P04·P06·P07·G3 “결과는 태블릿에서 확인해요”.
  static String get resultOnTablet => _ko('결과는 태블릿에서 확인해요');

  // --- 상태 칩 태그 ----------------------------------------------------------
  /// 태그: P01·G1–G5 “선공 뽑기”.
  static String get tagFirstDraw => _ko('선공 뽑기');

  /// 태그: P02·P09 “5R · 선공”.
  static String tagFirst(int round) => _ko('${round}R · 선공');

  /// 태그: P03·P05 “5R · 후공”.
  static String tagSecond(int round) => _ko('${round}R · 후공');

  /// 태그: P04 “5R · 후공 차례”.
  static String tagSecondTurn(int round) => _ko('${round}R · 후공 차례');

  /// 태그: P06 “5R · 시간 초과”.
  static String tagTimeout(int round) => _ko('${round}R · 시간 초과');

  /// 태그: P07 “5R · 결과 대기”.
  static String tagWaitingResult(int round) => _ko('${round}R · 결과 대기');

  /// 태그: P08·G6 “5R 결과”.
  static String tagRoundResult(int round) => _ko('${round}R 결과');

  /// 태그: G7 “조기 종료”.
  static String get tagEarlyEnd => _ko('조기 종료');

  /// 태그: G8 “동점 뽑기”.
  static String get tagTieDraw => _ko('동점 뽑기');

  // --- P01 / G1 뽑기 내 차례 (결정 9: 같은 화면) ---------------------------------
  /// 상태: “내가 먼저 뽑아요”.
  static String get drawMyTurnStatus => _ko('내가 먼저 뽑아요');

  /// 제목: P01·G1·G8 “태블릿에서 카드를 뽑아요”.
  static String get drawOnTablet => _ko('태블릿에서 카드를 뽑아요');

  /// 본문: “태블릿의 뒤집힌 타일 중 하나를 골라 주세요”.
  static String get drawPickOne => _ko('태블릿의 뒤집힌 타일 중 하나를 골라 주세요');

  /// 보조: P01·G1·G2 “더 큰 숫자를 뽑은 사람이 1라운드 선공이에요”.
  static String get drawRuleFirst => _ko('더 큰 숫자를 뽑은 사람이 1라운드 선공이에요');

  // --- G2 상대가 먼저 뽑는 중 ---------------------------------------------------
  /// 상태·제목: “A가 먼저 뽑고 있어요”.
  static String drawOtherFirst(String who) => _ko('$who가 먼저 뽑고 있어요');

  /// 본문: “A가 뽑으면 내 차례예요”.
  static String drawAfterOther(String who) => _ko('$who가 뽑으면 내 차례예요');

  // --- G3 뽑은 뒤 대기 --------------------------------------------------------
  /// 상태: “뽑았어요 · B를 기다려요”.
  static String drawPickedWaiting(String who) => _ko('뽑았어요 · $who를 기다려요');

  /// 제목: “뽑았어요”.
  static String get drawPicked => _ko('뽑았어요');

  /// 본문: “B가 뽑으면 두 숫자를 함께 공개해요”.
  static String drawRevealTogether(String who) =>
      _ko('$who가 뽑으면 두 숫자를 함께 공개해요');

  // --- G4 / G5 뽑기 결과 ------------------------------------------------------
  /// 상태·제목: G4 “내가 선공이에요”.
  static String get drawIAmFirst => _ko('내가 선공이에요');

  /// 상태·제목: G5 “A가 선공이에요”.
  static String drawOtherIsFirst(String who) => _ko('$who가 선공이에요');

  /// 그림 줄: G4·G5·G6 “vs”.
  static String get versus => _ko('vs');

  /// 본문: G4 “7 vs 3 · 더 큰 숫자를 뽑았어요”.
  static String drawIWon(int mine, int theirs) =>
      _ko('$mine vs $theirs · 더 큰 숫자를 뽑았어요');

  /// 본문: G5 “3 vs 7 · A가 더 큰 숫자를 뽑았어요”.
  static String drawOtherWon(int mine, int theirs, String who) =>
      _ko('$mine vs $theirs · $who가 더 큰 숫자를 뽑았어요');

  /// 보조: G4 “1라운드는 내가 먼저 내요”.
  static String get drawIPlayFirst => _ko('1라운드는 내가 먼저 내요');

  /// 보조: G5 “1라운드는 A 다음에 내요”.
  static String drawIPlayAfter(String who) => _ko('1라운드는 $who 다음에 내요');

  // --- P02 선공 선택 중 --------------------------------------------------------
  /// 상태: “타일을 고르고 제출하세요”.
  static String get firstChoose => _ko('타일을 고르고 제출하세요');

  /// 패널 라벨: “이 타일을 낼까요?”.
  static String get confirmTile => _ko('이 타일을 낼까요?');

  /// 패널 빈 자리(선택 전) 라벨: “타일을 골라 주세요”. 프로토타입 ② 휴대폰 A 0ms 프레임 원문.
  static String get pickTilePrompt => _ko('타일을 골라 주세요');

  /// 패널 빈 자리 값: “—”. 프로토타입 ② 원문.
  static String get emptyValue => _ko('—');

  // --- P03 후공 미리 선택 ------------------------------------------------------
  /// 패널 빈 자리(미리 선택 전) 라벨: “미리 골라 둘 수 있어요”. 프로토타입 ② 휴대폰 B 원문.
  static String get preselectPrompt => _ko('미리 골라 둘 수 있어요');

  /// 상태: “상대가 고르는 중 · 미리 골라두세요”.
  static String get preselectStatus => _ko('상대가 고르는 중 · 미리 골라두세요');

  /// 안내: “선공 색을 본 뒤 바꿔도 돼요”.
  static String get preselectChangeLater => _ko('선공 색을 본 뒤 바꿔도 돼요');

  /// 잠긴 버튼: “선공 제출 후 제출 가능”.
  static String get submitLocked => _ko('선공 제출 후 제출 가능');

  /// 안내: “내 차례는 A 차례 이후 시작해요”.
  static String myTurnAfter(String who) => _ko('내 차례는 $who 차례 이후 시작해요');

  // --- P04 선공 제출 완료 ------------------------------------------------------
  /// 상태: “상대가 고르는 중이에요”.
  static String get opponentChoosing => _ko('상대가 고르는 중이에요');

  // --- P05 후공 제출 가능 ------------------------------------------------------
  /// 상태: “내 차례예요 · 타일을 고르고 제출하세요”.
  static String get secondChoose => _ko('내 차례예요 · 타일을 고르고 제출하세요');

  /// 요약줄: “A가 흑 타일을 냈어요”.
  static String firstPlayed(String who, String color) =>
      _ko('$who가 $color 타일을 냈어요');

  // --- P06 시간 초과 자동 제출 --------------------------------------------------
  /// 상태: “시간이 지나 타일이 자동으로 제출됐어요”.
  static String get autoSubmittedStatus => _ko('시간이 지나 타일이 자동으로 제출됐어요');

  /// 배지: “자동 제출”.
  static String get autoSubmittedBadge => _ko('자동 제출');

  /// 패널 라벨: “남은 타일 중 무작위로”.
  static String get autoSubmittedLabel => _ko('남은 타일 중 무작위로');

  /// 안내: “이번 라운드에 냈어요”.
  static String get autoSubmittedNote => _ko('이번 라운드에 냈어요');

  // --- P07 후공 제출 완료 ------------------------------------------------------
  /// 상태: “두 사람 모두 냈어요”.
  static String get bothSubmitted => _ko('두 사람 모두 냈어요');

  // --- P08 결과·다음 라운드 전환 -------------------------------------------------
  /// 상태(이긴 경우): “내가 이겼어요! +1”.
  static String get roundIWon => _ko('내가 이겼어요! +1');

  /// 상태(진 경우): “상대가 이겼어요”. 시안에 없어 하준 결정(2026-11-25)으로 정했다.
  static String get roundOpponentWon => _ko('상대가 이겼어요');

  /// 상태(동점): “동점이에요! +0”. 태블릿 T08 “+0” 배지와 맞춘 하준 결정(2026-11-25).
  static String get roundTieStatus => _ko('동점이에요! +0');

  /// 패널 라벨: “곧 다음 라운드가 시작돼요”.
  static String get nextRoundSoon => _ko('곧 다음 라운드가 시작돼요');

  /// 패널 값: “6라운드”.
  static String nextRound(int round) => _ko('$round라운드');

  /// 선공 표식: “선공”.
  static String get firstMark => _ko('선공');

  /// 다음 라운드 안내(선공일 때): “내가 먼저 내요”.
  static String get iPlayFirst => _ko('내가 먼저 내요');

  /// 후공 표식: “후공”. 선공 표식 자리에 같은 모양으로 쓴다(하준 결정 2026-11-25).
  static String get secondMark => _ko('후공');

  /// 다음 라운드 안내(후공일 때): “상대 다음에 내요”(하준 결정 2026-11-25).
  static String get iPlayAfterOpponent => _ko('상대 다음에 내요');

  /// 대시 상자: “태블릿에서 결과를 보여주는 중”.
  static String get tabletShowingResult => _ko('태블릿에서 결과를 보여주는 중');

  // --- P09 마지막 타일 --------------------------------------------------------
  /// 상태: “마지막 타일이에요 · 제출 버튼을 눌러 주세요”.
  static String get lastTileStatus => _ko('마지막 타일이에요 · 제출 버튼을 눌러 주세요');

  /// 패널 라벨: “마지막 남은 타일”.
  static String get lastTileLabel => _ko('마지막 남은 타일');

  // --- P10 / P11 게임 종료 (결정 10: 진 사람도 승자 표시) ------------------------
  /// 승자 라벨: “WINNER”.
  static String get winnerLabel => _ko('WINNER');

  /// 안내: “최종 6 : 2 · 다시하기와 HOME은 태블릿에서 선택해요”.
  static String finalNote(int mine, int theirs) =>
      _ko('최종 $mine : $theirs · 다시하기와 HOME은 태블릿에서 선택해요');

  // --- G6 라운드 결과 확인 안내 ---------------------------------------------------
  /// 상태: “결과 확인 중”.
  static String get resultChecking => _ko('결과 확인 중');

  /// 제목: “태블릿에서 결과를 확인해요”.
  static String get checkResultOnTablet => _ko('태블릿에서 결과를 확인해요');

  /// 본문: “이번 라운드 승패와 점수가 태블릿에 표시돼요”.
  static String get resultShownOnTablet => _ko('이번 라운드 승패와 점수가 태블릿에 표시돼요');

  /// 보조: “이긴 사람이 다음 라운드 선공이에요”.
  static String get winnerGoesFirst => _ko('이긴 사람이 다음 라운드 선공이에요');

  // --- G7 조기 종료 안내 ------------------------------------------------------
  /// 상태: “게임 종료”.
  static String get gameOver => _ko('게임 종료');

  /// 제목: “게임이 일찍 끝났어요”.
  static String get earlyEndTitle => _ko('게임이 일찍 끝났어요');

  /// 본문: “남은 라운드를 모두 이겨도 결과가 바뀌지 않아요”.
  static String get earlyEndReason => _ko('남은 라운드를 모두 이겨도 결과가 바뀌지 않아요');

  /// 보조: “최종 결과는 태블릿과 이 화면에 곧 표시돼요”.
  static String get earlyEndSoon => _ko('최종 결과는 태블릿과 이 화면에 곧 표시돼요');

  // --- G8 최종 동점 뽑기 안내 ---------------------------------------------------
  /// 상태: “내 차례”.
  static String get myTurn => _ko('내 차례');

  /// 본문: “최종 점수가 5 : 5 동점이에요”.
  static String finalTie(int mine, int theirs) =>
      _ko('최종 점수가 $mine : $theirs 동점이에요');

  /// 보조: “더 큰 숫자를 뽑은 사람이 최종 승리해요”.
  static String get drawRuleFinal => _ko('더 큰 숫자를 뽑은 사람이 최종 승리해요');

  // --- 규칙(룰북) -----------------------------------------------------------
  /// 규칙 창 제목. 게임 이름을 쓴다.
  static String get rulebookTitle => ElevenCopy.title;

  /// 규칙 본문(game_kit 룰북 형식: `# 항목` + 본문). 계약 2절 규칙 요약을 그대로 옮긴 초안이며
  /// 하준 확인 대상이다(S5 레인 검수 B5). 숫자 판정 예시는 넣지 않는다.
  static String get rulebookMarkdown => _ko('''
# 게임 방법
두 사람이 각자 숫자 타일 11개(0–9, 11)로 11라운드를 겨뤄요. 10은 없어요.
라운드마다 선공이 먼저 타일 하나를 내고, 후공이 이어서 하나를 내요. 낸 타일은 다시 쓸 수 없어요.
제한 시간은 각각 60초예요. 시간이 지나면 남은 타일 중 하나가 무작위로 제출돼요.

# 흑과 백
흑 타일은 0, 2, 4, 6, 8, 11이고 백 타일은 1, 3, 5, 7, 9예요.
상대가 낸 타일의 색만 공개되고 숫자는 끝까지 공개되지 않아요.

# 승패 판정
두 숫자가 같으면 동점이에요. 둘 다 점수를 얻지 못해요.
두 숫자의 합이 20이면 11을 낸 사람이 이겨요.
합이 10보다 작으면 큰 숫자가 이기고, 10 이상이면 작은 숫자가 이겨요.
이긴 사람은 1점을 얻고 다음 라운드 선공이 돼요. 동점이면 선공이 그대로예요.

# 선공 뽑기
첫 라운드 선공은 태블릿의 뒤집힌 카드 9장(1–9) 중 하나씩 골라 정해요.
더 큰 숫자를 뽑은 사람이 1라운드 선공이에요.

# 게임 종료
점수 차가 남은 라운드 수보다 커지면 바로 끝나요.
11라운드가 끝났을 때 점수가 같으면 같은 방식의 카드 뽑기로 최종 승자를 정해요.
''');

  /// 색 이름: “흑”, “백”(기존 [ElevenCopy.black]/[ElevenCopy.white]와 같은 값).
  static String get black => _ko('흑');
  static String get white => _ko('백');
}
