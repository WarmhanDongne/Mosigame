// 레인 B 소유: lib/tablet 의 디자인 가드 허용 목록(test/shared/design_guard_test.dart가 읽음).
//
// S4 임시 골격 화면의 기존 위반이다. 화면을 시안으로 바꿔 줄이 사라지면 여기서도 지운다
// (남아 있으면 가드 테스트가 실패한다). 새 위반을 추가하지 않는다. 예외가 꼭 필요하면
// LOG-B.md에 이유를 적어 Claude 검수 때 판단받는다.

/// (파일, 규칙) → 허용하는 줄 내용(앞뒤 공백 제거). 같은 줄이 여러 번이면 그만큼 적는다.
const tabletDesignGuardAllowlist = <(String, String), List<String>>{
  ('lib/tablet/src/board_state.dart', 'TextStyle('): [
    'style: const TextStyle(color: ElevenColors.ink),',
    'style: const TextStyle(',
    'style: const TextStyle(',
    'style: const TextStyle(',
    'style: const TextStyle(',
    'style: const TextStyle(',
  ],
  ('lib/tablet/src/board_state.dart', 'Color(0x'): [
    'color: const Color(0x99000000),',
  ],
  ('lib/tablet/widgets/draw_grid.dart', 'TextStyle('): [
    'style: const TextStyle(color: ElevenColors.ink, fontSize: 14),',
  ],
  ('lib/tablet/widgets/score_board.dart', 'TextStyle('): [
    'style: const TextStyle(',
    'style: const TextStyle(color: ElevenColors.inkMuted, fontSize: 15),',
    'style: const TextStyle(',
    'style: const TextStyle(',
    'style: const TextStyle(',
  ],
  ('lib/tablet/widgets/score_board.dart', 'Duration(<숫자>'): [
    'duration: const Duration(milliseconds: 200),',
  ],
};
