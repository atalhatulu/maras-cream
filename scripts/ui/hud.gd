class_name HUD
extends Control

@onready var money_label: Label = $TopBar/HBox/MoneyLabel
@onready var reputation_label: Label = $TopBar/HBox/ReputationLabel
@onready var day_label: Label = $TopBar/HBox/DayLabel

@onready var balance_bar: ProgressBar = $BottomContainer/BalanceContainer/BalanceBar
@onready var balance_label: Label = $BottomContainer/BalanceContainer/Label

@onready var notification_label: Label = $NotificationContainer/NotificationLabel
@onready var notification_timer: Timer = $NotificationContainer/NotificationTimer
@onready var crosshair: ColorRect = $Crosshair
@onready var interaction_tooltip_label: Label = $InteractionTooltipLabel
@onready var floating_cash_container: Control = $FloatingCashContainer

@onready var scoop_gesture_container: Control = $ScoopGestureContainer
@onready var scoop_gauge_bar: ProgressBar = $ScoopGestureContainer/ScoopGaugeBar
@onready var arrow_label: Label = $ScoopGestureContainer/ArrowLabel

# --- SİPARİŞ KARTI UI ---
@onready var order_card_container: Control = $OrderCardContainer
@onready var order_title_label: Label = $OrderCardContainer/VBox/OrderHeader/OrderTitleLabel
@onready var score_header_label: Label = $OrderCardContainer/VBox/OrderHeader/ScoreHeaderLabel
@onready var order_score_label: Label = $OrderCardContainer/VBox/OrderScoreLabel
@onready var order_items_list: VBoxContainer = $OrderCardContainer/VBox/OrderItemsList

var _current_active_order: OrderData = null
var _latest_progress_info: Dictionary = {}

func _ready() -> void:
	if scoop_gesture_container:
		scoop_gesture_container.visible = false
	if order_card_container:
		order_card_container.visible = false
	if interaction_tooltip_label:
		interaction_tooltip_label.text = ""
		
	_update_labels()
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.cone_balance_updated.connect(_on_balance_updated)
	EventBus.notification_requested.connect(_on_notification_requested)
	EventBus.scoop_dive_progress.connect(_on_scoop_dive_progress)
	EventBus.interaction_target_changed.connect(_on_interaction_target_changed)
	
	# Gün Döngüsü Sinyalleri
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_progress_updated.connect(_on_day_progress_updated)
	
	# Müşteri ve Sipariş Sinyalleri
	EventBus.customer_arrived.connect(_on_customer_arrived)
	EventBus.customer_score_updated.connect(_on_customer_score_updated)
	EventBus.order_progress_updated.connect(_on_order_progress_updated)
	EventBus.order_completed.connect(_on_order_completed)
	EventBus.customer_left.connect(_on_customer_left)
	
	if notification_timer:
		notification_timer.timeout.connect(_on_notification_timeout)

func _update_labels() -> void:
	if money_label:
		money_label.text = "Kasa: $%.2f" % GameManager.current_money
	if reputation_label:
		reputation_label.text = "İtibar: %%%d" % int(GameManager.current_reputation)
	if day_label:
		day_label.text = "Gün: %d [%d/%d]" % [GameManager.current_day, GameManager.customers_served, GameManager.day_customer_target]

func _on_day_started(day_num: int, target: int) -> void:
	if day_label:
		day_label.text = "Gün: %d [0/%d] • %s" % [day_num, target, GameManager.current_daily_event_title]

func _on_day_progress_updated(served: int, target: int) -> void:
	if day_label:
		day_label.text = "Gün: %d [%d/%d] • %s" % [GameManager.current_day, served, target, GameManager.current_daily_event_title]

func _on_money_changed(new_money: float, diff: float) -> void:
	if money_label:
		money_label.text = "Kasa: $%.2f" % new_money
		if diff > 0.0:
			_spawn_floating_cash(diff)

