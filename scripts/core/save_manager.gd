extends Node

const SAVE_PATH: String = "user://savegame.json"

func save_game() -> bool:
	var save_data = {
		"version": 1,
		"money": GameManager.current_money,
		"reputation": GameManager.current_reputation,
		"day": GameManager.current_day
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Save dosyası açılamadı: " + str(FileAccess.get_open_error()))
		return false
		
	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("Save dosyası okunamadı: " + str(FileAccess.get_open_error()))
		return false
		
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result != OK:
		push_error("Save JSON verisi ayrıştırılamadı!")
		return false
		
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		GameManager.current_money = data.get("money", 50.0)
		GameManager.current_reputation = data.get("reputation", 100.0)
		GameManager.current_day = data.get("day", 1)
		EventBus.money_changed.emit(GameManager.current_money, 0.0)
		EventBus.reputation_changed.emit(GameManager.current_reputation, 0.0)
		return true
		
	return false
