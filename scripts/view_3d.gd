class_name View3D
extends Node3D
## Shows the 2D game as a 3D pop-up book. The game still plays entirely in 2D; this only redraws it.
## Each 2D layer (Background, Hazards, Dino) renders into its own texture (a SubViewport sharing the game's 2D world)
## shown on a paper card standing at that layer's depth: the same art, cut out with a paper border and a little
## thickness. The water is the surface line extruded along z into a slab the cards stand in.
## Cards further back are scaled up so that, with the camera at rest, they line up with the 2D game exactly
## (so the hit boxes still match what you see); as the camera follows, leans and shakes, the depth shows as parallax.
## Anything drawn must live under one of the layer nodes, or it shows up on every card.
## Pixel art added under Background ends up on the furthest card, behind the water. V switches to the flat 2D view.

const S := 0.01  # 3D units per 2D px
# Visibility layer bits. Every node starts on BASE, so a layer's whole subtree follows its root's bit.
const BASE := 1
const BACKGROUND_BIT := 1 << 1
const HAZARDS_BIT := 1 << 2
const DINO_BIT := 1 << 3
const WATER_BIT := 1 << 4  # drawn in 3D as the slab, never on a card

const CARD_SHADER := preload("res://shaders/paper_card.gdshader")

@export var game_camera: GameCamera
@export var water: Water
@export var background: Node2D
@export var hazards: Node2D
@export var dino: Dino

@export_group("Depth (px, + = toward the camera)")
@export var background_z: float = -900.0
@export var hazards_z: float = -10.0
@export var dino_z: float = 10.0
@export var water_front_z: float = 70.0
@export var water_back_z: float = -70.0

@export_group("Camera")
@export var fov_deg: float = 30.0  # narrower = flatter, wider = more depth
@export var pitch_deg: float = 12.0  # looks down a little, so the top of the water shows

@export_group("Paper")
@export var paper_color: Color = Color.WHITE
@export var edge_color: Color = Color("a8a8a8")
@export var border_px: float = 2.0  # paper left around the art
@export var thickness_px: int = 3  # edge slices behind each card, 1 px apart
@export var card_size: Vector2i = Vector2i(1024, 768)  # texture px per card: the view plus room for lean, shake and pitch

@export_group("Water")
@export var water_top_color: Color = Color("ebebeb")
@export var water_front_color: Color = Color("dcdcdc")
@export var water_line_color: Color = Color("535353")
@export var water_line_px: float = 2.0


class Card:
	var node: CanvasItem
	var z: float  # px
	var scale: float  # how much bigger than 1:1, so it lines up at rest despite being further away
	var viewport: SubViewport
	var root: Node3D


var on := true
var _camera: Camera3D
var _rest_distance := 0.0  # px from the camera to the z = 0 plane
var _rest_center := Vector2.ZERO  # the 2D view centre with the camera at rest; far cards scale about it
var _cards: Array[Card] = []
var _water_mesh := ArrayMesh.new()
var _water_material := StandardMaterial3D.new()


func _ready() -> void:
	var view_h := get_viewport().get_visible_rect().size.y / game_camera.zoom.y
	_rest_distance = view_h / 2.0 / tan(deg_to_rad(fov_deg) / 2.0)
	_rest_center = Vector2(game_camera.position.x, game_camera.rest_y)

	(get_parent() as CanvasItem).visibility_layer = BACKGROUND_BIT | HAZARDS_BIT | DINO_BIT | WATER_BIT
	water.visibility_layer = WATER_BIT
	_add_card(background, BACKGROUND_BIT, background_z)
	_add_card(hazards, HAZARDS_BIT, hazards_z)
	_add_card(dino, DINO_BIT, dino_z)

	_water_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_water_material.vertex_color_use_as_albedo = true
	_water_material.vertex_color_is_srgb = true
	_water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var slab := MeshInstance3D.new()
	slab.mesh = _water_mesh
	slab.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # rebuilt every frame from the smoothed line
	add_child(slab)

	_camera = Camera3D.new()
	_camera.fov = fov_deg
	_camera.near = 1.0
	_camera.far = (_rest_distance - background_z) * S * 2.0
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
	_camera.current = on


