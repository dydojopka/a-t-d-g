@tool
extends StaticBody3D
## Связывает подсветку шкалы с её локальным светом, без логики питания радио.

@export_group("Свечение")
@export var illumination_enabled: bool = false:
	set(value):
		illumination_enabled = value
		if is_node_ready():
			_apply_illumination()


func _ready() -> void:
	_apply_illumination()


func _apply_illumination() -> void:
	$ScaleLight.visible = illumination_enabled
	$Model/radio_transceiver_01/CabinetSurface.set_instance_shader_parameter(
		"power_led_level", 0.65 if illumination_enabled else 0.0)
