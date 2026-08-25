class_name GameState
extends Node

enum DayState {
	DAY_START,
	SERVING,
	DAY_COMPLETE,
	SUMMARY,
	SHOP,
	NEXT_DAY
}

# --- GLOBAL OYUN VE GÜN DURUMU ---
var current_day: int = 1
var current_money: float = 50.0
var current_reputation: float = 100.0

var day_state: DayState = DayState.DAY_START
var day_active: bool = false

# --- GÜNLÜK HEDEF VE İSTATİSTİKLER ---
var day_customer_target: int = 10
var customers_served: int = 0
var successful_orders: int = 0
var failed_orders: int = 0

var daily_start_money: float = 50.0
var daily_start_reputation: float = 100.0
var daily_base_revenue: float = 0.0
var daily_tips: float = 0.0
var daily_bonus: float = 0.0
var daily_wasted_cones: int = 0

# --- DONDURMA TATLARI VE SÜSLEMELERİ ÖNBELLEĞİ ---
var available_flavors: Dictionary = {}
var available_toppings: Dictionary = {}

var unlocked_flavor_ids: Array[String] = ["sade", "cikolata", "fistik", "cilek", "karamel"]
var unlocked_topping_ids: Array[String] = ["cikolata_sos", "patlayan_seker"]

# --- UPGRADE KATALOĞU ---
var upgrades: Dictionary = {}

const SAVE_PATH: String = "user://maras_savegame.json"

func _ready() -> void:
	_load_initial_flavors()
	_load_initial_toppings()
	_init_upgrade_catalog()
	_connect_signals()
	
	# Oyunu başlat
	start_day(current_day)

func _load_initial_flavors() -> void:
	var flavor_paths = [
		"res://resources/flavors/sade.tres",
		"res://resources/flavors/cikolata.tres",
		"res://resources/flavors/fistik.tres",
		"res://resources/flavors/cilek.tres",
		"res://resources/flavors/karamel.tres",
		"res://resources/flavors/muz.tres",
		"res://resources/flavors/mango.tres",
		"res://resources/flavors/bogurtlen.tres",
		"res://resources/flavors/limon.tres",
		"res://resources/flavors/nane.tres"
	]
	
	for path in flavor_paths:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is FlavorData:
				available_flavors[res.id] = res

func _load_initial_toppings() -> void:
	var topping_paths = [
		"res://resources/toppings/cikolata_sos.tres",
		"res://resources/toppings/patlayan_seker.tres",
		"res://resources/toppings/antep_fistigi.tres"
	]
	
	for path in topping_paths:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is ToppingData:
				available_toppings[res.id] = res

