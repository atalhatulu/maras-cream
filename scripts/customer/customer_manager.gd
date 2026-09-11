class_name CustomerManager
extends Node

@export var customer_scene: PackedScene
@export var spawn_marker: Marker3D
@export var counter_marker: Marker3D
@export var next_customer_delay: float = 1.5

var active_customer: Customer = null
var active_order: OrderData = null
var active_archetype: CustomerArchetype = null

var _last_cone_flavors: Array[FlavorData] = []
var _last_cone_toppings: Array[ToppingData] = []
var _is_order_ready_to_deliver: bool = false
var _archetypes: Array[CustomerArchetype] = []
var _spawn_timer: SceneTreeTimer = null
var _last_archetype_type: int = -1
var _active_trick_count: int = 0
var _active_flip_count: int = 0
var _active_clutch_saved: bool = false

func _ready() -> void:
	_init_archetypes()
	EventBus.day_started.connect(_on_day_started)
	EventBus.bell_rung.connect(_on_bell_rung)
	EventBus.cone_state_changed.connect(_on_cone_state_changed)
	EventBus.topping_added_to_cone.connect(_on_topping_added_to_cone)
	EventBus.order_delivery_attempted.connect(_on_order_delivery_attempted)
	EventBus.cone_discarded.connect(_on_cone_discarded)
	EventBus.cone_dropped.connect(_on_cone_dropped)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.customer_arrived.connect(_on_customer_arrived)
	EventBus.maras_trick_performed.connect(func(cnt, _mult): _active_trick_count = cnt)
	EventBus.cone_flipped.connect(func(is_flip): if is_flip: _active_flip_count += 1)
	EventBus.clutch_catch_succeeded.connect(func(): _active_clutch_saved = true)
	
	if GameManager.can_spawn_customer():
		_schedule_next_customer(1.0)

