class_name Balance
extends RefCounted
## 밸런스 수치 한 곳 (기획서 5장, 6장). 조정은 여기서만 한다.

const HOUSE: int = 1
const PORT: int = 2
const BARRACKS: int = 3
const MARKET: int = 4
const FARM: int = 5
const FISHERY: int = 6 ## 낚시터
const TRADING_POST: int = 7 ## 교역소
const TOWER: int = 9 ## 방어탑
const LIBRARY: int = 10 ## 도서관 (임시명)
const LAB: int = 11 ## 연구소 (임시명)
const MINE: int = 12 ## 광산 (산 칸 전용)
const MAX_LEVEL: int = 3

## cost: 건설 골드, hp: 체력(M3부터), sand: 모래 위 건설 가능 여부, sea: 인접 바다 필요 여부
const BUILDINGS: Dictionary = {
	HOUSE: {"name": "집", "cost": 20, "hp": 50, "sand": true, "sea": false, "color": Color(0.6, 0.4, 0.2)},
	PORT: {"name": "항구", "cost": 50, "hp": 80, "tech": "sail", "sand": true, "sea": true, "color": Color(0.15, 0.25, 0.6)},
	BARRACKS: {"name": "병영", "cost": 30, "hp": 100, "sand": false, "sea": false, "any_territory": true, "color": Color(0.45, 0.45, 0.5)},
	MARKET: {"name": "시장", "cost": 50, "hp": 70, "tech": "trade", "sand": false, "sea": false, "color": Color(0.85, 0.65, 0.1)},
	FARM: {"name": "밭", "cost": 25, "hp": 50, "sand": false, "sea": false, "color": Color(0.35, 0.55, 0.2)},
	FISHERY: {"name": "낚시터", "cost": 25, "hp": 50, "sand": true, "sea": false, "on_water": true, "color": Color(0.2, 0.65, 0.75)},
	TRADING_POST: {"name": "교역소", "cost": 40, "hp": 70, "tech": "trade", "sand": true, "sea": false, "open_sea": true, "unique": true, "color": Color(0.7, 0.35, 0.75)},
	LIBRARY: {"name": "도서관", "cost": 40, "hp": 60, "sand": true, "sea": false, "color": Color(0.55, 0.35, 0.65)},
	LAB: {"name": "연구소", "cost": 80, "hp": 70, "sand": false, "sea": false, "color": Color(0.25, 0.7, 0.6)},
	MINE: {"name": "광산", "cost": 60, "hp": 100, "tech": "mining", "sand": false, "sea": false, "mountain_only": true, "color": Color(0.5, 0.45, 0.4)},
	TOWER: {"name": "방어탑", "cost": 40, "hp": 200, "tech": "archery", "sand": true, "sea": false, "color": Color(0.35, 0.4, 0.55)},
}

## 건설 메뉴 카테고리 (아래에서 위로 펼쳐지는 드롭다운) (기획서 7.2)
const CATEGORIES: Array = [
	{"name": "생산", "ids": [HOUSE, FARM, FISHERY, MINE]},
	{"name": "군사·해상", "ids": [BARRACKS, PORT, TOWER]},
	{"name": "상업", "ids": [MARKET, TRADING_POST]},
	{"name": "과학", "ids": [LIBRARY, LAB]},
]

