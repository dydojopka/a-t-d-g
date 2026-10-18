extends Node3D
## Поведение тестовой комнаты; окружение и интерфейс сохранены в сцене.

@onready var player: CharacterBody3D = $Player
@onready var help_block: VBoxContainer = $HUD/Overlay/Help
@onready var capture_hint: Label = $HUD/Overlay/CaptureHint
@onready var movement_state: Label = $HUD/Overlay/MovementState
@onready var localized_labels: Array[Node] = $HUD.find_children("*", "Label")


func _ready() -> void:
	Locale.locale_changed.connect(_refresh_text)
	player.mouse_capture_changed.connect(_refresh_capture_hint)
	_refresh_text()


func _refresh_text(_code: String = "") -> void:
	for label: Label in localized_labels:
		if label.has_meta("locale_key"):
			label.text = Locale.text(str(label.get_meta("locale_key")))
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
