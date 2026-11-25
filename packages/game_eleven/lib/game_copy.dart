// [game_copy.dart] 는 ELEVEN에서만 쓰는 화면 문구를 모아 두는 파일이다.
//
// - [Package] : ELEVEN
// - [Copy] : 게임 화면 문구의 번역 키(getter)
//
// 노션 개발 계획 S4·Q64: 다국어 구조와 키는 앱 골격에서 만들고, 한국어로 화면을 완성한 뒤
// S7(2026-11-25)에 en·zh-Hans·zh-Hant 번역을 GameLocale.select로 일괄 적용했다.
// 게임 이름은 ko 일레븐, en·zh-Hans·zh-Hant ELEVEN(하준 결정 2026-11-25, 계약 10절 1).
// 한국어는 시안 원문 그대로다(test/shared/screen_copy_test.dart). 실기기에서 언어별 긴 문장·
// 잘림·줄바꿈은 S8에서 확인한다.
// 공통 문구(GAME START, 인원 부족 등)는 game_kit의 GameFlowCopy를 쓴다.

// ========================[ import ]==========================
import 'package:game_kit/localization/game_locale.dart';

// ============================================================

abstract final class ElevenCopy {
  static String get title => GameLocale.select(
    ko: '일레븐',
    en: 'ELEVEN',
    zhHans: 'ELEVEN',
    zhHant: 'ELEVEN',
  );

  static String round(int round) => GameLocale.select(
    ko: '$round / 11 라운드',
    en: 'Round $round / 11',
    zhHans: '第 $round / 11 回合',
    zhHant: '第 $round / 11 回合',
  );

  static String get firstPlayerDraw => GameLocale.select(
    ko: '선공 뽑기',
    en: 'First-player draw',
    zhHans: '先手抽签',
    zhHant: '先手抽籤',
  );

  static String get tieDraw => GameLocale.select(
    ko: '동점 · 최종 뽑기',
    en: 'Tie · Final draw',
    zhHans: '平局 · 最终抽签',
    zhHant: '平局 · 最終抽籤',
  );

  static String pickTurn(String nickname) => GameLocale.select(
    ko: '$nickname 님이 타일을 고르세요',
    en: '$nickname, pick a tile',
    zhHans: '请 $nickname 选牌',
    zhHant: '請 $nickname 選牌',
  );

  static String drawWinnerFirst(String nickname) => GameLocale.select(
    ko: '$nickname 님이 선공입니다',
    en: '$nickname goes first',
    zhHans: '$nickname 先手',
    zhHant: '$nickname 先手',
  );

  static String choosing(String nickname) => GameLocale.select(
    ko: '$nickname 님이 고르는 중',
    en: '$nickname is choosing',
    zhHans: '$nickname 正在选择',
    zhHant: '$nickname 正在選擇',
  );

  static String get first =>
      GameLocale.select(ko: '선공', en: 'First', zhHans: '先手', zhHant: '先手');
  static String get second =>
      GameLocale.select(ko: '후공', en: 'Second', zhHans: '后手', zhHant: '後手');

  static String roundWinner(String nickname) => GameLocale.select(
    ko: '$nickname 님 승리',
    en: '$nickname wins',
    zhHans: '$nickname 获胜',
    zhHant: '$nickname 獲勝',
  );

  static String get roundTie =>
      GameLocale.select(ko: '동점', en: 'Tie', zhHans: '平局', zhHant: '平局');

  static String get autoSubmitted => GameLocale.select(
    ko: '시간 초과 · 자동 제출',
    en: 'Time out · Auto-submitted',
    zhHans: '超时 · 自动提交',
    zhHant: '超時 · 自動提交',
  );

  static String winner(String nickname) => GameLocale.select(
    ko: '$nickname 님 최종 승리',
    en: '$nickname wins the game',
    zhHans: '$nickname 最终获胜',
    zhHant: '$nickname 最終獲勝',
  );

  static String earlyEnd(int remaining, int gap) => GameLocale.select(
    ko: '남은 $remaining라운드보다 점수 차($gap)가 커 조기 종료',
    en: 'Ended early: the gap ($gap) is larger than the $remaining rounds left',
    zhHans: '分差（$gap）大于剩余的 $remaining 回合，提前结束',
    zhHant: '分差（$gap）大於剩餘的 $remaining 回合，提前結束',
  );

  static String get waitingDraw => GameLocale.select(
    ko: '태블릿에서 타일을 뽑고 있습니다',
    en: 'Drawing tiles on the tablet',
    zhHans: '正在平板上抽牌',
    zhHant: '正在平板上抽牌',
  );

  static String get yourTurn => GameLocale.select(
    ko: '낼 타일을 고르세요',
    en: 'Choose a tile to play',
    zhHans: '请选择要出的牌',
    zhHant: '請選擇要出的牌',
  );

  static String get preselect => GameLocale.select(
    ko: '선공이 고르는 중 · 미리 골라 둘 수 있어요',
    en: 'First player is choosing · You can pick ahead',
    zhHans: '先手正在选择 · 你可以先选好',
    zhHant: '先手正在選擇 · 你可以先選好',
  );

  static String firstColor(String color) => GameLocale.select(
    ko: '선공은 $color 타일을 냈습니다',
    en: 'First player played a $color tile',
    zhHans: '先手出了$color牌',
    zhHant: '先手出了$color牌',
  );

  static String get black =>
      GameLocale.select(ko: '흑', en: 'Black', zhHans: '黑', zhHant: '黑');
  static String get white =>
      GameLocale.select(ko: '백', en: 'White', zhHans: '白', zhHant: '白');

  static String get submit =>
      GameLocale.select(ko: '제출', en: 'Submit', zhHans: '提交', zhHant: '提交');

  static String get submitted => GameLocale.select(
    ko: '제출 완료 · 상대를 기다리는 중',
    en: 'Submitted · Waiting for opponent',
    zhHans: '已提交 · 等待对手',
    zhHant: '已提交 · 等待對手',
  );

  static String get lastTile => GameLocale.select(
    ko: '마지막 타일입니다',
    en: 'This is your last tile',
    zhHans: '这是最后一张牌',
    zhHant: '這是最後一張牌',
  );

  static String get roundResultPhone => GameLocale.select(
    ko: '태블릿에서 결과를 확인하세요',
    en: 'Check the result on the tablet',
    zhHans: '请在平板上查看结果',
    zhHant: '請在平板上查看結果',
  );

