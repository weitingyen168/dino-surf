class_name Tsunami
extends Node
## The water well behind the dino is always pushed up into a big hump, so the dino rides its front slope and keeps
## getting shoved forward.

@export var water: Water
@export var dino: Dino
@export var offset: float = -120.0  # centre of the hump, relative to the dino
@export var radius: float = 120.0  # half-width; its front foot reaches the dino when radius = -offset
@export var strength: float = 3000.0  # how hard it's pushed up; 0 turns it off


func _physics_process(delta: float) -> void:
	if strength > 0.0:
		water.push(dino.position.x + offset, radius, strength, delta)
