extends Node3D
## Small render study. Geometry is generated from built-in Godot primitives.

@export var grid_shader: Shader

const ACCENT := Color("83efd2")
const TEXT := Color("e7eef5")
const MUTED := Color("8d9eaf")
const PRIMITIVE_MATERIAL: ShaderMaterial = preload("res://assets/materials/primitive_surface.tres")
const SHAPE_COLORS: Array[Color] = [
	Color("fa6173"), Color("ffcd67"), Color("64d6f0"),
	Color("a38bff"), Color("71e5aa"), Color("f68acb"),
]

@onready var world: Node3D = $World
@onready var camera: Camera3D = $Camera3D
@onready var ascii: AsciiRenderer = $AsciiRenderer

var figures: Array[MeshInstance3D] = []
var view_buttons: Array[Button] = []
var color_toggle: CheckButton
var character_selector: OptionButton
var pause_button: Button
var size_slider: HSlider
var size_label: Label
var status_label: Label
var split_labels: HBoxContainer
var view_mode: int = 1
var paused: bool = false
var elapsed: float = 0.0
var camera_yaw: float = 0.22


func _ready() -> void:
	_build_world()
	_build_hud()
	_update_camera()
	_set_view(1)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_previews.call_deferred(argument.trim_prefix("--capture-dir="))


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("090f1a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8c8e2")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.light_color = Color("fff1de")
	key.light_energy = 1.25
	key.shadow_enabled = true
	world.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(4.0, 5.0, 2.0)
	fill.light_color = Color("bddfff")
	fill.light_energy = 1.3
	fill.omni_range = 18.0
	world.add_child(fill)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(200.0, 200.0)
	var floor_material := ShaderMaterial.new()
	floor_material.shader = grid_shader
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = floor_material
	world.add_child(floor_instance)

	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 1.65
	var sphere := SphereMesh.new()
	sphere.radius = 0.95
	sphere.height = 1.9
	var torus := TorusMesh.new()
	torus.inner_radius = 0.48
	torus.outer_radius = 1.03
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.95
	cone.height = 1.9
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.72
	cylinder.bottom_radius = 0.72
	cylinder.height = 1.9
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.68
	capsule.height = 2.1
	var meshes: Array[Mesh] = [cube, sphere, torus, cone, cylinder, capsule]
	var names: Array[String] = ["Cube", "Sphere", "Torus", "Cone", "Cylinder", "Capsule"]
	var pedestal := CylinderMesh.new()
	pedestal.top_radius = 1.3
	pedestal.bottom_radius = 1.35
	pedestal.height = 0.24
	for index: int in meshes.size():
		var x := float(index % 3 - 1) * 3.6
		var z := -2.0 if index < 3 else 2.0
		var base := MeshInstance3D.new()
		base.mesh = pedestal
		base.position = Vector3(x, 0.12, z)
		_apply_material(base, Color("263445"))
		world.add_child(base)
		var shape := MeshInstance3D.new()
		shape.name = names[index]
		shape.mesh = meshes[index]
		shape.position = Vector3(x, 1.65, z)
		_apply_material(shape, SHAPE_COLORS[index])
		if index == 2:
			shape.rotation_degrees.x = 68.0
		world.add_child(shape)
		figures.append(shape)


func _apply_material(mesh: MeshInstance3D, color: Color) -> void:
	mesh.material_override = PRIMITIVE_MATERIAL
	mesh.set_instance_shader_parameter("albedo_color", color)
	mesh.set_instance_shader_parameter("roughness", 0.55)
	mesh.set_instance_shader_parameter("metallic", 0.08)
	mesh.set_instance_shader_parameter("specular", 0.5)
	mesh.set_instance_shader_parameter("emission_color", Color(0, 0, 0, 1))
	mesh.set_instance_shader_parameter("emission_energy", 0.0)


func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
		for index: int in figures.size():
			figures[index].rotation.y = elapsed * (0.27 + float(index) * 0.035)
			figures[index].position.y = 1.65 + sin(elapsed * 1.2 + float(index)) * 0.13
	var orbit := Input.get_axis("ui_left", "ui_right")
	if orbit != 0.0:
		camera_yaw += orbit * delta * 0.65
		_update_camera()