  static String get youWin => GameLocale.select(
    ko: '승리!',
    en: 'Victory!',
    zhHans: '胜利！',
    zhHant: '勝利！',
  );
  static String get youLose =>
      GameLocale.select(ko: '패배', en: 'Defeat', zhHans: '失败', zhHant: '失敗');

  static String get restart => GameLocale.select(
    ko: '다시 하기',
    en: 'Play again',
    zhHans: '再来一局',
    zhHant: '再來一局',
  );
  static String get toLobby => GameLocale.select(
    ko: '대기실로',
    en: 'To lobby',
    zhHans: '返回大厅',
    zhHant: '返回大廳',
  );
  static String get endGame => GameLocale.select(
    ko: '게임 종료',
    en: 'Game over',
    zhHans: '游戏结束',
    zhHant: '遊戲結束',
  );
  static String get retry =>
      GameLocale.select(ko: '다시 시도', en: 'Retry', zhHans: '重试', zhHant: '重試');
}

/// 시안 A(느와르) 화면 문구 키입니다(S5-0b). 원문은 docs/design/eleven/screens.md
/// 4절의 화면별 “문구” 열이고, 값은 그 원문 그대로입니다. 레인 A·B는 이 파일을
/// 고치지 않고 아래 키만 씁니다. 번역은 S7에서 GameLocale.select로 번역을 적용했다.
///
/// - [who]는 화면에 보이는 사람 표시입니다. 시안은 좌석 표시 “A”/“B”로 그렸습니다.
/// - 숫자·점수·시간 자체(“7”, “6 : 2”, “0:42”)는 문구가 아니라 값이므로 키가 없습니다.
/// - 원문의 줄바꿈 `<br>`은 `\n`입니다(T09, T10 토스트).
abstract final class ElevenScreenCopy {
  // ===========================================================================
  // 태블릿 공통 (T01–T13, T13-B)
  // ===========================================================================
  /// 상태 pill: T01·T03·T04·T09·T11 “내 차례”.
  static String get pillMyTurn => GameLocale.select(
    ko: '내 차례',
    en: 'My turn',
    zhHans: '我的回合',
    zhHant: '我的回合',
  );

  /// 상태 pill: T01·T03·T04·T09·T11 “상대 차례”.
  static String get pillOpponentTurn => GameLocale.select(
    ko: '상대 차례',
    en: 'Opponent\'s turn',
    zhHans: '对手回合',
    zhHant: '對手回合',
  );

  /// 상태 pill: T02 “선택 완료”.
  static String get pillPicked => GameLocale.select(
    ko: '선택 완료',
    en: 'Picked',
    zhHans: '已选择',
    zhHant: '已選擇',
  );

  /// 상태 pill: T05 “제출 완료”.
  static String get pillSubmitted => GameLocale.select(
    ko: '제출 완료',
    en: 'Submitted',
    zhHans: '已提交',
    zhHant: '已提交',
  );

  /// 상태 pill: T06 “자동 제출”(양쪽, 자동 제출한 쪽은 pillWarn).
  static String get pillAutoSubmitted => GameLocale.select(
    ko: '자동 제출',
    en: 'Auto-submitted',
    zhHans: '自动提交',
    zhHant: '自動提交',
  );

  /// 상태 pill: T07·T12·T13·T13-B “승리”.
  static String get pillWin =>
      GameLocale.select(ko: '승리', en: 'Win', zhHans: '胜利', zhHant: '勝利');

  /// 상태 pill: T07·T12·T13·T13-B “패배”.
  static String get pillLose =>
      GameLocale.select(ko: '패배', en: 'Defeat', zhHans: '失败', zhHant: '失敗');

  /// 상태 pill: T08 “동점”.
  static String get pillTie =>
      GameLocale.select(ko: '동점', en: 'Tie', zhHans: '平局', zhHant: '平局');

  /// 상태 pill: T10 “게임 종료”.
  static String get pillGameOver => GameLocale.select(
    ko: '게임 종료',
    en: 'Game over',
    zhHans: '游戏结束',
    zhHant: '遊戲結束',
  );

  /// 점수 라벨: T04–T12 “점수”.
  static String get scoreLabel =>
      GameLocale.select(ko: '점수', en: 'Score', zhHans: '分数', zhHant: '分數');

  /// 점수 옆 배지: T07 “+1”, T08 “+0”.
  static String scoreDelta(int delta) => GameLocale.select(
    ko: '+$delta',
    en: '+$delta',
    zhHans: '+$delta',
    zhHant: '+$delta',
  );

  /// 메뉴 버튼 aria: “게임 규칙 열기”.
  static String get menuRules => GameLocale.select(
    ko: '게임 규칙 열기',
    en: 'Open game rules',
    zhHans: '打开游戏规则',
    zhHant: '打開遊戲規則',
  );

  /// 메뉴 버튼 aria: “게임 설정 열기”.
  static String get menuSettings => GameLocale.select(
    ko: '게임 설정 열기',
    en: 'Open game settings',
    zhHans: '打开游戏设置',
    zhHant: '打開遊戲設定',
  );

  /// 시간 바 aria: T04 “남은 시간 약 80%”.
  static String timeBarSemantics(int percent) => GameLocale.select(
    ko: '남은 시간 약 $percent%',
    en: 'About $percent% of time left',
    zhHans: '剩余时间约 $percent%',
    zhHant: '剩餘時間約 $percent%',
  );

  /// 슬롯 aria: T02 “A가 고른 뒤집힌 타일”.
  static String slotPickedBack(String who) => GameLocale.select(
    ko: '$who가 고른 뒤집힌 타일',
    en: 'Face-down tile picked by $who',
    zhHans: '$who 选的背面牌',
    zhHant: '$who 選的背面牌',
  );

  /// 슬롯 aria: T05–T08 “A가 낸 흑 타일”, “B가 낸 백 타일”.
  static String slotSubmitted(String who, String color) => GameLocale.select(
    ko: '$who가 낸 $color 타일',
    en: '$color tile played by $who',
    zhHans: '$who 出的$color牌',
    zhHant: '$who 出的$color牌',
  );

  /// 슬롯 aria: T06 “B가 자동 제출한 흑 타일”.
  static String slotAutoSubmitted(String who, String color) =>
      GameLocale.select(
        ko: '$who가 자동 제출한 $color 타일',
        en: '$color tile auto-submitted for $who',
        zhHans: '$who 自动提交的$color牌',
        zhHant: '$who 自動提交的$color牌',
      );

  /// 뽑기 카드 aria: T01–T03 “뒤집힌 타일”.
  static String get drawCardBack => GameLocale.select(
    ko: '뒤집힌 타일',
    en: 'Face-down tile',
    zhHans: '背面牌',
    zhHant: '背面牌',
  );

