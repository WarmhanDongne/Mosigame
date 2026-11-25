import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

abstract final class RouletteColors {
  static const red = Color(0xFFB3201F);
  static const deepRed = Color(0xFF7E1414);
  static const ink = Color(0xFF121110);
  static const cream = Color(0xFFECE3D0);
  static const paper = Color(0xFFF8F1E5);
  static const muted = Color(0xFF7A7164);
  static const gold = Color(0xFFD6B36A);

  /// B안 시안의 보조 회색들입니다.
  static const sub = Color(0xFFA39B8E);
  static const dim = Color(0xFF8A8378);
  static const grey = Color(0xFF5C564D);
  static const line = Color(0xFF3A3631);
  static const track = Color(0xFF2A2724);
  static const panel = Color(0xFF1E1C1A);
  static const dash = Color(0xFF5A554D);
  static const paperLight = Color(0xFFF7F4EC);
  static const shadow = Color(0xFF05031F);
}

/// B안 시안 글꼴입니다. 시안의 Black Han Sans·Oswald 대신 앱에 들어 있는
/// IBM Plex Sans KR(굵게)·Space Grotesk를 씁니다.
abstract final class RouletteType {
  static TextStyle display(double size, Color color, {double height = 1.1}) =>
      MosiFonts.sans(
        size: size,
        weight: FontWeight.w700,
        color: color,
        height: height,
      );

  static TextStyle body(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w500,
    double height = 1.4,
  }) =>
      MosiFonts.sans(size: size, weight: weight, color: color, height: height);

  static TextStyle number(double size, Color color, {double spacing = 0}) =>
      MosiFonts.grotesk(
        size: size,
        weight: FontWeight.w700,
        color: color,
        letterSpacing: spacing,
        height: 1,
      );
}

abstract final class RouletteCopy {
  static String get title => GameLocale.select(
    ko: '러시안 룰렛',
    en: 'Russian Roulette',
    zhHans: '俄罗斯轮盘',
    zhHant: '俄羅斯輪盤',
  );

  static String get choose => GameLocale.select(
    ko: '행동을 선택하세요',
    en: 'Choose your action',
    zhHans: '选择你的行动',
    zhHant: '選擇你的行動',
  );

  static String get waiting => GameLocale.select(
    ko: '다른 플레이어를 기다리는 중',
    en: 'Waiting for the others',
    zhHans: '正在等待其他玩家',
    zhHant: '正在等待其他玩家',
  );

  static String action(RouletteLabel label) => switch (label) {
    RouletteLabel.spin => GameLocale.select(
      ko: '총 돌리기',
      en: 'Spin the gun',
      zhHans: '转动手枪',
      zhHant: '轉動手槍',
    ),
    RouletteLabel.shield => GameLocale.select(
      ko: '방패 사용',
      en: 'Use shield',
      zhHans: '使用护盾',
      zhHant: '使用護盾',
    ),
    RouletteLabel.none => GameLocale.select(
      ko: '아무것도 안 하기',
      en: 'Do nothing',
      zhHans: '什么都不做',
      zhHant: '什麼都不做',
    ),
  };

  static String get rulesMarkdown => GameLocale.select(
    ko: '''# 게임 목표
마지막까지 살아남으면 승리합니다. 2~8명이 함께 하며 한 판은 약 5분입니다.

# 한 턴의 순서
모든 생존자는 30초 안에 **총 돌리기**, **방패 사용**, **아무것도 안 하기** 중 하나를 비공개로 고릅니다. 모두 고르면 즉시 공개됩니다.

# 총과 피격
첫 대상은 무작위로 고릅니다. 총은 `총 돌리기`를 고른 사람 수만큼 시계 방향으로 이동하며, 탈락한 자리는 건너뜁니다. 멈춘 대상이 총에 맞으면 탈락합니다.

# 방패와 시간 초과
방패를 고른 대상은 총알을 막고 살아남습니다. 방패는 연속 두 턴 사용할 수 없습니다. 30초가 넘으면 `아무것도 안 하기`가 자동 선택됩니다.

# 종료와 다시하기
마지막 생존자가 승리합니다. 다시하기를 누르면 현재 자리를 유지하고 첫 대상부터 다시 무작위로 결정합니다.''',
    en: '''# Objective
Be the last survivor. Russian Roulette is for 2–8 players and takes about 5 minutes.

# Each turn
Every living player secretly chooses **Spin the gun**, **Use shield**, or **Do nothing** within 30 seconds. Choices are revealed immediately when everyone has submitted.

# Gun and shot
The first target is random. The gun moves clockwise once for every Spin choice, skipping eliminated seats. The player it stops on is shot and eliminated unless protected.

# Shield and timeout
A shield blocks the shot, but it cannot be used on consecutive turns. A timeout automatically selects Do nothing.

# End and replay
The last survivor wins. Replay keeps every seat and resets the game with a new random first target.''',
    zhHans: '''# 游戏目标
成为最后的幸存者。支持2–8人，每局约5分钟。

# 每回合
所有幸存者在30秒内秘密选择**转动手枪**、**使用护盾**或**什么都不做**。全员选完后立即公开。

# 手枪与中弹
首个目标随机决定。每个“转动手枪”会让手枪顺时针移动一位，跳过已淘汰座位。停下的目标中弹并淘汰。

# 护盾与超时
护盾可挡住子弹，但不能连续两回合使用。超时自动选择“什么都不做”。

# 结束与重玩
最后幸存者获胜。重玩时保留座位，并重新随机选择首个目标。''',
    zhHant: '''# 遊戲目標
成為最後的幸存者。支援2–8人，每局約5分鐘。

# 每回合
所有幸存者在30秒內秘密選擇**轉動手槍**、**使用護盾**或**什麼都不做**。全員選完後立即公開。

# 手槍與中彈
首個目標隨機決定。每個「轉動手槍」會讓手槍順時針移動一位，跳過已淘汰座位。停下的目標中彈並淘汰。

# 護盾與逾時
護盾可擋住子彈，但不能連續兩回合使用。逾時自動選擇「什麼都不做」。

# 結束與重玩
最後幸存者獲勝。重玩時保留座位，並重新隨機選擇首個目標。''',
  );
}

enum RouletteLabel { spin, shield, none }
