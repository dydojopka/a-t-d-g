extends Node3D
## Небольшая лаборатория масштаба, силуэтов, освещения и перемещения.

const FLOOR_SHADER: Shader = preload("res://shaders/test_floor.gdshader")
const INK := Color("d8e6df")
const MUTED := Color("8faaa9")
const ACCENT := Color("9ee4c6")

@onready var world: Node3D = $World
@onready var player: CharacterBody3D = $Player

var help_labels: Dictionary = {}
var help_block: VBoxContainer
var capture_hint: Label
var movement_state: Label


func _ready() -> void:
	_build_room()
	_build_hud()
	Locale.locale_changed.connect(_refresh_text)
	player.mouse_capture_changed.connect(_refresh_capture_hint)
	_refresh_text()


func _build_room() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b141b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b6cbd2")
	environment.ambient_light_energy = 0.07
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)

	var wall := _material(Color("64737a"))
	var trim := _material(Color("293a43"))
	var metal := _material(Color("52646c"))
	var floor_material := ShaderMaterial.new()
	floor_material.shader = FLOOR_SHADER
	_box("Floor", Vector3(16.4, 0.3, 18.4), Vector3(0, -0.15, 0), floor_material)
	_box("Ceiling", Vector3(16.4, 0.2, 18.4), Vector3(0, 4.3, 0), trim)
	_box("WestWall", Vector3(0.3, 4.2, 18), Vector3(-8.15, 2.1, 0), wall)
	_box("EastWall", Vector3(0.3, 4.2, 18), Vector3(8.15, 2.1, 0), wall)
	_box("BackWall", Vector3(16.4, 4.2, 0.3), Vector3(0, 2.1, -9.15), wall)
	_box("EntryWall", Vector3(16.4, 4.2, 0.3), Vector3(0, 2.1, 9.15), wall)
	# Ниша в глубине отделена широким дверным проёмом.
	_box("PartitionLeft", Vector3(6.4, 4.2, 0.35), Vector3(-4.8, 2.1, -3.3), wall)
	_box("PartitionRight", Vector3(6.4, 4.2, 0.35), Vector3(4.8, 2.1, -3.3), wall)
	_box("DoorLintel", Vector3(3.2, 1.3, 0.35), Vector3(0, 3.55, -3.3), trim)
	for side: float in [-1.0, 1.0]:
		_box("DoorFrame", Vector3(0.14, 2.9, 0.46), Vector3(side * 1.65, 1.45, -3.3), metal)
		_box("WallRail", Vector3(0.08, 0.12, 18), Vector3(side * 7.96, 0.65, 0), trim)
		for z: float in [-6.0, 0.0, 6.0]:
			_box("WallRib", Vector3(0.22, 4.2, 0.2), Vector3(side * 7.85, 2.1, z), trim)

	# Освещённый участок слева служит ориентиром; остальные зоны заметно темнее.
	_light_strip(Vector3(-4.6, 4.12, 1.7), Color("ffce91"), 2.8, 6.8)
	_light_strip(Vector3(4.6, 4.12, 1.7), Color("9bdfed"), 0.0)
	_light_strip(Vector3(0, 4.12, -6.3), Color("b6eed5"), 0.0)
	_light(Vector3(0, 3.5, 6.7), Color("c9d9e5"), 0.55, 5.5)
	# Боковой свет даёт слабые контуры на правых объектах и глубокие тени за ними.
	_box("WallLight", Vector3(0.05, 0.18, 0.65), Vector3(7.94, 2.5, 0.6), _material(Color("78a2c1"), 1.5), false)
	_light(Vector3(7.55, 2.5, 0.6), Color("78a2c1"), 1.1, 5.0)

	# Одинаковые основания помогают сравнивать размеры и силуэты.
	_display_shape("Cube", Vector3(-4.6, 0, 3.2), Color("df7860"), 0)
	_display_shape("Sphere", Vector3(-4.6, 0, -0.7), Color("efc773"), 1)
	_display_shape("Cylinder", Vector3(4.6, 0, 3.2), Color("70b8ce"), 2)
	_display_shape("Cone", Vector3(4.6, 0, -0.7), Color("a99ad7"), 3)
	_display_shape("Torus", Vector3(-4.8, 0, -6.2), Color("85c49e"), 4)

	_build_desk(Vector3(1.8, 0, -7.5), metal)
	_build_shelf(Vector3(6.3, 0, -7.4), metal)
	# Низкая балка: стоя не пройти, присев можно пройти насквозь.
	_box("LowPassageTop", Vector3(2.4, 0.35, 2.2), Vector3(-6.25, 1.425, 6.0), metal)
	for side: float in [-1.0, 1.0]:
		_box("LowPassageLeg", Vector3(0.16, 1.25, 2.2), Vector3(-6.25 + side * 1.12, 0.625, 6.0), trim)
	_box("BenchSeat", Vector3(2.8, 0.16, 0.8), Vector3(5.6, 0.5, 7), _material(Color("a08c70")))
	for x: float in [4.5, 6.7]:
		_box("BenchLeg", Vector3(0.14, 0.42, 0.64), Vector3(x, 0.21, 7), metal)