func _init_upgrade_catalog() -> void:
	# 1. KEPÇE GELİŞTİRMELERİ (SCOOP)
	_register_upgrade("scoop_speed", "Usta Kepçeleme", "Dondurmayı küvetten sıyırma ve oyma hızını artırır.", UpgradeData.Category.SCOOP, 5, 30.0, 1.55, 1, {"scoop_speed": 0.15})
	_register_upgrade("snap_lift", "Çevik Bilek", "Kepçeyi doldurup küvetten çıkarma ve kaldırma hızını artırır.", UpgradeData.Category.SCOOP, 5, 35.0, 1.55, 1, {"snap_speed": 0.20})
	
	# 2. KÜLAH VE DENGE GELİŞTİRMELERİ (CONE)
	_register_upgrade("cone_stability", "Geniş Külah Tabanı", "Külahın kritik devrilme açısı toleransını genişletir.", UpgradeData.Category.CONE, 5, 40.0, 1.60, 1, {"angle_tolerance": 2.5})
	_register_upgrade("recovery_torque", "Bilek Destek Gücü", "[A]/[D] tuşlarıyla külahı toparlama ve düzeltme torkunu güçlendirir.", UpgradeData.Category.CONE, 5, 45.0, 1.60, 2, {"torque_boost": 0.12})
	_register_upgrade("cushion_spring", "Şok Emici Tutuş", "Top külaha indiğinde oluşan dikey ve yatay sarsıntıyı azaltır.", UpgradeData.Category.CONE, 5, 35.0, 1.50, 2, {"cushion_damping": 0.15})
	
	# 3. MÜŞTERİ VE EKONOMİ GELİŞTİRMELERİ (CUSTOMER)
	_register_upgrade("patience_boost", "Güler Yüz & Sohbet", "Müşterilerin bekleme sabrını artırır, puan düşüşünü yavaşlatır.", UpgradeData.Category.CUSTOMER, 5, 50.0, 1.65, 1, {"patience_decay_reduction": 0.10})
	_register_upgrade("tip_mastery", "Bahşiş Cazibesi", "Tüm müşterilerden alınan bahşiş çarpanını kalıcı olarak yükseltir.", UpgradeData.Category.CUSTOMER, 5, 60.0, 1.70, 2, {"tip_multiplier_bonus": 0.15})
	
	# 4. YENİ DONDURMA TATLARI (FLAVOR UNLOCK)
	_register_resource_unlock("flavor_muz", "Muzlu Dondurma", "Menüye taze muzlu dondurma ekler. Çocukların ve turistlerin gözdesi.", UpgradeData.Category.FLAVOR, 45.0, 1, "muz", true)
	_register_resource_unlock("flavor_mango", "Tropikal Mango", "Menüye egzotik mango lezzetini katar. Yüksek fiyat getirir.", UpgradeData.Category.FLAVOR, 65.0, 2, "mango", true)
	_register_resource_unlock("flavor_bogurtlen", "Orman Böğürtleni", "Menüye orman meyveleri aroması ekler. Gurmeler bayılır.", UpgradeData.Category.FLAVOR, 80.0, 3, "bogurtlen", true)
	_register_resource_unlock("flavor_limon", "Ferah Limon", "Menüye ekşi-ferah limon lezzetini katar.", UpgradeData.Category.FLAVOR, 70.0, 3, "limon", true)
	_register_resource_unlock("flavor_nane", "Nane Ferahlığı", "Menüye ferahlatıcı nane aroması ekler.", UpgradeData.Category.FLAVOR, 95.0, 4, "nane", true)
	
	# 5. YENİ SÜSLEMELER (TOPPING UNLOCK)
	_register_resource_unlock("topping_antep_fistigi", "Hakiki Antep Fıstığı Tozu", "Külahların üzerine serpilebilecek enfes Antep Fıstığı tozu.", UpgradeData.Category.TOPPING, 55.0, 2, "antep_fistigi", false)

func _register_upgrade(id: String, d_name: String, desc: String, cat: UpgradeData.Category, max_lvl: int, b_cost: float, cost_m: float, u_day: int, effects: Dictionary) -> void:
	var up = UpgradeData.new()
	up.id = id
	up.display_name = d_name
	up.description = desc
	up.category = cat
	up.max_level = max_lvl
	up.current_level = 0
	up.base_cost = b_cost
	up.cost_multiplier = cost_m
	up.unlock_day = u_day
	up.effects_per_level = effects
	upgrades[id] = up

func _register_resource_unlock(id: String, d_name: String, desc: String, cat: UpgradeData.Category, b_cost: float, u_day: int, res_id: String, is_flavor: bool) -> void:
	var up = UpgradeData.new()
	up.id = id
	up.display_name = d_name
	up.description = desc
	up.category = cat
	up.max_level = 1
	up.current_level = 0
	up.base_cost = b_cost
	up.cost_multiplier = 1.0
	up.unlock_day = u_day
	up.unlock_resource_id = res_id
	
	# Başlangıçta zaten açıksa level 1 yap
	if is_flavor and unlocked_flavor_ids.has(res_id):
		up.current_level = 1
	elif not is_flavor and unlocked_topping_ids.has(res_id):
		up.current_level = 1
		
	upgrades[id] = up

func _connect_signals() -> void:
	EventBus.cone_dropped.connect(_on_cone_dropped)
	EventBus.cone_discarded.connect(_on_cone_discarded)

# --- UPGRADE SATIN ALMA VE GETTERLAR ---

