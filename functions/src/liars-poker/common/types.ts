/* eslint-disable max-len */

import {PublicGameInterruption, ServerGameInterruption} from "../../game-interruption/types.js";

/** 라이어스 포커는 오직 진실·거짓 카드만 사용합니다. */
export const CARD_RANKS = ["TRUTH", "LIE"] as const;

export type CardRank = typeof CARD_RANKS[number];

export const TURN_DURATION_MS = 30000;
export const LAST_CARD_CHALLENGE_DURATION_MS = 10000;

export interface GameCard {
  id: string;
  rank: CardRank;
}

export interface PublicGamePlayer {
  uid: string;
  nickname: string;
  characterId: string;
  seatIndex: number;
  status: "alive" | "eliminated";
  penaltyCount: number;
  remainingCardCount: number;
}

export interface PublicLastPlay {
  playId: string;
  round: number;
  playerUid: string;
  cardCount: number;
  /** 모든 제출은 "진실"이라고 주장합니다. 배포 키는 호환을 위해 유지합니다. */
  declaredRank: "TRUTH";
  revealed: boolean;
  actualRanks?: CardRank[];
  submittedAt: number;
}

export interface PublicPenaltyResult {
  targetUid: string;
  result: "safe" | "eliminated";
  resolvedAt: number;
}

export interface PublicGameState {
  /** 다른 게임 상태를 같은 room.game 경로에서 잘못 읽는 것을 막는 판별자입니다. */
  gameType?: "liars_poker";
  status: "playing" | "finished";
  finishReason?: "winner" | "manual" | "insufficientPlayers" | "interruptionVoteExpired";
  phase: "dealing" | "playing" | "lastCardChallenge" | "penalty" |
    "finished";
  round: number;
  revision: number;
  /**
   * 기존 클라이언트의 table 키를 유지한 고정 선언값입니다. 새 규칙에는
   * 매 라운드 기준 랭크가 없으며, 모든 제출은 진실 카드라고 주장합니다.
   */
  table: "TRUTH";
  /** 이번 라운드 전체 덱의 진실·거짓 수와 분배 후 남겨 둔 카드 수입니다. */
  truthCardCount: number;
  lieCardCount: number;
  unrevealedCardCount: number;
  turnUid: string | null;
  turnDeadlineAt: number | null;
  isFirstTurnReady?: boolean;
  lastPlay: PublicLastPlay | null;
  /** 현재 라운드에 제출된 공개 카드 묶음입니다. 실제 랭크는 공개 전까지 없습니다. */
  roundPlays?: Record<string, PublicLastPlay>;
  penaltyTargetUid: string | null;
  penaltyResult?: PublicPenaltyResult;
  winnerUid: string | null;
  players: Record<string, PublicGamePlayer>;
  startedAt: number;
  updatedAt: number;
  finishedAt?: number;
  interruption?: PublicGameInterruption;
}

export interface PrivatePlayerState {
  hand: Record<string, GameCard>;
}

export interface ProcessedCommand {
  uid: string;
  type: string;
  createdAt: number;
  result: Record<string, unknown>;
}

export interface ServerGameState {
  lastPlayCards: GameCard[] | null;
  processedCommands: Record<string, ProcessedCommand>;
  roundStarterUid: string;
  /** 마지막 카드 도전의 LIAR 실패로 룰렛 전에 penaltyCount를 올렸는지 표시합니다. */
  penaltyCountIncrementedBeforeRoulette?: boolean;
  /** 서버가 추첨하고 태블릿 연출 완료를 기다리는 벌칙 결과입니다. */
  pendingPenaltyResolution?: {
    resolutionId: string;
    targetUid: string;
    result: "safe" | "eliminated";
    createdAt: number;
  };
  /** 태블릿 배분 연출이 끝나기 전까지 클라이언트에 공개하지 않는 손패입니다. */
  pendingHands?: Record<string, PrivatePlayerState>;
  /**
   * 분배하지 않은 3장입니다. 클라이언트가 읽을 수 없는 server 경로에만
   * 보관하며, 라운드 종료·판정 뒤에도 공개하지 않습니다.
   */
  unrevealedCards?: GameCard[];
  interruption?: ServerGameInterruption;
}

export interface LiarsPokerGameState {
  public: PublicGameState;
  private: Record<string, PrivatePlayerState>;
  server: ServerGameState;
}

export interface RealtimeRoom {
  controllerUid?: string;
  controllerSessionId?: string;
  hostUid?: string;
  status?: string;
  selectedGame?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: LiarsPokerGameState;
}
