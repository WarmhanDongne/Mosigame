// 화면 문구 키(ElevenScreenCopy)가 docs/design/eleven/screens.md 4절 원문과 같은지,
// 그리고 화면별 문구가 빠짐없이 키로 있는지 확인한다(S5-0b 5).
//
// 각 화면의 표 “문구” 열을 읽어, 값(숫자·점수·시간·좌석 글자 A/B·“?”)과 측정용 설명을
// 뺀 문구 집합을 만든다. 아래 [_screens]는 그 화면을 시안의 예시 값(A/B, 5R, 흑 6 등)으로
// 키에서 만든 문구다. 두 집합이 같아야 한다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_eleven/game_copy.dart';

typedef C = ElevenScreenCopy;

/// 화면 ID → 키로 만든 문구(시안 예시 값). 전적판 행·뽑기 카드·메뉴·선택 배지는
/// 마지막 테스트에서 따로 본다.
final Map<String, Set<String>> _screens = {
  'T01': {C.pillMyTurn, C.pillOpponentTurn, C.toastPickTile},
  'T02': {C.pillPicked, C.slotPickedBack('A'), C.pillMyTurn, C.toastPickTile},
  'T03': {
    C.pillMyTurn,
    C.pillOpponentTurn,
    C.toastRevealNumbers,
    C.toastFirstPlayer('A'),
  },
  'T04': {
    C.pillMyTurn,
    C.timeBarSemantics(80),
    C.scoreLabel,
    C.pillOpponentTurn,
    C.toastRound(1),
  },
  'T05': {
    C.pillSubmitted,
    C.slotSubmitted('A', C.black),
    C.scoreLabel,
    C.pillMyTurn,
    C.timeBarSemantics(70),
    C.toastSubmitted,
  },
  'T06': {
    C.pillAutoSubmitted,
    C.slotSubmitted('A', C.black),
    C.scoreLabel,
    C.slotAutoSubmitted('B', C.black),
    C.toastAutoSubmitted,
  },
  'T07': {
    C.pillWin,
    C.slotSubmitted('A', C.black),
    C.scoreLabel,
    C.scoreDelta(1),
    C.pillLose,
    C.slotSubmitted('B', C.white),
    C.toastWinner('A'),
  },
  'T08': {
    C.pillTie,
    C.slotSubmitted('A', C.black),
    C.scoreLabel,
    C.scoreDelta(0),
    C.slotSubmitted('B', C.black),
    C.toastTie,
  },
  'T09': {
    C.pillMyTurn,
    C.scoreLabel,
    C.pillOpponentTurn,
    C.toastRoundIntro(6, 'A'),
  },
  'T10': {
    C.pillGameOver,
    C.scoreLabel,
    C.crown,
    C.toastEarlyEnd,
    C.toastGameWinner('A'),
  },
  'T11': {
    C.pillOpponentTurn,
    C.scoreLabel,
    C.pillMyTurn,
    C.toastTie,
    C.toastFinalBout,
    C.toastPickTile,
  },
  'T12': {
    C.pillLose,
    C.scoreLabel,
    C.pillWin,
    C.toastRevealTiles,
    C.toastWinner('B'),
  },
  'T13': {
    C.finalScoreLabel,
    C.pillWin,
    C.crown,
    C.pillLose,
    C.restart,
    C.home,
    C.resultStays,
  },
  'T13-B': {
    C.finalWinnerLabel,
    C.pillLose,
    C.pillWin,
    C.crown,
    C.restart,
    C.home,
    C.resultStays,
  },
  'P01': {
    C.me,
    C.tagFirstDraw,
    C.drawMyTurnStatus,
    C.drawOnTablet,
    C.drawPickOne,
    C.drawRuleFirst,
  },
  'P02': {
    C.me,
    C.tagFirst(5),
    C.firstChoose,
    C.confirmTile,
    C.tileName(C.black, 6),
    C.submit,
    C.submitIsFinal,
  },
  'P03': {
    C.me,
    C.tagSecond(5),
    C.preselectStatus,
    C.selectedTile,
    C.tileName(C.white, 7),
    C.preselectChangeLater,
    C.submitLocked,
    C.myTurnAfter('A'),
  },
  'P04': {
    C.me,
    C.tagSecondTurn(5),
    C.opponentChoosing,
    C.submittedBadge,
    C.submittedTileLabel,
    C.tileName(C.black, 6),
    C.tabletShowsColorOnly(C.black),
    C.resultOnTablet,
  },
  'P05': {
    C.me,
    C.tagSecond(5),
    C.secondChoose,
    C.firstPlayed('A', C.black),
    C.selectedTile,
    C.tileName(C.white, 7),
    C.submit,
  },
  'P06': {
    C.me,
    C.tagTimeout(5),
    C.autoSubmittedStatus,
    C.autoSubmittedBadge,
    C.autoSubmittedLabel,
    C.tileName(C.black, 0),
    C.autoSubmittedNote,
    C.resultOnTablet,
  },
  'P07': {
    C.me,
    C.tagWaitingResult(5),
    C.bothSubmitted,
    C.submittedBadge,
    C.submittedTileLabel,
    C.tileName(C.white, 7),
    C.tabletShowsColorOnly(C.white),
    C.resultOnTablet,
  },
  'P08': {
    C.me,
    C.tagRoundResult(5),
    C.roundIWon,
    C.nextRoundSoon,
    C.nextRound(6),
    C.firstMark,
    C.iPlayFirst,
    C.tabletShowingResult,
  },
  'P09': {
    C.me,
    C.tagFirst(11),
    C.lastTileStatus,
    C.lastTileLabel,
    C.tileName(C.black, 11),
    C.submit,
    C.submitIsFinal,
  },
  'P10': {C.me, C.crown, C.winnerLabel, C.finalNote(6, 2)},
  'P11': {C.me, C.crown, C.winnerLabel, C.finalNote(2, 6)},
  'G1': {
    C.me,
    C.tagFirstDraw,
    C.drawMyTurnStatus,
    C.drawOnTablet,
    C.drawPickOne,
    C.drawRuleFirst,
  },
  'G2': {
    C.me,
    C.tagFirstDraw,
    C.drawOtherFirst('A'),
    C.drawAfterOther('A'),
    C.drawRuleFirst,
  },
  'G3': {
    C.me,
    C.tagFirstDraw,
    C.drawPickedWaiting('B'),
    C.drawPicked,
    C.drawRevealTogether('B'),
    C.resultOnTablet,
  },
  'G4': {
    C.me,
    C.tagFirstDraw,
    C.drawIAmFirst,
    C.versus,
    C.drawIWon(7, 3),
    C.drawIPlayFirst,
  },
  'G5': {
    C.me,
    C.tagFirstDraw,
    C.drawOtherIsFirst('A'),
    C.versus,
    C.drawOtherWon(3, 7, 'A'),
    C.drawIPlayAfter('A'),
  },
  'G6': {
    C.me,
    C.tagRoundResult(5),
    C.resultChecking,
    C.checkResultOnTablet,
    C.versus,
    C.resultShownOnTablet,
    C.winnerGoesFirst,
  },
  'G7': {
    C.me,
    C.tagEarlyEnd,
    C.gameOver,
    C.earlyEndTitle,
    C.earlyEndReason,
    C.earlyEndSoon,
  },
  'G8': {
    C.me,
    C.tagTieDraw,
    C.myTurn,
    C.drawOnTablet,
    C.finalTie(5, 5),
    C.drawRuleFinal,
  },
};

