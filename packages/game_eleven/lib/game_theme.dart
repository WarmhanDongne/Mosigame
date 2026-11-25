// [game_theme.dart] 는 ELEVEN에서 두 곳 이상 쓰는 색을 모아 두는 파일이다.
//
// - [Package] : ELEVEN
// - [Theme] : 흑·백 타일과 테이블 색
//
// S4 골격 단계의 임시 값이다. 디자인 캔버스 T01–T13, P01–P11 반영은 화면 단계에서 한다.

// ========================[ import ]==========================
import 'package:flutter/painting.dart';

// ============================================================

abstract final class ElevenColors {
  /// 게임 목록·자리 배치 테이블에 쓰는 대표 색입니다.
  static const table = Color(0xFF111111);
  static const background = Color(0xFF0B0B0B);
  static const blackTile = Color(0xFF1C1C1C);
  static const whiteTile = Color(0xFFF3F1EC);
  static const ink = Color(0xFFF3F1EC);
  static const inkMuted = Color(0xFF8A8A8A);
  static const accent = Color(0xFFD8B26A);
}
