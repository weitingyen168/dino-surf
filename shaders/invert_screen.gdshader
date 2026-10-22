shader_type canvas_item;
// Inverts everything drawn beneath it (see InvertScreen), blended in by `amount` for the fade.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	COLOR = vec4(mix(c, vec3(1.0) - c, amount), 1.0);
}