func _update_camera() -> void:
	camera.position = Vector3(sin(camera_yaw) * 14.8, 8.2, cos(camera_yaw) * 14.8)
	camera.look_at(Vector3(0.0, 0.65, 0.0))


func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(root)

	var header := MarginContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 32.0
	header.offset_top = 24.0
	header.offset_right = -32.0
	root.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 24)
	header.add_child(header_row)
	var title_block := VBoxContainer.new()
	title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_block.add_theme_constant_override("separation", 6)
	header_row.add_child(title_block)
	title_block.add_child(_label("A–T–D–G   /   RENDER STUDY 001", 12, ACCENT))
	title_block.add_child(_label("Геометрия из символов", 30, TEXT))
	title_block.add_child(_label("Шесть цветных форм. Свет, объём и движение в ASCII.", 14, MUTED))
	var mode_block := VBoxContainer.new()
	mode_block.add_theme_constant_override("separation", 10)
	header_row.add_child(mode_block)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	mode_block.add_child(mode_row)
	var group := ButtonGroup.new()
	var mode_names: Array[String] = ["Обычный 3D", "ASCII", "Сравнение"]
	for index: int in mode_names.size():
		var button := _button(mode_names[index])
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_set_view.bind(index))
		mode_row.add_child(button)
		view_buttons.append(button)
	status_label = _label("", 12, MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_block.add_child(status_label)

	split_labels = HBoxContainer.new()
	split_labels.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	split_labels.offset_top = 145.0
	split_labels.offset_left = 32.0
	split_labels.offset_right = -32.0
	root.add_child(split_labels)
	var original_label := _label("01 / ОБЫЧНЫЙ 3D", 12, MUTED)
	original_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_labels.add_child(original_label)
	var ascii_label := _label("02 / ASCII", 12, ACCENT)
	ascii_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ascii_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	split_labels.add_child(ascii_label)

	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 32.0
	footer.offset_right = -32.0
	footer.offset_top = -132.0
	footer.offset_bottom = -24.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("101c29")
	panel_style.border_color = Color("283c4a")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 22.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 16.0
	panel_style.content_margin_bottom = 14.0
	footer.add_theme_stylebox_override("panel", panel_style)
	root.add_child(footer)
	var footer_stack := VBoxContainer.new()
	footer_stack.add_theme_constant_override("separation", 12)
	footer.add_child(footer_stack)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 18)
	footer_stack.add_child(controls)
	color_toggle = CheckButton.new()
	color_toggle.focus_mode = Control.FOCUS_NONE
	color_toggle.text = "Цвет"
	color_toggle.button_pressed = true
	color_toggle.add_theme_color_override("font_color", TEXT)
	color_toggle.toggled.connect(func(value: bool) -> void: ascii.colored = value)
	controls.add_child(color_toggle)
	character_selector = OptionButton.new()
	character_selector.focus_mode = Control.FOCUS_NONE
	character_selector.add_item("9 символов", AsciiRenderer.CharacterSet.ORIGINAL_9)
	character_selector.add_item("16 символов", AsciiRenderer.CharacterSet.EXTENDED_16)
	character_selector.select(ascii.character_set)
	character_selector.tooltip_text = "Набор символов (F4)"
	character_selector.item_selected.connect(_change_character_set)
	controls.add_child(character_selector)
	controls.add_child(_label("Размер символов", 14, MUTED))
	size_slider = HSlider.new()
	size_slider.focus_mode = Control.FOCUS_NONE
	size_slider.custom_minimum_size = Vector2(140.0, 0.0)
	size_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_slider.min_value = 4.0
	size_slider.max_value = 20.0
	size_slider.step = 1.0
	size_slider.value = ascii.cell_size
	size_slider.value_changed.connect(_change_size)
	controls.add_child(size_slider)
	size_label = _label("8 px", 14, ACCENT)
	size_label.custom_minimum_size.x = 48.0
	controls.add_child(size_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)
	pause_button = _button("Пауза")
	pause_button.toggle_mode = true
	pause_button.toggled.connect(func(value: bool) -> void:
		paused = value
		pause_button.text = "Продолжить" if value else "Пауза")
	controls.add_child(pause_button)
	footer_stack.add_child(_label("F1  3D / ASCII     F2  цвет     F3  сравнение     F4  9 / 16     Пробел  пауза     ← →  камера     − +  размер", 12, MUTED))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	button.custom_minimum_size.y = 38.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_pressed_color", Color("071c18"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("182734")
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 16.0
	normal.content_margin_right = 16.0
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("294354")
	button.add_theme_stylebox_override("hover", hover)
	var selected := normal.duplicate() as StyleBoxFlat
	selected.bg_color = ACCENT
	button.add_theme_stylebox_override("pressed", selected)
	return button


