class_name ShopDialog
extends Control

@onready var money_label: Label = $Card/TopHeader/MoneyLabel
@onready var day_label: Label = $Card/TopHeader/DayLabel
@onready var items_container: VBoxContainer = $Card/ScrollContainer/ItemsContainer
@onready var start_day_button: Button = $Card/BottomBar/StartDayButton

# Kategori Sekmeleri
@onready var tab_all: Button = $Card/CategoryTabs/BtnAll
@onready var tab_cone: Button = $Card/CategoryTabs/BtnCone
@onready var tab_scoop: Button = $Card/CategoryTabs/BtnScoop
@onready var tab_customer: Button = $Card/CategoryTabs/BtnCustomer
@onready var tab_flavors: Button = $Card/CategoryTabs/BtnFlavors

var _current_filter: int = -1 # -1: Tümü, 0: SCOOP, 1: CONE, 2: CUSTOMER, 3: FLAVOR/TOPPING

func _ready() -> void:
	visible = false
	if start_day_button:
		start_day_button.pressed.connect(_on_start_day_pressed)
		
	if tab_all: tab_all.pressed.connect(func(): _set_category_filter(-1))
	if tab_cone: tab_cone.pressed.connect(func(): _set_category_filter(UpgradeData.Category.CONE))
	if tab_scoop: tab_scoop.pressed.connect(func(): _set_category_filter(UpgradeData.Category.SCOOP))
	if tab_customer: tab_customer.pressed.connect(func(): _set_category_filter(UpgradeData.Category.CUSTOMER))
	if tab_flavors: tab_flavors.pressed.connect(func(): _set_category_filter(UpgradeData.Category.FLAVOR))
	
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)

func open_shop() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_header()
	_render_items()
	EventBus.shop_opened.emit()

func close_shop() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.shop_closed.emit()

func _set_category_filter(cat: int) -> void:
	_current_filter = cat
	_render_items()

func _update_header() -> void:
	if money_label:
		money_label.text = "Kasa: $%.2f" % GameManager.current_money
	if day_label:
		day_label.text = "Gelecek Gün: %d" % (GameManager.current_day + 1)

func _on_money_changed(_m: float, _d: float) -> void:
	_update_header()
	_render_items()

func _on_upgrade_purchased(_id: String, _lvl: int) -> void:
	_update_header()
	_render_items()

func _render_items() -> void:
	if items_container == null:
		return
		
	for child in items_container.get_children():
		child.queue_free()
		
	var next_day = GameManager.current_day + 1
	
	for up_id in GameManager.upgrades.keys():
		var up: UpgradeData = GameManager.upgrades[up_id]
		
		# Kategori filtreleme
		if _current_filter != -1:
			if _current_filter == UpgradeData.Category.FLAVOR:
				if up.category != UpgradeData.Category.FLAVOR and up.category != UpgradeData.Category.TOPPING:
					continue
			elif up.category != _current_filter:
				continue
				
		# Gün kilidi kontrolü
		if not up.can_unlock_on_day(next_day) and up.current_level == 0:
			continue
			
		var card = _create_upgrade_card(up)
		items_container.add_child(card)

func _create_upgrade_card(up: UpgradeData) -> PanelContainer:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.14, 0.18, 0.9)
	card_style.set_corner_radius_all(8)
	card_style.set_border_width_all(1)
	card_style.border_color = Color(1, 1, 1, 0.1)
	card_style.set_expand_margin_all(8)
	card.add_theme_stylebox_override("panel", card_style)
	
	var hbox = HBoxContainer.new()
	hbox.theme_override_constants.set("separation", 16)
	card.add_child(hbox)
	
	# Sol: Bilgiler
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.theme_override_constants.set("separation", 4)
	hbox.add_child(info_vbox)
	
	var title_lbl = Label.new()
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.4, 1))
	if up.max_level > 1:
		title_lbl.text = "%s (Seviye %d / %d)" % [up.display_name, up.current_level, up.max_level]
	else:
		title_lbl.text = up.display_name
	info_vbox.add_child(title_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88, 1))
	desc_lbl.text = up.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_lbl)
	
	# Sağ: Fiyat ve Satın Al Butonu
	var btn_vbox = VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.custom_minimum_size = Vector2(130, 0)
	hbox.add_child(btn_vbox)
	
	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(120, 36)
	
	if up.is_maxed():
		buy_btn.text = "✓ TAMAMLANDI"
		buy_btn.disabled = true
		buy_btn.modulate = Color(0.5, 0.8, 0.5, 1)
	else:
		var cost = up.get_cost_for_next_level()
		buy_btn.text = "SATIN AL\n$%.2f" % cost
		if GameManager.current_money >= cost:
			buy_btn.disabled = false
			buy_btn.modulate = Color(0.4, 1.0, 0.5, 1)
		else:
			buy_btn.disabled = true
			buy_btn.modulate = Color(0.7, 0.7, 0.7, 0.6)
			
		buy_btn.pressed.connect(func():
			GameManager.buy_upgrade(up.id)
		)
		
	btn_vbox.add_child(buy_btn)
	return card

func _on_start_day_pressed() -> void:
	close_shop()
	GameManager.advance_to_next_day()
