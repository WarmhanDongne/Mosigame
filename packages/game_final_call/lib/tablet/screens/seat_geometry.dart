// [seat_geometry.dart] 는 파이널콜 태블릿에서 좌석의 위치와 회전 각도를 계산하는 파일이다.
//
// - [Package] : 파이널콜
// - [TabletScreen] : 태블릿 게임의 세부 진행 화면을 구성함
//
// 즉, 전체 참가자가 게임 단계와 결과를 함께 확인하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';

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

/// 좌석이 붙은 화면 변을 향하도록 돌리는 각도입니다.
///
/// 좌석은 화면 가장자리에 붙으므로([finalCallSeatCenters]) 가장 가까운 변의
/// 사람이 똑바로 읽도록 위 180°, 오른쪽 -90°, 왼쪽 90°, 아래 0°로 맞춥니다.
double finalCallSeatRotationForCenter({
  required Offset center,
  required Size boardSize,
}) {
  final distances = [
    (center.dy, math.pi), // 위
    (boardSize.width - center.dx, -math.pi / 2), // 오른쪽
    (boardSize.height - center.dy, 0.0), // 아래
    (center.dx, math.pi / 2), // 왼쪽
  ];
  distances.sort((a, b) => a.$1.compareTo(b.$1));
  return distances.first.$2;
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
/// 프로필이 화면 네 변의 가운데·끝에 붙도록 좌석 중심을 정합니다.
///
/// 원형 궤도 대신 화면 가장자리에 붙여, 태블릿을 둘러앉은 사람 바로 앞에
/// 자기 프로필이 오게 합니다. 좌석 번호는 위쪽부터 시계 방향입니다.
List<Offset> finalCallSeatCenters({
  required int playerCount,
  required Size boardSize,
}) {
  final w = boardSize.width;
  final h = boardSize.height;
  final inset = boardSize.shortestSide * 0.115;
  final top = Offset(w / 2, inset);
  final right = Offset(w - inset, h / 2);
  final bottom = Offset(w / 2, h - inset);
  final left = Offset(inset, h / 2);
  Offset topAt(double x) => Offset(w * x, inset);
  Offset bottomAt(double x) => Offset(w * x, h - inset);
  final seats = switch (playerCount) {
    <= 1 => [bottom],
    2 => [top, bottom],
    3 => [top, right, left],
    4 => [top, right, bottom, left],
    5 => [topAt(.36), topAt(.64), right, bottom, left],
    _ => [topAt(.36), topAt(.64), right, bottomAt(.64), bottomAt(.36), left],
  };
  return List<Offset>.generate(
    playerCount,
    (index) => seats[index % seats.length],
    growable: false,
  );
}