  /// 뽑기 카드 aria: T02 “A가 고른 타일”.
  static String drawCardPicked(String who) => GameLocale.select(
    ko: '$who가 고른 타일',
    en: 'Tile picked by $who',
    zhHans: '$who 选的牌',
    zhHant: '$who 選的牌',
  );

  /// 뽑기 카드 aria: T03 “A가 뽑은 타일 7”.
  static String drawCardRevealed(String who, int value) => GameLocale.select(
    ko: '$who가 뽑은 타일 $value',
    en: '$who drew $value',
    zhHans: '$who 抽到 $value',
    zhHant: '$who 抽到 $value',
  );

  /// 왕관 aria: T10·T13·T13-B·P10·P11 “왕관”.
  static String get crown =>
      GameLocale.select(ko: '왕관', en: 'Crown', zhHans: '王冠', zhHant: '王冠');

  // --- 전적판 (T04–T09) ------------------------------------------------------
  /// 열 머리 가운데: “라운드”(양옆은 좌석 표시 A / B).
  static String get historyColumnRound =>
      GameLocale.select(ko: '라운드', en: 'Round', zhHans: '回合', zhHant: '回合');

  /// 행 가운데 라운드: “1R”.
  static String historyRound(int round) => GameLocale.select(
    ko: '${round}R',
    en: '${round}R',
    zhHans: '${round}R',
    zhHant: '${round}R',
  );

  /// 행 결과: 왼쪽 승 “◀ 승”.
  static String get historyWinLeft =>
      GameLocale.select(ko: '◀ 승', en: '◀ Win', zhHans: '◀ 胜', zhHant: '◀ 勝');

  /// 행 결과: 오른쪽 승 “승 ▶”.
  static String get historyWinRight =>
      GameLocale.select(ko: '승 ▶', en: 'Win ▶', zhHans: '胜 ▶', zhHant: '勝 ▶');

  /// 행 결과: “동점”.
  static String get historyTie =>
      GameLocale.select(ko: '동점', en: 'Tie', zhHans: '平局', zhHant: '平局');

  /// 행 결과 동점 기호: “=”.
  static String get historyTieMark =>
      GameLocale.select(ko: '=', en: '=', zhHans: '=', zhHant: '=');

  /// 선공 칸 배지: “선”.
  static String get firstBadge =>
      GameLocale.select(ko: '선', en: '1st', zhHans: '先', zhHant: '先');

  /// 행 aria: “1라운드 A 승 · A 선공”.
  static String historyRowWin(int round, String winner, String first) =>
      GameLocale.select(
        ko: '$round라운드 $winner 승 · $first 선공',
        en: 'Round $round: $winner wins · $first went first',
        zhHans: '第 $round 回合 $winner 胜 · $first 先手',
        zhHant: '第 $round 回合 $winner 勝 · $first 先手',
      );

  /// 행 aria: “3라운드 동점 · B 선공”.
  static String historyRowTie(int round, String first) => GameLocale.select(
    ko: '$round라운드 동점 · $first 선공',
    en: 'Round $round: tie · $first went first',
    zhHans: '第 $round 回合 平局 · $first 先手',
    zhHant: '第 $round 回合 平局 · $first 先手',
  );

  /// 행 aria: “1라운드 진행 중 · 결과는 라운드가 끝난 뒤 표시”.
  static String historyRowCurrent(int round) => GameLocale.select(
    ko: '$round라운드 진행 중 · 결과는 라운드가 끝난 뒤 표시',
    en: 'Round $round in progress · Result shown after the round',
    zhHans: '第 $round 回合进行中 · 回合结束后显示结果',
    zhHant: '第 $round 回合進行中 · 回合結束後顯示結果',
  );

  /// 행 aria: “2라운드 진행 전”.
  static String historyRowUpcoming(int round) => GameLocale.select(
    ko: '$round라운드 진행 전',
    en: 'Round $round not started',
    zhHans: '第 $round 回合未开始',
    zhHant: '第 $round 回合未開始',
  );

  // --- 중앙 토스트 -------------------------------------------------------------
  /// T01·T02·T11 “타일 선택”.
  static String get toastPickTile => GameLocale.select(
    ko: '타일 선택',
    en: 'Pick a tile',
    zhHans: '选择牌',
    zhHant: '選擇牌',
  );

  /// T03 “숫자 공개”.
  static String get toastRevealNumbers => GameLocale.select(
    ko: '숫자 공개',
    en: 'Reveal',
    zhHans: '公开数字',
    zhHant: '公開數字',
  );

  /// T03 “A 선공”.
  static String toastFirstPlayer(String who) => GameLocale.select(
    ko: '$who 선공',
    en: '$who goes first',
    zhHans: '$who 先手',
    zhHant: '$who 先手',
  );

  /// T04 “1라운드”.
  static String toastRound(int round) => GameLocale.select(
    ko: '$round라운드',
    en: 'Round $round',
    zhHans: '第 $round 回合',
    zhHant: '第 $round 回合',
  );

  /// T05 “제출 완료”.
  static String get toastSubmitted => GameLocale.select(
    ko: '제출 완료',
    en: 'Submitted',
    zhHans: '已提交',
    zhHant: '已提交',
  );

  /// T06 “타일 자동 제출”.
  static String get toastAutoSubmitted => GameLocale.select(
    ko: '타일 자동 제출',
    en: 'Tile auto-submitted',
    zhHans: '自动提交',
    zhHant: '自動提交',
  );

  /// T07 “A 승리”, T12 “B 승리”.
  static String toastWinner(String who) => GameLocale.select(
    ko: '$who 승리',
    en: '$who wins',
    zhHans: '$who 获胜',
    zhHant: '$who 獲勝',
  );

  /// T08·T11 “동점”.
  static String get toastTie =>
      GameLocale.select(ko: '동점', en: 'Tie', zhHans: '平局', zhHant: '平局');

  /// T09 “6라운드 / A 선공”(두 줄).
  static String toastRoundIntro(int round, String who) => GameLocale.select(
    ko: '$round라운드\n$who 선공',
    en: 'Round $round\n$who first',
    zhHans: '第 $round 回合\n$who 先手',
    zhHant: '第 $round 回合\n$who 先手',
  );

  /// T10 “게임 조기 종료”.
  static String get toastEarlyEnd => GameLocale.select(
    ko: '게임 조기 종료',
    en: 'Game ended early',
    zhHans: '游戏提前结束',
    zhHant: '遊戲提前結束',
  );

