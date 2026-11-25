// [game_settings_dialog.dart] 는 태블릿 게임의 공통 설정 다이얼로그를 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 게임 화면에서 반복 사용하는 공통 UI를 구성함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:game_kit/mosi_ui/mosi_game_modal.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/sound/providers/sound_provider.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:provider/provider.dart';

// ============================================================

/// 모든 태블릿 게임이 재사용하는 설정 화면입니다(시안: 게임 · 현재 방 정보 · 소리).
class TabletGameSettingsDialog extends StatelessWidget {
  const TabletGameSettingsDialog({
    super.key,
    required this.provider,
    this.onRestartGame,
    this.onEndGame,
  });

  final GameRoomContext provider;
  final VoidCallback? onRestartGame;
  final VoidCallback? onEndGame;

  void _closeAndRun(BuildContext context, VoidCallback? action) {
    if (action == null) return;
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final theme = MosiGameModalTheme.fromName(provider.selectedGame?.name);
    final code = provider.roomCode ?? '';
    return MosiGameModalFrame(
      theme: theme,
      semanticLabel: '설정'.localized,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '설정'.localized,
                style: MosiFonts.sans(
                  size: 38,
                  weight: FontWeight.w700,
                  color: theme.onSurface,
                  letterSpacing: -1.5,
                ),
              ),
              if (code.isNotEmpty) ...[
                const SizedBox(width: 20),
                MosiDashedBorder(
                  color: MosiColors.ink,
                  radius: 12,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: MosiColors.cream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          GameLocale.select(
                            ko: '방 코드',
                            en: 'Room code',
                            zhHans: '房间码',
                            zhHant: '房間碼',
                          ),
                          style: MosiFonts.sans(
                            size: 13,
                            weight: FontWeight.w700,
                            color: MosiColors.muted,
                          ),
                        ),
                        for (final (i, char) in code.split('').indexed) ...[
                          const SizedBox(width: 8),
                          if (theme.tileCodeChips)
                            _TileCodeChip(char: char, dark: i.isEven)
                          else
                            Container(
                              width: 34,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: MosiColors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: MosiColors.ink,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: MosiColors.ink,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                char,
                                style: MosiFonts.grotesk(
                                  size: 20,
                                  color: MosiColors.navy,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              MosiSquareCloseButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 230, child: _GameInfo(provider: provider)),
                const SizedBox(width: 20),
                Expanded(flex: 115, child: _RoomInfo(provider: provider)),
                const SizedBox(width: 20),
                Expanded(flex: 100, child: _SoundSettings(theme: theme)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              MosiButton(
                label: '게임 재시작'.localized,
                leading: const Icon(Icons.refresh_rounded),
                background: theme.secondaryButton,
                foreground: theme.secondaryButtonFg,
                shadowColor: MosiColors.ink,
                height: 60,
                fontSize: 18,
                radius: 12,
                onPressed: onRestartGame == null
                    ? null
                    : () => _closeAndRun(context, onRestartGame),
              ),
              const SizedBox(width: 12),
              MosiButton(
                label: '게임 종료'.localized,
                leading: const Icon(Icons.stop_rounded),
                background: MosiColors.red,
                foreground: MosiColors.white,
                shadowColor: MosiColors.ink,
                height: 60,
                fontSize: 18,
                radius: 12,
                onPressed: onEndGame == null
                    ? null
                    : () => _closeAndRun(context, onEndGame),
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: MosiButton(
                  label: '계속하기'.localized,
                  background: theme.accent,
                  foreground: theme.accentFg,
                  shadowColor: MosiColors.ink,
                  height: 60,
                  fontSize: 20,
                  radius: 12,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameInfo extends StatelessWidget {
  const _GameInfo({required this.provider});

  final GameRoomContext provider;

  @override
  Widget build(BuildContext context) {
    final game = provider.selectedGame;
    final players = provider.players.where((p) => p.isPlayer).length;
    final gameId = _gameIdFromName(game?.name);
    return MosiCreamPanel(
      theme: MosiGameModalTheme.fromName(game?.name),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              GameLocale.select(
                ko: '게임',
                en: 'Game',
                zhHans: '游戏',
                zhHant: '遊戲',
              ),
              style: MosiFonts.sans(
                size: 14,
                weight: FontWeight.w700,
                color: MosiColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          MosiGameCover(
            gameId: gameId ?? '',
            width: 170,
            fallbackName: game?.name,
            fallbackImageUrl: game?.imageUrl,
          ),
          const SizedBox(height: 12),
          Text(
            gameId != null
                ? MosiGameArt.of(gameId).koreanName
                : game?.name ??
                      GameLocale.select(
                        ko: '게임 정보 불러오는 중',
                        en: 'Loading game details',
                        zhHans: '正在加载游戏信息',
                        zhHant: '正在載入遊戲資訊',
                      ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: MosiFonts.sans(
              size: 20,
              weight: FontWeight.w700,
              color: MosiColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          MosiPill(
            label: GameLocale.select(
              ko: '$players명',
              en: '$players players',
              zhHans: '$players 人',
              zhHant: '$players 人',
            ),
            background: MosiColors.white,
            borderColor: MosiColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          ),
        ],
      ),
    );
  }
}

/// 표지 그림을 고르려고 게임 이름에서 id를 추정합니다.
String? _gameIdFromName(String? name) {
  final lower = (name ?? '').toLowerCase();
  if (lower.contains('liar') || lower.contains('라이어')) return 'liars_poker';
  if (lower.contains('final') || lower.contains('파이널')) return 'final_call';
  if (lower.contains('mafia') || lower.contains('마피아')) return 'mafia';
  if (lower.contains('hold') || lower.contains('홀덤')) return 'holdem';
  if (lower.contains('russian') ||
      lower.contains('러시안') ||
      lower.contains('俄罗斯') ||
      lower.contains('俄羅斯')) {
    return 'russian_roulette';
  }
  if (lower.contains('eleven') || lower.contains('일레븐')) return 'eleven';
  return null;
}

class _RoomInfo extends StatefulWidget {
  const _RoomInfo({required this.provider});

  final GameRoomContext provider;

  @override
  State<_RoomInfo> createState() => _RoomInfoState();
}

/// 강퇴는 두 번 눌러 확정하고, 처리 중 표시 → 줄이 접히며 사라짐 → 아래
/// 안내 순서로 보여 줍니다. 서버 목록이 먼저 갱신돼도 사라지는 줄은 마지막
/// 모습을 잠깐 유지해 갑자기 튀지 않게 합니다.
class _RoomInfoState extends State<_RoomInfo> {
  static const _confirmWindow = Duration(seconds: 3);
  static const _collapseDuration = Duration(milliseconds: 320);
  static const _noticeDuration = Duration(milliseconds: 2600);

  /// 한 번 눌러 확인을 기다리는 사람입니다.
  String? _confirmUid;
  Timer? _confirmTimer;

  /// 서버 처리를 기다리는 사람들입니다.
  final Set<String> _pendingUids = {};

  /// 내보내기가 끝나 접히는 중인 줄입니다. 목록에서 빠져도 이 모습으로 접힙니다.
  final Map<String, GameRoomPlayer> _leaving = {};

  /// 접히기가 끝나 더 이상 그리지 않는 사람들입니다.
  final Set<String> _gone = {};

  /// 마지막으로 본 순서입니다. 목록에서 빠진 줄을 원래 자리에 접기 위해 씁니다.
  List<GameRoomPlayer> _lastPlayers = const [];

  String? _notice;
  bool _noticeIsError = false;
  Timer? _noticeTimer;

  @override
  void dispose() {
    _confirmTimer?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _tapRemove(GameRoomPlayer player) {
    if (_pendingUids.contains(player.uid) || _leaving.containsKey(player.uid)) {
      return;
    }
    if (_confirmUid != player.uid) {
      _confirmTimer?.cancel();
      setState(() => _confirmUid = player.uid);
      _confirmTimer = Timer(_confirmWindow, () {
        if (mounted) setState(() => _confirmUid = null);
      });
      return;
    }
    _confirmTimer?.cancel();
    setState(() {
      _confirmUid = null;
      _pendingUids.add(player.uid);
    });
    unawaited(_remove(player));
  }

  Future<void> _remove(GameRoomPlayer player) async {
    final ok = await widget.provider.removePlayer(player.uid);
    if (!mounted) return;
    setState(() {
      _pendingUids.remove(player.uid);
      if (ok) _leaving[player.uid] = player;
    });
    if (!ok) {
      _showNotice(
        GameLocale.select(
          ko: '${player.nickname}님을 내보내지 못했어요. 다시 눌러 주세요.',
          en: "Couldn't remove ${player.nickname}. Try again.",
          zhHans: '未能移除 ${player.nickname}，请重试。',
          zhHant: '未能移除 ${player.nickname}，請重試。',
        ),
        error: true,
      );
      return;
    }
    _showNotice(
      GameLocale.select(
        ko: '${player.nickname}님을 내보냈어요',
        en: '${player.nickname} was removed',
        zhHans: '已移除 ${player.nickname}',
        zhHant: '已移除 ${player.nickname}',
      ),
    );
    await Future<void>.delayed(_collapseDuration);
    if (!mounted) return;
    setState(() {
      _leaving.remove(player.uid);
      _gone.add(player.uid);
    });
  }

  void _showNotice(String text, {bool error = false}) {
    _noticeTimer?.cancel();
    setState(() {
      _notice = text;
      _noticeIsError = error;
    });
    _noticeTimer = Timer(_noticeDuration, () {
      if (mounted) setState(() => _notice = null);
    });
  }

  /// 서버 목록에 접히는 중인 줄을 원래 자리로 끼워 넣은 표시용 목록입니다.
  List<GameRoomPlayer> _displayPlayers(List<GameRoomPlayer> live) {
    final liveUids = {for (final player in live) player.uid};
    // 다시 들어온 사람은 숨김 목록에서 뺍니다.
    _gone.removeWhere(liveUids.contains);
    final result = <GameRoomPlayer>[];
    var liveIndex = 0;
    for (final previous in _lastPlayers) {
      if (liveUids.contains(previous.uid)) {
        while (liveIndex < live.length) {
          final player = live[liveIndex++];
          result.add(player);
          if (player.uid == previous.uid) break;
        }
      } else if (_leaving.containsKey(previous.uid)) {
        result.add(_leaving[previous.uid]!);
      }
    }
    while (liveIndex < live.length) {
      result.add(live[liveIndex++]);
    }
    return [
      for (final player in result)
        if (!_gone.contains(player.uid)) player,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final live = widget.provider.players;
        final players = _displayPlayers(live);
        _lastPlayers = players;
        final counted = [
          for (final player in live)
            if (!_leaving.containsKey(player.uid) &&
                !_gone.contains(player.uid))
              player,
        ];
        final online = counted.where((player) => player.isConnected).length;
        return MosiCreamPanel(
          theme: MosiGameModalTheme.fromName(
            widget.provider.selectedGame?.name,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      GameLocale.select(
                        ko: '현재 방 정보 · 플레이어',
                        en: 'Current room · Players',
                        zhHans: '当前房间 · 玩家',
                        zhHant: '目前房間 · 玩家',
                      ),
                      style: MosiFonts.sans(
                        size: 14,
                        weight: FontWeight.w700,
                        color: MosiColors.muted,
                      ),
                    ),
                  ),
                  Text(
                    GameLocale.select(
                      ko: '$online / ${counted.length} 연결',
                      en: '$online / ${counted.length} connected',
                      zhHans: '$online / ${counted.length} 已连接',
                      zhHant: '$online / ${counted.length} 已連線',
                    ),
                    style: MosiFonts.grotesk(size: 14, color: MosiColors.navy),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final player in players)
                      _GamePlayerRow(
                        key: ValueKey('settings-player-${player.uid}'),
                        player: player,
                        confirming: _confirmUid == player.uid,
                        pending: _pendingUids.contains(player.uid),
                        leaving: _leaving.containsKey(player.uid),
                        collapseDuration: _collapseDuration,
                        onRemove: () => _tapRemove(player),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _notice == null
                    ? Text(
                        GameLocale.select(
                          ko: '연결이 끊긴 사람은 30초 동안 자리를 지켜 둬요.',
                          en: 'A disconnected player keeps their seat for 30 seconds.',
                          zhHans: '断线玩家的座位会保留 30 秒。',
                          zhHant: '斷線玩家的座位會保留 30 秒。',
                        ),
                        key: const ValueKey('settings-room-hint'),
                        style: MosiFonts.sans(
                          size: 12,
                          color: MosiColors.muted,
                        ),
                      )
                    : _RemoveNotice(
                        key: ValueKey('settings-notice-$_notice'),
                        text: _notice!,
                        error: _noticeIsError,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 강퇴 결과를 패널 아래에 잠깐 보여 주는 한 줄 안내입니다.
class _RemoveNotice extends StatelessWidget {
  const _RemoveNotice({super.key, required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFA82E40) : const Color(0xFF23722F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFDE3E6) : const Color(0xFFE4F5E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MosiColors.ink, width: 2),
      ),
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MosiFonts.sans(
                size: 13,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 설정 패널의 플레이어 한 줄입니다. 내보내면 옆으로 밀리며 접힙니다.
class _GamePlayerRow extends StatelessWidget {
  const _GamePlayerRow({
    super.key,
    required this.player,
    required this.confirming,
    required this.pending,
    required this.leaving,
    required this.collapseDuration,
    required this.onRemove,
  });

  final GameRoomPlayer player;
  final bool confirming;
  final bool pending;
  final bool leaving;
  final Duration collapseDuration;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final connected = player.isConnected;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: confirming ? const Color(0xFFFFF1F3) : MosiColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: confirming ? MosiColors.red : MosiColors.ink,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          MosiFace(characterId: player.characterId, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MosiFonts.sans(
                size: 16,
                weight: FontWeight.w700,
                color: MosiColors.navy,
              ),
            ),
          ),
          if (!confirming) ...[
            _ConnectionPill(connected: connected),
            const SizedBox(width: 8),
          ],
          _RemoveButton(
            nickname: player.nickname,
            confirming: confirming,
            pending: pending,
            onTap: onRemove,
          ),
        ],
      ),
    );
    return AnimatedSize(
      duration: collapseDuration,
      curve: Curves.easeInCubic,
      alignment: Alignment.topCenter,
      child: leaving
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: pending ? .55 : (connected ? 1 : .8),
                child: row,
              ),
            ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: connected ? '연결됨'.localized : '연결 끊김'.localized,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: connected ? const Color(0xFFE4F5E2) : const Color(0xFFFDE3E6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: connected ? const Color(0xFF3BAA4E) : MosiColors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              connected ? '연결됨'.localized : '연결 끊김'.localized,
              style: MosiFonts.sans(
                size: 12,
                weight: FontWeight.w700,
                color: connected
                    ? const Color(0xFF23722F)
                    : const Color(0xFFA82E40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 첫 탭은 "내보내기?" 확인으로 바뀌고, 두 번째 탭에 실제로 내보냅니다.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({
    required this.nickname,
    required this.confirming,
    required this.pending,
    required this.onTap,
  });

  final String nickname;
  final bool confirming;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget label;
    if (pending) {
      label = const SizedBox(
        key: ValueKey('pending'),
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFFA82E40),
        ),
      );
    } else {
      label = Text(
        confirming
            ? GameLocale.select(
                ko: '내보내기',
                en: 'Remove?',
                zhHans: '确认移除',
                zhHant: '確認移除',
              )
            : '강퇴'.localized,
        key: ValueKey(confirming),
        maxLines: 1,
        style: MosiFonts.sans(
          size: confirming ? 13 : 12,
          weight: FontWeight.w700,
          color: confirming ? MosiColors.white : const Color(0xFFA82E40),
        ),
      );
    }
    return Tooltip(
      message: '강퇴'.localized,
      child: Semantics(
        button: true,
        label: confirming
            ? GameLocale.select(
                ko: '$nickname 내보내기 확인',
                en: 'Confirm removing $nickname',
                zhHans: '确认移除 $nickname',
                zhHant: '確認移除 $nickname',
              )
            : GameLocale.select(
                ko: '$nickname 강퇴',
                en: 'Remove $nickname',
                zhHans: '移除 $nickname',
                zhHant: '移除 $nickname',
              ),
        excludeSemantics: true,
        child: GestureDetector(
          onTap: pending ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            width: confirming ? 92 : 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: confirming ? MosiColors.red : MosiColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MosiColors.ink, width: 2),
              boxShadow: confirming
                  ? const [
                      BoxShadow(color: MosiColors.ink, offset: Offset(0, 3)),
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: label,
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundSettings extends StatefulWidget {
  const _SoundSettings({required this.theme});

  final MosiGameModalTheme theme;

  @override
  State<_SoundSettings> createState() => _SoundSettingsState();
}

// 모달을 닫아도 같은 사운드 인스턴스의 복원값을 유지합니다.
// weak key이므로 provider가 사라지면 복원값도 정리됩니다.
final _volumeBeforeMute = Expando<double>('settings mute volume');

class _SoundSettingsState extends State<_SoundSettings> {
  @override
  Widget build(BuildContext context) {
    final sound = context.watch<SoundProvider>();
    final muted = sound.masterVolume == 0;
    return MosiCreamPanel(
      theme: widget.theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            GameLocale.select(
              ko: '소리',
              en: 'Sound',
              zhHans: '声音',
              zhHant: '聲音',
            ),
            style: MosiFonts.sans(
              size: 14,
              weight: FontWeight.w700,
              color: MosiColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          _SoundSlider(
            title: '전체'.localized,
            icon: Icons.volume_up_rounded,
            iconBackground: widget.theme.soundIcons[0],
            value: sound.masterVolume,
            onChanged: sound.setMasterVolume,
            accent: widget.theme.deep,
          ),
          _SoundSlider(
            title: '효과'.localized,
            icon: Icons.auto_awesome_rounded,
            iconBackground: widget.theme.soundIcons[1],
            value: sound.effectVolume,
            onChanged: sound.setEffectVolume,
            accent: widget.theme.deep,
          ),
          _SoundSlider(
            title: '배경'.localized,
            icon: Icons.music_note_rounded,
            iconBackground: widget.theme.soundIcons[2],
            value: sound.bgmVolume,
            onChanged: sound.setBgmVolume,
            accent: widget.theme.deep,
          ),
          const Spacer(),
          MosiButton(
            label: muted ? '소리 다시 켜기'.localized : '모두 음소거'.localized,
            leading: Icon(
              muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            ),
            background: muted ? const Color(0xFFFDE3E6) : MosiColors.white,
            borderWidth: 2,
            shadowOffset: 0,
            height: 48,
            fontSize: 15,
            radius: 10,
            expand: true,
            onPressed: () {
              if (muted) {
                sound.setMasterVolume(_volumeBeforeMute[sound] ?? 50);
              } else {
                _volumeBeforeMute[sound] = sound.masterVolume;
                sound.setMasterVolume(0);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SoundSlider extends StatelessWidget {
  const _SoundSlider({
    required this.title,
    required this.icon,
    required this.iconBackground,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color iconBackground;
  final double value;
  final ValueChanged<double> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MosiColors.ink, width: 2),
                ),
                child: Icon(icon, size: 18, color: MosiColors.ink),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: MosiFonts.sans(
                  size: 17,
                  weight: FontWeight.w700,
                  color: MosiColors.navy,
                ),
              ),
              const Spacer(),
              Text(
                '${value.round()}%',
                style: MosiFonts.grotesk(size: 17, color: MosiColors.navy),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              inactiveTrackColor: const Color(0x330E0A3D),
              thumbColor: MosiColors.white,
              overlayColor: accent.withValues(alpha: 0.12),
              trackHeight: 6,
              thumbShape: const _BorderedThumb(),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              divisions: 100,
              label: '$title ${value.round()}',
              semanticFormatterCallback: (v) => GameLocale.select(
                ko: '$title 소리 ${v.round()}',
                en: '$title volume ${v.round()}',
                zhHans: '$title 音量 ${v.round()}',
                zhHant: '$title 音量 ${v.round()}',
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _BorderedThumb extends SliderComponentShape {
  const _BorderedThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(24, 24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 11, Paint()..color = MosiColors.white);
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..color = MosiColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
}

/// ELEVEN 방 코드 글자: 흑·백 타일을 번갈아 놓고 스텐실 숫자 글꼴로 씁니다.
class _TileCodeChip extends StatelessWidget {
  const _TileCodeChip({required this.char, required this.dark});

  final String char;
  final bool dark;

  static const _ink = Color(0xFF141414);
  static const _cream = Color(0xFFF7F0E4);

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF1B1B1B) : _cream,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: dark ? _cream : _ink, width: 2),
      boxShadow: const [BoxShadow(color: _ink, offset: Offset(0, 3))],
    ),
    child: Text(
      char,
      style: TextStyle(
        fontFamily: 'StardosStencil',
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 1,
        color: dark ? _cream : _ink,
      ),
    ),
  );
}
