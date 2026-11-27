extends Node
## 오토로드: 판 상태 — 자원과 웨이브 (기획서 5장, 7.5)

signal changed

var gold: int = Balance.START_GOLD
var food: int = Balance.START_FOOD
var wave: int = 1
var research_points: int = 0 ## 연구수치가 기준을 넘을 때마다 +1 (기획서 5.4)
var research_progress: int = 0 ## 아직 연구포인트가 못 된 연구수치
var research_gained: int = 0 ## 연구수치로 얻은 연구포인트 수 (다음 기준을 정한다) (기획서 5.4)
var researched: Dictionary = {} ## 연구를 마친 항목 id → true (기획서 5.4)
var run_seed: int = randi() ## 이 판의 적 구성을 정하는 값. 같은 웨이브는 예고와 전투에서 같은 구성이 나온다 (기획서 6장)


func reset() -> void:
	gold = Balance.START_GOLD
	food = Balance.START_FOOD
	wave = 1
	research_points = 0
	research_progress = 0
	research_gained = 0
	researched.clear()
	run_seed = randi()
	changed.emit()


func add(g: int, f: int) -> void:
	gold += g
	food += f
	changed.emit()


## 연구수치를 쌓고 기준을 넘은 만큼 연구포인트로 바꾼다. 얻은 연구포인트를 돌려 준다 (기획서 5.4)
func add_research_progress(n: int) -> int:
	research_progress += n
	var gained: int = 0
	while research_progress >= Balance.research_threshold(research_gained):
		research_progress -= Balance.research_threshold(research_gained)
		research_gained += 1
		gained += 1
	research_points += gained
	changed.emit()
	return gained


## 본부가 파괴되면 보유 골드·식량이 rate만큼 줄어든다(내림) (기획서 5.5)
func lose_share(rate: float) -> void:
	gold = floori(gold * (1.0 - rate))
	food = floori(food * (1.0 - rate))
	changed.emit()


func add_research(n: int) -> void:
	research_points += n
	changed.emit()


func has_tech(id: String) -> bool:
	return researched.has(id)


## 포인트가 충분하고 앞 단계를 마쳤으며 아직 안 한 연구인지
func can_research(id: String) -> bool:
	if researched.has(id):
		return false
	for pre: String in Balance.tech_prereqs(id):
		if not researched.has(pre):
			return false
	return research_points >= Balance.tech_cost(id)


func research(id: String) -> bool:
	if not can_research(id):
		return false
	research_points -= Balance.tech_cost(id)
	researched[id] = true
	changed.emit()
	return true


## 공학을 연구하면 건물 레벨업 비용이 20% 싸진다 (기획서 5.4)
func upgrade_discounted(cost: int) -> int:
	return roundi(cost * (1.0 - Balance.ENGINEERING_UPGRADE_DISCOUNT if has_tech("engineering") else 1.0))


func spend(cost: int, food_cost: int = 0) -> bool:
	if gold < cost or food < food_cost:
		return false
	gold -= cost
	food -= food_cost
	changed.emit()
	return true


func next_wave() -> void:
	wave += 1
	changed.emit()