func _display_shape(object_name: String, origin: Vector3, color: Color, kind: int) -> void:
	_box(object_name + "Plinth", Vector3(2.3, 0.25, 2.3), origin + Vector3(0, 0.125, 0), _material(Color("394a54")))
	var mesh: PrimitiveMesh
	var shape: Shape3D
	var center := origin + Vector3(0, 1.1, 0)
	match kind:
		0:
			var cube := BoxMesh.new()
			cube.size = Vector3(1.6, 1.7, 1.6)
			mesh = cube
			var box_shape := BoxShape3D.new()
			box_shape.size = cube.size
			shape = box_shape
		1:
			var sphere := SphereMesh.new()
			sphere.radius = 0.9
			sphere.height = 1.8
			mesh = sphere
			var sphere_shape := SphereShape3D.new()
			sphere_shape.radius = 0.9
			shape = sphere_shape
			center.y = 1.15
		2, 3:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.0 if kind == 3 else 0.7
			cylinder.bottom_radius = 0.9 if kind == 3 else 0.7
			cylinder.height = 1.7
			mesh = cylinder
			shape = cylinder.create_convex_shape()
		4:
			var torus := TorusMesh.new()
			torus.inner_radius = 0.48
			torus.outer_radius = 0.95
			mesh = torus
			# Выпуклая коллизия не подходит для отверстия тора.
			shape = torus.create_trimesh_shape()
			center.y = 1.2
	var body := _solid(object_name, mesh, shape, center, _material(color))
	if kind == 0:
		body.rotation_degrees.y = 18.0
	elif kind == 4:
		body.rotation_degrees.x = 90.0


func _build_desk(origin: Vector3, metal: Material) -> void:
	_box("DeskTop", Vector3(2.8, 0.15, 1.25), origin + Vector3(0, 0.85, 0), _material(Color("b6a188")))
	for x: float in [-1.2, 1.2]:
		for z: float in [-0.45, 0.45]:
			_box("DeskLeg", Vector3(0.12, 0.78, 0.12), origin + Vector3(x, 0.39, z), metal)
	_box("MonitorFoot", Vector3(0.65, 0.06, 0.4), origin + Vector3(0, 0.96, -0.15), metal)
	_box("MonitorStand", Vector3(0.12, 0.4, 0.1), origin + Vector3(0, 1.13, -0.2), metal)
	_box("MonitorCase", Vector3(1.15, 0.75, 0.2), origin + Vector3(0, 1.55, -0.25), _material(Color("27333a")))
	_box("MonitorScreen", Vector3(0.98, 0.58, 0.025), origin + Vector3(0, 1.55, -0.14), _material(Color("64b9a4"), 0.7), false)
	# В тёмной нише экран слабо освещает только стол и ближайшее окружение.
	_light(origin + Vector3(0, 1.5, 0.15), Color("64b9a4"), 0.6, 3.1)
	_box("Keyboard", Vector3(0.85, 0.055, 0.3), origin + Vector3(0, 0.96, 0.36), metal)