  /// 프로토타입 ⑦ 11라운드 정상 종료 “게임 종료”.
  static String get toastGameOver => GameLocale.select(
    ko: '게임 종료',
    en: 'Game over',
    zhHans: '游戏结束',
    zhHant: '遊戲結束',
  );

  /// T10 “승자 / A”(두 줄).
  static String toastGameWinner(String who) => GameLocale.select(
    ko: '승자\n$who',
    en: 'Winner\n$who',
    zhHans: '胜者\n$who',
    zhHant: '勝者\n$who',
  );

  /// T11 “최종 승부”.
  static String get toastFinalBout => GameLocale.select(
    ko: '최종 승부',
    en: 'Final showdown',
    zhHans: '最终决胜',
    zhHant: '最終決勝',
  );

  /// T12 “타일 공개”.
  static String get toastRevealTiles => GameLocale.select(
    ko: '타일 공개',
    en: 'Reveal tiles',
    zhHans: '公开牌',
    zhHant: '公開牌',
  );

  // --- 최종 결과 (T13, T13-B) --------------------------------------------------
  /// T13 머리 라벨 “최종 점수”.
  static String get finalScoreLabel => GameLocale.select(
    ko: '최종 점수',
    en: 'Final score',
    zhHans: '最终比分',
    zhHant: '最終比分',
  );

  /// T13-B 머리 라벨 “승자”.
  static String get finalWinnerLabel =>
      GameLocale.select(ko: '승자', en: 'Winner', zhHans: '胜者', zhHant: '勝者');

  /// 버튼 “다시하기”.
  static String get restart => GameLocale.select(
    ko: '다시하기',
    en: 'Play again',
    zhHans: '再来一局',
    zhHant: '再來一局',
  );

  /// 버튼 “HOME”.
  static String get home =>
      GameLocale.select(ko: 'HOME', en: 'HOME', zhHans: 'HOME', zhHant: 'HOME');

  /// 안내 “결과 화면은 자동으로 닫히지 않아요”.
  static String get resultStays => GameLocale.select(
    ko: '결과 화면은 자동으로 닫히지 않아요',
    en: 'This result screen won\'t close automatically',
    zhHans: '结果画面不会自动关闭',
    zhHant: '結果畫面不會自動關閉',
  );

  // ===========================================================================
  // 휴대폰 공통 (P01–P11, G1–G8)
  // ===========================================================================
  /// 플레이어 칩: “나”.
  static String get me =>
      GameLocale.select(ko: '나', en: 'Me', zhHans: '我', zhHant: '我');

  /// 아이콘 버튼 aria: “규칙 보기”.
  static String get rules => GameLocale.select(
    ko: '규칙 보기',
    en: 'View rules',
    zhHans: '查看规则',
    zhHant: '查看規則',
  );

  /// 패널 값: “흑 6”, “백 7”.
  static String tileName(String color, int value) => GameLocale.select(
    ko: '$color $value',
    en: '$color $value',
    zhHans: '$color $value',
    zhHant: '$color $value',
  );

  /// 손패 선택 배지: “선택”.
  static String get selectedBadge =>
      GameLocale.select(ko: '선택', en: 'Selected', zhHans: '已选', zhHant: '已選');

  /// 제출 버튼: P02·P05·P09 “제출하기”.
  static String get submit =>
      GameLocale.select(ko: '제출하기', en: 'Submit', zhHans: '提交', zhHant: '提交');

  /// 안내: P02·P09 “제출하면 취소할 수 없어요”.
  static String get submitIsFinal => GameLocale.select(
    ko: '제출하면 취소할 수 없어요',
    en: 'You can\'t undo a submission',
    zhHans: '提交后无法撤回',
    zhHant: '提交後無法撤回',
  );

  /// 패널 라벨: P03·P05 “선택한 타일”.
  static String get selectedTile => GameLocale.select(
    ko: '선택한 타일',
    en: 'Selected tile',
    zhHans: '已选的牌',
    zhHant: '已選的牌',
  );

  /// 배지: P04·P07 “제출 완료”.
  static String get submittedBadge => GameLocale.select(
    ko: '제출 완료',
    en: 'Submitted',
    zhHans: '已提交',
    zhHant: '已提交',
  );

  /// 패널 라벨: P04·P07 “이번 라운드에 낸 타일”.
  static String get submittedTileLabel => GameLocale.select(
    ko: '이번 라운드에 낸 타일',
    en: 'Tile played this round',
    zhHans: '本回合出的牌',
    zhHant: '本回合出的牌',
  );

  /// 안내: P04 “태블릿에는 흑색만 보여요”, P07 “태블릿에는 백색만 보여요”.
  static String tabletShowsColorOnly(String color) => GameLocale.select(
    ko: '태블릿에는 $color색만 보여요',
    en: 'The tablet shows only the color ($color)',
    zhHans: '平板上只显示颜色（$color）',
    zhHant: '平板上只顯示顏色（$color）',
  );

  /// 대시 상자·안내: P04·P06·P07·G3 “결과는 태블릿에서 확인해요”.
  static String get resultOnTablet => GameLocale.select(
    ko: '결과는 태블릿에서 확인해요',
    en: 'See the result on the tablet',
    zhHans: '请在平板上查看结果',
    zhHant: '請在平板上查看結果',
  );

  // --- 상태 칩 태그 ----------------------------------------------------------
  /// 태그: P01·G1–G5 “선공 뽑기”.
  static String get tagFirstDraw => GameLocale.select(
    ko: '선공 뽑기',
    en: 'First-player draw',
    zhHans: '先手抽签',
    zhHant: '先手抽籤',
  );

  /// 태그: P02·P09 “5R · 선공”.
  static String tagFirst(int round) => GameLocale.select(
    ko: '${round}R · 선공',
    en: '${round}R · First',
    zhHans: '${round}R · 先手',
    zhHant: '${round}R · 先手',
  );

  /// 태그: P03·P05 “5R · 후공”.
  static String tagSecond(int round) => GameLocale.select(
    ko: '${round}R · 후공',
    en: '${round}R · Second',
    zhHans: '${round}R · 后手',
    zhHant: '${round}R · 後手',
  );

  /// 태그: P04 “5R · 후공 차례”.
  static String tagSecondTurn(int round) => GameLocale.select(
    ko: '${round}R · 후공 차례',
    en: '${round}R · Second\'s turn',
    zhHans: '${round}R · 后手回合',
    zhHant: '${round}R · 後手回合',
  );

