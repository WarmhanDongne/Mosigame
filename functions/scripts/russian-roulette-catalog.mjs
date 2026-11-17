/* eslint-disable max-len */

const localeMap = (ko, en, zhHans, zhHant) => Object.freeze({
  ko,
  "zh-Hans": zhHans,
  "zh-Hant": zhHant,
  en,
});
export const russianRouletteCatalog = Object.freeze({
  russian_roulette: Object.freeze({
    name: "러시안 룰렛",
    localizedNames: localeMap("러시안 룰렛", "Russian Roulette", "俄罗斯轮盘", "俄羅斯輪盤"),
    description: "행동을 비공개로 고르고 총의 방향을 바꾸며 마지막 생존자를 가리는 파티 생존 게임입니다.",
    localizedDescriptions: localeMap(
      "행동을 비공개로 고르고 총의 방향을 바꾸며 마지막 생존자를 가리는 파티 생존 게임입니다.",
      "A party survival game of secret actions, a rotating revolver, and one last survivor.",
      "一款通过秘密选择行动、转动手枪来决出最后幸存者的聚会生存游戏。",
      "一款透過秘密選擇行動、轉動手槍來決出最後幸存者的派對生存遊戲。",
    ),
    rules: "2~6명이 30초 안에 총 돌리기, 방패 사용, 아무것도 안 하기 중 하나를 비공개로 고릅니다. 총은 돌리기 수만큼 시계 방향으로 이동하고, 멈춘 대상이 방패를 쓰지 않았다면 탈락합니다. 방패는 연속으로 쓸 수 없으며 시간 초과는 아무것도 안 하기로 처리합니다. 마지막 생존자가 승리합니다.",
    localizedRules: localeMap(
      "2~6명이 30초 안에 총 돌리기, 방패 사용, 아무것도 안 하기 중 하나를 비공개로 고릅니다. 총은 돌리기 수만큼 시계 방향으로 이동하고, 멈춘 대상이 방패를 쓰지 않았다면 탈락합니다. 방패는 연속으로 쓸 수 없으며 시간 초과는 아무것도 안 하기로 처리합니다. 마지막 생존자가 승리합니다.",
      "Two to six players secretly choose Spin, Shield, or Do nothing within 30 seconds. The gun moves clockwise by the number of Spin choices. Its target is eliminated unless protected by a shield. Shields cannot be used on consecutive turns, and timeouts become Do nothing. The last survivor wins.",
      "2至6名玩家在30秒内秘密选择转动手枪、使用护盾或什么都不做。手枪按转动选择的人数顺时针移动，停下的目标若没有护盾就被淘汰。护盾不能连续使用，超时自动视为什么都不做。最后的幸存者获胜。",
      "2至6名玩家在30秒內秘密選擇轉動手槍、使用護盾或什麼都不做。手槍按轉動選擇的人數順時針移動，停下的目標若沒有護盾就被淘汰。護盾不能連續使用，逾時自動視為什麼都不做。最後的幸存者獲勝。",
    ),
    // 출시된 앱에서 로비로 바로 시작할 수 있는 무료 게임입니다.
    enabled: true,
    genres: ["파티", "심리전", "생존"],
    localizedGenres: localeMap(
      ["파티", "심리전", "생존"],
      ["Party", "Psychological", "Survival"],
      ["聚会", "心理博弈", "生存"],
      ["派對", "心理博弈", "生存"],
    ),
    minPlayers: 2,
    maxPlayers: 6,
    playTime: 5,
    order: 13,
    accessType: "free",
    storeVisible: false,
  }),
});
