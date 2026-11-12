/* eslint-disable valid-jsdoc */

/** Public pre-join room profiles. Never include UID or session data. */
export const ROOM_PROFILE_RECONNECT_GRACE_MS = 90 * 1000;

export type RoomProfilePreviewSource = {
  nickname?: unknown;
  characterId?: unknown;
  role?: unknown;
  status?: unknown;
  isConnected?: unknown;
  lastSeen?: unknown;
};

export type RoomJoinPreviewPlayer = {
  nickname: string;
  characterId: string;
  reservationExpiresAt?: number;
};

/** Whether this participant still reserves its nickname and character. */
export function isRoomProfileReserved(
  player: RoomProfilePreviewSource | undefined,
  now: number,
): boolean {
  if (!player || (player.role !== undefined && player.role !== "player") ||
      (player.status !== undefined && player.status !== "active")) {
    return false;
  }
  if (player.isConnected !== false) return true;
  const lastSeen = player.lastSeen;
  return typeof lastSeen === "number" && Number.isFinite(lastSeen) &&
    now < lastSeen + ROOM_PROFILE_RECONNECT_GRACE_MS;
}

/** Builds the only participant data readable before joining a room. */
export function buildRoomJoinPreview(
  players: Record<string, RoomProfilePreviewSource> | undefined,
  now: number,
): {participants: RoomJoinPreviewPlayer[]; updatedAt: number} {
  const participants = Object.values(players ?? {})
    .filter((player) => isRoomProfileReserved(player, now))
    .flatMap((player) => {
      if (typeof player.nickname !== "string" ||
          typeof player.characterId !== "string") return [];
      const lastSeen = player.lastSeen;
      const reservationExpiresAt = player.isConnected === false &&
          typeof lastSeen === "number" && Number.isFinite(lastSeen) ?
        lastSeen + ROOM_PROFILE_RECONNECT_GRACE_MS : undefined;
      return [{nickname: player.nickname, characterId: player.characterId,
        ...(reservationExpiresAt === undefined ? {} : {reservationExpiresAt})}];
    })
    .sort((a, b) => a.nickname.localeCompare(b.nickname) ||
      a.characterId.localeCompare(b.characterId));
  return {participants, updatedAt: now};
}
