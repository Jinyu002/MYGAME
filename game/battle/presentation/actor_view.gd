extends Node2D

var catalog: RefCounted
var visual_id: String
var pose: String = "idle"
var body_height: float = 800.0
var active: bool = false
var targetable: bool = false
var chosen: bool = false
var alive: bool = true
var breathing: float = 0.0
var flash: float = 0.0
var idle_clock: float = 0.0
var cinematic: bool = false
var presentation_paused: bool = false
var presentation_speed: float = 1.0
var facing: String = "right"

func setup(art: RefCounted, visual: String, side: int = 0) -> void:
	catalog = art
	visual_id = visual
	facing = "right" if side == 0 else "left"
	idle_clock = float(visual.hash() % 100) / 10.0

func _process(delta: float) -> void:
	if presentation_paused: return
	delta *= presentation_speed
	idle_clock += delta
	breathing = sin(idle_clock * 1.7) * 3.0 if pose == "idle" and alive and not cinematic else 0.0
	flash = maxf(0, flash - delta * 5)
	queue_redraw()

func _draw() -> void:
	if catalog == null: return
	draw_set_transform(Vector2(0, 12), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 180, Color(0, 0, 0, 0.4))
	if (active or targetable or chosen) and not cinematic:
		var ring := Color("c8a66a") if active else Color("bc594e")
		if chosen: ring = Color("f7dfaa")
		draw_arc(Vector2.ZERO, 175, 0, TAU, 64, ring, 9 if chosen else 5, true)
	draw_set_transform(Vector2.ZERO)
	var tex: Texture2D = catalog.texture(visual_id, pose)
	var idle: Texture2D = catalog.texture(visual_id)
	if tex == null or idle == null:
		draw_circle(Vector2(0, -300), 90, Color("ad9473"))
		return
	var factor: float = body_height / idle.get_height()
	var dims: Vector2 = tex.get_size() * factor
	var rect := Rect2(Vector2(-dims.x / 2, -dims.y + breathing), dims)
	# Flip only the artwork around the foot origin, never UI, FX or the actor node.
	var mirror: bool = catalog.source_facing(visual_id) != facing
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if mirror else 1.0, 1.0))
	draw_texture_rect(tex, rect, false, Color(1 + flash * 1.5, 1 + flash, 1 + flash, 1))
	draw_set_transform(Vector2.ZERO)
	if active and not cinematic:
		draw_colored_polygon(PackedVector2Array([Vector2(-18, -body_height - 70), Vector2(18, -body_height - 70), Vector2(0, -body_height - 42)]), Color("d7bb80"))
