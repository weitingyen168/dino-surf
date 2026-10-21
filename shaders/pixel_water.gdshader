shader_type spatial;
// The water slab's pixel art (see View3D). UV.x is the x to tile along (screen x for the still water body,
// plus the ocean's scroll for the moving foam), UV.y is px below the surface (negative = above it). The art is tiled sideways, every other tile mirrored so the seams match,
// and its waterline row is pinned to the surface, so the glints and foam ride the waves.
render_mode unshaded, cull_disabled;

uniform sampler2D art : source_color, filter_linear, repeat_disable;
uniform float pixel_scale = 3.0;  // world px per art pixel
uniform float waterline_row = 98.0;  // art row that sits on the surface
uniform bool solid = false;  // the water body: gaps in the art are filled from below, so there are no holes
uniform float opacity = 1.0;  // < 1 lets you see a little into the water

// Pixel-art sampling: crisp texels, but each texel edge is blended over one screen pixel, so it doesn't crawl.
// fw is fwidth(p), taken once outside any loop.
vec2 pixel_uv(vec2 p, vec2 fw, vec2 size) {
	vec2 seam = floor(p + 0.5);
	p = seam + clamp((p - seam) / fw, -0.5, 0.5);
	return p / size;
}

void fragment() {
	vec2 size = vec2(textureSize(art, 0));
	vec2 p = vec2(UV.x, UV.y) / pixel_scale + vec2(0.0, waterline_row);
	p.x = size.x - abs(mod(p.x, 2.0 * size.x) - size.x);  // mirrored repeat
	p.y = clamp(p.y, 0.5, size.y - 0.5);  // below the art: its deepest row carries on
	vec2 fw = max(fwidth(p), vec2(1e-5));
	vec4 c = texture(art, pixel_uv(p, fw, size));
	for (int i = 0; i < 24 && solid && c.a < 0.5; i++) {
		p.y = min(p.y + 1.0, size.y - 0.5);
		c = texture(art, pixel_uv(p, fw, size));
	}
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = opacity;
}
