import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 화면 폭이 부족할 때 공백 단위로 문장을 균형 있게 나눕니다.
///
/// Flutter의 기본 한글 줄바꿈은 글자 사이에서도 줄을 나눌 수 있어 마지막 한두
/// 글자만 다음 줄에 남을 수 있습니다. 이 위젯은 한 줄에 들어가지 않는 짧은 안내
/// 문구에만 명시적인 줄바꿈을 넣어, 가능한 한 단어를 함께 유지합니다.
class MosiBalancedText extends StatelessWidget {
  const MosiBalancedText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines = 2,
    this.overflow = TextOverflow.clip,
    this.semanticsLabel,
    this.availableWidth,
  }) : assert(maxLines > 0);

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;
  final TextOverflow overflow;
  final String? semanticsLabel;

  /// 부모가 이미 계산한 실제 글자 폭입니다.
  ///
  /// [IntrinsicHeight] 안에서는 [LayoutBuilder]가 intrinsic 크기를 제공할 수
  /// 없으므로, 그 구조에서만 이 값을 넘겨 같은 줄바꿈 계산을 사용합니다.
  final double? availableWidth;

  @override
  Widget build(BuildContext context) {
    final knownWidth = availableWidth;
    if (knownWidth != null) return _buildForWidth(context, knownWidth);
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildForWidth(context, constraints.maxWidth),
    );
  }

  Widget _buildForWidth(BuildContext context, double width) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final balanced = width.isFinite && width > 0
        ? _balanceForWidth(
            data,
            maxWidth: width,
            maxLines: maxLines,
            style: effectiveStyle,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
          )
        : data;
    return Text(
      balanced,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      semanticsLabel: semanticsLabel ?? data,
    );
  }
}

String _balanceForWidth(
  String text, {
  required double maxWidth,
  required int maxLines,
  required TextStyle style,
  required TextDirection textDirection,
  required TextScaler textScaler,
  required Locale? locale,
}) {
  if (maxLines == 1 || text.contains('\n')) return text;
  final words = text.trim().split(RegExp(r'\s+'));
  if (words.length < 2) return text;

  double measure(String value) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  if (measure(text) <= maxWidth) return text;

  _BalancedCandidate? best;
  final largestLineCount = math.min(maxLines, words.length);
  for (var lineCount = 2; lineCount <= largestLineCount; lineCount++) {
    void visit(int start, int remaining, List<String> lines) {
      if (remaining == 1) {
        final last = words.sublist(start).join(' ');
        final candidateLines = [...lines, last];
        final widths = candidateLines.map(measure).toList(growable: false);
        if (widths.any((lineWidth) => lineWidth > maxWidth + .5)) return;
        final visibleLengths = candidateLines
            .map(_visibleCharacterCount)
            .toList(growable: false);
        if (visibleLengths.any((length) => length <= 2)) return;
        final average = widths.reduce((a, b) => a + b) / widths.length;
        final raggedness = widths.fold<double>(
          0,
          (score, lineWidth) => score + math.pow(lineWidth - average, 2),
        );
        final candidate = _BalancedCandidate(candidateLines, raggedness);
        if (best == null || candidate.score < best!.score) best = candidate;
        return;
      }
      final lastCut = words.length - remaining + 1;
      for (var cut = start + 1; cut <= lastCut; cut++) {
        final line = words.sublist(start, cut).join(' ');
        if (measure(line) > maxWidth + .5) break;
        visit(cut, remaining - 1, [...lines, line]);
      }
    }

    visit(0, lineCount, const []);
    if (best != null) return best!.lines.join('\n');
  }
  return text;
}

int _visibleCharacterCount(String text) =>
    text.replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '').runes.length;

class _BalancedCandidate {
  const _BalancedCandidate(this.lines, this.score);

  final List<String> lines;
  final double score;
}
