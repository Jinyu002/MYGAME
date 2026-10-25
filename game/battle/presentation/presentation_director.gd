extends Node
signal impact(record: Dictionary)
signal finished

var views: Dictionary
var camera: Camera2D
var tween: Tween
var record: Dictionary = {}
var elapsed: float = 0.0
var busy: bool = false
var impacted: bool = false
var shake_enabled: bool = true
var speed: float = 1.0
var homes: Dictionary = {}

func play(action: Dictionary, actor_views: Dictionary, rig: Camera2D) -> void:
	cleanup()
	record = action
	views = actor_views
	camera = rig
	busy = true
	impacted = false
	elapsed = 0
	homes.clear()
	for id in views: homes[id] = views[id].position
	var id: String = record.get("actor", "")
	var skill: String = record.get("skill", "")
	tween = create_tween().set_speed_scale(speed)
	if views.has(id) and not skill.is_empty():
		var v: Node2D = views[id]
		var direction: float = 1 if record.before.units[id].side == 0 else -1
		var affected: Array = record.get("targets", [])
		for vid in views:
			views[vid].modulate = Color.WHITE if vid == id or vid in affected else Color(0.42, 0.45, 0.50, 0.25)
		v.z_index = 10
		tween.set_parallel(true)
		tween.tween_property(v, "position:x", v.position.x - direction * 35, 0.16).set_trans(Tween.TRANS_SINE)
		tween.tween_property(camera, "zoom", Vector2(1.08, 1.08), 0.23)
		tween.tween_property(camera, "position", Vector2(1920, 1000), 0.23)
		if affected.size() == 1 and affected[0] != id and record.before.units[affected[0]].side != record.before.units[id].side:
			var target_view: Node2D = views[affected[0]]
			target_view.z_index = 9
			tween.tween_property(target_view, "position:x", 2320.0 if direction > 0 else 1520.0, 0.23).set_trans(Tween.TRANS_SINE)
		tween.chain().set_parallel(false).tween_callback(func():
			if is_instance_valid(v): v.pose = "attack")
		var goal: float = homes[id].x + direction * 130
		if not affected.is_empty() and record.before.units[affected[0]].side != record.before.units[id].side:
			goal = 1720 if direction > 0 else 2120
		tween.tween_property(v, "position:x", goal, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		tween.tween_interval(0.12)
	tween.tween_callback(_impact)
	tween.tween_interval(0.42)
	tween.tween_callback(_restore_pose)
	tween.chain().set_parallel(true)
	for vid in views:
		tween.tween_property(views[vid], "position", homes[vid], 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "zoom", Vector2.ONE, 0.28)
	tween.tween_property(camera, "position", Vector2(1920, 1080), 0.28)
	tween.chain().set_parallel(false).tween_callback(_complete)

func _impact() -> void:
	if impacted: return
	impacted = true
	for event in record.events:
		if event.type == "damage" and views.has(event.target):
			var v = views[event.target]
			v.flash = 1.0
			v.position.x += 28 if record.before.units[event.target].side == 1 else -28
	impact.emit(record)

func _process(delta: float) -> void:
	if not busy: return
	elapsed += delta
	if shake_enabled and impacted and is_instance_valid(camera):
		var power: float = maxf(0, 1.0 - (elapsed * speed - 0.35) * 5.0)
		var has_damage: bool = record.events.any(func(e): return e.type == "damage")
		camera.offset = Vector2(sin(elapsed * 91), cos(elapsed * 113)) * power * 9 if has_damage else Vector2.ZERO
	if elapsed > 5.0:
		push_warning("Presentation watchdog recovered action")
		skip()

func _restore_pose() -> void:
	for v in views.values():
		if is_instance_valid(v):
			v.pose = "idle"
			v.z_index = 0
			v.modulate = Color.WHITE

func skip() -> void:
	if not busy: return
	_impact()
	_complete()

func _complete() -> void:
	cleanup()
	finished.emit()

func cleanup() -> void:
	if tween and tween.is_valid(): tween.kill()
	busy = false
	_restore_pose()
	for id in homes:
		if views.has(id) and is_instance_valid(views[id]): views[id].position = homes[id]
	if is_instance_valid(camera):
		camera.position = Vector2(1920, 1080)
		camera.zoom = Vector2.ONE
		camera.offset = Vector2.ZERO
