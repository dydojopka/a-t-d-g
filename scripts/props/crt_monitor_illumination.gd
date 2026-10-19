@tool
extends StaticBody3D
## Управляет только видимым свечением. Питание и терминал пока не реализованы.

const SCREEN_OFF: Material = preload("res://assets/props/crt_monitor_01/materials/screen_off.tres")
const SCREEN_ON: Material = preload("res://assets/props/crt_monitor_01/materials/screen_on.tres")

@export_group("Свечение")
@export var illumination_enabled: bool = false:
	set(value):
		illumination_enabled = value
		if is_node_ready():
			_apply_illumination()


func _ready() -> void:
	_apply_illumination()


func _apply_illumination() -> void:
	$ScreenLight.visible = illumination_enabled
	$Model/crt_monitor_01/ScreenSurface.material_override = SCREEN_ON if illumination_enabled else SCREEN_OFF
