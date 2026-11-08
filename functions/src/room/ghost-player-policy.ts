/** 게임 종료가 확인된 뒤 끊긴 참가자를 정리하기까지의 유예입니다.
 *
 * 게임 중단의 재접속 유예(60초, `GAME_INTERRUPTION_VOTE_MS`)보다 충분히 길어야
 * 합니다. 짧게 잡으면 재접속 유예 중인 정상 참가자를 지웁니다.
 */
import {currentPresence} from "./current-presence.js";
import type {SessionRoom} from "./session-contract.js";
export const GHOST_PLAYER_GRACE_MS = 5 * 60 * 1000;

type GhostPlayer = {
  isConnected?: unknown;
  lastSeen?: unknown;
  role?: unknown;
  status?: unknown;
};

type GhostCleanupState = {
  roomStatus: unknown;
  gameStatus?: unknown;
  players: Record<string, GhostPlayer>;
  now: number;
  graceMs?: number;
  room?: SessionRoom;
};

/**
 * 방에서 지워야 할 유령 참가자 UID를 고릅니다.
 *
 * **왜 필요한가.** 종료된 게임에서 연결을 끝낸 참가자 노드가
 * 영구히 남지 않게 합니다. 다만 실행 중인 게임·대기실은 연결이
 * 오래 끊겨도 자동 퇴장시키지 않아야 동일 membership로 복귀할 수 있습니다.
 *
 * **판정 기준 세 가지.**
 * 1. 게임 종료가 확인되지 않은 방에서는 아무도 지우지 않습니다.
 * 2. `isConnected !== false`인 참가자는 지우지 않습니다. 값이 없는 옛 노드도
 *    살아 있는 것으로 봅니다(지우는 쪽이 되돌릴 수 없으므로 보수적으로).
 * 3. `lastSeen`이 유예보다 오래된 경우만 지웁니다. `lastSeen`이 아예 없으면
 *    판단 근거가 없으므로 남깁니다.
 *
 * @param {GhostCleanupState} state 현재 방 상태와 참가자입니다.
 * @return {string[]} 지울 참가자 UID입니다. 정렬은 하지 않습니다.
 */
export function findGhostPlayers(state: GhostCleanupState): string[] {
  const roomStatus = state.roomStatus ?? "waiting";
  if (state.gameStatus === "playing") return [];
  const isFinished = state.gameStatus === "finished" ||
    ["finished", "closed", "terminal"].includes(String(roomStatus));
  if (!isFinished) return [];

  const graceMs = state.graceMs ?? GHOST_PLAYER_GRACE_MS;
  const ghosts: string[] = [];
  for (const [uid, rawPlayer] of Object.entries(state.players ?? {})) {
    if (!rawPlayer || typeof rawPlayer !== "object") continue;
    const player = rawPlayer as GhostPlayer;
    // 관전자·이미 비활성 처리된 노드는 이 정리의 대상이 아닙니다.
    if ((player.role ?? "player") !== "player") continue;
    const current = state.room ?
      currentPresence(state.room, uid, "player") : undefined;
    if (state.room?.presenceProtocol === 2 && !current) continue;
    if (current?.connected) continue;
    if (!current && player.isConnected !== false) continue;
    const lastSeen = current?.lastSeen ?? player.lastSeen;
    if (typeof lastSeen !== "number" || !Number.isFinite(lastSeen)) continue;
    if (state.now - lastSeen <= graceMs) continue;
    ghosts.push(uid);
  }
  return ghosts;
}
