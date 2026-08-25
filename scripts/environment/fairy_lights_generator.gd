class_name FairyLightsGenerator
extends Node3D

@export var street_width: float = 7.4
@export var street_depth_start: float = -1.5
@export var street_depth_end: float = -26.0
@export var wire_count: int = 14
@export var bulbs_per_wire: int = 12
@export var base_height: float = 4.3
@export var wire_sag_amount: float = 0.35 # Kablonun ortadaki sarkma miktarı

# Ampul Renk Havuzu (Stone Street: Sıcak Altın, Eflatun/Mor, Pembe, Mavi)
const BULB_COLORS: Array[Color] = [
	Color(1.0, 0.82, 0.35, 1.0), # Altın Sarısı
	Color(1.0, 0.75, 0.25, 1.0), # Sıcak Kehribar
	Color(0.85, 0.35, 1.0, 1.0),  # Eflatun / Mor
	Color(0.95, 0.25, 0.75, 1.0), # Pembe / Magenta
	Color(0.35, 0.65, 1.0, 1.0)   # Elektrik Mavisi
]

func _ready() -> void:
	_generate_fairy_canopy()

func _generate_fairy_canopy() -> void:
	# Rastgele tohumu sabitle veya dinamik yap
	seed(42)
	
	var total_bulbs = wire_count * bulbs_per_wire
	
	# MultiMeshInstance3D ile sıfır performans kaybı
	var multi_mesh_inst = MultiMeshInstance3D.new()
	var multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.instance_count = total_bulbs
	
	var sphere = SphereMesh.new()
	sphere.radius = 0.038
	sphere.height = 0.076
	
	var bulb_mat = StandardMaterial3D.new()
	bulb_mat.vertex_color_use_as_albedo = true
	bulb_mat.emission_enabled = true
	bulb_mat.emission_energy_multiplier = 2.4
	# Vertex rengiyle emisyonu beslemek için:
	bulb_mat.emission = Color.WHITE
	bulb_mat.roughness = 0.2
	sphere.material = bulb_mat
	
	multi_mesh.mesh = sphere
	multi_mesh_inst.multimesh = multi_mesh
	add_child(multi_mesh_inst)
	
	var current_bulb_idx = 0
	var z_step = (street_depth_end - street_depth_start) / float(wire_count)
	
	for w in range(wire_count):
		var z_base = street_depth_start + (w * z_step)
		var z_left = z_base + randf_range(-0.6, 0.6)
		var z_right = z_base + randf_range(-0.6, 0.6)
		
		# Çapraz zig-zag kablo bağlantıları
		if w % 2 == 1:
			z_right -= randf_range(0.8, 1.6)
		else:
			z_left -= randf_range(0.8, 1.6)
			
		var left_pt = Vector3(-street_width * 0.5, base_height + randf_range(-0.15, 0.15), z_left)
		var right_pt = Vector3(street_width * 0.5, base_height + randf_range(-0.15, 0.15), z_right)
		var sag = wire_sag_amount * randf_range(0.8, 1.25)
		
		# Kablo görselini oluştur (Curve)
		_create_wire_mesh(left_pt, right_pt, sag)
		
		# Tel boyunca ampulleri yerleştir
		for b in range(bulbs_per_wire):
			if current_bulb_idx >= total_bulbs:
				break
				
			var t = (float(b) + randf_range(0.15, 0.85)) / float(bulbs_per_wire)
			# Parabolik sarkma formülü: y = 4 * sag * t * (1 - t)
			var sag_y = 4.0 * sag * t * (1.0 - t)
			var pos = left_pt.lerp(right_pt, t)
			pos.y -= sag_y
			
			var xform = Transform3D(Basis(), pos)
			multi_mesh.set_instance_transform(current_bulb_idx, xform)
			
			var random_color = BULB_COLORS.pick_random()
			multi_mesh.set_instance_color(current_bulb_idx, random_color)
			current_bulb_idx += 1

func _create_wire_mesh(start_pt: Vector3, end_pt: Vector3, sag: float) -> void:
	var segments = 10
	var prev_pt = start_pt
	
	for s in range(1, segments + 1):
		var t = float(s) / float(segments)
		var sag_y = 4.0 * sag * t * (1.0 - t)
		var curr_pt = start_pt.lerp(end_pt, t)
		curr_pt.y -= sag_y
		
		var seg_mesh = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.0035
		cyl.bottom_radius = 0.0035
		var dist = prev_pt.distance_to(curr_pt)
		cyl.height = dist
		
		var wire_mat = StandardMaterial3D.new()
		wire_mat.albedo_color = Color(0.12, 0.12, 0.12, 1.0)
		wire_mat.roughness = 0.9
		seg_mesh.mesh = cyl
		seg_mesh.material_override = wire_mat
		
		add_child(seg_mesh)
		
		# İki nokta arasına konumlandır ve döndür
		var mid = (prev_pt + curr_pt) * 0.5
		seg_mesh.position = mid
		seg_mesh.look_at(curr_pt, Vector3.UP)
		seg_mesh.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
		
		prev_pt = curr_pt
