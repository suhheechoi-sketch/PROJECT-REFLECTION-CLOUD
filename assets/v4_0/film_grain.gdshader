shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	// Stable spatial pattern; no flashing or temporal noise.
	vec2 pixel = floor(FRAGCOORD.xy);
	float pattern = mod(pixel.x + mod(pixel.y, 2.0) * 2.0, 4.0) / 4.0 - 0.375;
	vec3 quantized = floor(clamp(source + pattern / 96.0, 0.0, 1.0) * 63.0 + 0.5) / 63.0;
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float vignette = 1.0 - dot(centered, centered) * 0.075;
	COLOR = vec4(quantized * vignette, 1.0);
}