func _set_view(mode: int) -> void:
	view_mode = mode
	ascii.enabled = mode != 0
	ascii.split_screen = mode == 2
	for index: int in view_buttons.size():
		view_buttons[index].set_pressed_no_signal(index == mode)
	status_label.text = ["Исходное изображение камеры", "%d символов · обработка на GPU" % ascii.get_character_count(), "Слева — 3D / справа — ASCII"][mode]
	split_labels.visible = mode == 2
	color_toggle.disabled = mode == 0
	character_selector.disabled = mode == 0
	size_slider.editable = mode != 0


func _change_size(value: float) -> void:
	ascii.cell_size = int(value)
	size_label.text = "%d px" % ascii.cell_size


func _change_character_set(index: int) -> void:
	ascii.character_set = character_selector.get_item_id(index) as AsciiRenderer.CharacterSet
	_set_view(view_mode)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is not InputEventKey:
		return
	match event.physical_keycode:
		KEY_F1:
			_set_view(0 if view_mode != 0 else 1)
		KEY_F2:
			color_toggle.button_pressed = not color_toggle.button_pressed
		KEY_F3:
			_set_view(1 if view_mode == 2 else 2)
		KEY_F4:
			character_selector.select(1 - character_selector.selected)
			_change_character_set(character_selector.selected)
		KEY_SPACE:
			pause_button.button_pressed = not pause_button.button_pressed
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			size_slider.value += 1.0
		KEY_MINUS, KEY_KP_SUBTRACT:
			size_slider.value -= 1.0
		KEY_ESCAPE:
			get_tree().quit()


func _capture_previews(directory: String) -> void:
	# Optional real-GPU render verification, invoked only by a command-line flag.
	var result := DirAccess.make_dir_recursive_absolute(directory)
	if result != OK:
		push_error("Cannot create preview directory: %s" % error_string(result))
		get_tree().quit(1)
		return
	pause_button.button_pressed = true
	var modes: Array[int] = [0, 1, 2, 1]
	var filenames: Array[String] = ["01-normal.png", "02-ascii-color.png", "03-comparison.png", "04-ascii-mono.png"]
	for index: int in modes.size():
		_set_view(modes[index])
		color_toggle.button_pressed = index != 3
		# Let both the screen copy and rendering server settle after changing mode.
		for frame: int in 4:
			await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		result = image.save_png(directory.path_join(filenames[index]))
		if result != OK:
			push_error("Cannot save preview: %s" % error_string(result))
			get_tree().quit(1)
			return
		print("Saved preview: ", directory.path_join(filenames[index]))
	# Compare glyph sets at the exact same camera position and animation time.
	color_toggle.button_pressed = true
	_set_view(1)
	for character_set: int in [0, 1]:
		character_selector.select(character_set)
		_change_character_set(character_set)
		for frame: int in 4:
			await RenderingServer.frame_post_draw
		var filename := "05-ascii-9.png" if character_set == 0 else "06-ascii-16.png"
		result = get_viewport().get_texture().get_image().save_png(directory.path_join(filename))
		if result != OK:
			push_error("Cannot save character-set preview: %s" % error_string(result))
			get_tree().quit(1)
			return
		print("Saved preview: ", directory.path_join(filename))
	color_toggle.button_pressed = true
	pause_button.button_pressed = false
	_set_view(1)
	if "--capture-and-quit" in OS.get_cmdline_user_args():
		get_tree().quit()
