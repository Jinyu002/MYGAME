extends Node2D
## Original procedural environment, not a study scene/config copy.
var clock: float = 0.0

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-1000, -1000, 6000, 4000), Color("11171c"))
	for i in range(30):
		var t := i / 30.0
		draw_rect(Rect2(-500, i * 60, 5000, 61), Color("172027").lerp(Color("302c2b"), t))
	# Massive recesses and repeated pillars establish depth without obscuring silhouettes.
	for x in [170, 1040, 1920, 2800, 3670]:
		draw_rect(Rect2(x - 270, 390, 540, 940), Color("090e14"))
		draw_circle(Vector2(x, 390), 270, Color("090e14"))
		draw_arc(Vector2(x, 390), 300, PI, TAU, 48, Color("394044"), 42, true)
		for side in [-1, 1]:
			var px: float = x + side * 300
			draw_rect(Rect2(px - 28, 390, 56, 930), Color("33383a"))
			draw_line(Vector2(px - 25, 400), Vector2(px - 25, 1300), Color("4c4b48"), 5)
			for y in range(430, 1300, 130): draw_line(Vector2(px - 25, y), Vector2(px + 25, y), Color("171d23"), 7)
	for i in range(12):
		var y: float = 1300 + i * i * 4.0
		draw_line(Vector2(-500, y), Vector2(4340, y), Color(0.36, 0.33, 0.29, 0.16), 3)
	for x in range(-1000, 5000, 310):
		draw_line(Vector2(1920 + (x - 1920) * 0.6, 1300), Vector2(x, 2200), Color(0.36, 0.33, 0.29, 0.15), 3)
	for x in [210, 1920, 3630]:
		for radius in range(8, 0, -1):
			draw_circle(Vector2(x, 825), radius * 48.0, Color(0.85, 0.40, 0.12, 0.012))
		draw_rect(Rect2(x - 12, 820, 24, 105), Color("231c19"))
		var flicker: float = 9 * sin(clock * 5 + x)
		draw_colored_polygon(PackedVector2Array([Vector2(x-22, 825), Vector2(x-8, 769), Vector2(x+5, 729+flicker), Vector2(x+26, 801), Vector2(x+13, 827)]), Color("d59a4c"))
		draw_circle(Vector2(x, 806), 12, Color("f4d8a0"))
	for i in range(35):
		var px: float = fmod(i * 307.0 + clock * (4 + i % 5), 3840)
		var py: float = 320 + fmod(i * 97.0 + sin(clock * 0.4 + i) * 22, 1000)
		draw_circle(Vector2(px, py), 2.0 + i % 3, Color(0.75, 0.67, 0.49, 0.18))
