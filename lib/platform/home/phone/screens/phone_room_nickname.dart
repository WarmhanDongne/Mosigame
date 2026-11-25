import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:project00/platform/auth/models/nickname_policy.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';
import 'package:project00/platform/home/phone/models/guest_room_nickname.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/phone/widgets/phone_flow_transition.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/profile/providers/profile_update_controller.dart';

//=======================닉네임과 방 캐릭터 설정==============================
class PhoneRoomNickname extends StatefulWidget {
  const PhoneRoomNickname({
    super.key,
    required this.roomCode,
    required this.provider,
  });

  final String roomCode;
  final RoomProvider provider;

  @override
  State<PhoneRoomNickname> createState() => _PhoneRoomNicknameState();
}

const _roomNicknameMaxLength = 10;

enum _NicknameFieldStatus { empty, typing, available, duplicate, invalid }

class _PhoneRoomNicknameState extends State<PhoneRoomNickname> {
  static const _characterTakenReason = 'characterTaken';
  final math.Random _random = math.Random();
  late final TextEditingController _nicknameController;
  final FocusNode _nicknameFocus = FocusNode();
  String? _selectedCharacterId;
  bool _nicknameFollowsGuestCharacter = false;

  /// 닉네임 칸 오류가 날 때마다 바뀌어 그 칸만 흔듭니다(로비 연출 10번).
  int _nicknameShake = 0;
  bool _isOpeningWaitingRoom = false;

  RoomProvider get _roomProvider => widget.provider;

  @override
  void initState() {
    super.initState();
    final available = _availableCharacters;
    _selectedCharacterId = available.isEmpty
        ? null
        : available[_random.nextInt(available.length)].id;
    final user = FirebaseBackend.auth.currentUser;
    final pendingNickname = ProfileUpdateController.instance
        .pendingFor(user?.uid)
        ?.nickname
        .trim();
    final seed = roomNicknameSeed(
      isAnonymous: user?.isAnonymous == true,
      characterId: _selectedCharacterId,
      pendingNickname: pendingNickname,
      displayName: user?.displayName,
      email: user?.email,
      maxLength: _roomNicknameMaxLength,
    );
    _nicknameController = TextEditingController(text: seed.nickname);
    _nicknameFocus.addListener(_handleNicknameFocus);
    _nicknameFollowsGuestCharacter = seed.followsCharacter;
    _roomProvider.addListener(_handleRoomUpdate);
    _roomProvider.listenRoomPreview(widget.roomCode);
  }

  Set<String> get _occupiedCharacterIds {
    final currentUid = FirebaseBackend.auth.currentUser?.uid;
    return _roomProvider.players
        .where((player) => player.uid != currentUid)
        // 예전 동물 id도 같은 포커페이스로 그려지므로 그 얼굴로 맞춰 비교합니다.
        .map((player) => roomCharacterById(player.characterId).id)
        .toSet();
  }

  Set<String> get _occupiedNicknames {
    final currentUid = FirebaseBackend.auth.currentUser?.uid;
    return _roomProvider.players
        .where((player) => player.uid != currentUid)
        .map((player) => player.nickname)
        .toSet();
  }

  List<RoomCharacter> get _availableCharacters => _nicknameFollowsGuestCharacter
      ? availableGuestRoomCharacters(
          occupiedCharacterIds: _occupiedCharacterIds,
          occupiedNicknames: _occupiedNicknames,
        )
      : roomCharacters
            .where((character) => !_occupiedCharacterIds.contains(character.id))
            .toList(growable: false);

  void _handleRoomUpdate() {
    if (!_roomProvider.roomPreviewReady) {
      if (mounted) setState(() {});
      return;
    }
    final selected = _selectedCharacterId;
    final nicknameAvailable =
        !_nicknameFollowsGuestCharacter ||
        (selected != null &&
            !_occupiedNicknames.contains(
              guestRoomNicknameForCharacter(selected),
            ));
    if (selected != null &&
        !_occupiedCharacterIds.contains(selected) &&
        nicknameAvailable) {
      if (mounted) setState(() {});
      return;
    }
    _selectRandomAvailableCharacter();
  }