func _add_card(node: CanvasItem, bit: int, z: float) -> void:
	node.visibility_layer = bit
	var card := Card.new()
	card.node = node
	card.z = z
	card.scale = (_rest_distance - z) / _rest_distance

	var vp := SubViewport.new()
	vp.size = card_size
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
	quad.size = Vector2(card_size) * card.scale * S
	for i in thickness_px + 1:
		var mat := ShaderMaterial.new()
		mat.shader = CARD_SHADER
		mat.set_shader_parameter("art", vp.get_texture())
		mat.set_shader_parameter("paper", paper_color)
		mat.set_shader_parameter("edge", edge_color)
		mat.set_shader_parameter("border_px", border_px)
		mat.set_shader_parameter("is_edge", i > 0)
		var slice := MeshInstance3D.new()
		slice.mesh = quad
		slice.material_override = mat
		slice.position.z = -i * S  # the face first, then the edge slices 1 px apart behind it
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
	_build_water()


## Points the card's texture at the part of the 2D world the camera can see at the card's depth, and moves the
## card there. Snapped to whole px so the art doesn't shimmer.
func _place_card(card: Card, cam: Transform3D) -> void:
	var used := card.node != background or background.get_child_count() > 0  # no background art yet: skip its card
	card.root.visible = used
	card.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if used else SubViewport.UPDATE_DISABLED
	if not used:
		return
	var forward := -cam.basis.z
	var hit := cam.origin + forward * ((card.z * S - cam.origin.z) / forward.z)
	var seen := _to_2d(hit)  # in the 3D scene, where the camera's centre ray meets the card
	var center := _rest_center + (seen - _rest_center) / card.scale  # the same spot in the card's 2D art
	var origin := (center - Vector2(card_size) / 2.0).round()
	card.viewport.canvas_transform = Transform2D(0.0, -origin)
	var art_center := origin + Vector2(card_size) / 2.0
	card.root.position = _to_3d(_rest_center + (art_center - _rest_center) * card.scale, card.z)


## The surface line extruded from water_back_z to water_front_z: a top face, and a front face down to the bottom
## with the ink line along its top edge.
func _build_water() -> void:
	var pts := water.surface_points()
	if pts.size() < 2:
		return
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var bottom := maxf(water.bottom_y, maxf(a.y, b.y) + 20.0)
		_quad(verts, colors, water_top_color,
			_to_3d(a, water_back_z), _to_3d(b, water_back_z), _to_3d(b, water_front_z), _to_3d(a, water_front_z))
		_quad(verts, colors, water_front_color,
			_to_3d(a, water_front_z), _to_3d(b, water_front_z),
			_to_3d(Vector2(b.x, bottom), water_front_z), _to_3d(Vector2(a.x, bottom), water_front_z))
		var line := Vector2(0.0, water_line_px)
		var z := water_front_z + 0.5  # just in front of the face
		_quad(verts, colors, water_line_color,
			_to_3d(a - line / 2.0, z), _to_3d(b - line / 2.0, z), _to_3d(b + line / 2.0, z), _to_3d(a + line / 2.0, z))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	_water_mesh.clear_surfaces()
	_water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_water_mesh.surface_set_material(0, _water_material)


static func _quad(verts: PackedVector3Array, colors: PackedColorArray, color: Color,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		verts.append(v)
		colors.append(color)


## 2D px (y down) at depth z px -> 3D units (y up).
static func _to_3d(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x * S, -p.y * S, z * S)


static func _to_2d(p: Vector3) -> Vector2:
	return Vector2(p.x / S, -p.y / S)
