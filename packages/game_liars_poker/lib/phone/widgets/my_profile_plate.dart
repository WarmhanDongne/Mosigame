// [my_profile_plate.dart] 는 라이어스 포커 휴대폰 게임 화면 왼쪽 위에
// 내 캐릭터와 닉네임을 나무 명패로 보여 주는 파일이다.
//
// 태블릿 좌석 명패처럼 어두운 나무 바탕에 금색 테두리를 두르고, 캐릭터
// 얼굴이 명패 왼쪽을 살짝 덮습니다. 카드 수·벌칙·차례 표시는 넣지 않습니다.
// 디자인: Claude Design '라이어스 휴대폰 · 좌상단 내 프로필' 2안(나무 명패).

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

// ============================================================

class LiarsPokerMyProfilePlate extends StatelessWidget {
  const LiarsPokerMyProfilePlate({
    super.key,
    required this.nickname,
    required this.characterId,
    this.isLandscape = false,
  });

  final String nickname;
  final String characterId;
  final bool isLandscape;

  static const _ink = Color(0xFF17110F);
  static const _cream = Color(0xFFF2EADB);
  static const _gold = Color(0xFFB9A782);
  static const _face = Color(0xFFE3B95A);
  static const _woodTop = Color(0xFF2B1C13);
  static const _woodBottom = Color(0xFF1C120C);

  @override
  Widget build(BuildContext context) {
    final avatar = isLandscape ? 40.0 : 44.0;
    final plateHeight = isLandscape ? 30.0 : 32.0;
    // 얼굴이 명패 왼쪽을 덮는 만큼 명패 글자를 안쪽으로 밉니다.
    final overlap = avatar * .3;
    return Semantics(
      label: nickname,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 168),
        // 명패를 먼저 깔고 얼굴을 위에 올려, 얼굴이 명패 왼쪽 끝을 덮습니다.
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Padding(
              padding: EdgeInsets.only(left: avatar - overlap),
              child: Container(
                height: plateHeight,
                padding: EdgeInsets.fromLTRB(overlap + 8, 0, 12, 0),
                alignment: Alignment.centerLeft,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_woodTop, _woodBottom],
                  ),
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(10),
                  ),
                  border: Border(
                    top: BorderSide(color: _gold, width: 2),
                    right: BorderSide(color: _gold, width: 2),
                    bottom: BorderSide(color: _gold, width: 2),
                  ),
                ),
                child: Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MosiFonts.sans(
                    size: isLandscape ? 14 : 15,
                    weight: FontWeight.w700,
                    color: _cream,
                  ),
                ),
              ),
            ),
            _avatar(avatar),
          ],
        ),
      ),
    );
  }

  Widget _avatar(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _face,
      border: Border.all(color: _ink, width: 2.5),
      boxShadow: const [
        BoxShadow(color: _gold, spreadRadius: 2.5),
        BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2)),
      ],
    ),
    child: ClipOval(
      child: Padding(
        padding: EdgeInsets.all(size * .06),
        child: MosiFace(characterId: characterId, size: size),
      ),
    ),
  );
}
