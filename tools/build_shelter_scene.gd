extends SceneTree
## Разовая сборка редактируемых ресурсов. Во время игры этот скрипт не используется.
## Запуск: Godot --headless --path <проект> --script res://tools/build_shelter_scene.gd

const ASSETS := "res://assets/architecture/"
const MODULES := "res://scenes/architecture/"
const LEVEL := "res://scenes/shelter/shelter_apartment.tscn"
const MODULE_NAMES := ["wall_0p5m", "wall_1m", "wall_2m", "wall_1m_stained", "wall_corner_L_1m",
	"doorway_1p5m", "doorway_2m", "window_2m", "floor_1m", "floor_2m", "ceiling_1m", "ceiling_2m"]

var materials: Dictionary = {}
var modules: Dictionary = {}
var apartment: Node3D
var fitted_count := 0


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	for folder: String in [MODULES, "res://scenes/shelter/", ASSETS + "meshes/", ASSETS + "materials/shelter/", ASSETS + "materials/corridor/"]:
		DirAccess.make_dir_recursive_absolute(folder)
	_create_materials()
	for module_name: String in MODULE_NAMES:
		_create_module(module_name)
	_create_apartment()
	print("SHELTER_BUILT: 12 reusable modules, shared materials, apartment scene, existing Player instance; fitted infills: ", fitted_count)
	quit()


func _save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	var result := packed.pack(node)
	assert(result == OK, "Не удалось упаковать сцену " + path)
	result = ResourceSaver.save(packed, path)
	assert(result == OK, "Не удалось сохранить сцену " + path)


func _create_materials() -> void:
	var shader: Shader = load("res://shaders/architecture_surface.gdshader")
	for profile: String in ["shelter", "corridor"]:
		for surface: String in ["wall", "floor", "ceiling"]:
			var material := ShaderMaterial.new()
			material.resource_name = profile + "_" + surface
			material.shader = shader
			material.set_shader_parameter("wall_projection", surface == "wall")
			material.set_shader_parameter("surface_origin", Vector3.ZERO)
			material.set_shader_parameter("wall_period", 16.0)
			material.set_shader_parameter("wall_height", 2.6)
			material.set_shader_parameter("horizontal_period", 8.0)
			material.set_shader_parameter("normal_strength", 0.65)
			material.set_shader_parameter("color_multiplier", Vector3.ONE)
			for entry: Array in [["basecolor", "color_texture"], ["roughness", "roughness_texture"], ["normal", "normal_texture"]]:
				material.set_shader_parameter(entry[1], load(ASSETS + "textures/" + profile + "/" + surface + "_" + str(entry[0]) + ".png"))
			var path := ASSETS + "materials/" + profile + "/" + surface + ".tres"
			assert(ResourceSaver.save(material, path, ResourceSaver.FLAG_CHANGE_PATH) == OK)
			material.take_over_path(path)
			materials[profile + "_" + surface] = material
		var damp: ShaderMaterial = materials[profile + "_wall"].duplicate()
		damp.resource_name = profile + "_wall_stained"
		damp.set_shader_parameter("color_multiplier", Vector3(0.9, 0.93, 0.91))
		assert(ResourceSaver.save(damp, ASSETS + "materials/" + profile + "/wall_stained.tres", ResourceSaver.FLAG_CHANGE_PATH) == OK)
		damp.take_over_path(ASSETS + "materials/" + profile + "/wall_stained.tres")
		materials[profile + "_wall_stained"] = damp


