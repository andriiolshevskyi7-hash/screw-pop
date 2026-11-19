class_name Economy
extends RefCounted
## Усі ціни та нагороди в одному місці — зручно балансувати.
##
## Баланс 1.7: усі нагороди монетами за гру зменшено на 20% (×0.8, округлено
## до кратних 5), тож на ту саму покупку потрібно ~25% більше рівнів. Ціни не
## змінювались. Доплата за rewarded-рекламу НЕ зменшена: вона дорівнює старій
## (до знижки) нагороді — див. `ad_bonus()`, тож реклама стала відносно вигіднішою.

## Стартовий баланс нового гравця (не нагорода за гру — не змінювався).
const START_COINS := 200

## У скільки разів зменшено нагороди за гру.
const REWARD_SCALE := 0.8

## Нагорода за рівень до знижки: база + бонус за серію перемог + зірки;
## гравець отримує `nice(сума × REWARD_SCALE)` — див. level_reward().
const LEVEL_REWARD := 25
const STREAK_BONUS_PER_WIN := 3
const STREAK_BONUS_MAX := 15
const DAILY_REWARD := 60

## Бонус за кожну зірку понад першу (3 зірки — рівень без допомоги), до знижки.
const STAR_BONUS := 10

## Скриня: заповнюється кожні N пройдених рівнів, відкривається натисканням.
const CHEST_EVERY := 10
## Монети в скрині: випадково в цих межах (крок 10). Було 100–200.
const CHEST_COINS_MIN := 80
const CHEST_COINS_MAX := 160
## Ймовірність (0–1), що в скрині буде ще й бустер.
const CHEST_BOOSTER_CHANCE := 0.45

## Бустери в запасі гравця (з колеса та скрині).
const BOOSTER_SLOT := "slot"
const BOOSTER_UNDO := "undo"
const BOOSTER_HAMMER := "hammer"
const BOOSTERS := [BOOSTER_SLOT, BOOSTER_UNDO, BOOSTER_HAMMER]

## Монети за перегляд реклами в магазині / меню (rewarded — не зменшувались).
const AD_COINS := 100

## Безкоштовні скасування ходу на кожен рівень (далі — реклама або монети).
const FREE_UNDOS_PER_LEVEL := 3

## Ціни бустерів.
const PRICE_UNDO := 20
const PRICE_HAMMER := 50
const PRICE_SLOT := 60

## Щоденний бонус: нагорода за 1–7 день поспіль (потім цикл повторюється).
## Було [20, 30, 40, 60, 80, 100, 250].
const DAILY_BONUS := [15, 25, 30, 50, 65, 80, 200]

## Колесо фортуни: сектори (монети або бустери) і ваги ймовірності.
## Великі призи рідкісні: 160 монет — 2%, додаткова колба — 6%.
## Монети було: 20, 50, 30, 200, 100, 40.
const WHEEL_SECTORS := [
	{"type": "coins", "amount": 15, "weight": 18},
	{"type": BOOSTER_HAMMER, "amount": 1, "weight": 10},
	{"type": "coins", "amount": 40, "weight": 12},
	{"type": BOOSTER_UNDO, "amount": 3, "weight": 14},
	{"type": "coins", "amount": 25, "weight": 16},
	{"type": "coins", "amount": 160, "weight": 2},
	{"type": BOOSTER_SLOT, "amount": 1, "weight": 6},
	{"type": "coins", "amount": 80, "weight": 6},
	{"type": "coins", "amount": 30, "weight": 16},
]
## Додаткових обертань за рекламу на день.
const WHEEL_AD_SPINS := 3

## Скільки разів за рівень можна продовжити після програшу (+1 місце в буфері за рекламу).
const MAX_CONTINUES := 2


## «Гарне» число: кратне 5 (щонайменше 5 для ненульових сум).
static func nice(x: float) -> int:
	if x <= 0.0:
		return 0
	return maxi(5, int(round(x / 5.0)) * 5)


## Нагорода за рівень до знижки (як до версії 1.7).
static func level_reward_unscaled(win_streak: int, is_daily: bool, stars: int = 1) -> int:
	var star_bonus := (clampi(stars, 1, 3) - 1) * STAR_BONUS
	if is_daily:
		return DAILY_REWARD + star_bonus
	return LEVEL_REWARD + mini(maxi(win_streak - 1, 0) * STREAK_BONUS_PER_WIN, STREAK_BONUS_MAX) + star_bonus


static func level_reward(win_streak: int, is_daily: bool, stars: int = 1) -> int:
	return nice(level_reward_unscaled(win_streak, is_daily, stars) * REWARD_SCALE)


## Доплата за перегляд rewarded-реклами до нагороди `amount` (щоденний бонус,
## скриня): нагорода до знижки, округлена вгору до кратного 5 — реклама дає не
## менше, ніж до версії 1.7 (раніше — «×2», тепер ≈ ×2.25).
static func ad_bonus(amount: int) -> int:
	return int(ceil(amount / REWARD_SCALE / 5.0 - 0.0001)) * 5


## Доплата за рекламу на екрані перемоги — рівно стара (до знижки) нагорода за рівень.
static func level_ad_bonus(win_streak: int, is_daily: bool, stars: int = 1) -> int:
	return level_reward_unscaled(win_streak, is_daily, stars)


## Зірки за рівень: 3 — без допомоги, 2 — до двох бустерів/продовжень.
static func stars_for(assists: int) -> int:
	if assists <= 0:
		return 3
	return 2 if assists <= 2 else 1


## Випадковий сектор колеса з урахуванням ваг.
static func pick_wheel_sector(rng: RandomNumberGenerator) -> int:
	var total := 0
	for sector in WHEEL_SECTORS:
		total += int(sector.weight)
	var roll := rng.randi_range(1, total)
	for i in WHEEL_SECTORS.size():
		roll -= int(WHEEL_SECTORS[i].weight)
		if roll <= 0:
			return i
	return 0


## Вміст скрині: {"coins": N, "boosters": {id: count}}.
static func roll_chest(rng: RandomNumberGenerator) -> Dictionary:
	var coins := rng.randi_range(CHEST_COINS_MIN / 10, CHEST_COINS_MAX / 10) * 10
	var boosters := {}
	if rng.randf() < CHEST_BOOSTER_CHANCE:
		var pick: String = BOOSTERS[rng.randi_range(0, BOOSTERS.size() - 1)]
		boosters[pick] = 3 if pick == BOOSTER_UNDO else 1
	return {"coins": coins, "boosters": boosters}