  /// 태그: P06 “5R · 시간 초과”.
  static String tagTimeout(int round) => GameLocale.select(
    ko: '${round}R · 시간 초과',
    en: '${round}R · Time out',
    zhHans: '${round}R · 超时',
    zhHant: '${round}R · 超時',
  );

  /// 태그: P07 “5R · 결과 대기”.
  static String tagWaitingResult(int round) => GameLocale.select(
    ko: '${round}R · 결과 대기',
    en: '${round}R · Awaiting result',
    zhHans: '${round}R · 等待结果',
    zhHant: '${round}R · 等待結果',
  );

  /// 태그: P08·G6 “5R 결과”.
  static String tagRoundResult(int round) => GameLocale.select(
    ko: '${round}R 결과',
    en: '${round}R result',
    zhHans: '${round}R 结果',
    zhHant: '${round}R 結果',
  );

  /// 태그: G7 “조기 종료”.
  static String get tagEarlyEnd => GameLocale.select(
    ko: '조기 종료',
    en: 'Early end',
    zhHans: '提前结束',
    zhHant: '提前結束',
  );

  /// 태그: G8 “동점 뽑기”.
  static String get tagTieDraw => GameLocale.select(
    ko: '동점 뽑기',
    en: 'Tie draw',
    zhHans: '平局抽签',
    zhHant: '平局抽籤',
  );

  // --- P01 / G1 뽑기 내 차례 (결정 9: 같은 화면) ---------------------------------
  /// 상태: “내가 먼저 뽑아요”.
  static String get drawMyTurnStatus => GameLocale.select(
    ko: '내가 먼저 뽑아요',
    en: 'I draw first',
    zhHans: '我先抽',
    zhHant: '我先抽',
  );

  /// 제목: P01·G1·G8 “태블릿에서 카드를 뽑아요”.
  static String get drawOnTablet => GameLocale.select(
    ko: '태블릿에서 카드를 뽑아요',
    en: 'Draw a card on the tablet',
    zhHans: '在平板上抽牌',
    zhHant: '在平板上抽牌',
  );

  /// 본문: “태블릿의 뒤집힌 타일 중 하나를 골라 주세요”.
  static String get drawPickOne => GameLocale.select(
    ko: '태블릿의 뒤집힌 타일 중 하나를 골라 주세요',
    en: 'Pick one of the face-down tiles on the tablet',
    zhHans: '请在平板上从背面牌中选一张',
    zhHant: '請在平板上從背面牌中選一張',
  );

  /// 보조: P01·G1·G2 “더 큰 숫자를 뽑은 사람이 1라운드 선공이에요”.
  static String get drawRuleFirst => GameLocale.select(
    ko: '더 큰 숫자를 뽑은 사람이 1라운드 선공이에요',
    en: 'The higher number goes first in round 1',
    zhHans: '抽到较大数字的人在第 1 回合先手',
    zhHant: '抽到較大數字的人在第 1 回合先手',
  );

  // --- G2 상대가 먼저 뽑는 중 ---------------------------------------------------
  /// 상태·제목: “A가 먼저 뽑고 있어요”.
  static String drawOtherFirst(String who) => GameLocale.select(
    ko: '$who가 먼저 뽑고 있어요',
    en: '$who is drawing first',
    zhHans: '$who 正在先抽',
    zhHant: '$who 正在先抽',
  );

  /// 본문: “A가 뽑으면 내 차례예요”.
  static String drawAfterOther(String who) => GameLocale.select(
    ko: '$who가 뽑으면 내 차례예요',
    en: 'My turn after $who draws',
    zhHans: '$who 抽完后轮到我',
    zhHant: '$who 抽完後輪到我',
  );

  // --- G3 뽑은 뒤 대기 --------------------------------------------------------
  /// 상태: “뽑았어요 · B를 기다려요”.
  static String drawPickedWaiting(String who) => GameLocale.select(
    ko: '뽑았어요 · $who를 기다려요',
    en: 'Drawn · Waiting for $who',
    zhHans: '已抽 · 等待 $who',
    zhHant: '已抽 · 等待 $who',
  );

  /// 제목: “뽑았어요”.
  static String get drawPicked =>
      GameLocale.select(ko: '뽑았어요', en: 'Drawn', zhHans: '已抽', zhHant: '已抽');

  /// 본문: “B가 뽑으면 두 숫자를 함께 공개해요”.
  static String drawRevealTogether(String who) => GameLocale.select(
    ko: '$who가 뽑으면 두 숫자를 함께 공개해요',
    en: 'Both numbers are revealed after $who draws',
    zhHans: '$who 抽完后同时公开两个数字',
    zhHant: '$who 抽完後同時公開兩個數字',
  );

  // --- G4 / G5 뽑기 결과 ------------------------------------------------------
  /// 상태·제목: G4 “내가 선공이에요”.
  static String get drawIAmFirst => GameLocale.select(
    ko: '내가 선공이에요',
    en: 'I\'m first',
    zhHans: '我是先手',
    zhHant: '我是先手',
  );

  /// 상태·제목: G5 “A가 선공이에요”.
  static String drawOtherIsFirst(String who) => GameLocale.select(
    ko: '$who가 선공이에요',
    en: '$who is first',
    zhHans: '$who 是先手',
    zhHant: '$who 是先手',
  );

  /// 그림 줄: G4·G5·G6 “vs”.
  static String get versus =>
      GameLocale.select(ko: 'vs', en: 'vs', zhHans: 'vs', zhHant: 'vs');

  /// 본문: G4 “7 vs 3 · 더 큰 숫자를 뽑았어요”.
  static String drawIWon(int mine, int theirs) => GameLocale.select(
    ko: '$mine vs $theirs · 더 큰 숫자를 뽑았어요',
    en: '$mine vs $theirs · I drew the higher number',
    zhHans: '$mine vs $theirs · 我抽到了较大的数字',
    zhHant: '$mine vs $theirs · 我抽到了較大的數字',
  );

  /// 본문: G5 “3 vs 7 · A가 더 큰 숫자를 뽑았어요”.
  static String drawOtherWon(int mine, int theirs, String who) =>
      GameLocale.select(
        ko: '$mine vs $theirs · $who가 더 큰 숫자를 뽑았어요',
        en: '$mine vs $theirs · $who drew the higher number',
        zhHans: '$mine vs $theirs · $who 抽到了较大的数字',
        zhHant: '$mine vs $theirs · $who 抽到了較大的數字',
      );

