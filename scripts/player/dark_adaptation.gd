extends Node3D
## Ближнее зрение только при практически полном отсутствии освещения.
## Эффект камеры до ASCII-прохода.
## Освещённость оценивается у глаз по окружению и прямому свету с учётом стен.

@export var adaptation_enabled: bool = true
@export_range(0.0, 10.0, 0.1) var adaptation_delay: float = 1.0
@export_range(0.1, 20.0, 0.1) var adaptation_time: float = 3.0
@export_range(0.1, 5.0, 0.1) var light_recovery_time: float = 0.5
@export_range(0.5, 8.0, 0.1) var vision_radius: float = 3.0
## Подъём яркости видимых тёмных поверхностей в линейном пространстве.
@export_range(0.0, 0.1, 0.001) var vision_lift: float = 0.006
@export_range(0.0, 8.0, 0.1) var shadow_gain: float = 2.5
## Условные единицы, не люксы. Допуск около нуля: полумрак эффект не включает.
@export_range(0.0, 0.01, 0.00001) var darkness_threshold: float = 0.0001
## Порог выхода чуть выше порога входа, чтобы избежать дрожания на границе.
@export_range(0.0, 0.01, 0.00001) var light_threshold: float = 0.0002
## Слабый художественный фон нужен рендеру даже в неосвещённой комнате.
## Вычитается только из Environment; свет ламп и экранов учитывается целиком.
@export_range(0.0, 0.1, 0.001) var ambient_darkness_floor: float = 0.035
@export_range(0.05, 1.0, 0.05) var sample_interval: float = 0.15

@onready var _camera: Camera3D = get_parent() as Camera3D
@onready var _player: CharacterBody3D = _camera.get_parent() as CharacterBody3D
@onready var _surface: MeshInstance3D = $VisionSurface

var _material: ShaderMaterial

var _lights: Array[Light3D] = []
var _sample_countdown: float = 0.0
var _dark_time: float = 0.0
var _target: float = 0.0
var _adaptation: float = 0.0


func _ready() -> void:
	_material = _surface.material_override.duplicate() as ShaderMaterial
	_surface.material_override = _material
	visible = false
	for node in get_tree().root.find_children("*", "Light3D", true, false):
		_track_light(node)
	get_tree().node_added.connect(_track_light)
	get_tree().node_removed.connect(_untrack_light)


func _physics_process(delta: float) -> void:
	if not adaptation_enabled or not _camera.is_current():
		_dark_time = 0.0
		_adaptation = 0.0
		visible = false
		_material.set_shader_parameter("adaptation", 0.0)
		return
	_sample_countdown -= delta
	if _sample_countdown <= 0.0:
		_sample_countdown = sample_interval
		var illumination := _sample_illumination()
		if illumination <= darkness_threshold:
			_target = 1.0
		elif illumination >= maxf(light_threshold, darkness_threshold):
			_target = 0.0
	if _target > _adaptation:
		_dark_time += delta
		if _dark_time >= adaptation_delay:
			_adaptation = move_toward(_adaptation, _target, delta / adaptation_time)
	else:
		if _target <= 0.0:
			_dark_time = 0.0
		_adaptation = move_toward(_adaptation, _target, delta / light_recovery_time)
	_material.set_shader_parameter("vision_radius", vision_radius)
	_material.set_shader_parameter("vision_lift", vision_lift)
	_material.set_shader_parameter("shadow_gain", shadow_gain)
	_material.set_shader_parameter("adaptation", _adaptation)
	visible = _adaptation > 0.0001 and (vision_lift > 0.0 or shadow_gain > 0.0)


func get_adaptation() -> float:
	return _adaptation


func _track_light(node: Node) -> void:
	if node is Light3D and not _lights.has(node):
		_lights.append(node)


func _untrack_light(node: Node) -> void:
	if node is Light3D:
		_lights.erase(node)