func _build_shelf(origin: Vector3, metal: Material) -> void:
	for x: float in [-1.05, 1.05]:
		for z: float in [-0.42, 0.42]:
			_box("ShelfUpright", Vector3(0.1, 2.8, 0.1), origin + Vector3(x, 1.4, z), metal)
	for y: float in [0.12, 1.0, 1.9, 2.75]:
		_box("ShelfBoard", Vector3(2.2, 0.09, 0.95), origin + Vector3(0, y, 0), metal)
	for index: int in 3:
		_box("StoredBox", Vector3(0.65, 0.55, 0.65), origin + Vector3(-0.65 + index * 0.65, 1.32, 0), _material(Color("a8916d")))
	_box("TallBox", Vector3(0.7, 0.72, 0.65), origin + Vector3(-0.5, 0.525, 0), _material(Color("8c9fa8")))


func _box(object_name: String, dimensions: Vector3, center: Vector3, material: Material, collidable: bool = true) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var shape := BoxShape3D.new()
	shape.size = dimensions
	return _solid(object_name, mesh, shape if collidable else null, center, material)


func _solid(object_name: String, mesh: Mesh, shape: Shape3D, center: Vector3, material: Material) -> Node3D:
	var body: Node3D = StaticBody3D.new() if shape != null else Node3D.new()
	body.name = object_name
	body.position = center
	world.add_child(body)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	if shape != null:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
	return body


func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


func _light_strip(center: Vector3, color: Color, energy: float, radius: float = 6.8) -> void:
	var material := _material(color, 2.0) if energy > 0.0 else _material(Color("28343b"))
	_box("CeilingLight", Vector3(0.3, 0.06, 3.0), center, material, false)
	if energy > 0.0:
		_light(center - Vector3(0, 0.45, 0), color, energy, radius)


func _light(center: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = center
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = true
	world.add_child(light)


func _build_hud() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_font_override("font", font)
	$HUD.add_child(root)

	var header := VBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.position = Vector2(26, 22)
	header.add_theme_constant_override("separation", 5)
	root.add_child(header)
	_add_text(header, "ui.test_room.title", 17, ACCENT)
	_add_text(header, "ui.test_room.subtitle", 12, MUTED)

	var crosshair := _label("+", 19, INK)
	root.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -8
	crosshair.offset_right = 8
	crosshair.offset_top = -13
	crosshair.offset_bottom = 13
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	help_block = VBoxContainer.new()
	help_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(help_block)
	help_block.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help_block.offset_left = 26
	help_block.offset_top = -164
	help_block.offset_bottom = -42
	help_block.add_theme_constant_override("separation", 3)
	for key: String in ["movement", "look", "sprint", "crouch", "release_mouse"]:
		_add_text(help_block, "ui.controls." + key, 15, INK)

	capture_hint = _label("", 13, ACCENT)
	root.add_child(capture_hint)
	capture_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	capture_hint.offset_left = 26
	capture_hint.offset_top = -30
	capture_hint.offset_right = -26
	capture_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	movement_state = _label("", 13, MUTED)
	root.add_child(movement_state)
	movement_state.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	movement_state.offset_left = -180
	movement_state.offset_top = 26
	movement_state.offset_right = -26
	movement_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _label(content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("091016"))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_shadow_color", Color("091016"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _add_text(parent: Node, key: String, font_size: int, color: Color) -> void:
	var label := _label(Locale.text(key), font_size, color)
	help_labels[key] = label
	parent.add_child(label)


func _refresh_text(_code: String = "") -> void:
	for key: String in help_labels:
		(help_labels[key] as Label).text = Locale.text(key)
	_refresh_capture_hint(player.is_mouse_captured())


func _refresh_capture_hint(captured: bool) -> void:
	capture_hint.text = Locale.text("ui.test_room.hint_captured" if captured else "ui.test_room.hint_released")


func _process(_delta: float) -> void:
	var state := "ui.test_room.state_walk"
	if player.is_crouching():
		state = "ui.test_room.state_crouch"
	elif player.is_sprinting():
		state = "ui.test_room.state_sprint"
	movement_state.text = Locale.text(state)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		help_block.visible = not help_block.visible
		get_viewport().set_input_as_handled()
