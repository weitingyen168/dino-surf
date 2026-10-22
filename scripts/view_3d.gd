class_name View3D
extends Node3D
## Shows the 2D game as a 3D pop-up book. The game still plays entirely in 2D; this only redraws it.
## Each 2D layer is shown on a paper card standing at that layer's depth: the same art, cut out with a paper
## border and a little thickness.
##   Background  every Backdrop child gets its own card at its `depth`, far behind the water. A backdrop is just
##               its art scrolling, so its card samples the art directly (cheap: no render target)
##   Hazards     cacti and gulls, just behind the dino: rendered into a texture by a SubViewport sharing the
##               game's 2D world
##   Dino        the same, on a smaller card that follows the dino, at higher resolution for the hand-drawn art
## The water is the surface line extruded along z into a slab the cards stand in, textured with the pixel water
## art, with the foam strip along its front edge. It's slightly see-through, with a solid back wall, so you see
## the cacti and the dino's legs a little way into it.
## Cards further back are scaled up so that, with the camera at rest, they line up with the 2D game exactly
## (so the hit boxes still match what you see); as the camera follows, leans and shakes, the depth shows as parallax.
## Anything drawn must live under one of the layer nodes, or it shows up on every card. V switches to the flat 2D view.

const S := 0.01  # 3D units per 2D px
# Visibility layer bits. Every node starts on BASE, so a layer's whole subtree follows its root's bit.
const BASE := 1
const HAZARDS_BIT := 1 << 1
const DINO_BIT := 1 << 2
const WATER_BIT := 1 << 3  # drawn in 3D as the slab, never on a card
const BACKGROUND_BIT := 1 << 4  # the backdrops' cards sample their art directly, so no viewport draws these

const CARD_SHADER := preload("res://shaders/paper_card.gdshader")
const BACKDROP_SHADER := preload("res://shaders/paper_backdrop.gdshader")
const SHADOW_SHADER := preload("res://shaders/soft_shadow.gdshader")
const WATER_SHADER := preload("res://shaders/pixel_water.gdshader")

@export var game_camera: GameCamera
@export var water: Water
@export var background: Node2D
@export var hazards: Node2D
@export var dino: Dino

@export_group("Depth (px, + = toward the camera)")
@export var hazards_z: float = -10.0
@export var dino_z: float = 10.0
@export var water_front_z: float = 70.0
@export var water_back_z: float = -70.0

@export_group("Camera")
@export var fov_deg: float = 30.0  # narrower = flatter, wider = more depth
@export var pitch_deg: float = 16.0  # looks down a little, so the top of the water shows

@export_group("Paper")
@export var paper_color: Color = Color.WHITE
@export var edge_color: Color = Color("a8a8a8")
@export var border_px: float = 2.0  # paper left around the art, in world px
@export var card_thickness: bool = false  # a darker edge slice behind each card; costs a second full draw of it
@export var thickness_px: float = 2.0  # how far behind each card its edge slice sits
@export var card_size: Vector2i = Vector2i(1088, 800)  # world px a full-view card covers: the view plus room for lean, shake and pitch
@export var dino_card_size: Vector2i = Vector2i(256, 256)  # world px around the dino
@export var dino_resolution: float = 2.0  # texture px per world px on the dino's card; the art is made at 2×
@export var hazards_resolution: float = 1.25  # the same for the cacti and gulls; 2 is sharper but heavy in a browser
@export var dino_border_px: float = 0.0  # paper border around the dino (0 = none: just the outline, like the gulls)
@export var dino_ink_px: float = 2.0  # outline around the dino, in ink_color (0 = none)
@export var ink_color: Color = Color("3d1457")  # dark purple, to go with the dino

