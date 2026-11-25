// [player_slot_positions.dart] 는 좌석 번호를 화면 좌표로 변환하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [PlayerLayout] : 태블릿의 플레이어 자리 배치와 편집 규칙을 관리함
//
// 즉, 인원과 기기 크기에 맞춰 자리를 안정적으로 배치하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';

// ============================================================

typedef SeatingCardPositionsBuilder =
    List<Offset> Function({
      required int playerCount,
      required Size boardSize,
      required Size cardSize,
    });

//사용 방법
//normalizedPlayerCenters(playerCount)

//용도 숫자에 따라서 사용자 위치를 계산해주는 함수

const double defaultPlayerRingRadiusX = 0.34;
const double defaultPlayerRingRadiusY = 0.34;
const double defaultPlayerOrbitRadiusFactor = 0.395;

double _startAngleForPlayerCount(int playerCount) {
  return switch (playerCount) {
    2 => math.pi,
    4 => -math.pi * 0.75,
    _ => -math.pi / 2,
  };
}

/// 중앙 테이블을 기준으로 동일한 간격으로 배치된 플레이어 중심 정규화 좌표입니다.
///
/// 카드 분배, 잔여 카드 표시, 자리 설정 화면이 모두 이 좌표를 공유합니다.
List<Offset> normalizedPlayerCenters(int playerCount) {
  assert(playerCount > 0);

  final startAngle = _startAngleForPlayerCount(playerCount);

  return List<Offset>.generate(playerCount, (index) {
    final angle = startAngle + (math.pi * 2 * index / playerCount);
    return Offset(
      0.5 + math.cos(angle) * defaultPlayerRingRadiusX,
      0.5 + math.sin(angle) * defaultPlayerRingRadiusY,
    );
  }, growable: false);
}

/// 테이블의 네 면을 따라 고르게 놓인 좌석 중심입니다.
///
/// 모서리 배치의 원형 순서와 간격을 그대로 유지한 채 모든 좌석을 같은 방향으로
/// 좌석 간격의 절반만큼 회전하고, 각 중심을 가장 가까운 면까지 밀어냅니다.
/// 그래서 모서리↔면 전환 중 플레이어끼리 교차하거나 순서가 뒤집히지 않습니다.
List<Offset> normalizedSideSeatCenters(int playerCount) {
  assert(playerCount > 0);
  final startAngle = _startAngleForPlayerCount(playerCount);
  final sharedRotation = math.pi / playerCount;
  return List<Offset>.generate(playerCount, (index) {
    final angle =
        startAngle + sharedRotation + math.pi * 2 * index / playerCount;
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    final scale = 0.34 / math.max(dx.abs(), dy.abs());
    return Offset(0.5 + dx * scale, 0.5 + dy * scale);
  }, growable: false);
}

/// 자리 배치 선택에 맞는 정규화 좌석 중심입니다.
List<Offset> normalizedSeatCenters(int playerCount, {SeatLayoutMode? mode}) =>
    mode == SeatLayoutMode.sides
    ? normalizedSideSeatCenters(playerCount)
    : normalizedPlayerCenters(playerCount);

/// 화면의 짧은 변을 기준으로 실제 원형 궤도에 배치된 플레이어 중심 좌표입니다.
List<Offset> playerCentersForBoard({
  required int playerCount,
  required Size boardSize,
  double radiusFactor = defaultPlayerOrbitRadiusFactor,
  SeatLayoutMode? mode,
}) {
  assert(playerCount > 0);
  assert(radiusFactor > 0);

  if (mode == SeatLayoutMode.sides) {
    return normalizedSideSeatCenters(playerCount)
        .map(
          (normalized) => playerCenterFromNormalized(
            normalizedCenter: normalized,
            boardSize: boardSize,
          ),
        )
        .toList(growable: false);
  }

  final center = Offset(boardSize.width / 2, boardSize.height / 2);
  final radius = boardSize.shortestSide * radiusFactor;
  final startAngle = _startAngleForPlayerCount(playerCount);
  return List<Offset>.generate(playerCount, (index) {
    final angle = startAngle + (math.pi * 2 * index / playerCount);
    return center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }, growable: false);
}

/// 자리 배치 화면 카드의 좌측 상단 정규화 좌표입니다.
///
/// 카드는 가로가 긴 직사각형이라 가로·세로 크기를 따로 받습니다. 궤도는
/// [normalizedPlayerCenters]와 같은 **타원**입니다. 원형 궤도(=짧은 변 기준)로
/// 두면 가로가 긴 태블릿에서 좌우가 비고 위아래는 좁아져, 12인처럼 카드가
/// 많을 때 서로 겹칩니다.
List<Offset> seatingCardTopLeftPositions({
  required int playerCount,
  required Size boardSize,
  required Size cardSize,
}) {
  return normalizedPlayerCenters(playerCount)
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

/// 면 배치용 자리 카드의 좌측 상단 정규화 좌표입니다.
List<Offset> sideSeatingCardTopLeftPositions({
  required int playerCount,
  required Size boardSize,
  required Size cardSize,
}) {
  return normalizedSideSeatCenters(playerCount)
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

Offset playerCenterFromNormalized({
  required Offset normalizedCenter,
  required Size boardSize,
}) {
  return Offset(
    normalizedCenter.dx * boardSize.width,
    normalizedCenter.dy * boardSize.height,
  );
}
