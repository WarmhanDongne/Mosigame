// [seat_geometry.dart] 는 파이널콜 태블릿에서 좌석의 위치와 회전 각도를 계산하는 파일이다.
//
// - [Package] : 파이널콜
// - [TabletScreen] : 태블릿 게임의 세부 진행 화면을 구성함
//
// 즉, 전체 참가자가 게임 단계와 결과를 함께 확인하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';

// ============================================================

Alignment finalCallSeatAlignment(int index, int count) {
  if (count == 2) {
    return index == 0 ? Alignment.bottomCenter : Alignment.topCenter;
  }
  if (count == 3) {
    return const [
      Alignment.bottomCenter,
      Alignment.centerLeft,
      Alignment.centerRight,
    ][index];
  }
  return const [
    Alignment.bottomCenter,
    Alignment.centerRight,
    Alignment.topCenter,
    Alignment.centerLeft,
  ][index];
}

double finalCallSeatRotation(int index, int count) {
  final alignment = finalCallSeatAlignment(index, count);
  if (alignment == Alignment.topCenter) return math.pi;
  if (alignment == Alignment.centerLeft) return math.pi / 2;
  if (alignment == Alignment.centerRight) return -math.pi / 2;
  return 0;
}

/// 좌석이 가운데 테이블을 바라보도록 돌리는 각도입니다.
///
/// 자리에서 테이블 중심 쪽이 프로필의 아래가 되게 돌려, 그 자리에 앉은 사람이
/// 똑바로 읽습니다. 위 180°, 오른쪽 -90°, 왼쪽 90°, 아래 0°이고, 모서리 자리는
/// 그 사이 대각선 각도로 테이블을 향합니다.
double finalCallSeatRotationForCenter({
  required Offset center,
  required Size boardSize,
}) {
  final outward = center - boardSize.center(Offset.zero);
  if (outward.distance < 1) return 0;
  final angle = math.atan2(-outward.dx, outward.dy);
  // 정확히 위쪽 자리는 -180°가 나올 수 있어 같은 방향인 180°로 맞춥니다.
  return angle <= -math.pi + 1e-9 ? math.pi : angle;
}

// ---------------------------------------------------------------------------
// Party Pop 테이블 배치
// ---------------------------------------------------------------------------
/// 시안(1180×820)의 짧은 변 820px을 1로 둔 태블릿 배율입니다.
double finalCallTabletScale(Size boardSize) => boardSize.shortestSide / 820;

/// 가운데 둥근 테이블의 반지름입니다. 좌석 이름표 안쪽 가장자리보다 작습니다.
double finalCallTableRadius(Size boardSize) => boardSize.shortestSide * 0.32;

/// 테이블 가운데 덱·공개 카드 한 장의 폭입니다(시안 92).
double finalCallCenterCardWidth(Size boardSize) =>
    (92 * finalCallTabletScale(boardSize)).clamp(64.0, 120.0).toDouble();

/// 덱과 공개 카드 사이 간격입니다(시안 28).
double finalCallCenterCardGap(Size boardSize) =>
    28 * finalCallTabletScale(boardSize);

/// 공개 카드의 중심입니다. 버린 카드가 날아가 앉는 자리입니다.
Offset finalCallPublicCardCenter(Size boardSize) =>
    boardSize.center(Offset.zero) +
    Offset(
      (finalCallCenterCardWidth(boardSize) +
              finalCallCenterCardGap(boardSize)) /
          2,
      0,
    );

// ---------------------------------------------------------------------------
// 좌석 자리(A안)
// ---------------------------------------------------------------------------
/// 파이널콜 좌석을 모서리가 아닌 테이블의 네 면에 놓습니다.
///
/// 6인은 위·아래 면에 두 자리씩, 좌·우 면에 한 자리씩 놓습니다. 서로 마주
/// 보는 좌석은 0↔3, 1↔4, 2↔5라 서버의 팀 배치와도 일치합니다.
List<Offset> finalCallNormalizedSeatCenters(int playerCount) {
  return switch (playerCount) {
    4 => const [
      Offset(0.5, 0.84),
      Offset(0.84, 0.5),
      Offset(0.5, 0.16),
      Offset(0.16, 0.5),
    ],
    6 => const [
      Offset(0.35, 0.84),
      Offset(0.65, 0.84),
      Offset(0.84, 0.5),
      Offset(0.65, 0.16),
      Offset(0.35, 0.16),
      Offset(0.16, 0.5),
    ],
    _ => normalizedPlayerCenters(playerCount),
  };
}

/// 자리 배치 화면과 실제 게임 화면이 공유하는 파이널콜 좌석 좌표입니다.
List<Offset> finalCallSeatCenters({
  required int playerCount,
  required Size boardSize,
}) {
  if (playerCount <= 0) return const [];
  return finalCallNormalizedSeatCenters(playerCount)
      .map(
        (center) => playerCenterFromNormalized(
          normalizedCenter: center,
          boardSize: boardSize,
        ),
      )
      .toList(growable: false);
}

/// 공용 자리 배치 카드의 좌측 상단 좌표를 실제 게임 좌석과 맞춥니다.
List<Offset> finalCallSeatingCardTopLeftPositions({
  required int playerCount,
  required Size boardSize,
  required Size cardSize,
}) {
  return finalCallNormalizedSeatCenters(playerCount)
      .map(
        (normalized) => playerCenterFromNormalized(
          normalizedCenter: normalized,
          boardSize: boardSize,
        ),
      )
      .map(
        (center) => Offset(
          (center.dx - cardSize.width / 2) / boardSize.width,
          (center.dy - cardSize.height / 2) / boardSize.height,
        ),
      )
      .toList(growable: false);
}