func _init_archetypes() -> void:
	# 1. Aceleci İş İnsanı (2 - 4 Top, Yüksek Hız, Düşük Sabır)
	var bus = CustomerArchetype.new()
	bus.type = CustomerArchetype.ArchetypeType.BUSINESS
	bus.title_name = "İş İnsanı"
	bus.badge_tag = "💼 Aceleci (2x Bahşiş)"
	bus.body_color = Color(0.15, 0.16, 0.20, 1.0)
	bus.hat_color = Color(0.12, 0.12, 0.14, 1.0)
	bus.scale_factor = Vector3(1.02, 1.06, 1.02)
	bus.walk_speed = 3.0
	bus.min_scoops = 2
	bus.max_scoops = 4
	bus.topping_chance = 0.35
	bus.two_toppings_chance = 0.10
	bus.score_decay_rate = 0.048
	bus.patience_grace_time = 9.0
	bus.balance_tolerance = 0.90
	bus.tip_multiplier = 2.0
	bus.reputation_bonus = 1.2
	bus.order_complexity = 0.8
	bus.focus_flavor_chance = 0.35
	_archetypes.append(bus)
	
	# 2. Meraklı Turist (4 - 7 Top, Yüksek Sabır, Sos Meraklısı)
	var tour = CustomerArchetype.new()
	tour.type = CustomerArchetype.ArchetypeType.TOURIST
	tour.title_name = "Turist"
	tour.badge_tag = "📸 Meraklı Turist"
	tour.body_color = Color(0.22, 0.45, 0.75, 1.0)
	tour.hat_color = Color(0.92, 0.90, 0.85, 1.0)
	tour.scale_factor = Vector3(1.0, 1.0, 1.0)
	tour.walk_speed = 2.2
	tour.min_scoops = 4
	tour.max_scoops = 7
	tour.topping_chance = 0.80
	tour.two_toppings_chance = 0.40
	tour.score_decay_rate = 0.022
	tour.patience_grace_time = 18.0
	tour.balance_tolerance = 1.10
	tour.tip_multiplier = 1.5
	tour.reputation_bonus = 1.8
	tour.order_complexity = 1.2
	tour.focus_flavor_chance = 0.20
	_archetypes.append(tour)
	
	# 3. Tatlı Düşkünü Çocuk (5 - 9 Top, Karışık ve Bol Soslu)
	var child = CustomerArchetype.new()
	child.type = CustomerArchetype.ArchetypeType.CHILD
	child.title_name = "Çocuk"
	child.badge_tag = "🧒 Çılgın Kule (Sabırlı)"
	child.body_color = Color(0.85, 0.25, 0.28, 1.0)
	child.hat_color = Color(0.95, 0.75, 0.18, 1.0)
	child.scale_factor = Vector3(0.78, 0.78, 0.78)
	child.walk_speed = 2.0
	child.min_scoops = 5
	child.max_scoops = 9
	child.topping_chance = 0.95
	child.two_toppings_chance = 0.60
	child.score_decay_rate = 0.014
	child.patience_grace_time = 22.0
	child.balance_tolerance = 1.25
	child.tip_multiplier = 1.2
	child.topping_bonus = 4.0
	child.reputation_bonus = 1.5
	child.order_complexity = 1.4
	child.focus_flavor_chance = 0.15
	_archetypes.append(child)
	
	# 4. Titiz Gurme (4 - 7 Top, Denge ve Lezzette Çok Hassas)
	var gour = CustomerArchetype.new()
	gour.type = CustomerArchetype.ArchetypeType.GOURMET
	gour.title_name = "Gurme"
	gour.badge_tag = "⭐ Titiz Gurme (+İtibar)"
	gour.body_color = Color(0.42, 0.12, 0.16, 1.0)
	gour.hat_color = Color(0.15, 0.15, 0.15, 1.0)
	gour.scale_factor = Vector3(1.0, 1.02, 1.0)
	gour.walk_speed = 1.9
	gour.min_scoops = 4
	gour.max_scoops = 7
	gour.topping_chance = 0.60
	gour.two_toppings_chance = 0.25
	gour.score_decay_rate = 0.026
	gour.patience_grace_time = 12.0
	gour.balance_tolerance = 0.75 # Çok hassas denge
	gour.tip_multiplier = 2.5
	gour.reputation_bonus = 3.0
	gour.order_complexity = 0.9
	gour.focus_flavor_chance = 0.40
	_archetypes.append(gour)
	
	# 5. Sosyal Medya Fenomeni / Kule Avcısı (8 - 14 TOP REKOR KULE!)
	var inf = CustomerArchetype.new()
	inf.type = CustomerArchetype.ArchetypeType.INFLUENCER
	inf.title_name = "Fenomen"
	inf.badge_tag = "🏆 REKOR KULE (4x Bahşiş!)"
	inf.body_color = Color(0.75, 0.25, 0.85, 1.0)
	inf.hat_color = Color(0.10, 0.85, 0.75, 1.0)
	inf.scale_factor = Vector3(1.04, 1.04, 1.04)
	inf.walk_speed = 2.4
	inf.min_scoops = 8
	inf.max_scoops = 14
	inf.topping_chance = 0.98
	inf.two_toppings_chance = 0.75
	inf.score_decay_rate = 0.012
	inf.patience_grace_time = 25.0
	inf.balance_tolerance = 1.0
	inf.tip_multiplier = 4.0
	inf.reputation_bonus = 5.0
	inf.order_complexity = 1.5
	inf.focus_flavor_chance = 0.20
	_archetypes.append(inf)

func _on_day_started(_day_num: int, _target: int) -> void:
	if GameManager.can_spawn_customer() and active_customer == null:
		_schedule_next_customer(1.0)

func _schedule_next_customer(delay: float) -> void:
	if not GameManager.can_spawn_customer():
		return
		
	_spawn_timer = get_tree().create_timer(delay)
	_spawn_timer.timeout.connect(func():
		_spawn_timer = null
		_spawn_next_customer()
	)

