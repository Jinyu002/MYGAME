extends Node2D
## The director owns this effect clock, including pause, skip and cleanup.
var age: float = 0.0
var kind: String = "damage"
var critical: bool = false
var direction: float = 1.0

func _draw() -> void:
	var alpha: float = clampf(1.0 - age / 0.5, 0, 1)
	if kind in ["heal", "guard"]:
		var c := Color(0.70, 0.84, 0.58, alpha)
		for i in range(3): draw_arc(Vector2.ZERO, 65 + age * 160 + i * 24, 0, TAU, 48, c, 4, true)
		for i in range(7):
			var x := (i - 3) * 36.0
			var y := -age * 210 - float(i % 3) * 35
			draw_line(Vector2(x-8,y), Vector2(x+8,y), c, 4, true)
			draw_line(Vector2(x,y-8), Vector2(x,y+8), c, 4, true)
	elif kind == "miss":
		for i in range(3): draw_line(Vector2(-80, i * 25 - 25), Vector2(70, i * 25 - 55), Color(0.8,0.85,0.9,alpha * 0.5), 4, true)
	else:
		var radius: float = (150 if critical else 100) * (1.0 + age * 2.2)
		for i in range(11):
			var angle: float = float(i) * 2.399
			var end := Vector2(cos(angle), sin(angle)) * radius * (0.6 + (i % 3) * 0.2)
			var color := Color(0.7, 0.12, 0.09, alpha)
			if i % 3 == 0: color = Color(1,0.77,0.40,alpha)
			draw_line(end * 0.35, end, color, 7 if critical else 5, true)
		if age < 0.12: draw_line(Vector2(-95 * direction, 70), Vector2(105 * direction, -95), Color(1,0.89,0.68,alpha), 16 if critical else 9, true)