@export_group("Water")
@export var water_art: Texture2D = preload("res://art/backgrounds/water_01.png")
@export var foam_art: Texture2D = preload("res://art/backgrounds/water_waves_01.png")
@export var water_pixel_scale: float = 3.0  # world px per art pixel, same as the backdrops
@export var waterline_row: float = 98.0  # art row of the waterline (the water and foam art share one frame)
@export var foam_above_px: float = 24.0  # how far the foam strip reaches above / below the surface
@export var foam_below_px: float = 54.0
@export var top_depth: float = 0.35  # how quickly the top face fades to deeper water toward the back
@export_range(0.0, 1.0) var water_opacity: float = 0.8  # front and top faces; the back wall stays solid

@export_group("Depth cues")
## Things that make the 3D read: a shadow under the dino, and far layers fading toward the sky (haze).
@export_range(0.0, 1.0) var shadow_alpha: float = 0.45  # the dino's shadow on the water, when it's on it
@export var shadow_size: Vector2 = Vector2(56, 40)  # px across (x) and deep (z)
@export var shadow_fade_px: float = 260.0  # the shadow shrinks and fades out by this high above the water
@export var haze_per_px: float = 0.00018  # haze added per px of depth behind the water; capped at haze_max
@export_range(0.0, 1.0) var haze_max: float = 0.45


class Backdrop3D:
	var backdrop: Backdrop
	var scale: float
	var rows: Vector2  # world px from the art's top to its first drawn row, and past its last
	var root: Node3D
	var materials: Array[ShaderMaterial] = []


class Card:
	var node: CanvasItem
	var z: float  # px
	var scale: float  # how much bigger than 1:1, so it lines up at rest despite being further away
	var size: Vector2  # world px covered
	var resolution: float  # texture px per world px
	var follow: Node2D  # centre on this node; null = wherever the camera looks
	var viewport: SubViewport
	var root: Node3D
	var materials: Array[ShaderMaterial] = []


var on := true
var _camera: Camera3D
var _rest_distance := 0.0  # px from the camera to what it looks at
var _eye := Vector2.ZERO  # 2D position of the camera at rest; cards scale about it, so every depth lines up from there
var _eye_z := 0.0  # px from the camera at rest to the z = 0 plane
var _cards: Array[Card] = []
var _backdrops: Array[Backdrop3D] = []
var _water_mesh := ArrayMesh.new()
var _water_indices := PackedInt32Array()  # the same strip of quads every frame
var _water_materials: Array[ShaderMaterial] = []  # back, top, front, foam: drawn in this order, back to front
var _shadow := MeshInstance3D.new()
var _shadow_material := ShaderMaterial.new()


