/* eslint-disable require-jsdoc, valid-jsdoc, max-len */

export type PushKind = "gameStarted" | "yourTurn" | "gameFinished";

type Player = {role?: string; status?: string};
type Room = {
  status?: string;
  players?: Record<string, Player>;
  game?: {public?: {
    status?: string; turnUid?: string | null; turnDeadlineAt?: number | null;
    gameInstanceId?: string; turnSeq?: number; recovery?: {paused?: boolean};
  }};
};

export function activeParticipantUids(room: Room): string[] {
  return Object.entries(room.players ?? {})
    .filter(([, player]) => player?.role !== "controller" && player?.status === "active")
    .map(([uid]) => uid);
}

export function eventRecipients(kind: PushKind, room: Room, now: number): string[] {
  if (room.status === "closed" || room.status === "terminal") return [];
  const pub = room.game?.public;
  if (!pub) return [];
  const active = activeParticipantUids(room);
  if (kind === "gameStarted") return pub.status === "playing" ? active : [];
  if (kind === "gameFinished") return pub.status === "finished" ? active : [];
  if (pub.status !== "playing" || pub.recovery?.paused ||
      typeof pub.turnDeadlineAt !== "number" || pub.turnDeadlineAt <= now ||
      typeof pub.turnUid !== "string") return [];
  return active.includes(pub.turnUid) ? [pub.turnUid] : [];
}

export function notificationText(kind: PushKind, locale: string): {title: string; body: string} {
  const messages: Record<string, Record<PushKind, {title: string; body: string}>> = {
    korean: {
      gameStarted: {title: "게임 시작", body: "참가한 게임이 시작됐어요."},
      yourTurn: {title: "내 차례", body: "게임에서 내 차례가 됐어요."},
      gameFinished: {title: "게임 종료", body: "참가한 게임이 종료됐어요."},
    },
    english: {
      gameStarted: {title: "Game started", body: "Your game has started."},
      yourTurn: {title: "Your turn", body: "It's your turn in the game."},
      gameFinished: {title: "Game finished", body: "Your game has finished."},
    },
    simplifiedChinese: {
      gameStarted: {title: "游戏开始", body: "您参与的游戏已开始。"},
      yourTurn: {title: "轮到您了", body: "现在轮到您行动。"},
      gameFinished: {title: "游戏结束", body: "您参与的游戏已结束。"},
    },
    traditionalChinese: {
      gameStarted: {title: "遊戲開始", body: "您參與的遊戲已開始。"},
      yourTurn: {title: "輪到您了", body: "現在輪到您行動。"},
      gameFinished: {title: "遊戲結束", body: "您參與的遊戲已結束。"},
    },
  };
  return (messages[locale] ?? messages.korean)[kind];
}
