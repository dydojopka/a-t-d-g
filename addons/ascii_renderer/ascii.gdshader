/*
 * Adapted from AbstractBorderStudio/Ascii_Shader, Daniel Bologna, MIT (2024).
 * Upstream: d076d632f145532393f0ab25ed2eeae682725c86.
 * Original 9-glyph atlas: Garrett Gunnell / AcerolaFX, MIT (2022).
 * Extended 16-glyph atlas: original project bitmap artwork.
 * See licenses/ and README.md in this directory.
 * Changes: canvas post-process, four samples per cell, independent glyph scale,
 * color/monochrome, tone controls, and a comparison mode.
 */
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D ascii_atlas : repeat_disable, filter_nearest;
uniform int glyph_count : hint_range(1, 256) = 16;
uniform float cell_size : hint_range(4.0, 24.0, 1.0) = 8.0;
uniform float brightness : hint_range(0.25, 3.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.2;
uniform float gamma : hint_range(0.25, 2.0) = 0.9;
uniform bool colored = true;
uniform bool split_screen = false;
uniform vec4 background_color : source_color = vec4(0.006, 0.012, 0.022, 1.0);
uniform vec4 monochrome_color : source_color = vec4(0.75, 0.95, 0.85, 1.0);

vec3 sample_scene(vec2 pixel, vec2 resolution) {
    return textureLod(screen_texture,
        clamp(pixel, vec2(0.5), resolution - vec2(0.5)) / resolution, 0.0).rgb;
}

void fragment() {
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 pixel = SCREEN_UV * resolution;
    float size = max(floor(cell_size), 1.0);
    vec2 origin = floor(pixel / size) * size;

    // Average four points rather than choosing a corner of the cell.
    vec3 scene = (sample_scene(origin + size * vec2(0.25, 0.25), resolution)
                + sample_scene(origin + size * vec2(0.75, 0.25), resolution)
                + sample_scene(origin + size * vec2(0.25, 0.75), resolution)
                + sample_scene(origin + size * vec2(0.75, 0.75), resolution)) * 0.25;
    float luminance = dot(scene, vec3(0.2126, 0.7152, 0.0722));
    float tone = clamp((luminance * brightness - 0.5) * contrast + 0.5, 0.0, 1.0);
    tone = pow(tone, gamma);

    // Both atlases are strips of square 8x8 glyphs; active count is explicit.
    ivec2 atlas_size = textureSize(ascii_atlas, 0);
    float glyph_size = float(atlas_size.y);
    float usable_characters = float(clamp(glyph_count, 1, atlas_size.x / atlas_size.y));
    float index = clamp(floor(tone * usable_characters), 0.0, usable_characters - 1.0);
    vec2 local_pixel = floor(fract(pixel / size) * glyph_size);
    vec2 atlas_uv = (vec2(index * glyph_size, 0.0) + local_pixel + 0.5) / vec2(atlas_size);
    float mask = step(0.5, textureLod(ascii_atlas, atlas_uv, 0.0).r);
    vec3 ink = colored ? pow(clamp(scene * brightness, 0.0, 1.0), vec3(gamma)) : monochrome_color.rgb;
    vec3 result = mix(background_color.rgb, ink, mask);

    if (split_screen && SCREEN_UV.x < 0.5) {
        result = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
    }
    if (split_screen && abs(pixel.x - resolution.x * 0.5) < 1.0) {
        result = vec3(0.35, 0.9, 0.75);
    }
    COLOR = vec4(result, 1.0);
}
