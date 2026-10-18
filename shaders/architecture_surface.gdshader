// Общая проекция отделки в метрах; соответствует Blender-набору architecture_v02.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D color_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool wall_projection = true;
uniform vec3 surface_origin = vec3(0.0);
uniform float wall_period : hint_range(1.0, 64.0) = 16.0;
uniform float wall_height : hint_range(1.0, 8.0) = 2.6;
uniform float horizontal_period : hint_range(1.0, 64.0) = 8.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.65;
uniform vec3 color_multiplier = vec3(1.0);

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
	if (wall_projection && abs(n.y) < 0.5) {
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
	ALBEDO = texture(color_texture, projected_uv).rgb * color_multiplier;
	ROUGHNESS = texture(roughness_texture, projected_uv).r;
	METALLIC = 0.0;
	SPECULAR = 0.25;
	vec2 detail = (texture(normal_texture, projected_uv).rg * 2.0 - 1.0) * normal_strength;
	float normal_z = sqrt(max(1.0 - dot(detail, detail), 0.0));
	vec3 normal_world = normalize(n * normal_z + tangent_u * detail.x + tangent_v * detail.y);
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz);
}