func buy_upgrade(upgrade_id: String) -> bool:
	if not upgrades.has(upgrade_id):
		return false
		
	var up: UpgradeData = upgrades[upgrade_id]
	if up.is_maxed():
		EventBus.notification_requested.emit("Bu geliştirme maksimum seviyede!", 1.5)
		return false
		
	var cost = up.get_cost_for_next_level()
	if not remove_money(cost):
		EventBus.notification_requested.emit("Yetersiz bakiye! Gerekli: $%.2f" % cost, 1.5)
		return false
		
	up.current_level += 1
	
	# Eğer tat veya sos unlock ise havuzlara ekle
	if up.unlock_resource_id != "":
		if up.category == UpgradeData.Category.FLAVOR:
			if not unlocked_flavor_ids.has(up.unlock_resource_id):
				unlocked_flavor_ids.append(up.unlock_resource_id)
				EventBus.notification_requested.emit("YENİ TAT AÇILDI: %s!" % up.display_name, 2.5)
		elif up.category == UpgradeData.Category.TOPPING:
			if not unlocked_topping_ids.has(up.unlock_resource_id):
				unlocked_topping_ids.append(up.unlock_resource_id)
				EventBus.notification_requested.emit("YENİ SÜSLEME AÇILDI: %s!" % up.display_name, 2.5)
	else:
		EventBus.notification_requested.emit("%s Seviye %d'ye yükseltildi!" % [up.display_name, up.current_level], 2.0)
		
	save_game()
	EventBus.upgrade_purchased.emit(upgrade_id, up.current_level)
	return true

func get_upgrade_level(upgrade_id: String) -> int:
	if upgrades.has(upgrade_id):
		return upgrades[upgrade_id].current_level
	return 0

func get_upgrade_effect(upgrade_id: String, effect_key: String) -> float:
	if upgrades.has(upgrade_id):
		return upgrades[upgrade_id].get_total_effect(effect_key)
	return 0.0

func get_unlocked_flavors() -> Array[FlavorData]:
	var list: Array[FlavorData] = []
	for id in unlocked_flavor_ids:
		if available_flavors.has(id):
			list.append(available_flavors[id])
	return list

func get_unlocked_toppings() -> Array[ToppingData]:
	var list: Array[ToppingData] = []
	for id in unlocked_topping_ids:
		if available_toppings.has(id):
			list.append(available_toppings[id])
	return list

# --- GÜN DÖNGÜSÜ YÖNETİMİ ---

func start_day(day_num: int = 1) -> void:
	current_day = day_num
	day_state = DayState.SERVING
	day_active = true
	
	# Günlük hedef: 1. Gün 10 müşteri, sonraki günler +2 artar
	day_customer_target = 8 + (current_day * 2)
	customers_served = 0
	successful_orders = 0
	failed_orders = 0
	
	daily_start_money = current_money
	daily_start_reputation = current_reputation
	daily_base_revenue = 0.0
	daily_tips = 0.0
	daily_bonus = 0.0
	daily_wasted_cones = 0
	
	EventBus.day_started.emit(current_day, day_customer_target)
	EventBus.day_progress_updated.emit(customers_served, day_customer_target)
	EventBus.notification_requested.emit("GÜN %d BAŞLADI! Hedef: %d Müşteri" % [current_day, day_customer_target], 2.5)

func can_spawn_customer() -> bool:
	return day_active and (customers_served < day_customer_target)

func record_order_success(base_price: float, tip: float, bonus: float) -> void:
	if not day_active:
		return
		
	customers_served += 1
	successful_orders += 1
	daily_base_revenue += base_price
	daily_tips += tip
	daily_bonus += bonus
	
	var total_earned = base_price + tip + bonus
	add_money(total_earned)
	
	EventBus.day_progress_updated.emit(customers_served, day_customer_target)

func record_order_failed() -> void:
	if not day_active:
		return
		
	customers_served += 1
	failed_orders += 1
	
	EventBus.day_progress_updated.emit(customers_served, day_customer_target)

func check_day_completion() -> void:
	if not day_active:
		return
		
	if customers_served >= day_customer_target:
		complete_day()

func complete_day() -> void:
	if not day_active:
		return
		
	day_active = false
	day_state = DayState.SUMMARY
	
	var summary_data = get_day_summary()
	save_game()
	
	EventBus.day_completed.emit(summary_data)