func _sample_illumination() -> float:
	var eye_position := _camera.global_position
	var environment := _camera.environment
	if environment == null:
		environment = get_world_3d().environment
	var illumination := 0.0
	if environment != null and environment.ambient_light_source != Environment.AMBIENT_SOURCE_DISABLED:
		illumination = environment.ambient_light_energy * _luminance(environment.ambient_light_color)
		if environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY:
			illumination = environment.ambient_light_energy
		illumination = maxf(illumination - ambient_darkness_floor, 0.0)
	for light in _lights:
		if light.get_world_3d() != get_world_3d() or not light.is_visible_in_tree() or light.light_negative:
			continue
		var strength := light.light_energy * _luminance(light.light_color)
		if strength <= 0.0:
			continue
		var to_eye := eye_position - light.global_position
		var distance := to_eye.length()
		var ray_end := light.global_position
		if light is DirectionalLight3D:
			ray_end = eye_position + light.global_basis.z * 100.0
		else:
			var range_m: float
			var attenuation: float
			if light is OmniLight3D:
				range_m = light.omni_range
				attenuation = light.omni_attenuation
			elif light is SpotLight3D:
				range_m = light.spot_range
				attenuation = light.spot_attenuation
				var cosine := (-light.global_basis.z).dot(to_eye.normalized())
				var edge := cos(deg_to_rad(light.spot_angle))
				strength *= pow(clampf((cosine - edge) / maxf(1.0 - edge, 0.001), 0.0, 1.0),
					light.spot_angle_attenuation)
			elif light is AreaLight3D:
				range_m = light.area_range
				attenuation = light.area_attenuation
				# Ближайшая точка прямоугольного экрана; за экраном света нет.
				var local_eye := light.to_local(eye_position)
				if local_eye.z >= 0.0:
					continue
				ray_end = light.to_global(Vector3(clampf(local_eye.x, -light.area_size.x * 0.5, light.area_size.x * 0.5),
					clampf(local_eye.y, -light.area_size.y * 0.5, light.area_size.y * 0.5), 0.0))
				distance = eye_position.distance_to(ray_end)
			else:
				continue
			if range_m <= 0.0 or distance >= range_m:
				continue
			# Та же форма дистанционного затухания, что у прямого света Godot.
			var edge_fade := pow(clampf(1.0 - pow(distance / range_m, 4.0), 0.0, 1.0), 2.0)
			strength *= edge_fade * pow(maxf(distance, 0.1), -attenuation)
		if strength <= 0.0:
			continue
		var excluded: Array[RID] = [_player.get_rid()]
		# Свет экрана/шкалы может находиться внутри коллизии собственного
		# прибора: она не должна полностью гасить измеряемое освещение.
		var light_parent := light.get_parent()
		while light_parent != null:
			if light_parent is CollisionObject3D:
				excluded.append(light_parent.get_rid())
				break
			light_parent = light_parent.get_parent()
		var ray := PhysicsRayQueryParameters3D.create(eye_position,
			ray_end, _player.collision_mask, excluded)
		# Проверяем стену и мебель даже у источников с отключённой картой теней.
		if _light_reaches_eye(ray):
			illumination += strength
		if illumination >= maxf(light_threshold, darkness_threshold):
			break
	return illumination


func _light_reaches_eye(ray: PhysicsRayQueryParameters3D) -> bool:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(ray)
	while not hit.is_empty():
		var collider := hit.collider as CollisionObject3D
		var node: Node = collider
		while node != null and not node is MeshInstance3D:
			node = node.get_parent()
		# Колба не отбрасывает тень: её физическая оболочка также не должна
		# перекрывать свет внутри неё. Стены и затеняющая мебель остаются преградами.
		var occluder_mesh := node as MeshInstance3D
		if occluder_mesh == null or occluder_mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
		var excluded := ray.exclude
		excluded.append(collider.get_rid())
		ray.exclude = excluded
		hit = space.intersect_ray(ray)
	return true


func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