  /// 보조: G4 “1라운드는 내가 먼저 내요”.
  static String get drawIPlayFirst => GameLocale.select(
    ko: '1라운드는 내가 먼저 내요',
    en: 'I play first in round 1',
    zhHans: '第 1 回合我先出',
    zhHant: '第 1 回合我先出',
  );

  /// 보조: G5 “1라운드는 A 다음에 내요”.
  static String drawIPlayAfter(String who) => GameLocale.select(
    ko: '1라운드는 $who 다음에 내요',
    en: 'I play after $who in round 1',
    zhHans: '第 1 回合我在 $who 之后出',
    zhHant: '第 1 回合我在 $who 之後出',
  );

  // --- P02 선공 선택 중 --------------------------------------------------------
  /// 상태: “타일을 고르고 제출하세요”.
  static String get firstChoose => GameLocale.select(
    ko: '타일을 고르고 제출하세요',
    en: 'Pick a tile and submit',
    zhHans: '选一张牌并提交',
    zhHant: '選一張牌並提交',
  );

  /// 패널 라벨: “이 타일을 낼까요?”.
  static String get confirmTile => GameLocale.select(
    ko: '이 타일을 낼까요?',
    en: 'Play this tile?',
    zhHans: '要出这张牌吗？',
    zhHant: '要出這張牌嗎？',
  );

  /// 패널 빈 자리(선택 전) 라벨: “타일을 골라 주세요”. 프로토타입 ② 휴대폰 A 0ms 프레임 원문.
  static String get pickTilePrompt => GameLocale.select(
    ko: '타일을 골라 주세요',
    en: 'Pick a tile',
    zhHans: '请选一张牌',
    zhHant: '請選一張牌',
  );

  /// 패널 빈 자리 값: “—”. 프로토타입 ② 원문.
  static String get emptyValue =>
      GameLocale.select(ko: '—', en: '—', zhHans: '—', zhHant: '—');

  // --- P03 후공 미리 선택 ------------------------------------------------------
  /// 패널 빈 자리(미리 선택 전) 라벨: “미리 골라 둘 수 있어요”. 프로토타입 ② 휴대폰 B 원문.
  static String get preselectPrompt => GameLocale.select(
    ko: '미리 골라 둘 수 있어요',
    en: 'You can pick ahead',
    zhHans: '可以先选好',
    zhHant: '可以先選好',
  );

  /// 상태: “상대가 고르는 중 · 미리 골라두세요”.
  static String get preselectStatus => GameLocale.select(
    ko: '상대가 고르는 중 · 미리 골라두세요',
    en: 'Opponent is choosing · Pick ahead',
    zhHans: '对手正在选择 · 先选好吧',
    zhHant: '對手正在選擇 · 先選好吧',
  );

  /// 안내: “선공 색을 본 뒤 바꿔도 돼요”.
  static String get preselectChangeLater => GameLocale.select(
    ko: '선공 색을 본 뒤 바꿔도 돼요',
    en: 'You can change after seeing the first color',
    zhHans: '看到先手颜色后还可以更换',
    zhHant: '看到先手顏色後還可以更換',
  );

  /// 잠긴 버튼: “선공 제출 후 제출 가능”.
  static String get submitLocked => GameLocale.select(
    ko: '선공 제출 후 제출 가능',
    en: 'Available after first player submits',
    zhHans: '先手提交后才能提交',
    zhHant: '先手提交後才能提交',
  );

  /// 안내: “내 차례는 A 차례 이후 시작해요”.
  static String myTurnAfter(String who) => GameLocale.select(
    ko: '내 차례는 $who 차례 이후 시작해요',
    en: 'My turn starts after $who\'s turn',
    zhHans: '我的回合在 $who 之后开始',
    zhHant: '我的回合在 $who 之後開始',
  );

  // --- P04 선공 제출 완료 ------------------------------------------------------
  /// 상태: “상대가 고르는 중이에요”.
  static String get opponentChoosing => GameLocale.select(
    ko: '상대가 고르는 중이에요',
    en: 'Opponent is choosing',
    zhHans: '对手正在选择',
    zhHant: '對手正在選擇',
  );

  // --- P05 후공 제출 가능 ------------------------------------------------------
  /// 상태: “내 차례예요 · 타일을 고르고 제출하세요”.
  static String get secondChoose => GameLocale.select(
    ko: '내 차례예요 · 타일을 고르고 제출하세요',
    en: 'My turn · Pick a tile and submit',
    zhHans: '轮到我 · 选一张牌并提交',
    zhHant: '輪到我 · 選一張牌並提交',
  );

  /// 요약줄: “A가 흑 타일을 냈어요”.
  static String firstPlayed(String who, String color) => GameLocale.select(
    ko: '$who가 $color 타일을 냈어요',
    en: '$who played a $color tile',
    zhHans: '$who 出了$color牌',
    zhHant: '$who 出了$color牌',
  );

  // --- P06 시간 초과 자동 제출 --------------------------------------------------
  /// 상태: “시간이 지나 타일이 자동으로 제출됐어요”.
  static String get autoSubmittedStatus => GameLocale.select(
    ko: '시간이 지나 타일이 자동으로 제출됐어요',
    en: 'Time ran out, so a tile was submitted for me',
    zhHans: '时间到，已自动提交一张牌',
    zhHant: '時間到，已自動提交一張牌',
  );

  /// 배지: “자동 제출”.
  static String get autoSubmittedBadge => GameLocale.select(
    ko: '자동 제출',
    en: 'Auto-submitted',
    zhHans: '自动提交',
    zhHant: '自動提交',
  );

  /// 패널 라벨: “남은 타일 중 무작위로”.
  static String get autoSubmittedLabel => GameLocale.select(
    ko: '남은 타일 중 무작위로',
    en: 'Randomly from remaining tiles',
    zhHans: '从剩余牌中随机',
    zhHant: '從剩餘牌中隨機',
  );

  /// 안내: “이번 라운드에 냈어요”.
  static String get autoSubmittedNote => GameLocale.select(
    ko: '이번 라운드에 냈어요',
    en: 'Played this round',
    zhHans: '本回合已出',
    zhHant: '本回合已出',
  );

  // --- P07 후공 제출 완료 ------------------------------------------------------
  /// 상태: “두 사람 모두 냈어요”.
  static String get bothSubmitted => GameLocale.select(
    ko: '두 사람 모두 냈어요',
    en: 'Both players submitted',
    zhHans: '双方都已出牌',
    zhHant: '雙方都已出牌',
  );

