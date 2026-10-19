extends CharacterBody3D
## Контроллер от первого лица. Начало координат находится на уровне стоп.

signal mouse_capture_changed(captured: bool)

@export_group("Передвижение")
@export_range(0.1, 20.0, 0.1) var walk_speed: float = 2.4
@export_range(0.1, 20.0, 0.1) var sprint_speed: float = 3.8
@export_range(0.1, 20.0, 0.1) var crouch_speed: float = 1.0
@export_range(1.0, 100.0, 0.1) var ground_acceleration: float = 16.0
@export_range(0.0, 30.0, 0.1) var air_acceleration: float = 6.0
@export_range(0.0, 100.0, 0.1) var gravity: float = 24.0

@export_group("Взгляд")
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.12
@export_range(45.0, 110.0, 1.0) var field_of_view: float = 60.0

@export_group("Стойка")
@export_range(0.1, 1.0, 0.01) var body_radius: float = 0.3
@export_range(1.0, 2.5, 0.01) var standing_height: float = 1.8
@export_range(0.8, 2.0, 0.01) var crouching_height: float = 1.05
@export_range(0.5, 2.3, 0.01) var standing_eye_height: float = 1.62
@export_range(0.4, 1.8, 0.01) var crouching_eye_height: float = 0.9
@export_range(0.1, 10.0, 0.1) var crouch_transition_speed: float = 2.5

@onready var camera: Camera3D = $Camera3D
@onready var body_collision: CollisionShape3D = $CollisionShape3D

var _capsule: CapsuleShape3D
var _standing_capsule: CapsuleShape3D
var _mouse_captured: bool = false
var _is_crouching: bool = false
var _is_sprinting: bool = false
var _pitch: float = 0.0


func _ready() -> void:
	# Копия формы позволяет независимо менять стойку нескольких экземпляров.
	_capsule = body_collision.shape.duplicate() as CapsuleShape3D
	_capsule.radius = body_radius
	_capsule.height = standing_height
	body_collision.shape = _capsule
	body_collision.position.y = standing_height * 0.5
	_standing_capsule = _capsule.duplicate() as CapsuleShape3D
	camera.position.y = standing_eye_height
	camera.fov = field_of_view
	_pitch = camera.rotation.x
	get_window().focus_exited.connect(release_mouse)
	if DisplayServer.get_name() != "headless":
		capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		release_mouse()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			capture_mouse()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and is_mouse_captured():
		# Чувствительность задаётся в градусах на пиксель и не зависит от FPS.
		rotate_y(deg_to_rad(-event.screen_relative.x * mouse_sensitivity))
		_pitch = clampf(_pitch - deg_to_rad(event.screen_relative.y * mouse_sensitivity),
			deg_to_rad(-89.0), deg_to_rad(89.0))
		camera.rotation.x = _pitch
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var controls_active := is_mouse_captured()
	_is_sprinting = false
	if controls_active:
		_update_stance(delta)
		var input_direction := Input.get_vector("move_left", "move_right",
			"move_forward", "move_backward")
		var direction := global_basis * Vector3(input_direction.x, 0.0, input_direction.y)
		_is_sprinting = not _is_crouching and Input.is_action_pressed("sprint") and not input_direction.is_zero_approx()
		var speed := walk_speed
		if _is_crouching:
			speed = crouch_speed
		elif _is_sprinting:
			speed = sprint_speed
		var acceleration := ground_acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	else:
		# Освобождённый курсор сразу прекращает движение по горизонтали.
		velocity.x = 0.0
		velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()


func _update_stance(delta: float) -> void:
	var crouch_requested := Input.is_action_pressed("crouch")
	if not crouch_requested and not is_equal_approx(_capsule.height, standing_height) and not _has_standing_space():
		# Препятствие только останавливает вставание, но не опускает тело и камеру.
		return
	_is_crouching = crouch_requested
	var target_height := crouching_height if _is_crouching else standing_height
	_capsule.height = move_toward(_capsule.height, target_height, crouch_transition_speed * delta)
	body_collision.position.y = _capsule.height * 0.5
	var target_eye := crouching_eye_height if _is_crouching else standing_eye_height
	camera.position.y = move_toward(camera.position.y, target_eye, crouch_transition_speed * delta)


func _has_standing_space() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _standing_capsule
	# Малый зазор у стоп исключает пол из проверки свободного пространства.
	query.transform = Transform3D(global_basis.orthonormalized(),
		global_position + global_basis.y * (standing_height * 0.5 + 0.01))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.001
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func is_mouse_captured() -> bool:
	return _mouse_captured and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and get_window().has_focus()


func is_crouching() -> bool:
	return _is_crouching


func is_sprinting() -> bool:
	return _is_sprinting


func capture_mouse() -> void:
	if DisplayServer.get_name() == "headless" or not get_window().has_focus():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not _mouse_captured:
		_mouse_captured = true
		mouse_capture_changed.emit(true)


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_is_sprinting = false
	if _mouse_captured:
		_mouse_captured = false
		mouse_capture_changed.emit(false)


func _exit_tree() -> void:
	if _mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
