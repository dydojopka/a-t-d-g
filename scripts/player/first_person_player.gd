extends CharacterBody3D
## Контроллер от первого лица. Начало координат находится на уровне стоп.

signal mouse_capture_changed(captured: bool)

const CrawlSpace = preload("res://scripts/player/crawl_space.gd")

@export_group("Передвижение")
@export_range(0.1, 20.0, 0.1) var walk_speed: float = 2.4
@export_range(0.1, 20.0, 0.1) var sprint_speed: float = 3.8
@export_range(0.1, 20.0, 0.1) var crouch_speed: float = 1.0
@export_range(0.1, 5.0, 0.05) var prone_speed: float = 0.45
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
@export_group("Ползание")
## Ползание разрешают только специально размещённые CrawlSpace.
@export var auto_prone_enabled: bool = true
## Минимальная высота тела; максимальную задаёт верх области ползания.
@export_range(0.15, 0.7, 0.01) var prone_height: float = 0.25
@export_range(0.1, 0.6, 0.01) var prone_eye_height: float = 0.18
@export_range(0.05, 0.5, 0.01) var prone_probe_distance: float = 0.2
@export_range(0.0, 0.1, 0.005) var prone_surface_clearance: float = 0.02
@export_flags_3d_physics var crawl_space_mask: int = 128

@onready var camera: Camera3D = $Camera3D
@onready var body_collision: CollisionShape3D = $CollisionShape3D

var _capsule: CapsuleShape3D
var _low_body: CylinderShape3D
var _clearance_capsule: CapsuleShape3D
var _clearance_cylinder: CylinderShape3D
var _crawl_probe: CylinderShape3D
var _body_height: float
var _mouse_captured: bool = false
var _is_crouching: bool = false
var _is_prone: bool = false
var _is_sprinting: bool = false
var _pitch: float = 0.0


func _ready() -> void:
	# Копия формы позволяет независимо менять стойку нескольких экземпляров.
	_capsule = body_collision.shape.duplicate() as CapsuleShape3D
	_capsule.radius = body_radius
	_capsule.height = standing_height
	body_collision.shape = _capsule
	body_collision.position.y = standing_height * 0.5
	_low_body = CylinderShape3D.new()
	_low_body.radius = body_radius
	_clearance_capsule = _capsule.duplicate() as CapsuleShape3D
	_clearance_cylinder = _low_body.duplicate() as CylinderShape3D
	_body_height = standing_height
	_crawl_probe = CylinderShape3D.new()
	_crawl_probe.radius = body_radius
	_crawl_probe.height = 0.1
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
		var input_direction := Input.get_vector("move_left", "move_right",
			"move_forward", "move_backward")
		var direction := global_basis * Vector3(input_direction.x, 0.0, input_direction.y)
		_update_stance(delta, direction)
		_is_sprinting = not _is_crouching and Input.is_action_pressed("sprint") and not input_direction.is_zero_approx()
		var speed := walk_speed
		if _is_prone:
			speed = prone_speed
		elif _is_crouching:
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


func _update_stance(delta: float, direction: Vector3 = Vector3.ZERO) -> void:
	var crouch_requested := Input.is_action_pressed("crouch")
	var target_height := standing_height
	var target_eye := standing_eye_height
	var crawl_height := -1.0
	if (crouch_requested and auto_prone_enabled and is_on_floor()) or _is_prone:
		crawl_height = _get_crawl_space_height(direction.normalized() * prone_probe_distance)
	if crawl_height >= prone_height:
		# Зона задаёт позу независимо от сложности меша над игроком.
		target_height = crawl_height
		target_eye = _prone_eye_for_height(target_height)
	elif crouch_requested:
		target_height = crouching_height
		target_eye = crouching_eye_height
	elif _body_height < standing_height and not _has_standing_space():
		# Под мебелью нельзя встать даже после отпускания Ctrl.
		if _is_prone and _has_body_space(crouching_height):
			target_height = crouching_height
			target_eye = crouching_eye_height
		else:
			target_height = _body_height
			target_eye = camera.position.y
	var next_height := move_toward(_body_height, target_height, crouch_transition_speed * delta)
	if is_equal_approx(next_height, _body_height) or _has_body_space(next_height):
		_set_body_height(next_height)
	# Камера не может оказаться выше коллизии при выходе из-под препятствия.
	target_eye = minf(target_eye, _body_height - 0.05)
	camera.position.y = move_toward(camera.position.y, target_eye, crouch_transition_speed * delta)
	_is_prone = target_height < crouching_height - 0.01 or _body_height < crouching_height - 0.01
	_is_crouching = crouch_requested or _body_height < standing_height - 0.01


func _get_crawl_space_height(motion: Vector3 = Vector3.ZERO) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _crawl_probe
	query.collision_mask = crawl_space_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var limit := INF
	# Небольшое упреждение даёт время опуститься перед краем мебели.
	# Текущий объём удерживает позу до полного выхода из низкой зоны.
	for offset in [Vector3.ZERO, motion]:
		query.transform = Transform3D(global_basis.orthonormalized(),
			global_position + offset + Vector3.UP * 0.06)
		for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
			var area := hit.collider as CrawlSpace
			if area == null:
				continue
			var height := area.get_height_above(global_position)
			if height >= prone_height:
				limit = minf(limit, height)
	if is_inf(limit):
		return -1.0
	# Даже слишком высокая область не поднимает ползущего выше приседа.
	return maxf(prone_height, minf(limit, crouching_height) - prone_surface_clearance)


func _prone_eye_for_height(height: float) -> float:
	var fraction := inverse_lerp(prone_height, crouching_height, height)
	return lerpf(prone_eye_height, crouching_eye_height, clampf(fraction, 0.0, 1.0))


func _set_body_height(height: float) -> void:
	_body_height = height
	# Капсула не бывает ниже своего диаметра. Низкий цилиндр сохраняет
	# ширину плеч при ползании и не позволяет протискиваться в узкие щели.
	if height < body_radius * 2.0:
		_low_body.height = height
		body_collision.shape = _low_body
	else:
		_capsule.height = height
		body_collision.shape = _capsule
	body_collision.position.y = height * 0.5


func _has_standing_space() -> bool:
	return _has_body_space(standing_height)


func _has_body_space(height: float, motion: Vector3 = Vector3.ZERO) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	if height < body_radius * 2.0:
		_clearance_cylinder.height = height
		query.shape = _clearance_cylinder
	else:
		_clearance_capsule.height = height
		query.shape = _clearance_capsule
	# Малый зазор у стоп исключает пол из проверки свободного пространства.
	query.transform = Transform3D(global_basis.orthonormalized(),
		global_position + global_basis.y * (height * 0.5 + 0.01))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.001
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	if motion.is_zero_approx():
		return true
	query.motion = motion
	return space.cast_motion(query)[0] >= 1.0


func is_mouse_captured() -> bool:
	return _mouse_captured and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and get_window().has_focus()


func is_crouching() -> bool:
	return _is_crouching


func is_prone() -> bool:
	return _is_prone


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
