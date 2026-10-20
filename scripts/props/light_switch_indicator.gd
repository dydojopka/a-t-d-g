@tool
extends Node3D
## Визуальное состояние линзы; игровое переключение задаёт наследник light_switch.gd.

@export_group("Индикатор")
@export_enum("Нет электричества", "Выключено", "Включено") var indicator_state: int = 0:
	set(value):
		indicator_state = clampi(value, 0, 2)
		if is_node_ready():
			_apply_indicator()


func _ready() -> void:
	_apply_indicator()


func _apply_indicator() -> void:
	$Model/light_switch_single_01/Rocker.set_instance_shader_parameter(
		"indicator_state", float(indicator_state))
