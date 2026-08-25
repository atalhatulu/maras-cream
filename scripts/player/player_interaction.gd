class_name PlayerInteraction
extends Node

func _ready() -> void:
	EventBus.player_interacted.connect(_on_player_interacted)
	EventBus.player_secondary_interacted.connect(_on_player_secondary_interacted)

func _on_player_interacted(collider: Object) -> void:
	if collider == null:
		return
		
	if collider is ConeDispenser:
		collider.interact()
		return
		
	if collider is TrashCan:
		collider.interact()
		return
		
	if collider.is_in_group("cone_target") or collider is LeftHandController:
		EventBus.place_on_cone_attempted.emit()
		return

func _on_player_secondary_interacted(_collider: Object) -> void:
	EventBus.place_on_cone_attempted.emit()
