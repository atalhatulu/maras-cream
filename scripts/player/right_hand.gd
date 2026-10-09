class_name RightHandController
extends Node3D

@export_group("Kepçeleme Fiziği")
@export var required_drag_distance: float = 180.0
@export var required_depth: float = 48.0
@export var dive_spring_speed: float = 24.0
@export var return_speed_empty: float = 18.0
@export var return_speed_full: float = 14.0

@export_group("Top Titreme Fiziği (Spring-Damper)")
@export var jiggle_spring: float = 190.0
@export var jiggle_damping: float = 15.0

@onready var scoop_pivot: Node3D = $ScoopPivot
@onready var grip_fingers: Node3D = $ArmRig/WristRig/PalmMesh/FingersGrip
@onready var grip_thumb: Node3D = $ArmRig/WristRig/PalmMesh/ThumbGrip
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
var _motion_tween: Tween
var _grip_strength: float = 0.0
var _scoop_pop: float = 0.0
var _elastic_strand: MeshInstance3D
var _elastic_anchor: Vector3 = Vector3.ZERO

func _ready() -> void:
	_base_local_pos = position
	_prev_world_pos = global_position
	_update_visual()
	EventBus.scoop_dive_started.connect(_on_scoop_dive_started)
	EventBus.ice_cream_placed_on_cone.connect(_on_ice_cream_placed_on_cone)
	EventBus.trash_can_interacted.connect(func():
		end_dive()
		if has_ice_cream():
			consume_scoop()
	)

func _process(delta: float) -> void:
	var safe_delta = min(delta, 0.05)
	if not is_animating:
		_handle_dive_motion(safe_delta)
	_handle_jiggle_physics(safe_delta)
	_update_grip_and_scoop_feedback(safe_delta)
	_update_elastic_strand()

func _update_grip_and_scoop_feedback(delta: float) -> void:
	# Grip tightens as the player scrapes, then relaxes with a filled scoop.
	var target_grip: float = _scoop_progress if is_diving else (0.4 if has_ice_cream() else 0.0)
	_grip_strength = lerpf(_grip_strength, target_grip, 1.0 - exp(-12.0 * delta))
	if grip_fingers:
		grip_fingers.rotation.x = deg_to_rad(_grip_strength * 17.0)
	if grip_thumb:
		grip_thumb.rotation.y = deg_to_rad(-_grip_strength * 12.0)
	_scoop_pop = move_toward(_scoop_pop, 0.0, delta * 3.5)
	if ice_cream_scoop_mesh and has_ice_cream():
		var stretch: float = 1.0 + _scoop_pop * 0.24
		ice_cream_scoop_mesh.scale = Vector3(1.0 - _scoop_pop * 0.10, stretch, 1.0 - _scoop_pop * 0.10)
	elif ice_cream_scoop_mesh:
		ice_cream_scoop_mesh.scale = Vector3.ONE

func _update_elastic_strand() -> void:
	if not is_instance_valid(_elastic_strand):
		return
	if not is_diving or current_target_flavor == null or not is_instance_valid(current_target_tub):
		_elastic_strand.visible = false
		return
	var tip: Vector3 = get_scoop_tip_global_position()
	var displacement: Vector3 = tip - _elastic_anchor
	var length: float = displacement.length()
	_elastic_strand.visible = length > 0.015 and length < 1.0
	if not _elastic_strand.visible:
		return
	_elastic_strand.global_position = (_elastic_anchor + tip) * 0.5
	# CylinderMesh runs along local Y; orient its Y axis along the strand.
	_elastic_strand.global_basis = Basis(Quaternion(Vector3.UP, displacement.normalized()))
	var tension: float = clampf(length / 0.45, 0.0, 1.0)
	_elastic_strand.scale = Vector3(1.0 - tension * 0.65, length, 1.0 - tension * 0.65)

func _start_elastic_strand(anchor: Vector3, flavor: FlavorData) -> void:
	_clear_elastic_strand()
	_elastic_anchor = anchor
	_elastic_strand = MeshInstance3D.new()
	_elastic_strand.name = "ElasticMarasStrand"
	var strand_mesh: CylinderMesh = CylinderMesh.new()
	strand_mesh.top_radius = 0.012
	strand_mesh.bottom_radius = 0.021
	strand_mesh.height = 1.0
	var strand_material: StandardMaterial3D = StandardMaterial3D.new()
	strand_material.albedo_color = flavor.color
	strand_material.roughness = 0.72
	strand_mesh.material = strand_material
	_elastic_strand.mesh = strand_mesh
	get_tree().root.add_child(_elastic_strand)
	_elastic_strand.visible = false

func _clear_elastic_strand() -> void:
	if is_instance_valid(_elastic_strand):
		_elastic_strand.queue_free()
	_elastic_strand = null

func _exit_tree() -> void:
	_clear_elastic_strand()