func _spawn_floating_cash(amount: float) -> void:
	if floating_cash_container == null:
		return
		
	var float_lbl = Label.new()
	float_lbl.text = "+$%.2f" % amount
	float_lbl.add_theme_font_size_override("font_size", 16)
	float_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.5, 1.0))
	float_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	float_lbl.add_theme_constant_override("outline_size", 3)
	floating_cash_container.add_child(float_lbl)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(float_lbl, "position:y", float_lbl.position.y - 28.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(float_lbl, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		if is_instance_valid(float_lbl):
			float_lbl.queue_free()
	)

func _on_interaction_target_changed(hint_text: String) -> void:
	if interaction_tooltip_label:
		interaction_tooltip_label.text = hint_text
	if crosshair:
		if hint_text != "":
			crosshair.color = Color(1.0, 0.85, 0.3, 0.95)
			crosshair.size = Vector2(7, 7)
			crosshair.position = Vector2(-3.5, -3.5)
		else:
			crosshair.color = Color(1, 1, 1, 0.6)
			crosshair.size = Vector2(5, 5)
			crosshair.position = Vector2(-2.5, -2.5)

func _on_reputation_changed(new_rep: float, _diff: float) -> void:
	if reputation_label:
		reputation_label.text = "İtibar: %%%d" % int(new_rep)

func _on_balance_updated(balance_ratio: float, current_angle_deg: float) -> void:
	if balance_bar:
		balance_bar.value = (balance_ratio + 1.0) * 50.0
		
	if balance_label:
		if abs(balance_ratio) >= 0.72:
			balance_label.text = "⚠️ KRİTİK DENGE! (%.1f°)" % current_angle_deg
			balance_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		elif abs(current_angle_deg) > 2.0:
			balance_label.text = "Denge [A / D] (%.1f°)" % current_angle_deg
			balance_label.modulate = Color.WHITE
		else:
			balance_label.text = "Denge [A / D]"
			balance_label.modulate = Color.WHITE

func _on_scoop_dive_progress(progress_ratio: float) -> void:
	if scoop_gesture_container and scoop_gauge_bar:
		if progress_ratio > 0.0:
			scoop_gesture_container.visible = true
			scoop_gauge_bar.value = progress_ratio * 100.0
			if arrow_label:
				arrow_label.position.y = lerpf(115.0, 125.0, sin(Time.get_ticks_msec() * 0.01))
		else:
			scoop_gesture_container.visible = false
			scoop_gauge_bar.value = 0.0

func _on_customer_arrived(customer: Node3D, order: OrderData) -> void:
	_current_active_order = order
	_latest_progress_info = {
		"matched_flavors": [],
		"invalid_flavors": [],
		"matched_toppings": [],
		"invalid_toppings": [],
		"is_completed": false,
		"total_required": order.flavors.size(),
		"prep_count": 0
	}
	if order_card_container:
		order_card_container.visible = true
		
	if order_title_label:
		if customer and "archetype" in customer and customer.archetype and order:
			order_title_label.text = "%s (⭐ %.1f)" % [customer.archetype.badge_tag, order.difficulty]
		else:
			order_title_label.text = "SİPARİŞ"
			
	_update_score_and_reward(order.current_score)
	_render_order_card()

func _on_customer_score_updated(score: float) -> void:
	_update_score_and_reward(score)

func _update_score_and_reward(score: float) -> void:
	if score_header_label:
		score_header_label.text = "⭐ %.2f / 5.00" % score
		if score >= 4.0:
			score_header_label.modulate = Color(0.45, 0.95, 0.45, 1)
		elif score >= 2.5:
			score_header_label.modulate = Color(1.0, 0.85, 0.35, 1)
		else:
			score_header_label.modulate = Color(1.0, 0.4, 0.4, 1)
			
	if order_score_label and _current_active_order:
		var base_price = _current_active_order.flavors.size() * 5.0
		for top in _current_active_order.toppings:
			base_price += top.extra_price
			
		var tip = (score / 5.0) * (base_price * 0.4)
		var total_reward = base_price + tip
		order_score_label.text = "Beklenen Kazanç: $%.2f" % total_reward

func _on_order_progress_updated(progress_info: Dictionary) -> void:
	_latest_progress_info = progress_info
	_render_order_card()

func _on_order_completed(_order: OrderData, final_score: float) -> void:
	if order_score_label:
		order_score_label.text = "Teslim Edildi! ⭐ %.2f" % final_score
		order_score_label.modulate = Color(0.35, 1.0, 0.45, 1)

func _on_customer_left(_customer: Node3D) -> void:
	_current_active_order = null
	if order_card_container:
		order_card_container.visible = false

func _render_order_card() -> void:
	if _current_active_order == null or order_items_list == null:
		return
		
	for child in order_items_list.get_children():
		child.queue_free()
		
	var matched_flavors: Array = _latest_progress_info.get("matched_flavors", [])
	var invalid_flavors: Array = _latest_progress_info.get("invalid_flavors", [])
	var matched_toppings: Array = _latest_progress_info.get("matched_toppings", [])
	var invalid_toppings: Array = _latest_progress_info.get("invalid_toppings", [])
	
	var matched_pool = matched_flavors.duplicate()
	var matched_top_pool = matched_toppings.duplicate()
	
	# 1. İstenen dondurma topları
	for i in range(_current_active_order.flavors.size()):
		var req_flavor = _current_active_order.flavors[i]
		var item_label = Label.new()
		item_label.add_theme_font_size_override("font_size", 14)
		
		var found_match_idx = -1
		for m in range(matched_pool.size()):
			if matched_pool[m].id == req_flavor.id:
				found_match_idx = m
				break
				
		if found_match_idx != -1:
			item_label.text = "✓ %s" % req_flavor.flavor_name
			item_label.modulate = Color(0.4, 1.0, 0.4, 1)
			matched_pool.remove_at(found_match_idx)
		else:
			item_label.text = "○ %s" % req_flavor.flavor_name
			item_label.modulate = Color(0.85, 0.85, 0.85, 1)
			
		order_items_list.add_child(item_label)
		
	# 2. İstenen soslar ve süslemeler
	for k in range(_current_active_order.toppings.size()):
		var req_top = _current_active_order.toppings[k]
		var top_label = Label.new()
		top_label.add_theme_font_size_override("font_size", 13)
		
		var found_top_match = -1
		for t in range(matched_top_pool.size()):
			if matched_top_pool[t].id == req_top.id:
				found_top_match = t
				break
				
		if found_top_match != -1:
			top_label.text = "✓ + %s" % req_top.topping_name
			top_label.modulate = Color(0.4, 0.95, 0.6, 1)
			matched_top_pool.remove_at(found_top_match)
		else:
			top_label.text = "○ + %s" % req_top.topping_name
			top_label.modulate = Color(1.0, 0.85, 0.4, 1)
			
		order_items_list.add_child(top_label)
		
	# Hatalı aroma uyarısı
	for inv in invalid_flavors:
		var inv_label = Label.new()
		inv_label.add_theme_font_size_override("font_size", 13)
		inv_label.text = "✗ Fazla/Hatalı: %s" % inv.flavor_name
		inv_label.modulate = Color(1.0, 0.35, 0.35, 1)
		order_items_list.add_child(inv_label)
		
	# Ekstra sos ikramı gösterimi
	var extra_toppings: Array = _latest_progress_info.get("extra_toppings", [])
	for ext in extra_toppings:
		var ext_top_label = Label.new()
		ext_top_label.add_theme_font_size_override("font_size", 13)
		ext_top_label.text = "★ İkram: +%s" % ext.topping_name
		ext_top_label.modulate = Color(1.0, 0.85, 0.35, 1)
		order_items_list.add_child(ext_top_label)
		
	# Teslimat yönlendirmesi
	if _latest_progress_info.get("is_completed", false):
		var deliver_hint = Label.new()
		deliver_hint.add_theme_font_size_override("font_size", 13)
		deliver_hint.text = "▶ [E] Teslim Et"
		deliver_hint.modulate = Color(1.0, 0.88, 0.2, 1)
		order_items_list.add_child(deliver_hint)

func _on_notification_requested(text: String, duration: float) -> void:
	if notification_label:
		notification_label.text = text
		notification_label.visible = true
	if notification_timer:
		notification_timer.start(duration)

func _on_notification_timeout() -> void:
	if notification_label:
		notification_label.visible = false
