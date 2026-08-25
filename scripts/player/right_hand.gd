class_name RightHandController
extends Node3D

@export_group("Kepçeleme Fiziği")
@export var required_drag_distance: float = 150.0
@export var required_depth: float = 18.0
@export var dive_spring_speed: float = 24.0
@export var return_speed_empty: float = 18.0
@export var return_speed_full: float = 14.0

@export_group("Top Titreme Fiziği (Spring-Damper)")
@export var jiggle_spring: float = 190.0
@export var jiggle_damping: float = 15.0

@onready var scoop_pivot: Node3D = $ScoopPivot
@onready var scoop_mesh: Node3D = $ScoopPivot/ScoopPlaceholder
@onready var ice_cream_scoop_mesh: MeshInstance3D = $ScoopPivot/IceCreamScoopVisual

# Durumlar
var current_scooped_flavor: FlavorData = null
var is_diving: bool = false
var is_animating: bool = false
var is_retracting: bool = false
var current_target_tub: Node3D = null
var current_target_flavor: FlavorData = null

var _accumulated_drag: float = 0.0
var _accumulated_depth: float = 0.0
var _scoop_progress: float = 0.0
var _is_scoop_ready_in_dive: bool = false

var _base_local_pos: Vector3
var _dive_target_pos: Vector3 = Vector3.ZERO
var _dive_target_rot: Vector3 = Vector3.ZERO

var _jiggle_offset: Vector3 = Vector3.ZERO
var _jiggle_velocity: Vector3 = Vector3.ZERO
var _prev_world_pos: Vector3

func _ready() -> void:
	_base_local_pos = position
	_prev_world_pos = global_position
	_update_visual()
	EventBus.scoop_dive_started.connect(_on_scoop_dive_started)
	EventBus.ice_cream_placed_on_cone.connect(_on_ice_cream_placed_on_cone)

func _process(delta: float) -> void:
	var safe_delta = min(delta, 0.05)
	if not is_animating:
		_handle_dive_motion(safe_delta)
	_handle_jiggle_physics(safe_delta)

func _handle_dive_motion(delta: float) -> void:
	var speed = return_speed_full if has_ice_cream() else return_speed_empty
	
	if is_diving:
		speed = dive_spring_speed
		# Fare aşağı çekildikçe bilek dondurmayı oymak için aşağı ve ters döner
		var scrape_lift = _scoop_progress * 0.045
		var scrape_pull = -_scoop_progress * 0.085
		var scrape_pitch = lerpf(deg_to_rad(42.0), deg_to_rad(105.0), _scoop_progress)
		var scrape_roll = lerpf(-deg_to_rad(8.0), deg_to_rad(65.0), _scoop_progress)
		var scrape_yaw = lerpf(-deg_to_rad(10.0), deg_to_rad(22.0), _scoop_progress)
		
		var live_dive_pos = _dive_target_pos + Vector3(0, scrape_lift, scrape_pull)
		var live_dive_rot = Vector3(scrape_pitch, scrape_yaw, scrape_roll)
		
		position = position.lerp(live_dive_pos, speed * delta)
		rotation = rotation.lerp(live_dive_rot, speed * delta)
	else:
		position = position.lerp(_base_local_pos, speed * delta)
		rotation = rotation.lerp(Vector3.ZERO, speed * delta)

func _handle_jiggle_physics(delta: float) -> void:
	if not ice_cream_scoop_mesh or current_scooped_flavor == null:
		_jiggle_offset = Vector3.ZERO
		_jiggle_velocity = Vector3.ZERO
		return
		
	var current_world_pos = global_position
	var world_accel = (current_world_pos - _prev_world_pos) / max(delta, 0.0001)
	_prev_world_pos = current_world_pos
	
	var local_force = -to_local(current_world_pos + world_accel) * 0.0018
	_jiggle_velocity += local_force
	
	var spring_force = -_jiggle_offset * jiggle_spring
	var damping_force = -_jiggle_velocity * jiggle_damping
	
	_jiggle_velocity += (spring_force + damping_force) * delta
	_jiggle_offset += _jiggle_velocity * delta
	_jiggle_offset = _jiggle_offset.clamp(Vector3(-0.012, -0.012, -0.012), Vector3(0.012, 0.012, 0.012))
	
	ice_cream_scoop_mesh.position = Vector3(0, 0.01, -0.2) + _jiggle_offset

func _on_scoop_dive_started(tub_node: Node3D, flavor: FlavorData, hit_point: Vector3 = Vector3.ZERO) -> void:
	if has_ice_cream():
		EventBus.notification_requested.emit("Kepçede zaten dondurma var!", 1.2)
		return
		
	if flavor == null:
		return
		
	is_diving = true
	is_animating = true
	current_target_tub = tub_node
	current_target_flavor = flavor
	_accumulated_drag = 0.0
	_accumulated_depth = 0.0
	_scoop_progress = 0.0
	_is_scoop_ready_in_dive = false
	
	var target_world = hit_point
	if target_world == Vector3.ZERO and tub_node:
		target_world = tub_node.global_position + Vector3(0, 0.05, 0.05)
		
	if get_parent():
		var local_target = get_parent().to_local(target_world)
		_dive_target_pos = local_target + Vector3(0.03, 0.06, 0.15)
	else:
		_dive_target_pos = _base_local_pos + Vector3(0, -0.35, -0.55)
		
	_dive_target_rot = Vector3(deg_to_rad(42.0), -deg_to_rad(10.0), deg_to_rad(10.0))
	
	# Tatlı Daldırma Animasyonu (Anticipation Lift -> Plunge into Tub)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	
	var prep_pos = _base_local_pos + Vector3(0.02, 0.06, -0.08)
	var prep_rot = Vector3(deg_to_rad(20.0), 0, deg_to_rad(5.0))
	
	tween.set_parallel(true)
	tween.tween_property(self, "position", prep_pos, 0.07).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", prep_rot, 0.07).set_ease(Tween.EASE_OUT)
	
	tween.chain().set_parallel(true)
	tween.tween_property(self, "position", _dive_target_pos, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", _dive_target_rot, 0.14).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		is_animating = false
	)
	
	EventBus.notification_requested.emit("Kepçelemek için fareyi çek...", 0.8)

