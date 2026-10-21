extends SceneTree
## Turns the artists' full-size exports into game-ready PNGs under art/. Re-run whenever the art changes:
##   Godot_console.exe --headless --path . --script res://tools/prepare_art.gd -- "<artist folder>"
## Pixel art (exported blown up, e.g. 20×) goes back to 1 px per art pixel. Drawn art is cropped to what's drawn
## and shrunk to 2× its in-game size (View3D draws the dino's card at 2× resolution).
## The small far cacti (above CACTI_SPLIT_ROW in the cactus art) are moved up or down onto the dunes' outline,
## each where it stands, into their own layer that goes with the dunes.

const PIXEL := {
	"Other sprites/1_desertFarMountains.png": "backgrounds/desert_far_mountains_01.png",
	"Other sprites/2_desertMountains.png": "backgrounds/desert_mountains_01.png",
	"Other sprites/3_desertGround.png": "backgrounds/desert_ground_01.png",
	"Other sprites/4_cactus.png": "backgrounds/desert_cacti_01.png",
	"Other sprites/5_water.png": "backgrounds/water_01.png",
	"Other sprites/6_waves.png": "backgrounds/water_waves_01.png",
}

const CACTI := "Other sprites/4_cactus.png"
const HILLS := "Other sprites/2_desertMountains.png"
const HILL_CACTI := "backgrounds/desert_hill_cacti_01.png"
const CACTI_SPLIT_ROW := 116  # cactus art rows above this are the small far ones; Main's Cacti backdrop starts here

## Animations: a folder of frames (in name order) -> one strip, frames left to right, sharing one crop.
## [folder, output, output frame height in px].
const ANIMS := [
	["seagull_animation", "obstacles/seagull_fly_01.png", 76],
]

## Each set shares one crop, so its variants stay lined up: [sources, outputs, output height in px].
const DRAWN := [
	[["NEW_Dino_sprite_art/dino_normal.png", "NEW_Dino_sprite_art/dino_scared.png"],
		["dino/dino_ride_01.png", "dino/dino_scared_01.png"], 88],
	[["NEW_Dino_sprite_art/surf_board_sprite.png", "NEW_Dino_sprite_art/board_scared.png"],
		["dino/board_ride_01.png", "dino/board_scared_01.png"], 30],
]


func _initialize() -> void:
	var src: String = OS.get_cmdline_user_args()[0]
	var pixel := {}
	for from in PIXEL:
		var img := Image.load_from_file(src.path_join(from))
		var block := _block_size(img)
		img.resize(img.get_width() / block, img.get_height() / block, Image.INTERPOLATE_NEAREST)
		_save(img, PIXEL[from])
		pixel[from] = img
		print("%s: %d× blocks -> %s" % [from, block, img.get_size()])
	var hill_cacti := _plant_on_hills(pixel[CACTI], pixel[HILLS])
	_save(hill_cacti, HILL_CACTI)
	print("small cacti planted on the dunes -> %s" % HILL_CACTI)
	for set in DRAWN:
		var imgs: Array[Image] = []
		var used := Rect2i()
		for from in set[0]:
			var img := Image.load_from_file(src.path_join(from))
			_shrink_to(img, img.get_height() / 4)
			var r := _drawn_rect(img)
			used = r if used.size == Vector2i.ZERO else used.merge(r)
			imgs.append(img)
		for i in imgs.size():
			var img := imgs[i].get_region(used)
			_shrink_to(img, set[2])
			_save(img, set[1][i])
			print("%s -> %s" % [set[0][i], img.get_size()])
	for anim in ANIMS:
		var frames: Array[Image] = []
		var used := Rect2i()
		var names := Array(DirAccess.get_files_at(src.path_join(anim[0]))).filter(func(f): return f.ends_with(".png"))
		names.sort()
		for f in names:
			var img := Image.load_from_file(src.path_join(anim[0]).path_join(f))
			_shrink_to(img, img.get_height() / 4)
			var r := _drawn_rect(img)
			used = r if used.size == Vector2i.ZERO else used.merge(r)
			frames.append(img)
		var strip: Image
		for i in frames.size():
			var img := frames[i].get_region(used)
			_shrink_to(img, anim[2])
			if strip == null:
				strip = Image.create(img.get_width() * frames.size(), img.get_height(), false, Image.FORMAT_RGBA8)
			strip.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * img.get_width(), 0))
		_save(strip, anim[1])
		print("%s: %d frames -> %s" % [anim[0], frames.size(), strip.get_size()])
	quit()


