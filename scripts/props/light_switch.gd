@tool
extends "res://scripts/props/light_switch_indicator.gd"
## Прямая связь выключателя с одной или несколькими лампами, без симуляции электросети.

@export_group("Выключатель")
## Перетащите сюда корни экземпляров ламп из дерева текущей сцены.
@export var lamps: Array[SwitchableLamp] = []:
	set(value):
		lamps = value
		if is_node_ready():
			_apply_state()
@export var is_on: bool = false:
	set(value):
		is_on = value
		if is_node_ready():
			_apply_state()


func _ready() -> void:
	super._ready()
	_apply_state()


func interact() -> void:
	is_on = not is_on


func _apply_state() -> void:
	indicator_state = 2 if is_on else 1
	# Лицевая сторона смотрит по +Z: внизу утоплено при +4°, вверху при -4°.
	$Model/light_switch_single_01/Rocker.rotation_degrees.x = -4.0 if is_on else 4.0
	for lamp: SwitchableLamp in lamps:
		if is_instance_valid(lamp):
			lamp.is_on = is_on
