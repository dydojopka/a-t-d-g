// Общая непрозрачная отделка тестовых примитивов; значения задаются на узле.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

instance uniform vec4 albedo_color : source_color = vec4(1.0);
instance uniform float roughness : hint_range(0.0, 1.0) = 1.0;
instance uniform float metallic : hint_range(0.0, 1.0) = 0.0;
instance uniform float specular : hint_range(0.0, 1.0) = 0.5;
instance uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
instance uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	EMISSION = emission_color.rgb * emission_energy;
}