  // --- P08 결과·다음 라운드 전환 -------------------------------------------------
  /// 상태(이긴 경우): “내가 이겼어요! +1”.
  static String get roundIWon => GameLocale.select(
    ko: '내가 이겼어요! +1',
    en: 'I won! +1',
    zhHans: '我赢了！+1',
    zhHant: '我贏了！+1',
  );

  /// 상태(진 경우): “상대가 이겼어요”. 시안에 없어 하준 결정(2026-11-25)으로 정했다.
  static String get roundOpponentWon => GameLocale.select(
    ko: '상대가 이겼어요',
    en: 'Opponent won',
    zhHans: '对手赢了',
    zhHant: '對手贏了',
  );

  /// 상태(동점): “동점이에요! +0”. 태블릿 T08 “+0” 배지와 맞춘 하준 결정(2026-11-25).
  static String get roundTieStatus => GameLocale.select(
    ko: '동점이에요! +0',
    en: 'It\'s a tie! +0',
    zhHans: '平局！+0',
    zhHant: '平局！+0',
  );

  /// 패널 라벨: “곧 다음 라운드가 시작돼요”.
  static String get nextRoundSoon => GameLocale.select(
    ko: '곧 다음 라운드가 시작돼요',
    en: 'Next round starts soon',
    zhHans: '下一回合即将开始',
    zhHant: '下一回合即將開始',
  );

  /// 패널 값: “6라운드”.
  static String nextRound(int round) => GameLocale.select(
    ko: '$round라운드',
    en: 'Round $round',
    zhHans: '第 $round 回合',
    zhHant: '第 $round 回合',
  );

  /// 선공 표식: “선공”.
  static String get firstMark =>
      GameLocale.select(ko: '선공', en: 'First', zhHans: '先手', zhHant: '先手');

  /// 다음 라운드 안내(선공일 때): “내가 먼저 내요”.
  static String get iPlayFirst => GameLocale.select(
    ko: '내가 먼저 내요',
    en: 'I play first',
    zhHans: '我先出',
    zhHant: '我先出',
  );

  /// 후공 표식: “후공”. 선공 표식 자리에 같은 모양으로 쓴다(하준 결정 2026-11-25).
  static String get secondMark =>
      GameLocale.select(ko: '후공', en: 'Second', zhHans: '后手', zhHant: '後手');

  /// 다음 라운드 안내(후공일 때): “상대 다음에 내요”(하준 결정 2026-11-25).
  static String get iPlayAfterOpponent => GameLocale.select(
    ko: '상대 다음에 내요',
    en: 'I play after my opponent',
    zhHans: '我在对手之后出',
    zhHant: '我在對手之後出',
  );

  /// 대시 상자: “태블릿에서 결과를 보여주는 중”.
  static String get tabletShowingResult => GameLocale.select(
    ko: '태블릿에서 결과를 보여주는 중',
    en: 'Showing the result on the tablet',
    zhHans: '平板正在显示结果',
    zhHant: '平板正在顯示結果',
  );

  // --- P09 마지막 타일 --------------------------------------------------------
  /// 상태: “마지막 타일이에요 · 제출 버튼을 눌러 주세요”.
  static String get lastTileStatus => GameLocale.select(
    ko: '마지막 타일이에요 · 제출 버튼을 눌러 주세요',
    en: 'Last tile · Press Submit',
    zhHans: '最后一张牌 · 请按提交',
    zhHant: '最後一張牌 · 請按提交',
  );

  /// 패널 라벨: “마지막 남은 타일”.
  static String get lastTileLabel => GameLocale.select(
    ko: '마지막 남은 타일',
    en: 'Last remaining tile',
    zhHans: '最后一张牌',
    zhHant: '最後一張牌',
  );

  // --- P10 / P11 게임 종료 (결정 10: 진 사람도 승자 표시) ------------------------
  /// 승자 라벨: “WINNER”.
  static String get winnerLabel => GameLocale.select(
    ko: 'WINNER',
    en: 'WINNER',
    zhHans: 'WINNER',
    zhHant: 'WINNER',
  );

  /// 안내: “최종 6 : 2 · 다시하기와 HOME은 태블릿에서 선택해요”.
  static String finalNote(int mine, int theirs) => GameLocale.select(
    ko: '최종 $mine : $theirs · 다시하기와 HOME은 태블릿에서 선택해요',
    en: 'Final $mine : $theirs · Choose Play again or HOME on the tablet',
    zhHans: '最终 $mine : $theirs · 请在平板上选择再来一局或 HOME',
    zhHant: '最終 $mine : $theirs · 請在平板上選擇再來一局或 HOME',
  );

  // --- G6 라운드 결과 확인 안내 ---------------------------------------------------
  /// 상태: “결과 확인 중”.
  static String get resultChecking => GameLocale.select(
    ko: '결과 확인 중',
    en: 'Checking result',
    zhHans: '正在确认结果',
    zhHant: '正在確認結果',
  );

  /// 제목: “태블릿에서 결과를 확인해요”.
  static String get checkResultOnTablet => GameLocale.select(
    ko: '태블릿에서 결과를 확인해요',
    en: 'Check the result on the tablet',
    zhHans: '请在平板上查看结果',
    zhHant: '請在平板上查看結果',
  );

  /// 본문: “이번 라운드 승패와 점수가 태블릿에 표시돼요”.
  static String get resultShownOnTablet => GameLocale.select(
    ko: '이번 라운드 승패와 점수가 태블릿에 표시돼요',
    en: 'This round\'s result and score appear on the tablet',
    zhHans: '本回合胜负和分数显示在平板上',
    zhHant: '本回合勝負和分數顯示在平板上',
  );

  /// 보조: “이긴 사람이 다음 라운드 선공이에요”.
  static String get winnerGoesFirst => GameLocale.select(
    ko: '이긴 사람이 다음 라운드 선공이에요',
    en: 'The winner goes first next round',
    zhHans: '胜者在下一回合先手',
    zhHant: '勝者在下一回合先手',
  );

  // --- G7 조기 종료 안내 ------------------------------------------------------
  /// 상태: “게임 종료”.
  static String get gameOver => GameLocale.select(
    ko: '게임 종료',
    en: 'Game over',
    zhHans: '游戏结束',
    zhHant: '遊戲結束',
  );

  /// 제목: “게임이 일찍 끝났어요”.
  static String get earlyEndTitle => GameLocale.select(
    ko: '게임이 일찍 끝났어요',
    en: 'The game ended early',
    zhHans: '游戏提前结束了',
    zhHant: '遊戲提前結束了',
  );

