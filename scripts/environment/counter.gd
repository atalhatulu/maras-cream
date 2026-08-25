class_name Counter
extends Node3D

@export var tubs: Array[IceCreamTub] = []
@export var cone_stand_marker: Node3D
@export var service_tray_marker: Marker3D

var page_1_flavors: Array[FlavorData] = []
var page_2_flavors: Array[FlavorData] = []
var current_page: int = 1

func _ready() -> void:
	_init_flavor_pages()
	EventBus.tub_switch_interacted.connect(switch_flavor_page)

func _init_flavor_pages() -> void:
	# 1. Sıra
	page_1_flavors = [
		GameManager.get_flavor_by_id("sade"),
		GameManager.get_flavor_by_id("cikolata"),
		GameManager.get_flavor_by_id("fistik"),
		GameManager.get_flavor_by_id("cilek"),
		GameManager.get_flavor_by_id("karamel")
	]
	# 2. Sıra
	page_2_flavors = [
		GameManager.get_flavor_by_id("muz"),
		GameManager.get_flavor_by_id("mango"),
		GameManager.get_flavor_by_id("bogurtlen"),
		GameManager.get_flavor_by_id("limon"),
		GameManager.get_flavor_by_id("nane")
	]

func switch_flavor_page() -> void:
	if current_page == 1:
		current_page = 2
		_apply_page(page_2_flavors)
		EventBus.notification_requested.emit("2. Sıra Tatlar Geldi (Muz, Mango, Böğürtlen, Limon, Nane)", 1.5)
	else:
		current_page = 1
		_apply_page(page_1_flavors)
		EventBus.notification_requested.emit("1. Sıra Tatlar Geldi (Sade, Çikolata, Fıstık, Çilek, Karamel)", 1.5)

func _apply_page(flavor_list: Array[FlavorData]) -> void:
	for i in range(mini(tubs.size(), flavor_list.size())):
		if tubs[i] and flavor_list[i]:
			tubs[i].set_flavor(flavor_list[i])
