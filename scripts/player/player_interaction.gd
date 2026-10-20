extends RayCast3D
## Ближайшая коллизия в центре взгляда перекрывает взаимодействие с объектами за ней.
## Интерактивный корень предоставляет interact() и при необходимости can_interact().

@export_group("Взаимодействие")
@export_range(0.2, 5.0, 0.1, "suffix:m") var reach: float = 1.8

@onready var _camera: Camera3D = get_parent() as Camera3D
@onready var _player: CharacterBody3D = _camera.get_parent() as CharacterBody3D
@onready var _cursor: Label = $"../../InteractionHUD/Cursor"

var _target: Node
var _interaction_requested: bool = false


func _ready() -> void:
	add_exception(_player)
	Locale.locale_changed.connect(_refresh_cursor)
	_player.mouse_capture_changed.connect(_on_mouse_capture_changed)
	_refresh_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and _controls_active():
		# Выполняем запрос после обновления луча в физическом кадре.
		_interaction_requested = true
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not _controls_active():
		_target = null
		_interaction_requested = false
		_cursor.hide()
		return
	target_position = Vector3(0.0, 0.0, -reach)
	force_raycast_update()
	_target = _find_target()
	if _interaction_requested:
		_interaction_requested = false
		if is_instance_valid(_target):
			_target.call("interact")
		# Взаимодействие может удалить объект или сделать его недоступным.
		force_raycast_update()
		_target = _find_target()
	_refresh_cursor()
	_cursor.show()


func _find_target() -> Node:
	if not is_colliding():
		return null
	var node := get_collider() as Node
	while node != null and node != get_tree().root:
		if node.is_queued_for_deletion():
			return null
		if node.has_method("interact"):
			if not node.has_method("can_interact") or bool(node.call("can_interact")):
				return node
			return null
		node = node.get_parent()
	return null


func _controls_active() -> bool:
	return _camera.is_current() and _player.is_mouse_captured()


func _refresh_cursor(_locale: String = "") -> void:
	_cursor.text = Locale.text("ui.interaction.prompt" if is_instance_valid(_target)
		else "ui.interaction.crosshair")


func _on_mouse_capture_changed(captured: bool) -> void:
	if not captured:
		_target = null
		_interaction_requested = false
		_cursor.hide()