func _find_mesh(node: Node, inherited: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	var transform := inherited
	if node is Node3D:
		transform = inherited * (node as Node3D).transform
	if node is MeshInstance3D:
		return {"mesh": (node as MeshInstance3D).mesh, "transform": transform}
	for child: Node in node.get_children():
		var found := _find_mesh(child, transform)
		if not found.is_empty():
			return found
	return {}


func _create_module(module_name: String) -> void:
	var source: PackedScene = load(ASSETS + "models/" + module_name + ".glb")
	assert(source != null, "Не импортирован модуль " + module_name)
	var imported := source.instantiate()
	var mesh_data := _find_mesh(imported)
	assert(not mesh_data.is_empty(), "В модуле отсутствует Mesh " + module_name)
	var mesh: Mesh = mesh_data["mesh"]
	assert(ResourceSaver.save(mesh, ASSETS + "meshes/" + module_name + ".res", ResourceSaver.FLAG_CHANGE_PATH) == OK)
	mesh.take_over_path(ASSETS + "meshes/" + module_name + ".res")
	var body := StaticBody3D.new()
	body.name = module_name.to_pascal_case()
	body.set_meta("source_module", module_name)
	body.set_meta("grid_m", 0.5)
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = mesh
	visual.transform = mesh_data["transform"]
	var surface := "floor" if module_name.begins_with("floor_") else "ceiling" if module_name.begins_with("ceiling_") else "wall"
	if module_name.ends_with("stained"):
		surface = "wall_stained"
	visual.material_override = materials["shelter_" + surface]
	body.add_child(visual)
	visual.owner = body
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = mesh.create_trimesh_shape()
	collision.transform = visual.transform
	body.add_child(collision)
	collision.owner = body
	_save_scene(body, MODULES + module_name + ".tscn")
	modules[module_name] = load(MODULES + module_name + ".tscn")
	imported.free()
	body.free()


func _group(name: String, parent: Node = null) -> Node3D:
	var group := Node3D.new()
	group.name = name
	(parent if parent != null else apartment).add_child(group)
	group.owner = apartment
	return group


func _module(name: String, asset: String, parent: Node, x: float, plan_y: float,
		angle: float = 0.0, height: float = 0.0, fit_width: float = 0.0) -> Node3D:
	var instance: Node3D = (modules[asset] as PackedScene).instantiate()
	instance.name = name
	parent.add_child(instance)
	instance.owner = apartment
	instance.position = Vector3(x, height, -plan_y)
	instance.rotation.y = deg_to_rad(angle)
	if fit_width > 0.0:
		# Подгоняется экземпляр простого прямоугольного модуля; исходный Mesh не изменяется.
		var mesh := instance.get_node("Mesh") as MeshInstance3D
		var bounds: AABB = mesh.transform * mesh.mesh.get_aabb()
		var scale_transform := Transform3D(Basis.from_scale(Vector3(fit_width / bounds.size.x, 1.0, 1.0)), Vector3.ZERO)
		mesh.transform = scale_transform * mesh.transform
		bounds = mesh.transform * mesh.mesh.get_aabb()
		var collision := instance.get_node("Collision") as CollisionShape3D
		var box := BoxShape3D.new()
		box.size = bounds.size
		collision.shape = box
		collision.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
		apartment.set_editable_instance(instance, true)
		instance.set_meta("fitted_width_m", fit_width)
		fitted_count += 1
	return instance


func _marker(name: String, x: float, plan_y: float) -> void:
	var marker := Marker3D.new()
	marker.name = name
	marker.position = Vector3(x, 0, -plan_y)
	apartment.get_node("RoomMarkers").add_child(marker)
	marker.owner = apartment


func _create_apartment() -> void:
	apartment = Node3D.new()
	apartment.name = "ShelterApartment"
	apartment.set_meta("description_ru", "Геометрия однокомнатного убежища: комната у окна, кухня слева, санузел справа, прихожая с нишей. Мебель не установлена.")
	apartment.set_meta("interior_bounds_m", Vector3(4.5, 2.6, 8.0))
	var architecture := _group("Architecture")
	var perimeter := _group("PerimeterWalls", architecture)
	var partitions := _group("Partitions", architecture)
	var floor := _group("Floor", architecture)
	var ceiling := _group("Ceiling", architecture)
	_group("RoomMarkers")
	var lights := _group("PreviewDeviceLighting")
	lights.set_meta("description_ru", "Временная имитация света монитора и радио для осмотра геометрии; модели устройств будут добавлены отдельно.")

	# Пол и потолок: два ряда 2-метровых плит и узкая полоса из тех же метровых ассетов.
	for x: int in [0, 2]:
		for y: int in [0, 2, 4, 6]:
			_module("Floor_%d_%d" % [x, y], "floor_2m", floor, x, y)
			_module("Ceiling_%d_%d" % [x, y], "ceiling_2m", ceiling, x, y, 0, 2.6)
	for y: int in range(8):
		_module("FloorEdge_%d" % y, "floor_1m", floor, 4, y, 0, 0, 0.5)
		_module("CeilingEdge_%d" % y, "ceiling_1m", ceiling, 4, y, 0, 2.6, 0.5)

	_module("CornerSW", "wall_corner_L_1m", perimeter, 0, 0)
	_module("CornerSE", "wall_corner_L_1m", perimeter, 4.5, 0, 90)
	_module("CornerNE", "wall_corner_L_1m", perimeter, 4.5, 8, 180)
	_module("CornerNW", "wall_corner_L_1m", perimeter, 0, 8, 270)
	_module("EntranceLeft", "wall_0p5m", perimeter, 1, 0)
	_module("EntranceOpening", "doorway_1p5m", perimeter, 1.5, 0)
	_module("EntranceRight", "wall_0p5m", perimeter, 3, 0)
	_module("LivingWindow", "window_2m", perimeter, 3, 8, 180)
	_module("WindowRight", "wall_0p5m", perimeter, 3.5, 8, 180)
	for y: int in [1, 3, 5]:
		_module("East_%d" % y, "wall_2m", perimeter, 4.5, y, 90)
	for y: int in [7, 5, 3]:
		_module("West_%d" % y, "wall_2m", perimeter, 0, y, 270)

	# Перегородка комнаты с центральным проёмом в прихожую.
	_module("LivingLeft", "wall_1m", partitions, 0, 3.5)
	_module("LivingLeftEnd", "wall_0p5m", partitions, 1, 3.5)
	_module("LivingOpening", "doorway_1p5m", partitions, 1.5, 3.5)
	_module("LivingRight", "wall_1m", partitions, 3, 3.5)
	_module("LivingRightEnd", "wall_0p5m", partitions, 4, 3.5)
	# Кухня слева: проход из средней части прихожей.
	_module("KitchenLower", "wall_1m", partitions, 1.5, 0, 90)
	_module("KitchenOpening", "doorway_1p5m", partitions, 1.5, 1, 90)
	_module("KitchenUpper", "wall_0p5m", partitions, 1.5, 2.5, 90)
	_module("KitchenJunction", "wall_0p5m", partitions, 1.5, 3, 90, 0, 0.3)
	# Санузел справа; перед ним остаётся ниша прихожей.
	_module("BathroomOpening", "doorway_1p5m", partitions, 2.9, 3.3, 270)
	_module("BathroomLower", "wall_0p5m", partitions, 2.9, 1.8, 270)
	_module("BathroomLowerEnd", "wall_0p5m", partitions, 2.9, 1.3, 270, 0, 0.1)
	_module("BathroomFront", "wall_1m", partitions, 2.9, 1.2)
	_module("BathroomFrontEnd", "wall_0p5m", partitions, 3.9, 1.2)
	_module("BathroomFrontJunction", "wall_0p5m", partitions, 4.4, 1.2, 0, 0, 0.1)
	_module("BathroomCornerFill", "wall_0p5m", partitions, 2.7, 1.2, 0, 0, 0.2)

	_marker("LivingRoom", 2.25, 5.7)
	_marker("Kitchen", 0.75, 1.7)
	_marker("Bathroom", 3.7, 2.2)
	_marker("EntranceHall", 2.2, 1.5)
	_marker("HallNiche", 3.5, 0.5)

	# Пока внешний этаж не построен, ограничитель закрывает выход за границу сцены.
	var entrance_boundary := StaticBody3D.new()
	entrance_boundary.name = "EntranceBoundary"
	entrance_boundary.set_meta("description_ru", "Временная граница уровня за входным проёмом. Удалить при подключении общего коридора; это не дверь.")
	apartment.add_child(entrance_boundary)
	entrance_boundary.owner = apartment
	var boundary_shape := CollisionShape3D.new()
	boundary_shape.name = "Collision"
	var boundary_box := BoxShape3D.new()
	boundary_box.size = Vector3(0.9, 2.1, 0.12)
	boundary_shape.shape = boundary_box
	boundary_shape.position = Vector3(2.25, 1.05, 0.27)
	entrance_boundary.add_child(boundary_shape)
	boundary_shape.owner = apartment

	var environment_node := WorldEnvironment.new()
	environment_node.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.001, 0.002, 0.003)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.31, 0.38)
	environment.ambient_light_energy = 0.10
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	apartment.add_child(environment_node)
	environment_node.owner = apartment
	var monitor := OmniLight3D.new()
	monitor.name = "MonitorGlowPreview"
	monitor.position = Vector3(3.05, 1.1, -7.45)
	monitor.light_color = Color(0.58, 0.78, 0.64)
	monitor.light_energy = 3.0
	monitor.omni_range = 6.5
	monitor.omni_attenuation = 1.25
	monitor.shadow_enabled = true
	lights.add_child(monitor)
	monitor.owner = apartment
	var radio := OmniLight3D.new()
	radio.name = "RadioGlowPreview"
	radio.position = Vector3(2.4, 0.95, -7.4)
	radio.light_color = Color(0.85, 0.44, 0.14)
	radio.light_energy = 0.7
	radio.omni_range = 4.0
	radio.shadow_enabled = true
	lights.add_child(radio)
	radio.owner = apartment

	var player: Node3D = (load("res://scenes/player/first_person_player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	player.position = Vector3(2.25, 0.05, -4.3)
	apartment.add_child(player)
	player.owner = apartment
	var ascii: Node = (load("res://addons/ascii_renderer/ascii_renderer.tscn") as PackedScene).instantiate()
	ascii.name = "AsciiRenderer"
	ascii.set("brightness", 1.65)
	ascii.set("contrast", 0.95)
	ascii.set("gamma", 0.85)
	apartment.add_child(ascii)
	ascii.owner = apartment
	_save_scene(apartment, LEVEL)
	apartment.free()