func process_dive_mouse_input(relative: Vector2) -> void:
	if not is_diving or _is_scoop_ready_in_dive or is_animating:
		return
		
	# Aşağı yönlü çekiş hareketi + Dükkan Scoop Speed Upgrade'i
	var speed_boost = 1.0 + GameManager.get_upgrade_effect("scoop_speed", "scoop_speed")
	var down_amount = max(0.0, relative.y) * speed_boost
	var general_drag = relative.length() * 0.4 * speed_boost
	
	_accumulated_depth += down_amount
	_accumulated_drag += general_drag
	
	var depth_ratio = clampf(_accumulated_depth / required_depth, 0.0, 1.0)
	var drag_ratio = clampf(_accumulated_drag / required_drag_distance, 0.0, 1.0)
	
	_scoop_progress = (depth_ratio * 0.7) + (drag_ratio * 0.3)
	EventBus.scoop_dive_progress.emit(_scoop_progress)
	
	if _scoop_progress >= 1.0 and not _is_scoop_ready_in_dive:
		_is_scoop_ready_in_dive = true
		_complete_scoop_and_retract()

func _complete_scoop_and_retract() -> void:
	current_scooped_flavor = current_target_flavor
	_update_visual()
	
	EventBus.scoop_filled.emit(current_scooped_flavor)
	EventBus.scoop_state_changed.emit(true, current_scooped_flavor)
	EventBus.notification_requested.emit("%s kepçelendi!" % current_scooped_flavor.flavor_name, 1.2)
	EventBus.scoop_dive_progress.emit(0.0)
	
	is_diving = false
	is_animating = true
	
	# Snap Lift Upgrade'i ile daha seri kaldırma
	var snap_boost = GameManager.get_upgrade_effect("snap_lift", "snap_speed")
	var lift_duration = max(0.06, 0.14 * (1.0 - snap_boost * 0.4))
	var return_duration = max(0.12, 0.28 * (1.0 - snap_boost * 0.4))
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	var lift_pos = position + Vector3(0, 0.16, 0.10)
	var lift_rot = Vector3(-deg_to_rad(20.0), -deg_to_rad(5.0), 0.0)
	
	tween.set_parallel(true)
	tween.tween_property(self, "position", lift_pos, lift_duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", lift_rot, lift_duration).set_ease(Tween.EASE_OUT)
	
	tween.chain().set_parallel(true)
	tween.tween_property(self, "position", _base_local_pos, return_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", Vector3.ZERO, return_duration).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		is_animating = false
		current_target_tub = null
		current_target_flavor = null
		_is_scoop_ready_in_dive = false
	)

func animate_reach_and_place_on_cone() -> void:
	is_animating = true
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	
	# 1. Külaha doğru uzanma (Reach to Cone)
	var reach_pos = _base_local_pos + Vector3(-0.28, -0.05, -0.15)
	var reach_rot = Vector3(deg_to_rad(25.0), -deg_to_rad(30.0), -deg_to_rad(20.0))
	
	tween.set_parallel(true)
	tween.tween_property(self, "position", reach_pos, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", reach_rot, 0.12).set_ease(Tween.EASE_OUT)
	
	# 2. Topu bırakma ve bileği geri çekerek elastik toparlanma
	tween.chain().set_parallel(true)
	tween.tween_property(self, "position", _base_local_pos, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", Vector3.ZERO, 0.24).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		is_animating = false
	)

func end_dive() -> void:
	if not is_diving or is_animating:
		return
		
	is_diving = false
	if not _is_scoop_ready_in_dive and current_scooped_flavor == null:
		EventBus.scoop_dive_cancelled.emit()
		EventBus.notification_requested.emit("Kepçeleme yetersiz kaldı.", 1.0)
		
	current_target_tub = null
	current_target_flavor = null
	_is_scoop_ready_in_dive = false
	_scoop_progress = 0.0
	EventBus.scoop_dive_progress.emit(0.0)

func _on_ice_cream_placed_on_cone(_flavor: FlavorData, _stack_index: int) -> void:
	consume_scoop()

func consume_scoop() -> FlavorData:
	var f = current_scooped_flavor
	current_scooped_flavor = null
	_update_visual()
	EventBus.scoop_state_changed.emit(false, null)
	return f

func _update_visual() -> void:
	if ice_cream_scoop_mesh:
		if current_scooped_flavor != null:
			ice_cream_scoop_mesh.visible = true
			var mat = StandardMaterial3D.new()
			mat.albedo_color = current_scooped_flavor.color
			mat.roughness = 0.55
			ice_cream_scoop_mesh.material_override = mat
		else:
			ice_cream_scoop_mesh.visible = false

func has_ice_cream() -> bool:
	return current_scooped_flavor != null

func get_scooped_flavor() -> FlavorData:
	return current_scooped_flavor

func get_scoop_tip_global_position() -> Vector3:
	if ice_cream_scoop_mesh:
		return ice_cream_scoop_mesh.global_position
	return global_position
