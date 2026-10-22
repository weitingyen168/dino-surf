shader_type canvas_item;
// Recolours the dino's greens (body and its dark outline) to another hue, so it stands out against the sand,
// sky and water. Everything that isn't green (board, necklace, spray, blade trail) is left alone.

uniform float hue : hint_range(0.0, 1.0) = 0.78;  // the new hue: 0.78 is purple
uniform float brightness : hint_range(0.0, 2.0) = 0.8;  // < 1 darkens it for more contrast
uniform vec2 green_hues = vec2(0.2, 0.5);  // the hue range that counts as the dino's green

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec3 hsv = rgb_to_hsv(c.rgb);
	if (hsv.x > green_hues.x && hsv.x < green_hues.y && hsv.y > 0.15) {
		c.rgb = hsv_to_rgb(vec3(hue, hsv.y, hsv.z * brightness));
	}
	COLOR = c;
}