const U_SOLDIER: int = 0
const U_PIRATE: int = 1
const U_SHIP: int = 2
const U_BOAT: int = 3
const U_ARCHER: int = 4
const U_CAVALRY: int = 5
const U_CROSSBOW: int = 6 ## 석궁수 (적)
const U_AXE: int = 7 ## 도끼병 (적)
const U_SHIELD: int = 8 ## 방패병 (적)
const U_CAPTAIN: int = 9 ## 선장 (보스 라운드의 적)
const ENEMY_KINDS: Array[int] = [U_PIRATE, U_CROSSBOW, U_AXE, U_SHIELD, U_CAPTAIN]
const SOLDIER_KINDS: Array[int] = [U_SOLDIER, U_ARCHER, U_CAVALRY] ## 병영에서 고를 수 있는 병종
const UNITS: Dictionary = {
	U_SOLDIER: {"name": "검병", "hp": 30.0, "atk": 5.0, "speed": 1.5, "reach": 0.7, "color": Color(0.2, 0.4, 1.0)},
	U_PIRATE: {"name": "해적", "hp": 25.0, "atk": 2.0, "speed": 1.2, "reach": 0.7, "color": Color(0.15, 0.05, 0.1)},
	U_SHIP: {"name": "해적선", "hp": 1.0, "atk": 0.0, "speed": 2.0, "reach": 0.7, "color": Color(0.45, 0.3, 0.15)},
	U_BOAT: {"name": "보트", "hp": 1.0, "atk": 0.0, "speed": 2.5, "reach": 0.7, "color": Color(0.85, 0.75, 0.55)},
	U_ARCHER: {"name": "궁수", "hp": 20.0, "atk": 3.0, "speed": 1.5, "reach": 2.0, "ranged": true, "color": Color(0.2, 0.75, 0.3)},
	U_CAVALRY: {"name": "기병", "hp": 40.0, "atk": 6.0, "speed": 2.5, "reach": 0.7, "color": Color(0.95, 0.55, 0.1)},
	U_CROSSBOW: {"name": "석궁수", "hp": 18.0, "atk": 3.0, "speed": 1.1, "reach": 1.8, "ranged": true, "color": Color(0.55, 0.15, 0.3)},
	U_AXE: {"name": "도끼병", "hp": 50.0, "atk": 4.0, "speed": 1.2, "reach": 0.7, "color": Color(0.45, 0.1, 0.1)},
	U_SHIELD: {"name": "방패병", "hp": 100.0, "atk": 2.5, "speed": 0.9, "reach": 0.7, "color": Color(0.3, 0.3, 0.35)},
	U_CAPTAIN: {"name": "선장", "hp": 350.0, "atk": 6.0, "speed": 1.1, "reach": 0.7, "color": Color(0.7, 0.05, 0.05)},
}
const UNIT_SCALE: Dictionary = {U_AXE: 1.1, U_SHIELD: 1.25, U_CAPTAIN: 1.6} ## 강한 적은 더 크게 그린다
const ENEMY_FIRST_WAVE: Dictionary = {U_CROSSBOW: 5, U_AXE: 8, U_SHIELD: 12, U_CAPTAIN: 10} ## 새 적이 처음 나오는 웨이브 (기획서 6장)

