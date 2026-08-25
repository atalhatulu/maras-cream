class_name OrderData
extends Resource

enum OrderType {
	NORMAL,        # 2 - 4 Top standart
	LARGE,         # 4 - 7 Top büyük
	TOWER,         # 8 - 14 Top dev kule
	MIXED,         # Çok çeşitli aromalar
	FLAVOR_FOCUS,  # Aynı aromadan çoklu top (Örn: 3x Çikolata)
	TOPPING_FOCUS  # Sos ve süsleme ağırlıklı
}

@export var order_id: String = ""
@export var order_type: OrderType = OrderType.NORMAL
@export var flavors: Array[FlavorData] = []
@export var toppings: Array[ToppingData] = []
@export var current_score: float = 5.0
@export var min_score: float = 2.5
@export var score_decay_rate: float = 0.032
@export var difficulty: float = 1.0 # 1.0 - 5.0

var is_active: bool = false
var is_completed: bool = false

func calculate_difficulty(balance_tolerance: float = 1.0) -> float:
	var scoop_count = flavors.size()
	var unique_flavors: Dictionary = {}
	for f in flavors:
		unique_flavors[f.id] = true
	var unique_count = unique_flavors.size()
	var top_count = toppings.size()
	
	var score = 1.0
	
	# 1. Top Sayısı Zorluğu
	if scoop_count <= 3:
		score += 0.4
	elif scoop_count <= 7:
		score += 1.4
	else:
		score += 2.8
		
	# 2. Çeşitlilik / Odak Zorluğu
	score += float(unique_count) * 0.15
	
	# 3. Sos Zorluğu
	score += float(top_count) * 0.35
	
	# 4. Külah Denge Hassasiyeti (Düşük tolerans = Yüksek zorluk)
	if balance_tolerance < 0.85:
		score += 0.6
	elif balance_tolerance > 1.15:
		score -= 0.3
		
	difficulty = clampf(score, 1.0, 5.0)
	return difficulty

func get_flavor_counts_summary() -> Array[Dictionary]:
	var summary: Array[Dictionary] = []
	var count_map: Dictionary = {}
	var ref_map: Dictionary = {}
	
	for f in flavors:
		if not count_map.has(f.id):
			count_map[f.id] = 0
			ref_map[f.id] = f
		count_map[f.id] += 1
		
	for f_id in count_map.keys():
		summary.append({
			"flavor": ref_map[f_id],
			"count": count_map[f_id]
		})
	return summary

func check_progress(prepared_flavors: Array[FlavorData], prepared_toppings: Array[ToppingData] = []) -> Dictionary:
	var total_required_flavors = flavors.size()
	var current_prep_count = prepared_flavors.size()
	
	# 1. Aroma Havuzu Kontrolü (Multiset)
	var needed_flavor_pool: Array[FlavorData] = flavors.duplicate()
	var matched_flavors: Array[FlavorData] = []
	var invalid_flavors: Array[FlavorData] = []
	
	for prepared in prepared_flavors:
		var found_index = -1
		for i in range(needed_flavor_pool.size()):
			if needed_flavor_pool[i].id == prepared.id:
				found_index = i
				break
				
		if found_index != -1:
			matched_flavors.append(prepared)
			needed_flavor_pool.remove_at(found_index)
		else:
			invalid_flavors.append(prepared)
			
	var is_flavors_completed = (needed_flavor_pool.is_empty() and invalid_flavors.is_empty() and current_prep_count == total_required_flavors)
	
	# 2. Sos ve Süsleme Kontrolü
	var needed_topping_pool: Array[ToppingData] = toppings.duplicate()
	var matched_toppings: Array[ToppingData] = []
	var extra_toppings: Array[ToppingData] = []
	
	for prep_top in prepared_toppings:
		var found_top_idx = -1
		for j in range(needed_topping_pool.size()):
			if needed_topping_pool[j].id == prep_top.id:
				found_top_idx = j
				break
				
		if found_top_idx != -1:
			matched_toppings.append(prep_top)
			needed_topping_pool.remove_at(found_top_idx)
		else:
			extra_toppings.append(prep_top)
			
	var is_toppings_satisfied = needed_topping_pool.is_empty()
	var is_fully_completed = (is_flavors_completed and is_toppings_satisfied)
	var is_valid_so_far = invalid_flavors.is_empty()
	
	return {
		"is_completed": is_fully_completed,
		"is_valid_so_far": is_valid_so_far,
		"matched_flavors": matched_flavors,
		"needed_pool": needed_flavor_pool,
		"invalid_flavors": invalid_flavors,
		"matched_toppings": matched_toppings,
		"needed_toppings": needed_topping_pool,
		"extra_toppings": extra_toppings,
		"total_required": total_required_flavors,
		"prep_count": current_prep_count,
		"total_toppings_required": toppings.size(),
		"prep_toppings_count": prepared_toppings.size()
	}
