shader_type canvas_item;
// Dark scrim over the 3D stage: the scene behind a menu, blurred and darkened, so cream text
// reads even over a noon sky. The blur samples a low mip of the screen copy in a small cross
// of taps: cheap enough for a paused game.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.05, 0.06, 0.08, 0.84);
uniform float blur_lod = 3.0;

void fragment() {
	vec2 offs = SCREEN_PIXEL_SIZE * exp2(blur_lod) * 1.5;
	vec3 sum = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb * 0.28;
	sum += textureLod(screen_texture, SCREEN_UV + vec2(offs.x, 0.0), blur_lod).rgb * 0.12;
	sum += textureLod(screen_texture, SCREEN_UV - vec2(offs.x, 0.0), blur_lod).rgb * 0.12;
	sum += textureLod(screen_texture, SCREEN_UV + vec2(0.0, offs.y), blur_lod).rgb * 0.12;
	sum += textureLod(screen_texture, SCREEN_UV - vec2(0.0, offs.y), blur_lod).rgb * 0.12;
	sum += textureLod(screen_texture, SCREEN_UV + offs, blur_lod).rgb * 0.06;
	sum += textureLod(screen_texture, SCREEN_UV - offs, blur_lod).rgb * 0.06;
	sum += textureLod(screen_texture, SCREEN_UV + vec2(offs.x, -offs.y), blur_lod).rgb * 0.06;
	sum += textureLod(screen_texture, SCREEN_UV + vec2(-offs.x, offs.y), blur_lod).rgb * 0.06;
	COLOR = vec4(mix(sum, tint.rgb, tint.a), 1.0);
}
