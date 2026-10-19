// Один непрозрачный материал на предмет; параметры деталей хранятся в COLOR.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D color_texture : source_color, filter_nearest_mipmap;
uniform sampler2D roughness_texture : hint_default_white, filter_nearest_mipmap;
// Для печатных светящихся шкал: рисунок остаётся в общем атласе предмета.
uniform bool power_uses_color_texture = false;
// Сменные материалы лампочки: нулевые значения сохраняют прежнее поведение.
uniform bool power_emission_uses_surface_color = true;
uniform float power_material_level : hint_range(0.0, 4.0) = 0.0;
uniform vec4 dark_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 power_color : source_color = vec4(0.025, 0.2, 0.075, 1.0);
uniform vec4 status_color : source_color = vec4(0.06, 0.033, 0.005, 1.0);
uniform vec4 aux_color : source_color = vec4(0.012, 0.045, 0.022, 1.0);
uniform vec4 power_emission : source_color = vec4(0.06, 0.7, 0.22, 1.0);
uniform vec4 status_emission : source_color = vec4(0.7, 0.3, 0.02, 1.0);
uniform vec4 aux_emission : source_color = vec4(0.06, 0.7, 0.22, 1.0);
instance uniform float power_led_level : hint_range(0.0, 4.0) = 0.0;
instance uniform float status_led_level : hint_range(0.0, 4.0) = 0.0;
instance uniform float aux_led_level : hint_range(0.0, 4.0) = 0.0;

void fragment() {
	float power_level = max(power_led_level, power_material_level);
	// R: блик; G: шероховатость/множитель карты; B: вид поверхности; A: металл.
	int kind = int(round(COLOR.b * 4.0));
	SPECULAR = COLOR.r;
	METALLIC = COLOR.a;
	ROUGHNESS = COLOR.g;
	if (kind == 0) {
		ALBEDO = texture(color_texture, UV).rgb;
		ROUGHNESS *= texture(roughness_texture, UV).r;
	} else if (kind == 1) {
		ALBEDO = dark_color.rgb;
	} else if (kind == 2) {
		if (power_uses_color_texture) {
			vec3 printed_color = texture(color_texture, UV).rgb;
			ALBEDO = printed_color;
			ROUGHNESS *= texture(roughness_texture, UV).r;
			vec3 emission_surface = power_emission_uses_surface_color ? printed_color : vec3(1.0);
			EMISSION = emission_surface * power_emission.rgb * power_level;
		} else {
			ALBEDO = power_color.rgb;
			EMISSION = power_emission.rgb * power_level;
		}
	} else if (kind == 3) {
		ALBEDO = status_color.rgb;
		EMISSION = status_emission.rgb * status_led_level;
	} else {
		ALBEDO = aux_color.rgb;
		EMISSION = aux_emission.rgb * aux_led_level;
	}
}
