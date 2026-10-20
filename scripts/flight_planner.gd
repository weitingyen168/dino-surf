class_name FlightPlanner
## Answers "where can debris go so the player can still fly over it?" for ObstacleSpawner.
## Plays the dino forward on the swell alone (the spring ripples are small) with a full forward tilt from
## right now: same physics as Dino._float, same tilt spring as Controls. The swells travel, so it steps time
## too; debris stays put in world space but bobs with the swell under it.


## World positions (screen x + scroll) from screen x `from_x` to `from_x + reach` where debris `width` wide,
## standing `height` px above the water, would be cleared by the first flight a full forward tilt produces.
static func clearable_spots(d: Dino, water: Water, controls: Controls, from_x: float, reach: float,
		width: float, height: float) -> Array[float]:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var target := deg_to_rad(controls.max_tilt_deg)
	var s := water.scroll()
	var now := water.time()
	var first := from_x + s
	var last := first + reach
	var y := d.position.y
	var vy := d.velocity.y
	var v := d.speed
	var t := controls.tilt
	var tv := controls.tilt_vel
	var on := d.on_surface
	var touching := d._touching
	var flights: Array[Vector3] = []  # (dino world x, board y, time) while airborne
	var in_air := false
	while d.home_x + s < last + width:
		var spring := Controls.spring_step(t, tv, target, controls.tilt_response, dt)
		t = spring.x
		tv = spring.y
		s += v * dt
		now += dt
		var w := d.home_x + s
		var surf := water.swell_y(w, now)
		var slope := atan2(water.swell_y(w + 4.0, now) - water.swell_y(w - 4.0, now), 8.0)
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
			var downhill := slope + t
			v += d.gravity * sin(downhill) * cos(downhill) * d.slope_gain * dt
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
				clear = p.y <= water.swell_y(x, p.z) - height
		if clear:
			spots.append(x)
		x += 4.0
	return spots


## True if the dino is airborne for the whole stretch from x0 to x1 (not on the water anywhere in it).
static func _covered(flights: Array[Vector3], x0: float, x1: float) -> bool:
	return flights.size() > 0 and flights[0].x <= x0 and flights.back().x >= x1
