@tool
extends Area3D
## Разрешённое место для ползания. Начало координат — в центре нижней грани.

@export var enabled: bool = true
## Менять размеры здесь: форма остаётся привязана нижней гранью к полу.
@export var dimensions: Vector3 = Vector3(1.0, 0.7, 1.0):
	set(value):
		dimensions = value.max(Vector3(0.01, 0.01, 0.01))
		if is_node_ready():
			_update_shape()


func _ready() -> void:
	# Правка экземпляра не меняет размеры других зон с общим префабом.
	$CollisionShape3D.shape = $CollisionShape3D.shape.duplicate()
	_update_shape()


func _update_shape() -> void:
	var collision: CollisionShape3D = $CollisionShape3D
	(collision.shape as BoxShape3D).size = dimensions
	collision.position = Vector3(0.0, dimensions.y * 0.5, 0.0)


func get_height_above(feet_position: Vector3) -> float:
	if not enabled:
		return -1.0
	# Высота берётся от стоп до верха области, учитывая её положение и масштаб.
	return to_global(Vector3(0.0, dimensions.y, 0.0)).y - feet_position.y
