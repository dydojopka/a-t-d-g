// Эффект зрения: изменяется только изображение текущей камеры, без лампы в мире.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;
uniform float adaptation : hint_range(0.0, 1.0) = 0.0;
uniform float vision_radius : hint_range(0.5, 8.0) = 3.0;
uniform float vision_lift : hint_range(0.0, 0.1) = 0.006;
uniform float shadow_gain : hint_range(0.0, 8.0) = 2.5;

void vertex() {
    // Обратная глубина Godot 4.3+: ближняя плоскость находится на Z = 1.
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    vec3 scene = textureLod(scene_texture, SCREEN_UV, 0.0).rgb;
    float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
    vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
    vec3 surface_position = view.xyz / view.w;
    float distance_to_eye = length(surface_position);
    // Широкая область видимости с плавным спадом, без пятна точечного света.
    float proximity = 1.0 - smoothstep(vision_radius * 0.35, vision_radius, distance_to_eye);
    float luminance = dot(scene, vec3(0.2126, 0.7152, 0.0722));
    float dark_surface = 1.0 - smoothstep(0.01, 0.09, luminance);
    vec3 normal_view = textureLod(normal_texture, SCREEN_UV, 0.0).rgb * 2.0 - 1.0;
    vec3 normal_world = mat3(INV_VIEW_MATRIX) * normal_view;
    // Сдержанное различие плоскостей без направления источника или бликов.
    float relief = 0.65 + 0.35 * normal_world.y;
    float strength = adaptation * proximity * dark_surface * step(0.000001, depth);
    float lift = strength * vision_lift * relief;
    // Фон не имеет поверхности и не должен превращаться в светящуюся дымку.
    ALBEDO = scene * (1.0 + shadow_gain * strength) + vec3(0.88, 0.94, 1.0) * lift;
}