## 적 수 곡선의 기준점 [웨이브, 적 수]. 사이는 선형으로 이어 붙이고 반올림 (기획서 6장)
const ENEMY_CURVE: Array = [[1, 1], [2, 1], [3, 2], [4, 3], [5, 4], [6, 5], [7, 6], [8, 7], [10, 9], [15, 15], [20, 22], [25, 29], [30, 36]]
## 웨이브 구간별 종류 비율 [구간 끝 웨이브, {종류: %}]. 해적은 남는 수
const ENEMY_BANDS: Array = [
	[4, {}],
	[7, {U_CROSSBOW: 30}],
	[11, {U_CROSSBOW: 25, U_AXE: 25}],
	[17, {U_CROSSBOW: 25, U_AXE: 30, U_SHIELD: 15}],
	[999, {U_CROSSBOW: 20, U_AXE: 30, U_SHIELD: 35}],
]
const CAPTAINS: Dictionary = {10: 1, 20: 2, 30: 2} ## 보스 라운드의 선장 수
const TOWER_ATK_LV: Array[float] = [4.0, 6.0, 8.0]
const TOWER_RANGE_LV: Array[float] = [3.0, 3.5, 4.0]
const TOWER_INTERVAL: float = 1.0
const HQ_ATK: float = 3.0 ## 본부의 약한 자동 공격 (레벨과 무관) (기획서 6장)
const HQ_RANGE: float = 2.5
const HQ_HP: float = 300.0
const HQ_PIECE_WAVES: Array[int] = [10, 20] ## 이 웨이브(보스)를 이기면 본부 조각을 하나 더 놓아야 한다 (기획서 5.5)
const HQ_LOSS_RATE: float = 0.3 ## 본부가 파괴될 때마다 줄어드는 골드·식량 비율
const BUILDING_EDGE: float = 0.5 ## 건물 칸 중심에서 가장자리까지 (건물 공격 거리는 가장자리부터 잰다) (기획서 6장)
const UNIT_GAP: float = 0.3 ## 유닛끼리 이 거리보다 가까우면 서로 밀어낸다
const LUNGE_TIME: float = 0.22 ## 공격할 때 앞으로 약진했다 돌아오는 시간(초)
const LUNGE_DIST: float = 0.35 ## 약진하는 거리(칸)
const AGGRO_RANGE: float = 2.5 ## 집결지가 있을 때 병사가 이 거리 안의 적만 상대한다
const BATTLE_SPEEDS: Array[int] = [1, 2, 4] ## 전투 배속
const ATTACK_INTERVAL: float = 1.0
const PIRATES_PER_SHIP: int = 3
const MIN_PIRATES_PER_SHIP: int = 2 ## 해적선 한 척의 최소 인원. 한 명만 타고 오는 배는 없다 (기획서 6장)
const SHIP_INTERVAL: float = 3.0
const HQ_GUARDS: int = 2 ## 웨이브 시작 때 본부가 무료로 내보내는 수비병
const UNIT_TECH: Dictionary = {U_ARCHER: "archery", U_CAVALRY: "cavalry"} ## 병종을 해금하는 연구
const WAVE_TIME_LIMIT: float = 120.0 ## 이 시간이 지나면 남은 적을 정리하고 웨이브를 끝낸다
const COMBAT_PITCH: float = 55.0
const SEA_TILE_WAVE: int = 10 ## 이 웨이브보다 뒤부터 바다 칸이 섞인 타일이 후보에 나온다 (기획서 4장)
const SEA_TILE_CHANCE: float = 0.4 ## 그때 한 카드가 바다 섞인 타일일 확률
const PREP_CAM_SIZE: float = 18.0 ## 준비 단계 카메라 크기(작을수록 확대)
const COMBAT_CAM_SIZE: float = 13.5 ## 전투 카메라는 준비 단계보다 더 확대한다 (기획서 7.2)

const HQ_LEVEL_FOOD: Array[int] = [5, 12, 22, 35, 50, 70, 95, 125, 160, 200, 245, 295, 350, 410, 475, 545, 620, 700, 785] ## 본부 레벨 2~20이 되는 식량 누적량 (기획서 5.3)
const TERRITORY_SQUARE_CHANCE: float = 0.6 ## 영역 확장 때 정사각형 우선으로 고를 확률 (나머지는 무작위) (기획서 5.3)
const TERRITORY_START_RADIUS: int = 1 ## 본부 영역의 시작 크기: 본부 칸 주변 이 거리까지 (3x3) (기획서 5.3)
const GROW_EVERY: int = 2 ## 이 라운드마다 필드가 4방으로 한 줄씩 넓어진다 (기획서 3장)

const EXPLORE_COST: int = 20 ## 유적지 원정 골드 (기획서 3장)
const EXPLORE_GOLD_MIN: int = 60
const EXPLORE_GOLD_MAX: int = 100
const EXPLORE_RP_CHANCE: float = 0.3 ## 골드 대신 연구포인트 +1을 얻을 확률
const RUIN_CHANCE: float = 0.02 ## 대륙 안쪽 평원 칸이 유적지일 확률
const CONTINENT_FREQ: float = 0.05 ## 필드 밖 지형 노이즈 주파수(낮을수록 큰 대륙)
const CONTINENT_LEVEL: float = -0.1 ## 이 값보다 큰 노이즈가 땅