  void _selectRandomAvailableCharacter({
    Set<String> excluding = const <String>{},
  }) {
    final available = _availableCharacters
        .where((character) => !excluding.contains(character.id))
        .toList(growable: false);
    final next = available.isEmpty
        ? null
        : available[_random.nextInt(available.length)].id;
    _setSelectedCharacter(next);
  }

  void _setSelectedCharacter(String? characterId) {
    if (!mounted) {
      _selectedCharacterId = characterId;
      return;
    }
    setState(() {
      _selectedCharacterId = characterId;
      if (_nicknameFollowsGuestCharacter && characterId != null) {
        _nicknameController.text = guestRoomNicknameForCharacter(characterId);
      }
    });
  }

  @override
  void dispose() {
    _roomProvider.removeListener(_handleRoomUpdate);
    _roomProvider.stopRoomPreview();
    _nicknameFocus.removeListener(_handleNicknameFocus);
    _nicknameFocus.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _handleNicknameFocus() {
    if (mounted) setState(() {});
  }

  _NicknameFieldStatus _nicknameStatus({
    required String nickname,
    required bool duplicate,
  }) {
    if (nickname.isEmpty) return _NicknameFieldStatus.empty;
    if (nickname == '나' || nickname.runes.length < nicknameMinLength) {
      return _nicknameFocus.hasFocus
          ? _NicknameFieldStatus.typing
          : _NicknameFieldStatus.invalid;
    }
    if (duplicate) return _NicknameFieldStatus.duplicate;
    return _nicknameFocus.hasFocus
        ? _NicknameFieldStatus.typing
        : _NicknameFieldStatus.available;
  }

  /// 입력한 닉네임과 캐릭터를 이 방의 참가자 정보에만 저장하고 입장합니다.
  ///
  /// 계정 프로필은 수정하지 않으며, [RoomProvider.joinRoom]이 전달한 값은
  /// `rooms/{roomCode}/players/{uid}`의 방 전용 표시 정보로만 사용됩니다.
  Future<void> _joinRoomWithNickname() async {
    FocusScope.of(context).unfocus();
    var nickname = _nicknameController.text.trim();
    var characterId = _selectedCharacterId;
    if (nickname.isEmpty) {
      _roomProvider.errorMessage = GameLocale.select(
        ko: '닉네임을 입력해주세요.',
        en: 'Enter a nickname.',
        zhHans: '请输入昵称。',
        zhHant: '請輸入暱稱。',
      );
      setState(() => _nicknameShake++);
      return;
    }
    if (nickname == '나') {
      _roomProvider.errorMessage = GameLocale.select(
        ko: '닉네임으로 “나”는 사용할 수 없어요.',
        en: '“Me” cannot be used as a nickname.',
        zhHans: '不能使用“我”作为昵称。',
        zhHant: '不能使用「我」作為暱稱。',
      );
      setState(() => _nicknameShake++);
      return;
    }
    if (nickname.runes.length > _roomNicknameMaxLength) {
      _roomProvider.errorMessage = GameLocale.select(
        ko: '닉네임은 $_roomNicknameMaxLength자 이하로 입력해주세요.',
        en: 'Use no more than $_roomNicknameMaxLength characters.',
        zhHans: '昵称不得超过 $_roomNicknameMaxLength 个字符。',
        zhHant: '暱稱不得超過 $_roomNicknameMaxLength 個字元。',
      );
      setState(() => _nicknameShake++);
      return;
    }
    if (characterId == null) {
      _roomProvider.errorMessage = GameLocale.select(
        ko: '사용할 수 있는 캐릭터가 없습니다.',
        en: 'No characters are available.',
        zhHans: '没有可用角色。',
        zhHant: '沒有可用角色。',
      );
      setState(() {});
      return;
    }

    final currentUid = FirebaseBackend.auth.currentUser?.uid;
    final duplicateNickname = _roomProvider.players.any(
      (player) => player.uid != currentUid && player.nickname == nickname,
    );
    if (duplicateNickname) {
      _roomProvider.errorMessage = GameLocale.select(
        ko: '이미 사용 중인 닉네임입니다.',
        en: 'That nickname is already in use.',
        zhHans: '该昵称已被使用。',
        zhHant: '該暱稱已被使用。',
      );
      setState(() => _nicknameShake++);
      return;
    }
    final attemptedCharacterIds = <String>{};
    if (_occupiedCharacterIds.contains(characterId)) {
      attemptedCharacterIds.add(characterId);
      _selectRandomAvailableCharacter(excluding: attemptedCharacterIds);
      characterId = _selectedCharacterId;
      nickname = _nicknameController.text.trim();
      if (characterId == null) {
        _roomProvider.errorMessage = GameLocale.select(
          ko: '사용할 수 있는 캐릭터가 없습니다.',
          en: 'No characters are available.',
          zhHans: '没有可用角色。',
          zhHant: '沒有可用角色。',
        );
        setState(() {});
        return;
      }
    }
    if (_isOpeningWaitingRoom) return;
    setState(() => _isOpeningWaitingRoom = true);

    var joined = false;
    while (characterId != null && attemptedCharacterIds.add(characterId)) {
      joined = await _roomProvider.joinRoom(
        widget.roomCode,
        nickname,
        characterId: characterId,
      );
      if (!mounted) return;
      if (joined) break;
      final characterWasTaken =
          _roomProvider.lastCommandErrorReason == _characterTakenReason ||
          _roomProvider.errorMessage == '이미 선택된 캐릭터입니다.';
      if (!characterWasTaken) break;

      // 화면을 본 직후 다른 휴대폰이 같은 캐릭터를 먼저 확정한 경쟁입니다.
      // 이미 거절된 후보를 제외한 채 서버 projection을 다시 받아, 남은 후보가
      // 있는 동안만 제한적으로 재시도합니다.
      _roomProvider.errorMessage = null;
      await _roomProvider.refreshRoomPreview(widget.roomCode);
      if (!mounted) return;
      final selected = _selectedCharacterId;
      if (selected == null ||
          attemptedCharacterIds.contains(selected) ||
          _occupiedCharacterIds.contains(selected)) {
        _selectRandomAvailableCharacter(excluding: attemptedCharacterIds);
      }
      characterId = _selectedCharacterId;
      nickname = _nicknameController.text.trim();
    }
    if (!joined && characterId == null) {
      _roomProvider.errorMessage = GameLocale.select(
        ko: '사용할 수 있는 캐릭터가 없습니다.',
        en: 'No characters are available.',
        zhHans: '没有可用角色。',
        zhHant: '沒有可用角色。',
      );
    }
    if (!joined) {
      setState(() => _isOpeningWaitingRoom = false);
      return;
    }

    await Navigator.push(
      context,
      PhoneFlowRoute<void>(
        builder: (_) => PhoneRoomWaiting(provider: _roomProvider),
      ),
    );
    if (!mounted) return;
    setState(() => _isOpeningWaitingRoom = false);

    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    if (!_roomProvider.isInRoom) Navigator.of(context).pop();
  }

  void _selectCharacter(String characterId) {
    if (_occupiedCharacterIds.contains(characterId)) return;
    _roomProvider.errorMessage = null;
    _setSelectedCharacter(characterId);
  }

  Future<void> _cancelSetup() async {
    if (_roomProvider.isLoading) return;
    _roomProvider.stopRoomPreview();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _roomProvider,
      builder: (context, _) {
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final nickname = _nicknameController.text.trim();
        final nicknameTaken =
            nickname.isNotEmpty && _occupiedNicknames.contains(nickname);
        final nicknameStatus = _nicknameStatus(
          nickname: nickname,
          duplicate: nicknameTaken,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: MosiColors.violet,
            body: CustomPaint(
              painter: const _JoinDotsPainter(),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _JoinHeader(
                      roomCode: widget.roomCode,
                      players: _roomProvider.players,
                      checking: !_roomProvider.roomPreviewReady,
                      onBack: _cancelSetup,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 2, 18, 16),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  GameLocale.select(
                                    ko: '닉네임 정하기',
                                    en: 'Pick a nickname',
                                    zhHans: '设置昵称',
                                    zhHant: '設定暱稱',
                                  ),
                                  style: TextStyle(
                                    fontFamily:
                                        'packages/${MosiFonts.package}'
                                        '/${MosiFonts.logo}',
                                    fontSize: 26,
                                    height: 1.2,
                                    color: MosiColors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                MosiBalancedText(
                                  GameLocale.select(
                                    ko: '이 그룹에서만 쓰는 이름이에요. 다른 사람과 겹치면 안 돼요.',
                                    en: 'Only used in this room. It must differ from everyone else’s.',
                                    zhHans: '仅在此房间使用，不能与其他人重复。',
                                    zhHant: '僅在此房間使用，不能與其他人重複。',
                                  ),
                                  maxLines: 3,
                                  style: MosiFonts.sans(
                                    size: 12.5,
                                    color: const Color(0xD9FFFFFF),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                MosiShake(
                                  trigger: _nicknameShake == 0
                                      ? null
                                      : _nicknameShake,
                                  child: _nicknameField(
                                    nickname: nickname,
                                    status: nicknameStatus,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        GameLocale.select(
                                          ko: '캐릭터 고르기',
                                          en: 'Pick a character',
                                          zhHans: '选择角色',
                                          zhHant: '選擇角色',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily:
                                              'packages/${MosiFonts.package}'
                                              '/${MosiFonts.logo}',
                                          fontSize: 21,
                                          height: 1.2,
                                          color: MosiColors.white,
                                        ),
                                      ),
                                    ),
                                    _RandomCharacterButton(
                                      onPressed: _availableCharacters.isEmpty
                                          ? null
                                          : _selectRandomAvailableCharacter,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                GridView.builder(
                                  key: const Key('room-character-grid'),
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: roomCharacters.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 6,
                                        // 얼굴 아래 이름표까지 한 칸에 들어오는 비율입니다.
                                        childAspectRatio: .9,
                                      ),
                                  itemBuilder: (context, index) {
                                    final character = roomCharacters[index];
                                    return _CharacterChoice(
                                      character: character,
                                      selected:
                                          character.id == _selectedCharacterId,
                                      taken: _occupiedCharacterIds.contains(
                                        character.id,
                                      ),
                                      onTap: () =>
                                          _selectCharacter(character.id),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 아래 버튼은 보라 바탕이 짙어지며 떠 있는 것처럼 보입니다.
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x003A22C8), Color(0xF23A22C8)],
                          stops: [0, .3],
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          18,
                          14,
                          18,
                          16 + bottomInset,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isOpeningWaitingRoom) ...[
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  '입장하는 중…'.localized,
                                  textAlign: TextAlign.center,
                                  style: MosiFonts.sans(
                                    size: 14,
                                    color: MosiColors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            // 오류 안내는 부드럽게 펼쳐지고, 고치면 접힙니다(로비 연출 10번).
                            MosiReveal(
                              visible: _roomProvider.errorMessage != null,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Semantics(
                                  liveRegion: true,
                                  child: _SetupAlert(
                                    message: _roomProvider.errorMessage ?? '',
                                  ),
                                ),
                              ),
                            ),
                            MosiButton(
                              label: '입장하기'.localized,
                              expand: true,
                              height: 56,
                              fontSize: 18,
                              radius: 16,
                              shadowOffset: 5,
                              background: MosiColors.lime,
                              foreground: MosiColors.ink,
                              trailing: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                                color: MosiColors.ink,
                              ),
                              loading: _isOpeningWaitingRoom,
                              // 참가 전에는 RTDB 규칙상 다른 참가자 목록을 읽지 못할 수 있습니다.
                              // 미리보기는 보조 정보이고 최종 중복 검증은 join callable이 담당합니다.
                              onPressed:
                                  _selectedCharacterId == null ||
                                      _isOpeningWaitingRoom
                                  ? null
                                  : _joinRoomWithNickname,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 흰 닉네임 칸입니다. 오른쪽 끝에서 쓸 수 있는지 바로 알려 줍니다.
  Widget _nicknameField({
    required String nickname,
    required _NicknameFieldStatus status,
  }) {
    final invalid = status == _NicknameFieldStatus.invalid;
    final taken = status == _NicknameFieldStatus.duplicate;
    return Container(
      height: 58,
      padding: const EdgeInsets.only(left: 14, right: 10),
      decoration: BoxDecoration(
        color: MosiColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: invalid || taken ? MosiColors.red : MosiColors.ink,
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(color: MosiColors.navy, offset: Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nicknameController,
              focusNode: _nicknameFocus,
              maxLength: _roomNicknameMaxLength,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_roomNicknameMaxLength),
              ],
              style: MosiFonts.sans(
                size: 20,
                weight: FontWeight.w800,
                color: MosiColors.navy,
              ),
              // 앱 테마의 입력칸 테두리(눌렀을 때 생기는 네모 선)를 모두 끕니다.
              // 바깥 흰 칸이 테두리 역할을 합니다.
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                counterText: '',
                hintText: GameLocale.select(
                  ko: '닉네임 · 최대 $_roomNicknameMaxLength자',
                  en: 'Nickname · up to $_roomNicknameMaxLength characters',
                  zhHans: '昵称 · 最多 $_roomNicknameMaxLength 个字符',
                  zhHant: '暱稱 · 最多 $_roomNicknameMaxLength 個字元',
                ),
                hintStyle: MosiFonts.sans(size: 15, color: MosiColors.muted),
              ),
              onChanged: (_) {
                final followedCharacter = _nicknameFollowsGuestCharacter;
                _nicknameFollowsGuestCharacter = false;
                if (followedCharacter &&
                    _selectedCharacterId == null &&
                    _availableCharacters.isNotEmpty) {
                  _selectedCharacterId =
                      _availableCharacters[_random.nextInt(
                            _availableCharacters.length,
                          )]
                          .id;
                }
                _roomProvider.errorMessage = null;
                // 사용 가능 표시가 글자마다 바뀌도록 다시 그립니다.
                setState(() {});
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: switch (status) {
              _NicknameFieldStatus.empty => const SizedBox(
                key: ValueKey('nickname-status-empty'),
                width: 28,
              ),
              _NicknameFieldStatus.typing => _NicknameCountBadge(
                key: const ValueKey('nickname-count'),
                count: nickname.runes.length,
              ),
              _NicknameFieldStatus.available => const _NicknameOkBadge(
                key: ValueKey('nickname-ok'),
              ),
              _NicknameFieldStatus.duplicate => const _NicknameTakenBadge(
                key: ValueKey('nickname-taken'),
              ),
              _NicknameFieldStatus.invalid => const _NicknameInvalidBadge(
                key: ValueKey('nickname-invalid'),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// 같은 이름을 이미 쓰고 있을 때 체크 자리에 들어서는 분홍 알약입니다.
class _NicknameTakenBadge extends StatelessWidget {
  const _NicknameTakenBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final label = GameLocale.select(
      ko: '이미 있어요',
      en: 'Taken',
      zhHans: '已被使用',
      zhHant: '已被使用',
    );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD0D8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: MosiColors.ink, width: 2.5),
        ),
        child: Text(
          label,
          style: MosiFonts.sans(
            size: 12.5,
            weight: FontWeight.w800,
            color: const Color(0xFFC2283C),
          ),
        ),
      ),
    );
  }
}

/// 입력 중인 닉네임 길이를 보여 주는 오른쪽 카운터입니다.
class _NicknameCountBadge extends StatelessWidget {
  const _NicknameCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Text(
    '$count/$_roomNicknameMaxLength',
    key: const ValueKey('nickname-count-label'),
    style: MosiFonts.grotesk(
      size: 13,
      color: MosiColors.muted,
      weight: FontWeight.w700,
    ),
  );
}

/// 사용할 수 없는 닉네임에 표시하는 X 배지입니다.
class _NicknameInvalidBadge extends StatelessWidget {
  const _NicknameInvalidBadge({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: GameLocale.select(
      ko: '사용할 수 없는 닉네임',
      en: 'Nickname unavailable',
      zhHans: '昵称不可用',
      zhHant: '暱稱不可用',
    ),
    excludeSemantics: true,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: MosiColors.red,
        shape: BoxShape.circle,
        border: Border.all(color: MosiColors.ink, width: 2.5),
      ),
      child: const Icon(
        Icons.close_rounded,
        size: 18,
        color: MosiColors.white,
        weight: 800,
      ),
    ),
  );
}

/// 닉네임을 쓸 수 있을 때 칸 오른쪽에 붙는 초록 체크 배지입니다.
class _NicknameOkBadge extends StatelessWidget {
  const _NicknameOkBadge({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: GameLocale.select(
      ko: '사용 가능한 닉네임',
      en: 'Nickname available',
      zhHans: '昵称可用',
      zhHant: '暱稱可用',
    ),
    excludeSemantics: true,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF3FAE5A),
        shape: BoxShape.circle,
        border: Border.all(color: MosiColors.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(color: MosiColors.navy, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 18,
        color: MosiColors.white,
        weight: 800,
      ),
    ),
  );
}

/// 보라 바탕 위 뒤로가기 · 제목 · 이미 들어온 사람 얼굴입니다.
class _JoinHeader extends StatelessWidget {
  const _JoinHeader({
    required this.roomCode,
    required this.players,
    required this.checking,
    required this.onBack,
  });

  final String roomCode;
  final List<RoomPlayer> players;
  final bool checking;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final faces = players.take(4).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: '뒤로'.localized,
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x80FFFFFF), width: 2),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: MosiColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 어느 방에 들어가는 중인지 코드로 보여 줍니다.
          Semantics(
            label: GameLocale.select(
              ko: '방 코드 ${roomCode.split('').join(' ')}',
              en: 'Room code ${roomCode.split('').join(' ')}',
              zhHans: '房间码 ${roomCode.split('').join(' ')}',
              zhHant: '房間碼 ${roomCode.split('').join(' ')}',
            ),
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(9, 5, 12, 5),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    GameLocale.select(
                      ko: '방',
                      en: 'ROOM',
                      zhHans: '房间',
                      zhHant: '房間',
                    ),
                    style: MosiFonts.sans(
                      size: 10.5,
                      weight: FontWeight.w700,
                      color: const Color(0xCCFFFFFF),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    roomCode,
                    style: MosiFonts.grotesk(
                      size: 14,
                      color: MosiColors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (checking)
            Semantics(
              liveRegion: true,
              child: Text(
                GameLocale.select(
                  ko: '참가자 확인 중…',
                  en: 'Checking…',
                  zhHans: '正在确认…',
                  zhHant: '正在確認…',
                ),
                style: MosiFonts.sans(size: 12, color: const Color(0xFFD9D3FF)),
              ),
            )
          else if (faces.isNotEmpty) ...[
            Semantics(
              label: players.map((player) => player.nickname).join(', '),
              excludeSemantics: true,
              child: SizedBox(
                width: 32 + (faces.length - 1) * 22,
                height: 32,
                child: Stack(
                  children: [
                    for (final (i, player) in faces.indexed)
                      Positioned(
                        left: i * 22,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MosiColors.white,
                              width: 2,
                            ),
                          ),
                          child: MosiFace(
                            characterId: player.characterId,
                            size: 28,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              GameLocale.select(
                ko: '${players.length}명',
                en: '${players.length}',
                zhHans: '${players.length} 人',
                zhHant: '${players.length} 人',
              ),
              style: MosiFonts.sans(
                size: 13,
                weight: FontWeight.w700,
                color: MosiColors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 검정 테두리와 남색 그림자를 가진 흰 카드입니다.
/// 주사위 두 개 아이콘이 붙은 노란 랜덤 버튼입니다.
class _RandomCharacterButton extends StatefulWidget {
  const _RandomCharacterButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_RandomCharacterButton> createState() => _RandomCharacterButtonState();
}

class _RandomCharacterButtonState extends State<_RandomCharacterButton> {
  bool _pressed = false;
  int _rolls = 0;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '랜덤 선택'.localized,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: enabled
            ? (_) {
                setState(() {
                  _pressed = false;
                  _rolls++;
                });
                widget.onPressed!();
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
            padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
            decoration: BoxDecoration(
              color: MosiColors.sun,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MosiColors.ink, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: MosiColors.navy,
                  offset: Offset(0, _pressed ? 0 : 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 누를 때마다 주사위가 한 바퀴 굴러갑니다.
                AnimatedRotation(
                  turns: _rolls.toDouble(),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  child: const CustomPaint(
                    size: Size(28, 24),
                    painter: _TwoDicePainter(),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  GameLocale.select(
                    ko: '랜덤',
                    en: 'Random',
                    zhHans: '随机',
                    zhHant: '隨機',
                  ),
                  style: MosiFonts.sans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: MosiColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 보라 주사위(눈 2)와 흰 주사위(눈 3)가 엇갈려 구르는 아이콘입니다(28×24 기준).
class _TwoDicePainter extends CustomPainter {
  const _TwoDicePainter();

  void _die(
    Canvas canvas,
    Rect rect,
    double degrees,
    Color fill,
    Color pip,
    List<Offset> pips,
    double s,
  ) {
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(degrees * math.pi / 180);
    final local = Rect.fromCenter(
      center: Offset.zero,
      width: rect.width,
      height: rect.height,
    );
    final rrect = RRect.fromRectAndRadius(local, Radius.circular(4 * s));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = MosiColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * s,
    );
    for (final p in pips) {
      canvas.drawCircle(
        Offset(p.dx * rect.width, p.dy * rect.height),
        1.4 * s,
        Paint()..color = pip,
      );
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 28;
    _die(
      canvas,
      Rect.fromLTWH(2 * s, 6 * s, 14 * s, 14 * s),
      -14,
      MosiColors.violet,
      MosiColors.white,
      const [Offset(-.2, -.2), Offset(.2, .2)],
      s,
    );
    _die(
      canvas,
      Rect.fromLTWH(12 * s, 2 * s, 14 * s, 14 * s),
      12,
      MosiColors.white,
      MosiColors.ink,
      const [Offset(-.2, -.2), Offset(0, 0), Offset(.2, .2)],
      s,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 로비와 같은 옅은 흰 점무늬입니다.
class _JoinDotsPainter extends CustomPainter {
  const _JoinDotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1FFFFFFF);
    const gap = 18.0;
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 동그란 캐릭터 한 칸입니다. 얼굴 아래에 이름표가 붙고, 고르면 라임 고리와
/// 체크가, 다른 사람이 쓰면 흑백 얼굴에 '사용 중' 이름표가 됩니다.
class _CharacterChoice extends StatelessWidget {
  const _CharacterChoice({
    required this.character,
    required this.selected,
    required this.taken,
    required this.onTap,
  });

  final RoomCharacter character;
  final bool selected;

  /// 다른 사람이 이미 쓰고 있어 고를 수 없는 캐릭터입니다.
  final bool taken;
  final VoidCallback onTap;

  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final disabled = taken;
    final face = MosiFace(characterId: character.id, size: 60, ring: true);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: disabled
          ? GameLocale.select(
              ko: '${character.localizedLabel}, 사용 중',
              en: '${character.localizedLabel}, already in use',
              zhHans: '${character.localizedLabel}，已被其他人使用',
              zhHant: '${character.localizedLabel}，已被其他人使用',
            )
          : character.localizedLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: EdgeInsets.all(selected ? 4 : 0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? MosiColors.lime : null,
                            border: selected
                                ? Border.all(color: MosiColors.ink, width: 4)
                                : null,
                          ),
                          // 고른 얼굴이 살짝 커졌다 안착합니다(로비 연출 2번).
                          child: MosiSelectPop(
                            selected: selected,
                            child: FittedBox(
                              child: disabled
                                  ? Opacity(
                                      opacity: .45,
                                      child: ColorFiltered(
                                        colorFilter: _grayscale,
                                        child: face,
                                      ),
                                    )
                                  : face,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: MosiPopBadge(
                          visible: selected,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: MosiColors.lime,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: MosiColors.ink,
                                width: 2.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: MosiColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: selected
                  ? const EdgeInsets.symmetric(horizontal: 7, vertical: 1)
                  : EdgeInsets.zero,
              decoration: selected
                  ? BoxDecoration(
                      color: MosiColors.lime,
                      borderRadius: BorderRadius.circular(999),
                    )
                  : null,
              child: Text(
                disabled
                    ? GameLocale.select(
                        ko: '사용 중',
                        en: 'In use',
                        zhHans: '使用中',
                        zhHant: '使用中',
                      )
                    : character.localizedLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MosiFonts.sans(
                  size: 11,
                  weight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? MosiColors.navy
                      : disabled
                      ? const Color(0x99FFFFFF)
                      : const Color(0xE6FFFFFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupAlert extends StatelessWidget {
  const _SetupAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MosiNotice(message: message);
}