/// 문구가 아니라 값인 칸: 숫자, “x : y”, “0:42”, 좌석 글자, “?”.
final _valueOnly = RegExp(r'^(\d+|\d+ : \d+|\d:\d\d|[AB]|\?)$');

/// 측정용 설명이라 화면 문구가 아닌 칸입니다(screens.md가 붙인 설명).
const _descriptions = {'뒤집힌 타일'};

/// screens.md 4절에서 화면 ID별 “문구” 열을 읽습니다(전적 행·뽑기 카드·메뉴는 아래에서 따로).
Map<String, Set<String>> _readScreens() {
  final file = File('../../docs/design/eleven/screens.md');
  final result = <String, Set<String>>{};
  String? current;
  for (final line in file.readAsLinesSync()) {
    final heading = RegExp(r'^### (\S+) ').firstMatch(line);
    if (heading != null) {
      current = heading.group(1);
      if (current != null && _screens.containsKey(current)) {
        result[current] = {};
      } else {
        current = null;
      }
      continue;
    }
    if (current == null || !line.startsWith('| ')) continue;
    final cols = line.substring(1).split('|').map((c) => c.trim()).toList();
    if (cols.length < 5 || cols.first == '부품 / 요소') continue;
    if (cols.first.startsWith('---')) continue;
    final name = cols[0];
    if (const [
      '배경 stage',
      '전적 행',
      '뽑기 카드',
      '메뉴',
      '중앙 카드',
      '전적 열 머리',
      '토스트 영역',
      '손패 타일',
      '타일(인라인 크기)',
      '아이콘 버튼',
    ].any(name.startsWith)) {
      continue;
    }
    var text = cols[4];
    if (text.isEmpty) continue;
    // 점수 칸 “점수 3 +1” = 라벨 “점수” + 값 + 배지.
    if (name.contains('점수 score')) {
      final parts = text.split(' ');
      result[current]!.add(parts.first);
      if (parts.length > 2) result[current]!.add(parts[2]);
      continue;
    }
    if (name.contains('슬롯 카드') && _valueOnly.hasMatch(text)) continue;
    if (_valueOnly.hasMatch(text) || _descriptions.contains(text)) continue;
    // 원문 `<br>`은 표에서 공백으로 측정됐다(T09·T10 토스트).
    text = switch ((current, text)) {
      ('T09', '6라운드 A 선공') => '6라운드\nA 선공',
      ('T10', '승자 A') => '승자\nA',
      _ => text,
    };
    result[current]!.add(text);
  }
  return result;
}

void main() {
  test('every screen in screens.md is covered', () {
    final fromDoc = _readScreens();
    expect(fromDoc.keys.toSet(), _screens.keys.toSet());
  });

  for (final id in _screens.keys) {
    test('$id copy keys match screens.md exactly', () {
      final fromDoc = _readScreens()[id]!;
      expect(_screens[id], fromDoc);
    });
  }

  test('history board, draw cards and menu (T01–T09) match the originals', () {
    final doc = File('../../docs/design/eleven/screens.md').readAsStringSync();
    for (final text in [
      C.historyColumnRound,
      C.historyRound(1),
      C.historyRound(11),
      C.historyWinLeft,
      C.historyWinRight,
      C.historyTie,
      C.historyTieMark,
      C.historyRowWin(1, 'A', 'A'),
      C.historyRowWin(2, 'B', 'A'),
      C.historyRowTie(3, 'B'),
      C.historyRowCurrent(5),
      C.historyRowUpcoming(6),
      C.drawCardBack,
      C.drawCardPicked('A'),
      C.drawCardRevealed('A', 7),
      C.drawCardRevealed('B', 3),
      C.menuRules,
      C.menuSettings,
      C.rules,
      C.firstBadge,
      // 손패 선택 배지 `.badge`“선택”(screens.md 2-2, 표에서는 변형 열에 “+선택 배지”).
      C.selectedBadge,
    ]) {
      expect(doc, contains(text), reason: text);
    }
  });
}
