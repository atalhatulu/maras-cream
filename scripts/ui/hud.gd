class_name HUD
extends Control

@onready var money_label: Label = $TopBar/HBox/MoneyLabel
@onready var reputation_label: Label = $TopBar/HBox/ReputationLabel
@onready var day_label: Label = $TopBar/HBox/DayLabel
@onready var daily_event_label: Label = $DailyEventPanel/DailyEventLabel

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
var _is_clutch_ui_active: bool = false
var _clutch_ui_generation: int = 0
var _hand_busy: bool = false
var _crosshair_interactive: bool = false
var _tutorial_panel: PanelContainer
var _tutorial_title: Label
var _tutorial_text: Label
var _tutorial_footer: Label
var _player: PlayerController
var _manager: CustomerManager

func _ready() -> void:
	_player = get_parent().get_node_or_null("PlayerRig")
	_manager = get_parent().get_node_or_null("CustomerManager")
	_build_tutorial_panel()
	# The old 5px dot was hard to see; draw a high-contrast reticle instead.
	crosshair.visible = false
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
	
	# Şov ve Kurtarma Sinyalleri
	EventBus.show_cancelled.connect(func(): _is_clutch_ui_active = false)
	EventBus.clutch_window_started.connect(_on_clutch_window_started)
	EventBus.clutch_catch_succeeded.connect(_on_clutch_catch_succeeded)
	EventBus.clutch_catch_failed.connect(_on_clutch_catch_failed)
	EventBus.cone_flipped.connect(_on_cone_flipped)
	EventBus.cone_dropped.connect(func(): _is_clutch_ui_active = false)
	EventBus.cone_reset.connect(func(): _is_clutch_ui_active = false)
	EventBus.show_reward_awarded.connect(_on_show_reward_awarded)
	EventBus.cone_critical_tilt.connect(_on_cone_critical_tilt)
	
	# Gün Döngüsü Sinyalleri
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_progress_updated.connect(_on_day_progress_updated)
	EventBus.daily_event_announced.connect(_on_daily_event_announced)
	
	# Müşteri ve Sipariş Sinyalleri
	EventBus.hand_busy_changed.connect(func(busy):
		_hand_busy = busy
		_render_order_card()
	)
	EventBus.reward_quote_updated.connect(_on_reward_quote_updated)
	EventBus.customer_unavailable.connect(_on_customer_left)
	EventBus.show_context_changed.connect(func(available):
		if not available: _is_clutch_ui_active = false
	)
	EventBus.customer_arrived.connect(_on_customer_arrived)
	EventBus.customer_score_updated.connect(_on_customer_score_updated)
	EventBus.order_progress_updated.connect(_on_order_progress_updated)
	EventBus.order_completed.connect(_on_order_completed)
	EventBus.customer_left.connect(_on_customer_left)
	
	if notification_timer:
		notification_timer.timeout.connect(_on_notification_timeout)

func _build_tutorial_panel() -> void:
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.name = "TutorialPanel"
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_panel.add_theme_stylebox_override("panel", $DailyEventPanel.get_theme_stylebox("panel"))
	add_child(_tutorial_panel)
	_tutorial_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_tutorial_panel.offset_left = -330.0
	_tutorial_panel.offset_right = -24.0
	_tutorial_panel.offset_top = 188.0
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	_tutorial_panel.add_child(box)
	_tutorial_title = Label.new()
	_tutorial_title.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	_tutorial_title.add_theme_font_size_override("font_size", 15)
	box.add_child(_tutorial_title)
	_tutorial_text = Label.new()
	_tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_text.add_theme_font_size_override("font_size", 14)
	box.add_child(_tutorial_text)
	_tutorial_footer = Label.new()
	_tutorial_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_footer.add_theme_font_size_override("font_size", 12)
	_tutorial_footer.modulate = Color(0.75, 0.8, 0.85)
	box.add_child(_tutorial_footer)
	# Dialogs must stay above contextual help.
	move_child(_tutorial_panel, 0)

