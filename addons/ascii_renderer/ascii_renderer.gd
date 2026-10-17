class_name AsciiRenderer
extends CanvasLayer
## Reusable screen effect. Instance after the world and before the HUD.

enum CharacterSet { ORIGINAL_9, EXTENDED_16 }

const ORIGINAL_ATLAS: Texture2D = preload("res://addons/ascii_renderer/textures/fill_ascii.png")
const EXTENDED_ATLAS: Texture2D = preload("res://addons/ascii_renderer/textures/ascii_16.svg")

@export var character_set: CharacterSet = CharacterSet.EXTENDED_16:
	set(value):
		character_set = value
		_apply_character_set()

@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			$Screen.visible = enabled
@export var colored: bool = true:
	set(value):
		colored = value
		_update_parameter("colored", colored)
@export var split_screen: bool = false:
	set(value):
		split_screen = value
		_update_parameter("split_screen", split_screen)
@export_range(4, 24, 1) var cell_size: int = 8:
	set(value):
		cell_size = clampi(value, 4, 24)
		_update_parameter("cell_size", float(cell_size))
@export_range(0.25, 3.0) var brightness: float = 1.0:
	set(value):
		brightness = value
		_update_parameter("brightness", brightness)
@export_range(0.5, 2.0) var contrast: float = 1.2:
	set(value):
		contrast = value
		_update_parameter("contrast", contrast)
@export_range(0.25, 2.0) var gamma: float = 0.9:
	set(value):
		gamma = value
		_update_parameter("gamma", gamma)


func _ready() -> void:
	# Each instance owns its parameters, even when sharing the packed scene.
	$Screen.material = $Screen.material.duplicate()
	$Screen.visible = enabled
	for parameter: String in ["colored", "split_screen", "brightness", "contrast", "gamma"]:
		_update_parameter(parameter, get(parameter))
	_update_parameter("cell_size", float(cell_size))
	_apply_character_set()


func get_character_count() -> int:
	return 9 if character_set == CharacterSet.ORIGINAL_9 else 16


func _apply_character_set() -> void:
	var atlas := ORIGINAL_ATLAS if character_set == CharacterSet.ORIGINAL_9 else EXTENDED_ATLAS
	_update_parameter("ascii_atlas", atlas)
	# The original atlas's final solid square is excluded only in the 9-glyph set.
	_update_parameter("glyph_count", get_character_count())


func _update_parameter(parameter: StringName, value: Variant) -> void:
	if is_node_ready():
		($Screen.material as ShaderMaterial).set_shader_parameter(parameter, value)