## Each small cactus (a connected blob above CACTI_SPLIT_ROW), moved up or down so its base sits on the hills'
## outline at its middle column. Same frame and size as the cactus art.
func _plant_on_hills(cacti: Image, hills: Image) -> Image:
	var out := Image.create(cacti.get_width(), cacti.get_height(), false, Image.FORMAT_RGBA8)
	var seen := {}
	for y in CACTI_SPLIT_ROW:
		for x in cacti.get_width():
			var start := Vector2i(x, y)
			if seen.has(start) or cacti.get_pixelv(start).a == 0.0:
				continue
			# Flood-fill the blob.
			var blob: Array[Vector2i] = []
			var todo: Array[Vector2i] = [start]
			seen[start] = true
			while not todo.is_empty():
				var p: Vector2i = todo.pop_back()
				blob.append(p)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					var q: Vector2i = p + d
					if q.x >= 0 and q.x < cacti.get_width() and q.y >= 0 and q.y < CACTI_SPLIT_ROW 							and not seen.has(q) and cacti.get_pixelv(q).a > 0.0:
						seen[q] = true
						todo.append(q)
			var lo := blob[0]
			var hi := blob[0]
			for p in blob:
				lo = lo.min(p)
				hi = hi.max(p)
			var ground := _top_row(hills, (lo.x + hi.x) / 2)
			var dy := ground - hi.y  # its bottom row lands on the hills' top row, so it stands just in front of the edge
			for p in blob:
				var to := p + Vector2i(0, dy)
				if to.y >= 0 and to.y < out.get_height():
					out.set_pixelv(to, cacti.get_pixelv(p))
	return out


## First drawn row in a column of the art.
func _top_row(img: Image, x: int) -> int:
	for y in img.get_height():
		if img.get_pixel(x, y).a > 0.0:
			return y
	return img.get_height() - 1


## Biggest block size the pixel art was blown up by: every block of that size is one flat colour.
func _block_size(img: Image) -> int:
	for s in [40, 32, 30, 25, 24, 20, 16, 15, 12, 10, 8, 6, 5, 4, 3, 2]:
		if img.get_width() % s or img.get_height() % s:
			continue
		var flat := true
		for i in 3000:
			var x: int = (randi() % (img.get_width() / s)) * s
			var y: int = (randi() % (img.get_height() / s)) * s
			var c := img.get_pixel(x, y)
			if not c.is_equal_approx(img.get_pixel(x + s - 1, y + s - 1)) or not c.is_equal_approx(img.get_pixel(x + s / 2, y + s / 3)):
				flat = false
				break
		if flat:
			return s
	return 1


## Shrinks in halves (a clean average each step), then to the exact height, keeping the aspect.
func _shrink_to(img: Image, height: int) -> void:
	while img.get_height() >= height * 2:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	var w := roundi(img.get_width() * float(height) / img.get_height())
	img.resize(w, height, Image.INTERPOLATE_CUBIC)


## Bounds of the clearly drawn pixels, ignoring faint smudges.
func _drawn_rect(img: Image) -> Rect2i:
	var lo := Vector2i(img.get_width(), img.get_height())
	var hi := Vector2i(-1, -1)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.25:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	return Rect2i(lo, hi - lo + Vector2i.ONE).grow(2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))


func _save(img: Image, to: String) -> void:
	var path := ProjectSettings.globalize_path("res://art".path_join(to))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