func _handle_dive_motion(delta: float) -> void:
	var speed = return_speed_full if has_ice_cream() else return_speed_empty
	
	if is_diving:
		speed = dive_spring_speed
		# Fare aşağı çekildikçe bilek dondurmayı oymak için aşağı ve ters döner
		var scrape_lift = ease(_scoop_progress, 1.5) * 0.045
		var scrape_pull = -ease(_scoop_progress, 1.5) * 0.085
		var scrape_pitch = lerpf(deg_to_rad(42.0), deg_to_rad(105.0), _scoop_progress)
		var scrape_roll = lerpf(-deg_to_rad(8.0), deg_to_rad(65.0), _scoop_progress)
		var scrape_yaw = lerpf(-deg_to_rad(10.0), deg_to_rad(22.0), _scoop_progress)
		
		var live_dive_pos = _dive_target_pos + Vector3(0, scrape_lift, scrape_pull)
		var live_dive_rot = Vector3(scrape_pitch, scrape_yaw, scrape_roll)
		
		var blend := 1.0 - exp(-speed * delta)
		position = position.lerp(live_dive_pos, blend)
		rotation = rotation.lerp(live_dive_rot, blend)
	else:
		var blend := 1.0 - exp(-speed * delta)
		position = position.lerp(_base_local_pos, blend)
		rotation = rotation.lerp(Vector3.ZERO, blend)

func _handle_jiggle_physics(delta: float) -> void:
	if not ice_cream_scoop_mesh or current_scooped_flavor == null:
		_jiggle_offset = Vector3.ZERO
		_jiggle_velocity = Vector3.ZERO
		_prev_world_pos = global_position
		if ice_cream_scoop_mesh:
			ice_cream_scoop_mesh.position = Vector3(0, 0.01, -0.2)
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
	if is_animating or is_diving:
		return
	if has_ice_cream():
		EventBus.notification_requested.emit("Kepçede zaten dondurma var!", 1.2)
		return
		
	if flavor == null:
		return
		
	is_diving = true
	is_animating = true
	current_target_tub = tub_node
	current_target_flavor = flavor
	if is_instance_valid(tub_node):
		_start_elastic_strand(hit_point if hit_point != Vector3.ZERO else tub_node.global_position, flavor)
	_accumulated_drag = 0.0
	_accumulated_depth = 0.0
	_scoop_progress = 0.0
	_is_scoop_ready_in_dive = false
	
	var target_world = hit_point
	if target_world == Vector3.ZERO and is_instance_valid(tub_node):
		target_world = tub_node.global_position + Vector3(0, 0.05, 0.05)
		
	if get_parent():
		var local_target = get_parent().to_local(target_world)
		_dive_target_pos = local_target + Vector3(0.03, 0.06, 0.15)
	else:
		_dive_target_pos = _base_local_pos + Vector3(0, -0.35, -0.55)
		
	_dive_target_rot = Vector3(deg_to_rad(42.0), -deg_to_rad(10.0), deg_to_rad(10.0))
	
	# Tatlı Daldırma Animasyonu (Anticipation Lift -> Plunge into Tub)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	_motion_tween = tween
	
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
		if _scoop_progress >= 1.0 and is_diving:
			_complete_scoop_and_retract()
	)
	
	EventBus.notification_requested.emit("Kepçelemek için fareyi çek...", 0.8)

func process_dive_mouse_input(relative: Vector2) -> void:
	if not is_diving or _is_scoop_ready_in_dive:
		return
		
	# Aşağı yönlü çekiş hareketi + Dükkan Scoop Speed Upgrade'i
	var speed_boost = 1.0 + GameManager.get_upgrade_effect("scoop_speed", "scoop_speed")
	var down_amount = max(0.0, relative.y) * speed_boost
	var general_drag = relative.length() * speed_boost
	
	_accumulated_depth += down_amount
	_accumulated_drag += general_drag
	
	var depth_ratio = clampf(_accumulated_depth / required_depth, 0.0, 1.0)
	var drag_ratio = clampf(_accumulated_drag / required_drag_distance, 0.0, 1.0)
	
	# The final third feels heavier without changing the required mouse distance.
	var raw_progress: float = (depth_ratio * 0.7) + (drag_ratio * 0.3)
	_scoop_progress = ease(raw_progress, 1.25)
	EventBus.scoop_dive_progress.emit(_scoop_progress)
	
	if _scoop_progress >= 1.0 and not is_animating:
		_complete_scoop_and_retract()

func _complete_scoop_and_retract() -> void:
	_is_scoop_ready_in_dive = true
	_scoop_pop = 1.0
	_clear_elastic_strand()
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
	_motion_tween = tween
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
	if _motion_tween and _motion_tween.is_valid():
		_motion_tween.kill()
	is_animating = true
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	_motion_tween = tween
	
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
	if not is_diving:
		return
	if _motion_tween and _motion_tween.is_valid():
		_motion_tween.kill()
	is_animating = false
		
	is_diving = false
	_clear_elastic_strand()
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
	_scoop_pop = 0.0
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
