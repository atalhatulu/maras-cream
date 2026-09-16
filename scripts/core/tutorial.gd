extends Node

const SETTINGS_PATH := "user://tutorial.cfg"
var completed := false
var dismissed := false
var help_visible := false
var training_order: OrderData
var balance_practiced := false
var _tilt_introduced := false
var _correction_time := 0.0

func _ready() -> void:
	load_preferences()
	EventBus.order_completed.connect(_on_delivered)
	EventBus.day_started.connect(func(_day, _target): training_order = null)

func load_preferences() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		completed = bool(settings.get_value("tutorial", "completed", false))
		dismissed = bool(settings.get_value("tutorial", "dismissed", false))

func _save_preferences() -> void:
	var settings := ConfigFile.new()
	settings.set_value("tutorial", "completed", completed)
	settings.set_value("tutorial", "dismissed", dismissed)
	if settings.save(SETTINGS_PATH) != OK:
		EventBus.notification_requested.emit("Öğretici tercihi kaydedilemedi.", 2.0)

func should_offer() -> bool:
	return not completed and not dismissed and GameManager.current_day == 1 and GameManager.customers_served == 0

func begin(order: OrderData) -> void:
	training_order = order
	help_visible = true
	balance_practiced = false
	_tilt_introduced = false
	_correction_time = 0.0

func protects(order: OrderData) -> bool:
	return order != null and order == training_order and not dismissed

func skip() -> void:
	dismissed = true
	training_order = null
	help_visible = false
	_save_preferences()
	EventBus.notification_requested.emit("Öğretici atlandı. F1 ile yardımı açabilirsin.", 2.5)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		help_visible = not help_visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skip_tutorial") and training_order != null:
		skip()
		get_viewport().set_input_as_handled()

func observe_balance(hand: LeftHandController, delta: float) -> void:
	if training_order == null or balance_practiced:
		return
	if not hand.has_cone():
		_tilt_introduced = false
		_correction_time = 0.0
		return
	if hand.stacked_flavors.is_empty():
		return
	if hand.is_action_busy():
		return
	if not _tilt_introduced:
		# A small, recoverable tilt makes the effect of A/D visible.
		hand.current_angle_deg = 12.0
		hand.angular_velocity = 0.0
		_tilt_introduced = true
	var axis := Input.get_axis("balance_left", "balance_right")
	if axis * hand.current_angle_deg < 0.0:
		_correction_time += delta
	if _correction_time >= 0.18 and absf(hand.current_angle_deg) < 8.0:
		balance_practiced = true
		EventBus.notification_requested.emit("Denge tamam! Kısa A/D dokunuşlarıyla kuleyi dik tut.", 2.5)

func guidance(hand: LeftHandController, scoop: RightHandController, order: OrderData) -> Dictionary:
	if order == null:
		return {"step": "İLK SİPARİŞ", "text": "Müşteriyi bekle. Ortadaki noktayı ürüne getir; fareyle etrafa bak. Sol tarafta tarifini göreceksin."}
	if not hand.has_cone():
		return {"step": "1 / 6 · KÜLAH AL", "text": "Soldaki KÜLAH standına bakıp sol tıkla. Külah kaybolursa aynı yerden yenisini alabilirsin."}
	var progress := order.check_progress(hand.stacked_flavors, hand.applied_toppings)
	if not progress.invalid_flavors.is_empty():
		return {"step": "TARİFİ DÜZELT", "text": "Fazla veya yanlış tat var. Çöpe bakıp sol tıkla; yeni külahla tarifi yeniden hazırla."}
	if scoop.has_ice_cream():
		var wanted := false
		for flavor in progress.needed_pool:
			if flavor.id == scoop.current_scooped_flavor.id:
				wanted = true
		if not wanted:
			return {"step": "KEPÇEYİ BOŞALT", "text": "Kepçedeki tat tarifte eksik değil. Çöpe bakıp sol tıkla; kepçe ve külah temizlenir. Sonra yeni külahla devam et."}
		return {"step": "3 / 6 · KÜLAHA AKTAR", "text": "Kepçe geri gelince sağ tık veya Q ile topu külaha bırak. Sol tıkla tuttuysan önce bırak; böylece tekrar etrafa bakabilirsin."}
	if protects(order) and not balance_practiced and not hand.stacked_flavors.is_empty():
		return {"step": "4 / 6 · DENGEYİ DENE", "text": "Kule sağa yatıyorsa A, sola yatıyorsa D ile düzelt. Kısa basışlar kullan; alttaki göstergeyi ortada tut."}
	if not progress.needed_pool.is_empty():
		return {"step": "2 / 6 · KEPÇELE", "text": "Tarifteki tada bak. Sol tıkı basılı tutup fareyi aşağı çek; gösterge dolunca bırak. Her top için kepçele ve Q ile aktar. Yanlış kepçeyi çöpte boşaltabilirsin."}
	if not progress.is_completed:
		return {"step": "5 / 6 · SOS EKLE", "text": "Tarifteki sos şişesine bakıp sol tıkla. Kuleyi A/D ile dengede tut. Aynı sosu tekrar eklemene gerek yok."}
	return {"step": "6 / 6 · TESLİM ET", "text": "Müşteriye bakıp E'ye bas. Ellerindeki hareket bitsin. Sonraki siparişlerde F ile ters çevirme, boş kepçeyle Q ile kaçırma şovu yapabilirsin."}

func _on_delivered(order: OrderData, _score: float) -> void:
	if order != training_order:
		return
	completed = true
	training_order = null
	help_visible = false
	_save_preferences()
	EventBus.notification_requested.emit("İlk servis tamam! Artık süre işliyor. F1: yardım.", 3.0)