func pick_weighted_archetype() -> CustomerArchetype:
	var current_day = GameManager.current_day
	var total_weight = 0.0
	var weights: Array[float] = []
	
	for arch in _archetypes:
		var w = arch.get_spawn_weight_for_day(current_day)
		if arch.type == _last_archetype_type:
			w *= 0.35 # Arka arkaya aynı arketipin gelmesini %65 oranında azalt
			
		# Günün Olayı Çarpanı
		if GameManager.current_daily_event_id == "TOURIST_BUS" and arch.type == CustomerArchetype.ArchetypeType.TOURIST:
			w *= 3.2
		elif GameManager.current_daily_event_id == "CHILDRENS_DAY" and arch.type == CustomerArchetype.ArchetypeType.CHILD:
			w *= 3.2
		elif GameManager.current_daily_event_id == "GOURMET_VISIT" and arch.type == CustomerArchetype.ArchetypeType.GOURMET:
			w *= 3.2
			
		weights.append(w)
		total_weight += w
		
	var roll = randf() * total_weight
	var cumulative = 0.0
	for i in range(_archetypes.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			_last_archetype_type = _archetypes[i].type
			return _archetypes[i]
			
	return _archetypes.pick_random()

func _spawn_next_customer() -> void:
	if not GameManager.can_spawn_customer() or active_customer != null:
		return
		
	if customer_scene == null or spawn_marker == null or counter_marker == null:
		return
		
	var customer_inst = customer_scene.instantiate() as Customer
	add_child(customer_inst)
	active_customer = customer_inst
	_is_order_ready_to_deliver = false
	
	active_archetype = pick_weighted_archetype() if not _archetypes.is_empty() else null
	active_order = generate_order_for_archetype(active_archetype)
	customer_inst.initialize(active_order, spawn_marker.global_position, counter_marker.global_position, active_archetype)

func _on_bell_rung(_combo: int) -> void:
	if active_customer == null:
		if GameManager.can_spawn_customer():
			_spawn_timer = null
			_spawn_next_customer()
			EventBus.notification_requested.emit("Zil Çalındı! Müşteri Çağrıldı.", 1.2)
		else:
			EventBus.notification_requested.emit("Bugünün tüm müşterileri servis edildi!", 1.5)
	else:
		active_customer.entertain_with_bell(3.5)
		EventBus.notification_requested.emit("Müşteri şovdan keyif aldı! (+Sabır)", 1.2)

func generate_order_for_archetype(arch: CustomerArchetype) -> OrderData:
	var order = OrderData.new()
	order.order_id = "ORD_" + str(Time.get_ticks_msec())
	order.current_score = 5.0
	order.score_decay_rate = arch.score_decay_rate if arch else 0.025
	
	var current_day = GameManager.current_day
	
	# Day Progression Scoop Sınırları
	var day_min_scoop = 2
	var day_max_scoop = 5
	if current_day == 2:
		day_min_scoop = 2
		day_max_scoop = 7
	elif current_day == 3:
		day_min_scoop = 3
		day_max_scoop = 8
	elif current_day == 4:
		day_min_scoop = 3
		day_max_scoop = 10
	elif current_day >= 5:
		day_min_scoop = 4
		day_max_scoop = 14
		
	var arch_min = arch.min_scoops if arch else 2
	var arch_max = arch.max_scoops if arch else 6
	
	var target_min = maxi(day_min_scoop, arch_min)
	var target_max = mini(day_max_scoop, arch_max)
	if target_min > target_max:
		target_max = target_min
		
	var scoop_count = randi_range(target_min, target_max)
	var all_flavors = GameManager.get_unlocked_flavors()
	if all_flavors.is_empty():
		all_flavors = GameManager.get_all_flavors()
		if all_flavors.is_empty():
			return order
		
	# Aroma Üretimi (Flavor Focus veya Mixed Multiset)
	var is_focus = (randf() < (arch.focus_flavor_chance if arch else 0.25)) and (scoop_count >= 3)
	if is_focus:
		order.order_type = OrderData.OrderType.FLAVOR_FOCUS
		var main_flavor = all_flavors.pick_random()
		var repeat_count = randi_range(2, mini(4, scoop_count - 1))
		for r in range(repeat_count):
			order.flavors.append(main_flavor)
		while order.flavors.size() < scoop_count:
			order.flavors.append(all_flavors.pick_random())
	else:
		for i in range(scoop_count):
			order.flavors.append(all_flavors.pick_random())
			
	# Topping Üretimi (0, 1 veya 2 adet)
	var top_chance = arch.topping_chance if arch else 0.70
	var two_top_chance = arch.two_toppings_chance if arch else 0.30
	var all_toppings = GameManager.get_unlocked_toppings()
	
	if not all_toppings.is_empty() and randf() < top_chance:
		var first_top = all_toppings.pick_random()
		order.toppings.append(first_top)
		
		if randf() < two_top_chance and all_toppings.size() > 1:
			var second_top = all_toppings.pick_random()
			if second_top.id != first_top.id:
				order.toppings.append(second_top)
				order.order_type = OrderData.OrderType.TOPPING_FOCUS
				
	# Sipariş Tipi Belirleme
	if scoop_count >= 8:
		order.order_type = OrderData.OrderType.TOWER
	elif scoop_count >= 5 and order.order_type == OrderData.OrderType.NORMAL:
		order.order_type = OrderData.OrderType.LARGE
	elif order.order_type == OrderData.OrderType.NORMAL and order.flavors.size() >= 3:
		order.order_type = OrderData.OrderType.MIXED
		
	# Zorluk Hesaplama
	order.calculate_difficulty(arch.balance_tolerance if arch else 1.0)
	return order

func _on_customer_arrived(customer: Node3D, order: OrderData) -> void:
	if customer != active_customer or order != active_order:
		return
		
	_evaluate_order_progress(_last_cone_flavors, _last_cone_toppings)

func _on_cone_state_changed(_state_name: String, _count: int, flavors: Array[FlavorData]) -> void:
	_last_cone_flavors = flavors.duplicate()
	
	if active_order == null or active_customer == null:
		return
		
	_evaluate_order_progress(flavors, _last_cone_toppings)

func _on_topping_added_to_cone(topping: ToppingData) -> void:
	_last_cone_toppings.append(topping)
	
	if active_order == null or active_customer == null:
		return
		
	_evaluate_order_progress(_last_cone_flavors, _last_cone_toppings)

func _evaluate_order_progress(flavors: Array[FlavorData], toppings: Array[ToppingData]) -> void:
	if active_order == null or active_customer == null:
		return
		
	var progress_info = active_order.check_progress(flavors, toppings)
	EventBus.order_progress_updated.emit(progress_info)
	
	if progress_info.is_completed:
		if not _is_order_ready_to_deliver:
			_is_order_ready_to_deliver = true
			EventBus.notification_requested.emit("Kule Tamamlandı! Müşteriye Bak ve [E] ile Teslim Et.", 2.5)
	else:
		_is_order_ready_to_deliver = false

func _is_customer_receivable() -> bool:
	if active_customer == null:
		return false
	var s = active_customer.state
	return s == Customer.State.WAITING or s == Customer.State.ORDER_READY or s == Customer.State.ORDER_IN_PROGRESS or s == Customer.State.IMPATIENT or s == Customer.State.DISAPPOINTED

func _on_order_delivery_attempted() -> void:
	if active_order == null or active_customer == null:
		EventBus.notification_requested.emit("Bekleyen bir müşteri yok.", 1.2)
		return
		
	if not _is_customer_receivable():
		return
		
	if _last_cone_flavors.is_empty():
		EventBus.notification_requested.emit("Teslim edilecek bir dondurma yok!", 1.2)
		return
		
	var progress_info = active_order.check_progress(_last_cone_flavors, _last_cone_toppings)
	
	if progress_info.is_completed:
		_complete_active_order(progress_info)
	elif not progress_info.is_valid_so_far:
		EventBus.notification_requested.emit("Hatalı dondurma aroması! Müşteri bunu kabul etmiyor.", 1.8)
		if active_customer.speech_label_3d:
			active_customer.speech_label_3d.text = "Bu benim istediğim lezzet değil!"
	else:
		if _last_cone_flavors.size() < active_order.flavors.size():
			EventBus.notification_requested.emit("Kule eksik (%d/%d top hazır)!" % [_last_cone_flavors.size(), active_order.flavors.size()], 1.5)
		else:
			EventBus.notification_requested.emit("İstenen sos henüz dökülmedi!", 1.5)
			
		if active_customer.speech_label_3d:
			active_customer.speech_label_3d.text = "Dondurmam henüz hazır değil."

func _on_cone_discarded() -> void:
	_last_cone_flavors.clear()
	_last_cone_toppings.clear()
	_active_trick_count = 0
	_active_flip_count = 0
	_active_clutch_saved = false
	_is_order_ready_to_deliver = false
	if active_order and active_customer:
		var empty_flavors: Array[FlavorData] = []
		var empty_toppings: Array[ToppingData] = []
		var progress_info = active_order.check_progress(empty_flavors, empty_toppings)
		EventBus.order_progress_updated.emit(progress_info)

func _on_cone_dropped() -> void:
	_last_cone_flavors.clear()
	_last_cone_toppings.clear()
	_active_trick_count = 0
	_active_flip_count = 0
	_active_clutch_saved = false
	_is_order_ready_to_deliver = false
	if active_order and active_customer:
		var empty_flavors: Array[FlavorData] = []
		var empty_toppings: Array[ToppingData] = []
		var progress_info = active_order.check_progress(empty_flavors, empty_toppings)
		EventBus.order_progress_updated.emit(progress_info)

func _complete_active_order(progress_info: Dictionary = {}) -> void:
	if active_order == null or active_customer == null:
		return
		
	if not _is_customer_receivable():
		return
		
	var final_score = active_order.current_score
	var extra_toppings: Array = progress_info.get("extra_toppings", [])
	
	# 1. Taban Fiyat Hesaplaması (Dinamik Fiyat * Top Sayısı + İstenen Sos Fiyatları)
	var base_scoop_price = GameManager.get_base_scoop_price()
	var base_price = float(active_order.flavors.size()) * base_scoop_price
	for top in active_order.toppings:
		base_price += top.extra_price
		
	# 2. Bahşiş Hesaplaması (Puan ve Arketip Çarpanı + Dükkan Bahşiş Upgrade'i)
	var tip_mult = active_archetype.tip_multiplier if active_archetype else 1.0
	var tip_upgrade_bonus = GameManager.get_upgrade_effect("tip_mastery", "tip_multiplier_bonus")
	tip_mult += tip_upgrade_bonus
	var tip_amount = (final_score / 5.0) * (base_price * 0.40) * tip_mult
	
	# 3. İkram / Ekstra Sos Bonusu & Maraş Şov Bonusu
	var extra_bonus = 0.0
	var bonus_text = ""
	if not extra_toppings.is_empty():
		var bonus_val = active_archetype.topping_bonus if active_archetype else 2.0
		extra_bonus += bonus_val
		if active_archetype and active_archetype.type == CustomerArchetype.ArchetypeType.CHILD:
			bonus_text += " (🧒 İkram: +$%.2f!)" % bonus_val
		elif active_archetype and active_archetype.type == CustomerArchetype.ArchetypeType.TOURIST:
			GameManager.update_reputation(2.0)
			bonus_text += " (📸 Sürpriz İkram: +$%.2f & +%%2 İtibar!)" % bonus_val
		else:
			bonus_text += " (İkram: +$%.2f)" % bonus_val
			
	if _active_trick_count > 0:
		var trick_bonus = float(_active_trick_count) * 3.50
		extra_bonus += trick_bonus
		bonus_text += " (🎭 Maraş Şovu x%d: +$%.2f!)" % [_active_trick_count, trick_bonus]
		_active_trick_count = 0
		
	if _active_flip_count > 0:
		var flip_bonus = float(_active_flip_count) * 4.50
		extra_bonus += flip_bonus
		bonus_text += " (🔄 Yerçekimi Şovu x%d: +$%.2f!)" % [_active_flip_count, flip_bonus]
		_active_flip_count = 0
		
	if _active_clutch_saved:
		var clutch_bonus = 5.00
		extra_bonus += clutch_bonus
		bonus_text += " (⚡ Kurtarma Bonusu: +$%.2f!)" % clutch_bonus
		GameManager.update_reputation(1.5)
		_active_clutch_saved = false
			
	var total_earned = base_price + tip_amount + extra_bonus
	
	# 4. TEK MERKEZDEN GameManager'a Kayıt
	GameManager.record_order_success(base_price, tip_amount, extra_bonus)
	if active_archetype:
		GameManager.update_reputation(active_archetype.reputation_bonus)
		
	# 5. Müşteriyi Tamamla ve Sinyal Yay
	active_customer.complete_order(final_score)
	EventBus.order_completed.emit(active_order, final_score)
	EventBus.notification_requested.emit("Kule Teslim Edildi! +$%.2f (Puan: %.2f)%s" % [total_earned, final_score, bonus_text], 2.5)
	
	# 6. Sol Eldeki Külahı Sıfırla
	EventBus.cone_reset.emit()
	active_order = null
	active_archetype = null
	_last_cone_flavors.clear()
	_last_cone_toppings.clear()
	_is_order_ready_to_deliver = false

func _on_customer_left(_customer: Node3D) -> void:
	active_customer = null
	active_order = null
	active_archetype = null
	_last_cone_flavors.clear()
	_last_cone_toppings.clear()
	_is_order_ready_to_deliver = false
	
	# Gün Hedefinin Kontrolü
	GameManager.check_day_completion()
	
	if GameManager.can_spawn_customer():
		_schedule_next_customer(next_customer_delay)
