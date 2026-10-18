shader_type spatial;

varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 tile = world_position.xz / 1.5;
    vec2 edge = abs(fract(tile + 0.5) - 0.5);
    vec2 width = max(fwidth(tile), vec2(0.003));
    vec2 seam = 1.0 - smoothstep(vec2(0.012), vec2(0.012) + width, edge);
    float checker = mod(floor(tile.x + 0.5) + floor(tile.y + 0.5), 2.0);
    vec3 base = mix(vec3(0.23, 0.27, 0.29), vec3(0.28, 0.31, 0.32), checker);
    ALBEDO = mix(base, vec3(0.06, 0.09, 0.1), max(seam.x, seam.y));
    ROUGHNESS = 0.9;
}
