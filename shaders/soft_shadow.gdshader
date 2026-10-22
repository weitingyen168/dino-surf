shader_type spatial;
// A soft dark oval (see View3D's dino shadow): darkest in the middle, fading to nothing at the edge.
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float alpha = 0.35;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(0.0, 0.05, 0.15);
	ALPHA = alpha * (1.0 - smoothstep(0.35, 1.0, r));
}
