// [query_service.dart] 는 ELEVEN 서버 상태 구독을 모아 둔 파일이다.
//
// - [Package] : ELEVEN
// - [Query] : 공개·개인(공용 베이스) + controller 기록(이 게임 전용)
//
// 즉, 화면과 컨트롤러가 허용된 데이터만 읽기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:firebase_database/firebase_database.dart';
import 'package:game_kit/services/game_query_service.dart';

// ============================================================

class ElevenQueryService extends GameQueryService {
  ElevenQueryService({super.database});

  /// `rooms/{roomCode}/game/controller/history` — 태블릿 controller만 읽습니다.
  ///
  /// 공용 [GameQueryService]에는 controller 경로가 없어 이 게임에만 둡니다.
  /// RTDB rules가 controller UID 외 읽기를 거절하므로 휴대폰에서 부르지 않습니다.
  DatabaseReference controllerHistoryRef(String roomCode) =>
      database.ref('rooms/$roomCode/game/controller/history');

  Stream<DatabaseEvent> watchControllerHistory(String roomCode) =>
      observeRealtime(
        controllerHistoryRef(roomCode).onValue,
        channel: '일레븐 진행 기록',
      );
}