const SPECIAL_MAX: int = 2 ## 보상 타일 한 조각의 숲·산 칸 최대 수 (기획서 4장)
const SPECIAL_CHANCE: float = 0.3 ## 그 칸이 숲·산이 될 확률(칸마다 따로 굴림)
const MOUNTAIN_SHARE: float = 0.35 ## 숲·산 중 산일 확률
const FOREST_SPEED: float = 0.7 ## 숲 위 이동속도 배율 (아군·적 모두) (기획서 3장)
const SEA_CROSS_SPEED: float = 0.4 ## 바닷길이 막혔을 때 해적이 바다 칸을 걸어 건너는 속도 배율 (기획서 6장)
## 숲·산에 지을 수 있는 건물 (평원은 전부, 모래는 건물의 sand 값) (기획서 3장)
const FOREST_BUILDINGS: Array[int] = [HOUSE, LIBRARY, TOWER]
const MOUNTAIN_BUILDINGS: Array[int] = [TOWER, MINE]
const MINE_GOLD_LV: Array[int] = [20, 32, 48] ## 광산 정산 골드 (기획서 5.1)
const HQ_BASE_GOLD: int = 20 ## 살아 있는 본부마다 웨이브 정산 때 받는 기본 골드 (기획서 5.1)

const WIN_WAVE: int = 30 ## 이 웨이브를 이기면 승리 화면 (이후 무한 모드로 계속할 수 있다) (기획서 9.1)
const ENEMY_LAND_RATE: float = 0.035 ## 땅 10칸당 적 체력·공격 증가량 (기획서 6장)
const ENEMY_EXPAND_RATE: float = 0.07 ## 확장 1회당 적 체력·공격 증가량
const START_GOLD: int = 50
const START_FOOD: int = 20

## 건물 레벨별 수치 (인덱스 0 = 레벨 1) (기획서 5.2)
const HP_MULT: Array[float] = [1.0, 1.5, 2.0]
const HOUSE_GOLD_LV: Array[int] = [10, 16, 24] ## 모래 위는 ×1.5
const FARM_FOOD_LV: Array[int] = [5, 8, 12]
const BARRACKS_SOLDIERS_LV: Array[int] = [3, 4, 5] ## 웨이브 시작 때 한 번만 만드는 병사 수
const BARRACKS_L3_HP: float = 1.3
const PORT_CAPACITY_LV: Array[int] = [4, 6, 8]
const BOAT_SPEED_LV: Array[float] = [1.0, 1.0, 1.3]
const FISHERY_MULT_LV: Array[float] = [1.0, 1.5, 2.0]
const FISH_CAP: int = 40
const FISH_BASE: int = 3
const FISH_DIV: int = 6
const FISH_MAX: int = 9
const TRADE_INTERVAL: int = 3 ## 교역소가 있으면 이 웨이브마다 거래 NPC가 방문한다 (기획서 5.6)
const TRADE_OFFERS_LV: Array[int] = [3, 3, 3] ## 교역소 레벨별 거래 수 (거래 풀이 3종, 식량 거래 없음) (기획서 5.6)
const TRADES: Array = [
	{"id": "gold_rp", "name": "골드 60 → 연구포인트 1", "gold": 60, "food": 0},
	{"id": "gold_piece", "name": "골드 40 → 놓을 조각 +1", "gold": 40, "food": 0},
	{"id": "gold_guards", "name": "골드 30 → 다음 전투 수비병 +2", "gold": 30, "food": 0},
]
const FOOD_PER_PLAINS: int = 1
const MARKET_HOUSE_BONUS_LV: Array[float] = [0.25, 0.4, 0.6] ## 시장과 4방향으로 붙은 집의 정산 골드 보너스 (기획서 5.1)
const LIBRARY_RESEARCH_LV: Array[int] = [3, 4, 5] ## 웨이브 정산 때 얻는 연구수치 (기획서 5.4)
const LAB_RESEARCH_LV: Array[int] = [6, 8, 10]
const RESEARCH_FIRST: int = 5 ## 첫 연구포인트에 필요한 연구수치 (기획서 5.4)
const RESEARCH_STEP: int = 1 ## 포인트를 얻을 때마다 다음 기준이 이만큼 늘어난다
const HQ_RESEARCH: int = 1 ## 살아 있는 본부마다 정산 때 받는 연구수치


