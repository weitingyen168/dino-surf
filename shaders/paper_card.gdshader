shader_type spatial;
// One paper card of the pop-up view (see View3D): a 2D layer's art, cut out with a paper border around it.
// Edge slices behind the face use the same outline in a darker colour, so the card has a visible thickness.
render_mode unshaded, cull_disabled;

uniform sampler2D art : source_color, filter_linear, repeat_disable;
uniform vec4 paper : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.66, 0.66, 0.66, 1.0);
uniform float border_px = 2.0;  // paper left around the art, in art pixels
uniform bool is_edge = false;  // a thickness slice: solid edge colour

// Most art coverage in a ring `radius` art pixels around uv.
float ring(vec2 uv, vec2 px, float radius) {
	float a = 0.0;
	for (int i = 0; i < 12; i++) {
		float angle = float(i) * TAU / 12.0;
		a = max(a, texture(art, uv + vec2(cos(angle), sin(angle)) * px * radius).a);
	}
	return a;
}

// Pixel-art sampling: crisp texels like nearest filtering, but each texel edge is blended over one screen pixel,
// so art shown at a non-whole scale doesn't crawl as the camera moves.
vec2 pixel_uv(vec2 uv, vec2 size) {
	vec2 p = uv * size;
	vec2 seam = floor(p + 0.5);
	p = seam + clamp((p - seam) / max(fwidth(p), vec2(1e-5)), -0.5, 0.5);
	return p / size;
}

void fragment() {
	vec2 size = vec2(textureSize(art, 0));
	vec2 px = 1.0 / size;
	vec4 c = texture(art, pixel_uv(UV, size));
	if (c.a < 0.5 && ring(UV, px, border_px) < 0.5 && ring(UV, px, border_px * 0.5) < 0.5) {
		discard;
	}
	// The layer renders onto a transparent background, so its colours come out premultiplied: ink on paper.
	ALBEDO = is_edge ? edge.rgb : paper.rgb * (1.0 - c.a) + c.rgb;
}
