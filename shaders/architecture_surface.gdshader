// Общая проекция отделки в метрах. Ближайший тексель сохраняет пиксельные края.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Один общий материал на профиль отделки. Поверхность задаётся экземпляром,
// поэтому горизонтальный торец стены не превращается в пол или потолок.
uniform sampler2D wall_color_texture : source_color, repeat_enable, filter_nearest_mipmap;
uniform sampler2D wall_roughness_texture : hint_default_white, repeat_enable, filter_nearest_mipmap;
uniform sampler2D wall_normal_texture : hint_normal, repeat_enable, filter_nearest_mipmap;
uniform sampler2D floor_color_texture : source_color, repeat_enable, filter_nearest_mipmap;
uniform sampler2D floor_roughness_texture : hint_default_white, repeat_enable, filter_nearest_mipmap;
uniform sampler2D floor_normal_texture : hint_normal, repeat_enable, filter_nearest_mipmap;
uniform sampler2D ceiling_color_texture : source_color, repeat_enable, filter_nearest_mipmap;
uniform sampler2D ceiling_roughness_texture : hint_default_white, repeat_enable, filter_nearest_mipmap;
uniform sampler2D ceiling_normal_texture : hint_normal, repeat_enable, filter_nearest_mipmap;
instance uniform int surface_kind : hint_range(0, 2) = 0; // 0 — стена, 1 — пол, 2 — потолок.
instance uniform vec3 color_multiplier = vec3(1.0);
uniform vec3 surface_origin = vec3(0.0);
uniform float wall_period : hint_range(1.0, 64.0) = 16.0;
uniform float wall_height : hint_range(1.0, 8.0) = 2.6;
uniform float horizontal_period : hint_range(1.0, 64.0) = 8.0;
uniform float wall_normal_strength : hint_range(0.0, 2.0) = 0.35;
uniform float horizontal_normal_strength : hint_range(0.0, 2.0) = 0.65;

varying vec3 surface_position_world;
varying vec3 surface_normal_world;

void vertex() {
	surface_position_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = surface_position_world - surface_origin;
	vec3 n = normalize(surface_normal_world);
	vec2 projected_uv;
	vec3 tangent_u;
	vec3 tangent_v;
	if (surface_kind == 0 && abs(n.y) < 0.5) {
		// Blender X+Y преобразуется в Godot X-Z; PNG отсчитывается сверху вниз.
		projected_uv = vec2((p.x - p.z) / wall_period, 1.0 - p.y / wall_height);
		tangent_u = abs(n.x) > abs(n.z) ? vec3(0.0, 0.0, -1.0) : vec3(1.0, 0.0, 0.0);
		tangent_v = vec3(0.0, 1.0, 0.0);
	} else {
		// Горизонтальные грани, пол и потолок используют общую плоскость XZ.
		projected_uv = vec2(p.x / horizontal_period, 1.0 + p.z / horizontal_period);
		tangent_u = vec3(1.0, 0.0, 0.0);
		tangent_v = vec3(0.0, 0.0, -1.0);
	}
	vec3 surface_color;
	vec2 surface_detail;
	float normal_strength = horizontal_normal_strength;
	if (surface_kind == 1) {
		surface_color = texture(floor_color_texture, projected_uv).rgb;
		ROUGHNESS = texture(floor_roughness_texture, projected_uv).r;
		surface_detail = texture(floor_normal_texture, projected_uv).rg;
	} else if (surface_kind == 2) {
		surface_color = texture(ceiling_color_texture, projected_uv).rgb;
		ROUGHNESS = texture(ceiling_roughness_texture, projected_uv).r;
		surface_detail = texture(ceiling_normal_texture, projected_uv).rg;
	} else {
		surface_color = texture(wall_color_texture, projected_uv).rgb;
		ROUGHNESS = texture(wall_roughness_texture, projected_uv).r;
		surface_detail = texture(wall_normal_texture, projected_uv).rg;
		normal_strength = wall_normal_strength;
	}
	ALBEDO = surface_color * color_multiplier;
	METALLIC = 0.0;
	SPECULAR = 0.25;
	vec2 detail = (surface_detail * 2.0 - 1.0) * normal_strength;
	float normal_z = sqrt(max(1.0 - dot(detail, detail), 0.0));
	vec3 normal_world = normalize(n * normal_z + tangent_u * detail.x + tangent_v * detail.y);
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz);
}
