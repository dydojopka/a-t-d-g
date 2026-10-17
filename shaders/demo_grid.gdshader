shader_type spatial;
render_mode unshaded;

varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 grid_distance = abs(fract(world_position.xz + 0.5) - 0.5);
    vec2 width = max(fwidth(world_position.xz), vec2(0.012));
    vec2 line = 1.0 - smoothstep(vec2(0.015), vec2(0.015) + width, grid_distance);
    float grid = max(line.x, line.y);
    float fade = 1.0 - smoothstep(5.0, 11.0, length(world_position.xz));
    ALBEDO = mix(vec3(0.001, 0.002, 0.004), vec3(0.012, 0.025, 0.04), grid * fade);
}