## 연구 (테크트리, 문명5식): 4열 13개. 비용은 열 번호(1~4점)와 같고 선행 연구를 모두 마쳐야 한다 (기획서 5.4)
## col: 열(0~3), row: 화면의 줄, pre: 선행 연구 목록
const TECHS: Dictionary = {
	"tools": {"name": "농기구", "desc": "밭 식량 +30%", "col": 0, "row": 0, "pre": []},
	"mining": {"name": "채광", "desc": "광산 해금", "col": 0, "row": 2, "pre": []},
	"archery": {"name": "궁술", "desc": "궁수·방어탑 해금", "col": 0, "row": 4, "pre": []},
	"irrigation": {"name": "관개", "desc": "평원 칸 식량 +1 → +1.5", "col": 1, "row": 0, "pre": ["tools"]},
	"cavalry": {"name": "기마술", "desc": "기병 해금", "col": 1, "row": 1, "pre": ["tools"]},
	"trade": {"name": "교역", "desc": "시장·교역소 해금", "col": 1, "row": 2, "pre": ["tools", "mining"]},
	"sail": {"name": "항해술", "desc": "항구 해금", "col": 1, "row": 3, "pre": ["mining"]},
	"harvest": {"name": "대풍작", "desc": "밭 식량 +50%", "col": 2, "row": 0, "pre": ["irrigation"]},
	"drill": {"name": "단련", "desc": "모든 병사 체력·공격 +20%", "col": 2, "row": 1, "pre": ["archery", "cavalry"]},
	"commerce": {"name": "상업", "desc": "집 골드 +20%", "col": 2, "row": 2, "pre": ["trade"]},
	"ship": {"name": "조선술", "desc": "보트 +1척, 속도 +30%", "col": 2, "row": 3, "pre": ["sail"]},
	"finance": {"name": "금융", "desc": "건설·레벨업 비용 -15%", "col": 3, "row": 2, "pre": ["commerce"]},
	"ocean": {"name": "대양 항해", "desc": "보트 탑승 +2명", "col": 3, "row": 3, "pre": ["ship"]},
}
const TECH_COLS: int = 4
const TECH_ROWS: int = 5


## 연구수치로 이미 포인트를 gained개 얻었을 때 다음 포인트에 필요한 연구수치 (기획서 5.4)
static func research_threshold(gained: int) -> int:
	return RESEARCH_FIRST + gained * RESEARCH_STEP


static func tech_cost(id: String) -> int:
	return int(TECHS[id]["col"]) + 1


static func tech_prereqs(id: String) -> Array:
	return TECHS[id]["pre"]


## 건물을 to_level로 올리는 비용: 레벨 2는 건설비 ×1, 레벨 3은 ×1.5 (기획서 5.2)
static func upgrade_cost(id: int, to_level: int) -> int:
	var base: int = BUILDINGS[id]["cost"]
	return base if to_level <= 2 else roundi(base * 1.5)


static func house_gold(level: int, sand: bool) -> int:
	return roundi(HOUSE_GOLD_LV[level - 1] * (1.5 if sand else 1.0))


## 낚시터 식량: 이어진 바다 칸 수와 레벨로 정한다 (기획서 5.1)
static func fishing_food(sea_cells: int, level: int) -> int:
	var base: int = mini(FISH_MAX, FISH_BASE + floori(mini(sea_cells, FISH_CAP) / float(FISH_DIV)))
	return floori(base * FISHERY_MULT_LV[level - 1])