func advance_to_next_day() -> void:
	current_day += 1
	start_day(current_day)

func get_day_summary() -> Dictionary:
	var total_earned = daily_base_revenue + daily_tips + daily_bonus
	var net_money_change = current_money - daily_start_money
	var rep_change = current_reputation - daily_start_reputation
	
	return {
		"day_number": current_day,
		"target_customers": day_customer_target,
		"customers_served": customers_served,
		"successful_orders": successful_orders,
		"failed_orders": failed_orders,
		"base_revenue": daily_base_revenue,
		"tips": daily_tips,
		"bonus": daily_bonus,
		"total_earned": total_earned,
		"net_money_change": net_money_change,
		"wasted_cones": daily_wasted_cones,
		"final_money": current_money,
		"final_reputation": current_reputation,
		"reputation_change": rep_change
	}

# --- PARA VE İTİBAR FONKSİYONLARI ---

func add_money(amount: float) -> void:
	current_money += amount
	EventBus.money_changed.emit(current_money, amount)

func remove_money(amount: float) -> bool:
	if current_money >= amount:
		current_money -= amount
		EventBus.money_changed.emit(current_money, -amount)
		return true
	return false

func update_reputation(diff: float) -> void:
	current_reputation = clampf(current_reputation + diff, 0.0, 100.0)
	EventBus.reputation_changed.emit(current_reputation, diff)

func get_flavor_by_id(id: String) -> FlavorData:
	return available_flavors.get(id, null)

func get_all_flavors() -> Array[FlavorData]:
	var list: Array[FlavorData] = []
	for f in available_flavors.values():
		list.append(f)
	return list

func get_topping_by_id(id: String) -> ToppingData:
	return available_toppings.get(id, null)

func get_all_toppings() -> Array[ToppingData]:
	var list: Array[ToppingData] = []
	for t in available_toppings.values():
		list.append(t)
	return list

func _on_cone_dropped() -> void:
	daily_wasted_cones += 1
	update_reputation(-1.5)

func _on_cone_discarded() -> void:
	daily_wasted_cones += 1
	update_reputation(-0.5)

# --- SAVE / LOAD SİSTEMİ ---

func save_game() -> void:
	var up_levels_dict: Dictionary = {}
	for up_id in upgrades.keys():
		up_levels_dict[up_id] = upgrades[up_id].current_level
		
	var save_dict = {
		"current_day": current_day,
		"current_money": current_money,
		"current_reputation": current_reputation,
		"unlocked_flavor_ids": unlocked_flavor_ids,
		"unlocked_topping_ids": unlocked_topping_ids,
		"upgrade_levels": up_levels_dict
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(save_dict, "\t")
		file.store_string(json_str)
		file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
		
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_err = json.parse(json_str)
	if parse_err != OK:
		return false
		
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		current_day = int(data.get("current_day", 1))
		current_money = float(data.get("current_money", 50.0))
		current_reputation = float(data.get("current_reputation", 100.0))
		
		if data.has("unlocked_flavor_ids") and typeof(data["unlocked_flavor_ids"]) == TYPE_ARRAY:
			unlocked_flavor_ids.clear()
			for f_id in data["unlocked_flavor_ids"]:
				unlocked_flavor_ids.append(str(f_id))
				
		if data.has("unlocked_topping_ids") and typeof(data["unlocked_topping_ids"]) == TYPE_ARRAY:
			unlocked_topping_ids.clear()
			for t_id in data["unlocked_topping_ids"]:
				unlocked_topping_ids.append(str(t_id))
				
		if data.has("upgrade_levels") and typeof(data["upgrade_levels"]) == TYPE_DICTIONARY:
			var lvl_dict: Dictionary = data["upgrade_levels"]
			for up_id in lvl_dict.keys():
				if upgrades.has(up_id):
					upgrades[up_id].current_level = int(lvl_dict[up_id])
					
		EventBus.money_changed.emit(current_money, 0.0)
		EventBus.reputation_changed.emit(current_reputation, 0.0)
		return true
		
	return false
