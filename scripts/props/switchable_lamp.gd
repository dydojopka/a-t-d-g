@tool
class_name SwitchableLamp
extends Node3D
## Материал колбы и реальный источник света всегда переключаются вместе.

@export_group("Освещение")
@export var is_on: bool = false:
	set(value):
		is_on = value
		if is_node_ready():
			_apply_state()
@export var off_material: Material = preload("res://assets/props/hanging_bulb_01/materials/lamp_off.tres"):
	set(value):
		off_material = value
		if is_node_ready():
			_apply_state()
@export var on_material: Material = preload("res://assets/props/hanging_bulb_01/materials/lamp_on.tres"):
	set(value):
		on_material = value
		if is_node_ready():
			_apply_state()


func _ready() -> void:
	_apply_state()


func _apply_state() -> void:
	$Model/hanging_bulb_01/BodySurface.material_override = on_material if is_on else off_material
	$Light.visible = is_on
