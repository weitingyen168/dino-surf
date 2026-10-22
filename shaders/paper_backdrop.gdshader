shader_type spatial;
// A Backdrop's paper card in the pop-up view (see View3D). Samples the backdrop's pixel art directly, tiled
// sideways with every other tile mirrored just as Backdrop draws it, so it needs no render target.
// Like paper_card: a paper border around the art, and edge slices in a darker colour behind the face.
render_mode unshaded, cull_disabled;

uniform sampler2D art : source_color, filter_linear, repeat_disable;
uniform vec4 paper : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.66, 0.66, 0.66, 1.0);
uniform bool is_edge = false;
uniform float border_art_px = 0.67;  // paper left around the art, in art pixels
uniform float pixel_scale = 3.0;  // world px per art pixel
uniform float first_row = 0.0;  // the band of art rows this backdrop shows
uniform float end_row = 150.0;
uniform bool extend_down = false;  // below the band, carry its bottom row on down
uniform vec2 card_origin;  // 2D px of the card's top-left
uniform vec2 card_size;  // 2D px the card spans
uniform vec2 art_origin;  // 2D px of the art's top-left, scroll included
uniform vec4 haze_color : source_color = vec4(0.55, 0.78, 0.93, 1.0);  // the sky: far layers fade toward it
uniform float haze = 0.0;  // 0 = none, 1 = all sky

// Art pixel p folded into the mirrored tiling, or x < 0 when outside this backdrop's band.
vec2 fold(vec2 p, vec2 size) {
	p.x = size.x - abs(mod(p.x, 2.0 * size.x) - size.x);
	if (extend_down && p.y >= end_row) {
		p.y = end_row - 0.5;
	}
	return (p.y < first_row || p.y >= end_row) ? vec2(-1.0) : p;
}

float alpha_at(vec2 p, vec2 size) {
	p = fold(p, size);
	return p.x < 0.0 ? 0.0 : texture(art, p / size).a;
}

void fragment() {
	vec2 size = vec2(textureSize(art, 0));
	vec2 p = (card_origin + UV * card_size - art_origin) / pixel_scale;
	vec2 fw = max(fwidth(p), vec2(1e-5));
	vec2 f = fold(p, size);
	vec4 c = vec4(0.0);
	if (f.x >= 0.0) {
		// Pixel-art sampling: crisp texels, each edge blended over one screen pixel so it doesn't crawl.
		vec2 seam = floor(f + 0.5);
		c = texture(art, (seam + clamp((f - seam) / fw, -0.5, 0.5)) / size);
	}
	if (c.a < 0.5) {
		// Not art: paper if any art is within the border, else nothing.
		float near = 0.0;
		for (int i = 0; i < 8; i++) {
			float angle = float(i) * TAU / 8.0;
			near = max(near, alpha_at(p + vec2(cos(angle), sin(angle)) * border_art_px, size));
		}
		if (near < 0.5) {
			discard;
		}
	}
	ALBEDO = mix(is_edge ? edge.rgb : mix(paper.rgb, c.rgb, c.a), haze_color.rgb, haze);
}
