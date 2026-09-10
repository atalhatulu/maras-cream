class_name MarasBell
extends StaticBody3D

@export var bell_mesh: MeshInstance3D

var _is_highlighted: bool = false
var _bell_mat: StandardMaterial3D
var _ring_combo: int = 0
var _last_ring_time: float = 0.0

func _ready() -> void:
	if bell_mesh:
		_bell_mat = bell_mesh.get_active_material(0)
		if _bell_mat:
			_bell_mat = _bell_mat.duplicate()
			bell_mesh.material_override = _bell_mat

func set_highlight(enabled: bool) -> void:
	if _is_highlighted == enabled or _bell_mat == null:
		return
		
	_is_highlighted = enabled
	if enabled:
		_bell_mat.emission_enabled = true
		_bell_mat.emission = Color(1.0, 0.85, 0.3, 1.0) * 0.45
	else:
		_bell_mat.emission_enabled = false

func interact() -> void:
	ring()

func ring() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_ring_time < 2.0:
		_ring_combo += 1
	else:
		_ring_combo = 1
	_last_ring_time = now
	
	AudioManager.play_sfx("bell_hit")
	EventBus.bell_rung.emit(_ring_combo)
	
	# Zilin sallanma fiziği (Çan salınımı)
	var tween = create_tween()
	tween.tween_property(self, "rotation:z", deg_to_rad(25.0), 0.06).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "rotation:z", deg_to_rad(-20.0), 0.09).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "rotation:z", deg_to_rad(12.0), 0.12).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "rotation:z", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
