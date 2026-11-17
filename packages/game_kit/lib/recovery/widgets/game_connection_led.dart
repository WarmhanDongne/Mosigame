// [game_connection_led.dart] 는 게임 휴대폰 화면 맨 아래에 공통 연결 상태 띠를 붙이는 어댑터 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 끊김 → 다시 연결 중 → 복구를 로비와 같은 한 줄 띠로 보여 줌
//
// 즉, 기존 게임별 호출 구조는 지키면서 연결 UI를 한 종류로 통일하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_connection_band.dart';
import 'package:game_kit/recovery/widgets/connection_notice_host.dart';
import 'package:game_kit/localization/game_locale.dart';

export 'package:game_kit/recovery/widgets/connection_notice_host.dart'
    show ConnectionNoticePhase;

// ============================================================

/// 기존 게임별 호출부가 넘기는 연결 문구와 호환 스타일입니다.
///
/// 색 필드는 하위 호환용이고 현재 표시는 공통 [MosiConnectionBand] 색을 씁니다.
@immutable
class GameConnectionLedStyle {
  const GameConnectionLedStyle({
    required this.background,
    required this.offColor,
    required this.retryColor,
    required this.onColor,
    required this.textColor,
    this.topLineColor,
    this.dividerColor = const Color(0x33FFFFFF),
    this.lostLabel = '연결이 끊겼어요',
    this.reconnectingLabel = '다시 연결하는 중…',
    this.restoredLabel = '다시 연결됐어요',
    this.fontFamily,
    this.fontPackage,
  });

  /// 라이어스 포커 기본형입니다. 타이머와 같은 LED 전광판입니다.
  static const classic = GameConnectionLedStyle(
    background: Color(0xFF0D0A0C),
    topLineColor: Color(0x22FFFFFF),
    offColor: Color(0xFFFF4B3E),
    retryColor: Color(0xFFFFB627),
    onColor: Color(0xFF3BE38F),
    textColor: Color(0xFFE9E3DA),
  );

  final Color background;

  /// 위쪽 가는 선 색입니다(홀덤: 금색 빛 한 줄). 없으면 그리지 않습니다.
  final Color? topLineColor;

  /// 끊김(`oFF`) 숫자 색입니다.
  final Color offColor;

  /// 다시 연결 중(`2-5`) 숫자 색입니다.
  final Color retryColor;

  /// 복구(`on`) 숫자 색입니다.
  final Color onColor;

  /// 문구 색입니다.
  final Color textColor;
  final Color dividerColor;
  final String lostLabel;
  final String reconnectingLabel;
  final String restoredLabel;

  /// 문구 글꼴입니다(게임 본문 글꼴). 숫자는 늘 LED 글꼴입니다.
  final String? fontFamily;
  final String? fontPackage;
}

/// 게임 휴대폰 화면에도 로비와 같은 모시겜 연결 상태 띠를 얹습니다.
///
/// 기존 호출부의 스타일 인자는 호환을 위해 유지하지만, 연결 상태의 모양과 문구는
/// 이제 [MosiConnectionBand] 한 종류로 통일합니다.
class GameConnectionLedHost extends StatelessWidget {
  const GameConnectionLedHost({
    super.key,
    required this.child,
    required this.connectionChanges,
    this.style = GameConnectionLedStyle.classic,
  });

  final Widget child;
  final Stream<bool>? connectionChanges;
  final GameConnectionLedStyle style;

  @override
  Widget build(BuildContext context) => ConnectionNoticeHost(
    connectionChanges: connectionChanges,
    builder: (context, phase, step) =>
        GameConnectionLed(phase: phase, step: step, style: style),
    child: child,
  );
}

/// 기존 게임별 호출부를 유지하면서 공통 연결 상태 띠를 그리는 어댑터입니다.
class GameConnectionLed extends StatelessWidget {
  const GameConnectionLed({
    super.key,
    required this.phase,
    required this.style,
    this.step = 1,
    this.maxSteps = 5,
  });

  final ConnectionNoticePhase phase;
  final GameConnectionLedStyle style;

  /// 다시 연결 중 단계입니다(`2-5`의 2).
  final int step;
  final int maxSteps;

  /// 띠 높이입니다(안전 영역 제외).
  static const double height = 24;

  /// LED 숫자 글꼴입니다. 앱이 번들한 7세그먼트 글꼴입니다.
  static const String digitalFamily = 'DigitalTimer';

  @override
  Widget build(BuildContext context) {
    return MosiConnectionBand(
      phase: phase,
      labels: MosiConnectionBandLabels(
        lost: style.lostLabel.localized,
        reconnecting: style.reconnectingLabel.localized,
        restored: style.restoredLabel.localized,
      ),
    );
  }
}