func _process(_delta: float) -> void:
	if _player == null or _manager == null:
		return
	_tutorial_panel.visible = Tutorial.help_visible and GameManager.day_active
	if not _tutorial_panel.visible:
		return
	var guide := Tutorial.guidance(_player.left_hand, _player.right_hand, _manager.active_order)
	_tutorial_title.text = guide.step
	_tutorial_text.text = guide.text
	_tutorial_footer.text = "Süre durdu · F1: gizle · F2: atla" if Tutorial.training_order != null else "F1: yardımı kapat · A/D: denge"

func _update_labels() -> void:
	if money_label:
		money_label.text = "Kasa: $%.2f" % GameManager.current_money
	if reputation_label:
		reputation_label.text = "İtibar: %%%d" % int(GameManager.current_reputation)
	if day_label:
		day_label.text = "Gün: %d [%d/%d]" % [GameManager.current_day, GameManager.customers_served, GameManager.day_customer_target]
	_on_daily_event_announced(GameManager.current_daily_event_id, GameManager.current_daily_event_title, GameManager.current_daily_event_desc)

func _on_daily_event_announced(_id: String, title: String, description: String) -> void:
	daily_event_label.text = "%s\n%s" % [title, description]

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

func _draw() -> void:
	var center := size * 0.5
	var accent := Color(1.0, 0.83, 0.30, 1.0) if _crosshair_interactive else Color(0.96, 0.98, 1.0, 0.95)
	var shadow := Color(0.02, 0.03, 0.05, 0.9)
	var gap := 6.0
	var extent := 14.0
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var start: Vector2 = center + direction * gap
		var finish: Vector2 = center + direction * extent
		draw_line(start, finish, shadow, 5.0, true)
		draw_line(start, finish, accent, 2.5, true)
	draw_circle(center, 3.0, shadow)
	draw_circle(center, 1.6, accent)

func _on_interaction_target_changed(hint_text: String) -> void:
	if interaction_tooltip_label:
		interaction_tooltip_label.text = hint_text
	_crosshair_interactive = hint_text != ""
	queue_redraw()

func _on_reputation_changed(new_rep: float, _diff: float) -> void:
	if reputation_label:
		reputation_label.text = "İtibar: %%%d" % int(new_rep)

func _on_balance_updated(balance_ratio: float, current_angle_deg: float) -> void:
	if balance_bar:
		balance_bar.value = (balance_ratio + 1.0) * 50.0
		
	if _is_clutch_ui_active:
		return
		
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

func _on_clutch_window_started(fall_direction: float, _duration: float) -> void:
	_clutch_ui_generation += 1
	_is_clutch_ui_active = true
	if balance_label:
		if fall_direction > 0.0:
			balance_label.text = "🚨 DÜŞÜYOR! SOLA BAS! [A]"
		else:
			balance_label.text = "🚨 DÜŞÜYOR! SAĞA BAS! [D]"
		balance_label.modulate = Color(1.0, 0.15, 0.15, 1.0)

func _on_clutch_catch_succeeded() -> void:
	if balance_label:
		balance_label.text = "✨ KULE HAVADA KURTARILDI!"
		balance_label.modulate = Color(0.3, 1.0, 0.4, 1.0)
	var generation := _clutch_ui_generation
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(func():
		if generation == _clutch_ui_generation: _is_clutch_ui_active = false
	)

func _on_clutch_catch_failed() -> void:
	_is_clutch_ui_active = false

func _on_cone_flipped(is_flipped: bool) -> void:
	if is_flipped and balance_label:
		balance_label.text = "🔄 TERS ÇEVİRME ŞOVU!"
		balance_label.modulate = Color(0.4, 0.85, 1.0, 1.0)

func _on_cone_critical_tilt(tilt_severity: float) -> void:
	if balance_bar:
		balance_bar.modulate = Color(1.0, 0.35, 0.35, 1.0) if tilt_severity > 0.85 else Color(1.0, 0.75, 0.35, 1.0)

func _on_show_reward_awarded(result: Dictionary) -> void:
	_spawn_floating_show_banner(result)

