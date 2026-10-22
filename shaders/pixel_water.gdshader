shader_type spatial;
// The water slab's pixel art (see View3D). UV.x is the x to tile along (screen x for the still water body,
// plus the ocean's scroll for the moving foam), UV.y is px below the surface (negative = above it). The art is
// tiled sideways, every other tile mirrored so the seams match, and its waterline row is pinned to the surface, so
// the glints and foam ride the waves. The top face is a flat colour instead (so the slab reads as a block you look
// down on), and the faces darken with depth as if lit from above.
render_mode unshaded, cull_disabled, depth_draw_always;  // writes depth, so faces hide each other right in any draw order

uniform sampler2D art : source_color, filter_linear, repeat_disable;
uniform float pixel_scale = 3.0;  // world px per art pixel
uniform float waterline_row = 98.0;  // art row that sits on the surface
uniform bool solid = false;  // the water body: gaps in the art are filled from below, so there are no holes
uniform float opacity = 1.0;  // < 1 lets you see a little into the water
uniform bool flat_top = false;  // the top face: a flat colour from top_front (UV.y 0) to top_back (UV.y top_depth)
uniform vec4 top_front : source_color = vec4(0.8, 0.93, 1.0, 1.0);
uniform vec4 top_back : source_color = vec4(0.5, 0.75, 0.92, 1.0);
uniform float top_depth = 49.0;
uniform float shade = 0.0;  // how much darker the faces get by shade_depth px below the surface
uniform float shade_depth = 400.0;

// Pixel-art sampling: crisp texels, but each texel edge is blended over one screen pixel, so it doesn't crawl.
// fw is fwidth(p), taken once outside any loop.
vec2 pixel_uv(vec2 p, vec2 fw, vec2 size) {
	vec2 seam = floor(p + 0.5);
	p = seam + clamp((p - seam) / fw, -0.5, 0.5);
	return p / size;
}

// The pixel water at uv, darkened with depth; alpha < 0.5 where there's no art (the foam's gaps).
vec4 water_art(vec2 uv) {
	vec2 size = vec2(textureSize(art, 0));
	vec2 p = uv / pixel_scale + vec2(0.0, waterline_row);
	p.x = size.x - abs(mod(p.x, 2.0 * size.x) - size.x);  // mirrored repeat
	p.y = clamp(p.y, 0.5, size.y - 0.5);  // below the art: its deepest row carries on
	vec2 fw = max(fwidth(p), vec2(1e-5));
	vec4 c = texture(art, pixel_uv(p, fw, size));
	for (int i = 0; i < 24 && solid && c.a < 0.5; i++) {
		p.y = min(p.y + 1.0, size.y - 0.5);
		c = texture(art, pixel_uv(p, fw, size));
	}
	return vec4(c.rgb * (1.0 - shade * clamp(uv.y / shade_depth, 0.0, 1.0)), c.a);
}

void fragment() {
	if (flat_top) {
		float back = clamp(UV.y / top_depth, 0.0, 1.0);
		ALBEDO = mix(top_front.rgb, top_back.rgb, back) * (1.0 - 0.25 * smoothstep(0.9, 1.0, back));  // far edge line
		ALPHA = opacity;
	} else {
		vec4 c = water_art(UV);
		if (c.a < 0.5) {
			discard;
		}
		ALBEDO = c.rgb;
		ALPHA = opacity;
	}
}