  /// 본문: “남은 라운드를 모두 이겨도 결과가 바뀌지 않아요”.
  static String get earlyEndReason => GameLocale.select(
    ko: '남은 라운드를 모두 이겨도 결과가 바뀌지 않아요',
    en: 'Winning every remaining round can\'t change the result',
    zhHans: '即使赢下剩余所有回合，结果也不会改变',
    zhHant: '即使贏下剩餘所有回合，結果也不會改變',
  );

  /// 보조: “최종 결과는 태블릿과 이 화면에 곧 표시돼요”.
  static String get earlyEndSoon => GameLocale.select(
    ko: '최종 결과는 태블릿과 이 화면에 곧 표시돼요',
    en: 'The final result will appear on the tablet and here soon',
    zhHans: '最终结果即将显示在平板和此画面上',
    zhHant: '最終結果即將顯示在平板和此畫面上',
  );

  // --- G8 최종 동점 뽑기 안내 ---------------------------------------------------
  /// 상태: “내 차례”.
  static String get myTurn => GameLocale.select(
    ko: '내 차례',
    en: 'My turn',
    zhHans: '我的回合',
    zhHant: '我的回合',
  );

  /// 본문: “최종 점수가 5 : 5 동점이에요”.
  static String finalTie(int mine, int theirs) => GameLocale.select(
    ko: '최종 점수가 $mine : $theirs 동점이에요',
    en: 'Final score is tied at $mine : $theirs',
    zhHans: '最终比分 $mine : $theirs 平局',
    zhHant: '最終比分 $mine : $theirs 平局',
  );

  /// 보조: “더 큰 숫자를 뽑은 사람이 최종 승리해요”.
  static String get drawRuleFinal => GameLocale.select(
    ko: '더 큰 숫자를 뽑은 사람이 최종 승리해요',
    en: 'The higher number wins the game',
    zhHans: '抽到较大数字的人最终获胜',
    zhHant: '抽到較大數字的人最終獲勝',
  );

  // --- 규칙(룰북) -----------------------------------------------------------
  /// 규칙 창 제목. 게임 이름을 쓴다.
  static String get rulebookTitle => ElevenCopy.title;

  /// 규칙 본문(game_kit 룰북 형식: `# 항목` + 본문). 계약 2절 규칙 요약을 옮겼고 2026-11-25 하준이
  /// 이대로 확정했다(뽑는 순서·조기 종료 경계·차례별 시간은 추가하지 않기로 함). 숫자 판정 예시는 넣지 않는다.
  static String get rulebookMarkdown => GameLocale.select(
    ko: '''
# 게임 방법
두 사람이 각자 숫자 타일 11개(0–9, 11)로 11라운드를 겨뤄요. 10은 없어요.
라운드마다 선공이 먼저 타일 하나를 내고, 후공이 이어서 하나를 내요. 낸 타일은 다시 쓸 수 없어요.
제한 시간은 각각 60초예요. 시간이 지나면 남은 타일 중 하나가 무작위로 제출돼요.

# 카드 구성
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
''',
    en: '''
# How to play
Each player has 11 number tiles (0–9 and 11) and plays 11 rounds. There is no 10.
Each round the first player plays one tile, then the second player plays one. Played tiles can't be used again.
Each player has 60 seconds. When time runs out, one remaining tile is submitted at random.

# Card set
Black tiles are 0, 2, 4, 6, 8, 11 and white tiles are 1, 3, 5, 7, 9.
Only the color of your opponent's tile is shown. The number stays hidden to the end.

# Who wins a round
Equal numbers are a tie. Nobody scores.
If the two numbers add up to 20, whoever played 11 wins.
If the sum is under 10 the higher number wins; if it is 10 or more the lower number wins.
The winner scores 1 point and goes first next round. After a tie, the first player stays the same.

# First-player draw
For round 1, each player picks one of 9 face-down cards (1–9) on the tablet.
The higher number goes first in round 1.

# End of game
The game ends as soon as the score gap is larger than the number of rounds left.
If the score is tied after round 11, the same card draw decides the winner.
''',
    zhHans: '''
# 玩法
两人各有 11 张数字牌（0–9 和 11），进行 11 个回合。没有 10。
每回合先手先出一张牌，后手接着出一张。出过的牌不能再用。
每人各有 60 秒。时间到时，会从剩余牌中随机提交一张。

# 卡牌构成
黑牌是 0、2、4、6、8、11，白牌是 1、3、5、7、9。
只公开对手出牌的颜色，数字到最后都不公开。

# 胜负判定
两个数字相同为平局，双方都不得分。
两个数字之和为 20 时，出 11 的人获胜。
和小于 10 时大数字获胜；和为 10 以上时小数字获胜。
胜者得 1 分，并在下一回合先手。平局时先手不变。

# 先手抽签
第 1 回合的先手由两人各在平板上从 9 张背面卡牌（1–9）中选一张决定。
抽到较大数字的人在第 1 回合先手。

# 游戏结束
分差大于剩余回合数时立即结束。
第 11 回合结束后若比分相同，用同样的抽卡方式决定最终胜者。
''',
    zhHant: '''
# 玩法
兩人各有 11 張數字牌（0–9 和 11），進行 11 個回合。沒有 10。
每回合先手先出一張牌，後手接著出一張。出過的牌不能再用。
每人各有 60 秒。時間到時，會從剩餘牌中隨機提交一張。

# 卡牌構成
黑牌是 0、2、4、6、8、11，白牌是 1、3、5、7、9。
只公開對手出牌的顏色，數字到最後都不公開。

# 勝負判定
兩個數字相同為平局，雙方都不得分。
兩個數字之和為 20 時，出 11 的人獲勝。
和小於 10 時大數字獲勝；和為 10 以上時小數字獲勝。
勝者得 1 分，並在下一回合先手。平局時先手不變。

# 先手抽籤
第 1 回合的先手由兩人各在平板上從 9 張背面卡牌（1–9）中選一張決定。
抽到較大數字的人在第 1 回合先手。

# 遊戲結束
分差大於剩餘回合數時立即結束。
第 11 回合結束後若比分相同，用同樣的抽卡方式決定最終勝者。
''',
  );

  /// 색 이름: “흑”, “백”(기존 [ElevenCopy.black]/[ElevenCopy.white]와 같은 값).
  static String get black =>
      GameLocale.select(ko: '흑', en: 'Black', zhHans: '黑', zhHant: '黑');
  static String get white =>
      GameLocale.select(ko: '백', en: 'White', zhHans: '白', zhHant: '白');
}