## 레벨별 효과 설명 (UI)
static func effect_text(id: int, level: int) -> String:
	var i: int = level - 1
	if id == HOUSE:
		return "정산 골드 +%d (모래 위 +%d)" % [house_gold(level, false), house_gold(level, true)]
	if id == MINE:
		return "산 위에만 · 정산 골드 +%d" % MINE_GOLD_LV[i]
	if id == FARM:
		return "정산 식량 +%d" % FARM_FOOD_LV[i]
	if id == BARRACKS:
		return "웨이브 시작 병사 %d명%s" % [BARRACKS_SOLDIERS_LV[i], ", 병사 체력 +30%" if level == MAX_LEVEL else ""]
	if id == PORT:
		return "보트 탑승 %d명%s" % [PORT_CAPACITY_LV[i], ", 보트 속도 +30%" if level == MAX_LEVEL else ""]
	if id == MARKET:
		return "붙어 있는 집의 정산 골드 +%d%%" % roundi(MARKET_HOUSE_BONUS_LV[i] * 100.0)
	if id == LIBRARY:
		return "정산 연구수치 +%d (첫 %d점부터 연구포인트 1)" % [LIBRARY_RESEARCH_LV[i], RESEARCH_FIRST]
	if id == LAB:
		return "정산 연구수치 +%d (첫 %d점부터 연구포인트 1)" % [LAB_RESEARCH_LV[i], RESEARCH_FIRST]
	if id == FISHERY:
		return "물 위에 설치 · 정산 식량 +%d~%d (이어진 물가가 넓을수록)" % [fishing_food(0, level), fishing_food(FISH_CAP, level)]
	if id == TRADING_POST:
		return "%d웨이브마다 거래 NPC 방문 · 거래 %d개 · 1개만" % [TRADE_INTERVAL, TRADE_OFFERS_LV[i]]
	if id == TOWER:
		return "해적 자동 공격 %d · 사거리 %.1f칸" % [roundi(TOWER_ATK_LV[i]), TOWER_RANGE_LV[i]]
	return ""


## 웨이브 n의 해적 수: 1, 1, 2, 3, 4, ... (3웨이브부터 n-1명) (기획서 6장)
static func pirate_count(wave: int) -> int:
	return maxi(MIN_PIRATES_PER_SHIP, _curve_count(wave))


static func _curve_count(wave: int) -> int:
	var a: Array = ENEMY_CURVE
	if wave <= a[0][0]:
		return a[0][1]
	for i in range(1, a.size()):
		if wave <= a[i][0]:
			var t: float = float(wave - a[i - 1][0]) / float(a[i][0] - a[i - 1][0])
			return roundi(lerpf(float(a[i - 1][1]), float(a[i][1]), t))
	var last: Array = a[a.size() - 1]
	var prev: Array = a[a.size() - 2]
	return roundi(last[1] + float(last[1] - prev[1]) / float(last[0] - prev[0]) * (wave - last[0]))


## 웨이브의 적 구성: 종류 → 인원. 보스 라운드에는 선장이 먼저, 나머지는 구간 비율로 채우고 남는 수는 해적 (기획서 6장)
static func enemy_composition(wave: int) -> Dictionary:
	var total: int = pirate_count(wave)
	var out: Dictionary = {}
	var caps: int = mini(CAPTAINS.get(wave, 0), total)
	if caps > 0:
		out[U_CAPTAIN] = caps
	var rest: int = total - caps
	var shares: Dictionary = {}
	for band: Array in ENEMY_BANDS:
		if wave <= band[0]:
			shares = band[1]
			break
	var used: int = 0
	for kind in [U_SHIELD, U_AXE, U_CROSSBOW]:
		var n: int = floori(rest * shares.get(kind, 0) / 100.0)
		if n > 0:
			out[kind] = n
			used += n
	if rest - used > 0:
		out[U_PIRATE] = rest - used
	return out


## 해적선에 태우는 순서(강한 적이 먼저)로 늘어놓은 적 종류 목록
static func enemy_queue(wave: int) -> Array[int]:
	var q: Array[int] = []
	var comp: Dictionary = enemy_composition(wave)
	for kind in comp:
		for i in comp[kind]:
			q.append(kind)
	return q


## 이 웨이브에 처음 나오는 새 적 종류
static func new_enemy_kinds(wave: int) -> Array[int]:
	var out: Array[int] = []
	for kind in ENEMY_FIRST_WAVE:
		if ENEMY_FIRST_WAVE[kind] == wave:
			out.append(kind)
	return out


## 해적선은 한 척에 최대 PIRATES_PER_SHIP명을 태운다 (기획서 6장)
static func ship_count(wave: int) -> int:
	return ceili(pirate_count(wave) / float(PIRATES_PER_SHIP))


## 해적 체력·공격 배율: 땅 칸 수와 확장 횟수에 비례 (기획서 6장)
static func enemy_mult(land_cells: int, expansions: int) -> float:
	return 1.0 + ENEMY_LAND_RATE * (land_cells / 10.0) + ENEMY_EXPAND_RATE * expansions