func _spawn_floating_show_banner(result: Dictionary) -> void:
	var kind: String = str(result.get("kind", ""))
	var amount: float = float(result.get("amount", 0.0))
	var penalty: float = float(result.get("penalty", 0.0))
	var repeated: bool = bool(result.get("repeated", false))
	
	var text_title := "MARAŞ ŞOVU!"
	var banner_color := Color(1.0, 0.88, 0.25, 1.0)
	
	match kind:
		"tease":
			text_title = "UZAT-KAÇIR!"
		"flip":
			text_title = "YERÇEKİMİ ŞOVU!"
		"catch":
			text_title = "HAVADA KURTARMA!"
			banner_color = Color(0.35, 1.0, 0.6, 1.0)
		"spin":
			text_title = "FIRILDAK ŞOVU!"
			banner_color = Color(0.35, 0.9, 1.0, 1.0)
		"bell":
			text_title = "RİTİM ZİLİ!"
	
	var full_text := ""
	if amount > 0.0:
		full_text = "★ %s +$%.2f" % [text_title, amount]
		if repeated:
			full_text += " (Tekrar)"
	elif penalty > 0.0:
		full_text = "⚠ SABIRSIZ MÜŞTERİ! -%.2f Puan" % penalty
		banner_color = Color(1.0, 0.35, 0.35, 1.0)
	else:
		if kind == "bell" and float(result.get("pause", 0.0)) > 0.0:
			full_text = "🎵 %s (Sabır Durdu)" % text_title
			banner_color = Color(0.7, 0.9, 1.0, 1.0)
		else:
			return
			
	var banner_label = Label.new()
	banner_label.text = full_text
	banner_label.add_theme_font_size_override("font_size", 18)
	banner_label.add_theme_color_override("font_color", banner_color)
	banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	banner_label.add_theme_constant_override("outline_size", 4)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var center_x = get_viewport_rect().size.x * 0.5
	var center_y = get_viewport_rect().size.y * 0.38
	banner_label.position = Vector2(center_x - 130.0, center_y)
	banner_label.size = Vector2(260.0, 32.0)
	banner_label.pivot_offset = Vector2(130.0, 16.0)
	banner_label.scale = Vector2(0.4, 0.4)
	add_child(banner_label)
	
	var tween = create_tween()
	tween.tween_property(banner_label, "scale", Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner_label, "scale", Vector2.ONE, 0.10)
	tween.parallel().tween_property(banner_label, "position:y", center_y - 28.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner_label, "modulate:a", 0.0, 0.35).set_delay(0.65)
	tween.tween_callback(func():
		if is_instance_valid(banner_label):
			banner_label.queue_free()
	)

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
			
func _on_reward_quote_updated(quote: Dictionary) -> void:
	if order_score_label == null:
		return
	if quote.is_empty():
		order_score_label.text = ""
		return
	order_score_label.modulate = Color.WHITE
	order_score_label.text = "Beklenen Kazanç: $%.2f\nBahşiş $%.2f • İkram $%.2f\nŞov $%.2f • Kalan şov payı $%.2f\n%s" % [quote.total, quote.tip, quote.gift, quote.show, quote.show_remaining, quote.hint]
	if not str(quote.get("event_note", "")).is_empty():
		order_score_label.text += "\n" + str(quote.event_note)

func _on_order_progress_updated(progress_info: Dictionary) -> void:
	_latest_progress_info = progress_info
	_render_order_card()

func _on_order_completed(_order: OrderData, final_score: float) -> void:
	_latest_progress_info["is_completed"] = false
	_render_order_card()
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
	
	var matched_top_pool = matched_toppings.duplicate()
	
	# Recipes are multisets: group repeated flavours so tall orders stay legible.
	for group in _current_active_order.get_flavor_counts_summary():
		var req_flavor: FlavorData = group.flavor
		var item_label = Label.new()
		item_label.add_theme_font_size_override("font_size", 14)
		var matched := 0
		for flavor in matched_flavors:
			if flavor.id == req_flavor.id: matched += 1
		var done := matched == int(group.count)
		item_label.text = "%s %s  %d/%d" % ["✓" if done else "○", req_flavor.flavor_name, matched, group.count]
		if done:
			item_label.modulate = Color(0.4, 1.0, 0.4, 1)
		else:
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
		deliver_hint.text = "Hareket bitince teslim edebilirsin." if _hand_busy else "▶ [E] Teslim Et"
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
