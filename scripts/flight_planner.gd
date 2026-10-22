class_name FlightPlanner
## Answers "where can debris go so the player can still fly over it?" for ObstacleSpawner.
## Plays the dino forward on the swell alone (the spring ripples are small) from right now, with no input: same
## physics as Dino._float. The swells travel, so it steps time too; debris stays put in world space. The water's
## tilt (taken as it is now) adds to the slope, and moves a debris top up or down with where it is on screen. Planted debris (cacti) has a fixed top; floating debris (a buoy) rides
## the swell, so its top moves with the water under it.


## World positions (screen x + scroll) from screen x `from_x` to `from_x + reach` where debris `width` wide,
## with its top at screen y `top_y`, would be cleared by the next flight the swell gives the dino on its own.
## `rides_height` > 0 means it floats instead: its top is that far above the swell, wherever the swell is then.
static func clearable_spots(d: Dino, water: Water, from_x: float, reach: float,
		width: float, top_y: float, rides_height: float = 0.0) -> Array[float]:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var s := water.scroll()
	var now := water.time()
	var first := from_x + s
	var last := first + reach
	var y := d.position.y
	var vy := d.velocity.y
	var v := d.speed
	var on := d.on_surface
	var touching := d._touching
	var flights: Array[Vector3] = []  # (dino world x, board y, time) while airborne
	var in_air := false
	while d.home_x + s < last + width:
		s += v * dt
		now += dt
		var w := d.home_x + s
		var surf := water.swell_y(w, now)
		var slope := atan2(water.swell_y(w + 4.0, now) - water.swell_y(w - 4.0, now) + 8.0 * tan(water.tilt), 8.0)
		var depth := y - surf
		var accel := d.gravity
		if depth >= 0.0:
			if not on:
				var along := Vector2.from_angle(slope)
				v = clampf(maxf(Vector2(v, vy).dot(along) * along.x, d.min_speed), d.min_speed, d.max_speed)
				if in_air and flights.back().x >= first:
					break  # landed: only the first flight that reaches the spawn point counts, later ones depend on it
				flights.clear()  # a flight that ends before the spawn point (e.g. the current one) doesn't help
				in_air = false
			var surf_vy := (surf - water.swell_y(w - v * dt, now - dt)) / dt
			accel -= d.gravity + d.buoyancy * depth + d.water_drag * (vy - surf_vy)
			touching = true
			v += d.gravity * sin(slope) * cos(slope) * d.slope_gain * dt
			v -= v * d.water_friction * dt
		elif touching and depth > -d.stick_range:
			accel += d.stickiness
		else:
			touching = false
		v = clampf(v, d.min_speed, d.max_speed)
		vy += accel * dt
		y += vy * dt
		on = depth > -1.0
		if not on:
			in_air = in_air or depth < -2.0
			flights.append(Vector3(w, y, now))
	var spots: Array[float] = []
	if not in_air:
		return spots
	# Body box spans x -14..+12 around the dino; its bottom (the board) must stay above the debris top.
	var x := first
	while x < last:
		var clear := _covered(flights, x - width / 2.0 - 14.0, x + width / 2.0 + 12.0)
		for p in flights:
			if clear and p.x + 12.0 > x - width / 2.0 and p.x - 14.0 < x + width / 2.0:
				# The dino turns the tilt about itself, so debris at world x sits (x - p.x) along the tilt from it.
				var tilted := (x - p.x) * tan(water.tilt)
				clear = p.y <= tilted + (water.swell_y(x, p.z) - rides_height if rides_height > 0.0 else top_y)
		if clear:
			spots.append(x)
		x += 4.0
	return spots


## True if the dino is airborne for the whole stretch from x0 to x1 (not on the water anywhere in it).
static func _covered(flights: Array[Vector3], x0: float, x1: float) -> bool:
	return flights.size() > 0 and flights[0].x <= x0 and flights.back().x >= x1