func _ready() -> void:
	var view_h := get_viewport().get_visible_rect().size.y / game_camera.zoom.y
	_rest_distance = view_h / 2.0 / tan(deg_to_rad(fov_deg) / 2.0)
	var pitch := deg_to_rad(pitch_deg)
	_eye = Vector2(game_camera.position.x, game_camera.rest_y - _rest_distance * sin(pitch))
	_eye_z = _rest_distance * cos(pitch)

	var deepest := 0.0
	for b in background.get_children():
		if b is Backdrop:
			_add_backdrop(b)
			deepest = minf(deepest, b.depth)
	background.visibility_layer = BACKGROUND_BIT
	_add_card(hazards, HAZARDS_BIT, hazards_z, card_size, hazards_resolution, null)
	_add_card(dino, DINO_BIT, dino_z, dino_card_size, dino_resolution, dino)
	for mat in _cards.back().materials:
		mat.set_shader_parameter("border_px", dino_border_px * dino_resolution)
		mat.set_shader_parameter("ink_px", dino_ink_px * dino_resolution)
		mat.set_shader_parameter("ink", ink_color)
	water.visibility_layer = WATER_BIT
	(get_parent() as CanvasItem).visibility_layer = BACKGROUND_BIT | HAZARDS_BIT | DINO_BIT | WATER_BIT

	for i in 4:
		var mat := ShaderMaterial.new()
		mat.shader = WATER_SHADER
		mat.set_shader_parameter("art", foam_art if i == 3 else water_art)
		mat.set_shader_parameter("pixel_scale", water_pixel_scale)
		mat.set_shader_parameter("waterline_row", waterline_row)
		mat.set_shader_parameter("solid", i < 3)
		mat.set_shader_parameter("opacity", water_opacity if i in [1, 2] else 1.0)
		_water_materials.append(mat)
	var slab := MeshInstance3D.new()
	slab.mesh = _water_mesh
	slab.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # rebuilt every frame from the smoothed line
	add_child(slab)

	# The dino's shadow: a soft dark oval lying on the water's top under it.
	_shadow_material.shader = SHADOW_SHADER
	var oval := PlaneMesh.new()  # lies flat (in x and z), facing up
	oval.size = shadow_size * S
	_shadow.mesh = oval
	_shadow.material_override = _shadow_material
	_shadow.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_shadow)

	_camera = Camera3D.new()
	_camera.fov = fov_deg
	_camera.near = 1.0
	_camera.far = (_eye_z - deepest) * S * 2.0
	add_child(_camera)
	_place_camera()
	_camera.reset_physics_interpolation()
	_set_on(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		_set_on(not on)


## 3D view, or the plain 2D game. The 2D world is hidden from the main screen while the 3D view shows it.
func _set_on(value: bool) -> void:
	on = value
	var vp := get_viewport()
	vp.disable_3d = not on
	vp.canvas_cull_mask = BASE if on else 0xFFFFFFFF  # BASE alone still shows the HUD
	water.draw_flat = not on
	_camera.current = on
	for card in _cards:
		card.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


## A card at depth z is this many times bigger than 1:1, so that from the camera at rest it covers the same view.
func _scale_at(z: float) -> float:
	return (_eye_z - z) / _eye_z


## A backdrop's card: a quad over just the rows its art uses, sampling the art itself as it scrolls.
func _add_backdrop(b: Backdrop) -> void:
	var card := Backdrop3D.new()
	card.backdrop = b
	card.scale = _scale_at(b.depth)
	b.parallax = 1.0 / card.scale  # its on-screen speed, seen from the camera at that distance
	var used := b.used_rows()
	card.rows = Vector2(used.x - 1, used.y + 1) * b.pixel_scale + Vector2(0.0, b.extend_down_px)  # room for the border
	card.root = Node3D.new()
	card.root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # placed every frame from the smoothed camera
	add_child(card.root)
	var size := Vector2(card_size.x, card.rows.y - card.rows.x)
	var quad := QuadMesh.new()
	quad.size = size * card.scale * S
	for is_edge in ([false, true] if card_thickness else [false]):
		var mat := ShaderMaterial.new()
		mat.shader = BACKDROP_SHADER
		mat.set_shader_parameter("art", b.texture)
		mat.set_shader_parameter("paper", paper_color)
		mat.set_shader_parameter("edge", edge_color)
		mat.set_shader_parameter("border_art_px", border_px / b.pixel_scale)
		mat.set_shader_parameter("pixel_scale", b.pixel_scale)
		mat.set_shader_parameter("haze_color", RenderingServer.get_default_clear_color())
		mat.set_shader_parameter("haze", minf(-(b.depth - water_back_z) * haze_per_px, haze_max))
		mat.set_shader_parameter("first_row", float(b.first_row))
		mat.set_shader_parameter("end_row", float(b.end_row()))
		mat.set_shader_parameter("extend_down", b.extend_down_px > 0.0)
		mat.set_shader_parameter("card_size", size)
		mat.set_shader_parameter("is_edge", is_edge)
		card.materials.append(mat)
		var slice := MeshInstance3D.new()
		slice.mesh = quad
		slice.material_override = mat
		slice.position.z = -thickness_px * S if is_edge else 0.0  # the face, then the edge slice behind it
		card.root.add_child(slice)
	_backdrops.append(card)


func _add_card(node: CanvasItem, bit: int, z: float, size: Vector2, resolution: float, follow: Node2D) -> void:
	node.visibility_layer = bit
	var card := Card.new()
	card.node = node
	card.z = z
	card.scale = _scale_at(z)
	card.size = size
	card.resolution = resolution
	card.follow = follow

	var vp := SubViewport.new()
	vp.size = Vector2i(size * resolution)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.world_2d = get_viewport().world_2d  # draws the game's own 2D world, filtered to this layer
	vp.canvas_cull_mask = BASE | bit
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	card.viewport = vp

	var root := Node3D.new()
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # placed every frame from the smoothed camera
	add_child(root)
	card.root = root
	var quad := QuadMesh.new()
	quad.size = size * card.scale * S
	for is_edge in ([false, true] if card_thickness else [false]):
		var mat := ShaderMaterial.new()
		mat.shader = CARD_SHADER
		mat.set_shader_parameter("art", vp.get_texture())
		mat.set_shader_parameter("paper", paper_color)
		mat.set_shader_parameter("edge", edge_color)
		mat.set_shader_parameter("border_px", border_px * resolution)
		mat.set_shader_parameter("is_edge", is_edge)
		card.materials.append(mat)
		var slice := MeshInstance3D.new()
		slice.mesh = quad
		slice.material_override = mat
		slice.position.z = -thickness_px * S if is_edge else 0.0  # the face, then the edge slice behind it
		root.add_child(slice)
	_cards.append(card)


func _physics_process(_delta: float) -> void:
	_place_camera()  # after the Camera2D has moved this tick (it's earlier in the tree); interpolated between ticks


## Puts the 3D camera where the 2D one is looking, at the rest distance, leaning and shaking with it.
func _place_camera() -> void:
	var look := game_camera.position + game_camera.offset
	var facing := Basis.from_euler(Vector3(-deg_to_rad(pitch_deg), 0.0, -game_camera.rotation))
	_camera.transform = Transform3D(facing, _to_3d(look, 0.0) + facing.z * _rest_distance * S)


func _process(_delta: float) -> void:
	if not on:
		return
	var cam := _camera.get_global_transform_interpolated()
	for card in _cards:
		_place_card(card, cam)
	for card in _backdrops:
		_place_backdrop(card, cam)
	_build_water()
	_place_shadow()


## Lays the shadow on the water under the dino, tilted with the surface there; it shrinks and fades as the dino
## flies higher, which is what makes its height (and the water's top) read.
func _place_shadow() -> void:
	var x := dino.position.x
	var surface := water.surface_y(x)
	var k := clampf(1.0 - (surface - dino.position.y) / shadow_fade_px, 0.0, 1.0)
	_shadow.visible = k > 0.0 and not dino.crashed
	_shadow_material.set_shader_parameter("alpha", shadow_alpha * k)
	_shadow.transform = Transform3D(Basis(Vector3.BACK, -water.slope_angle(x)).scaled(Vector3.ONE * lerpf(0.5, 1.0, k)),
		_to_3d(Vector2(x, surface - 0.5), dino_z))


## Where the camera's centre ray meets the plane at depth z, in that depth's 2D art coordinates.
func _view_center(z: float, scale: float, cam: Transform3D) -> Vector2:
	var forward := -cam.basis.z
	var hit := cam.origin + forward * ((z * S - cam.origin.z) / forward.z)
	return _eye + (_to_2d(hit) - _eye) / scale


## Points the card's texture at the part of the 2D world it should show, and moves the card there.
## Snapped to whole texture px so the art doesn't shimmer.
func _place_card(card: Card, cam: Transform3D) -> void:
	var center := card.follow.position if card.follow else _view_center(card.z, card.scale, cam)
	var origin := ((center - card.size / 2.0) * card.resolution).round() / card.resolution
	card.viewport.canvas_transform = Transform2D(0.0, Vector2.ONE * card.resolution, 0.0, -origin * card.resolution)
	var art_center := origin + card.size / 2.0
	card.root.position = _to_3d(_eye + (art_center - _eye) * card.scale, card.z)


## Centres the backdrop's card on the view sideways (up and down it spans just the art's rows) and tells the
## shader where the scrolling art is under it.
func _place_backdrop(card: Backdrop3D, cam: Transform3D) -> void:
	var b := card.backdrop
	var size := Vector2(card_size.x, card.rows.y - card.rows.x)
	var origin := Vector2(_view_center(b.depth, card.scale, cam).x - size.x / 2.0, b.position.y + card.rows.x)
	for mat in card.materials:
		mat.set_shader_parameter("card_origin", origin)
		mat.set_shader_parameter("art_origin", Vector2(b.drawn_x(), b.position.y))
	card.root.position = _to_3d(_eye + (origin + size / 2.0 - _eye) * card.scale, b.depth)


## The surface line extruded from water_back_z to water_front_z: a back wall and a front face down to the bottom,
## a top face between them, and the foam strip along the front edge. UV = (x to tile along, px below the
## surface) for the shader: the water body stays put sideways (it only rides the waves up and down), the foam
## scrolls with the ocean.
func _build_water() -> void:
	var all := water.surface_points()
	var pts := PackedVector2Array()  # every other point: about 13 px apart still reads as a smooth curve, at half the work
	for i in range(0, all.size(), 2):
		pts.append(all[i])
	var n := pts.size()
	if n < 2:
		return
	if _water_indices.size() != (n - 1) * 6:
		# Each surface is two rows of n vertices (row 0 = 0..n-1, row 1 = n..2n-1), joined into quads.
		_water_indices.resize((n - 1) * 6)
		for i in n - 1:
			_water_indices[i * 6] = i
			_water_indices[i * 6 + 1] = i + 1
			_water_indices[i * 6 + 2] = n + i + 1
			_water_indices[i * 6 + 3] = i
			_water_indices[i * 6 + 4] = n + i + 1
			_water_indices[i * 6 + 5] = n + i
	var scroll := water.drawn_scroll()
	var back_depth := (water_front_z - water_back_z) * top_depth
	var foam_z := water_front_z + 0.5  # just in front of the face
	_water_mesh.clear_surfaces()
	for surface in 4:  # back, top, front, foam
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		verts.resize(n * 2)
		uvs.resize(n * 2)
		for i in n:
			var p := pts[i]
			match surface:
				0, 2:
					var z := water_back_z if surface == 0 else water_front_z
					var bottom := maxf(water.bottom_y, p.y + 20.0) + 600.0  # well below the view, even seen in perspective
					verts[i] = _to_3d(p, z)
					verts[n + i] = _to_3d(Vector2(p.x, bottom), z)
					uvs[i] = Vector2(p.x, 0.0)
					uvs[n + i] = Vector2(p.x, bottom - p.y)
				1:
					verts[i] = _to_3d(p, water_back_z)
					verts[n + i] = _to_3d(p, water_front_z)
					uvs[i] = Vector2(p.x, back_depth)
					uvs[n + i] = Vector2(p.x, 0.0)
				3:
					verts[i] = _to_3d(p - Vector2(0.0, foam_above_px), foam_z)
					verts[n + i] = _to_3d(p + Vector2(0.0, foam_below_px), foam_z)
					uvs[i] = Vector2(p.x + scroll, -foam_above_px)
					uvs[n + i] = Vector2(p.x + scroll, foam_below_px)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = _water_indices
		_water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_water_mesh.surface_set_material(surface, _water_materials[surface])


## Where a 2D world point drawn on the card at depth z ends up in 3D (cards are scaled about the camera's eye).
func card_point(at: Vector2, z: float) -> Vector3:
	return _to_3d(_eye + (at - _eye) * _scale_at(z), z)


## 2D px (y down) at depth z px -> 3D units (y up).
static func _to_3d(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x * S, -p.y * S, z * S)


static func _to_2d(p: Vector3) -> Vector2:
	return Vector2(p.x / S, -p.y / S)
