shader_type canvas_item;
// Camera look of the drone views, drawn under the viewfinder: a soft vignette and a fine
// animated grain, like a small action camera. The player's own view stays clean.

uniform float vignette = 0.32;
uniform float grain = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centred = SCREEN_UV - 0.5;
	centred.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dark = smoothstep(0.38, 0.95, length(centred)) * vignette;
	float noise = hash(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 24.0) * 17.0) - 0.5;
	float grain_alpha = abs(noise) * grain;
	// The vignette (black) and the grain (white or black) as one layer over the image.
	float alpha = 1.0 - (1.0 - dark) * (1.0 - grain_alpha);
	float light = noise > 0.0 ? grain_alpha : 0.0;
	COLOR = vec4(vec3(alpha > 0.0 ? light / alpha : 0.0), alpha);
}
