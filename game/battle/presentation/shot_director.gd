extends Node
## Atomic action tableau; rule resolution is independent of this timeline.
signal impact(record: Dictionary)
signal finished
signal focus_changed(amount: float)
const Effect = preload("res://battle/presentation/impact_effect.gd")
var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/presentation.json"))
var skills: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/battle.json")).skills
var views: Dictionary = {}
var homes: Dictionary = {}
var camera: Camera2D
var tween: Tween
var record: Dictionary = {}
var elapsed: float = 0.0
var impact_age: float = 0.0
var busy: bool = false
var impacted: bool = false
var shake_enabled: bool = true
var speed: float = 1.0
var profile_name: String = "melee"
var profile: Dictionary = {}
var curtain: ColorRect
var effects: Array = []
var direction: float = 1.0
var has_damage: bool = false

func _focus(amount: float) -> void:
	if is_instance_valid(curtain):
		curtain.visible = amount > 0.001
		curtain.material.set_shader_parameter("blend", amount)
	focus_changed.emit(amount)

func play(action: Dictionary, actor_views: Dictionary, rig: Camera2D) -> void:
	cleanup()
	record = action
	views = actor_views
	camera = rig
	busy = true
	impacted = false
	elapsed = 0.0
	impact_age = 0.0
	homes.clear()
	for id in views: homes[id] = views[id].position
	var actor: String = record.get("actor", "")
	var skill: String = record.get("skill", "")
	has_damage = record.events.any(func(e): return e.type == "damage")
	tween = create_tween().set_speed_scale(speed)
	profile = {}
	if not views.has(actor) or skill.is_empty():
		tween.tween_callback(_impact)
		tween.tween_interval(0.42)
		tween.tween_callback(_complete)
		return
	var definition: Dictionary = skills.get(skill, {})
	profile_name = "support" if definition.get("friendly", false) else ("ranged" if definition.get("ranged", false) else "melee")
	if record.events.any(func(e): return e.get("critical", false)): profile_name = "critical"
	if definition.get("kind", "") == "move": profile_name = "move"
	profile = config.profiles[profile_name]
	if profile_name == "move":
		tween.set_parallel(true)
		for id in views:
			var unit: Dictionary = record.after.units[id]
			var team: Array = record.after.teams[unit.side]
			var rank: int = team.find(id)
			if rank < 0: continue
			homes[id] = Vector2(1550 - rank * 370 if unit.side == 0 else 2290 + rank * 370, 1390)
			tween.tween_property(views[id], "position", homes[id], 0.42).set_trans(Tween.TRANS_SINE)
		tween.chain().set_parallel(false).tween_callback(_impact)
		tween.tween_interval(0.15)
		tween.tween_callback(_complete)
		return
	if not is_instance_valid(curtain):
		curtain = ColorRect.new()
		curtain.position = Vector2(-2000, -1500)
		curtain.size = Vector2(8000, 6000)
		curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		curtain.z_index = 5
		curtain.material = ShaderMaterial.new()
		curtain.material.shader = preload("res://battle/presentation/focus.gdshader")
		camera.get_parent().add_child(curtain)
	curtain.material.set_shader_parameter("blur_amount", profile.blur)
	curtain.material.set_shader_parameter("saturation", profile.saturation)
	var targets: Array = record.get("targets", []).duplicate()
	targets.erase(actor)
	direction = 1.0 if record.before.units[actor].side == 0 else -1.0
	for id in views:
		views[id].cinematic = true
		views[id].modulate.a = 1.0 if id == actor or id in targets else 0.0
		views[id].z_index = 20 if id == actor else (19 if id in targets else 0)
	views[actor].pose = config.poses.get(skill, "attack")
	var gap: float = profile.gap
	var actor_goal := Vector2(1920 - direction * gap * 0.5, 1280)
	if targets.is_empty(): actor_goal.x = 1920
	views[actor].position = actor_goal - Vector2(direction * 30, 0)
	for i in range(targets.size()):
		views[targets[i]].position = Vector2(1920 + direction * (gap * 0.5 + i * 360), 1280)
	var zoom: float = float(profile.zoom) - maxf(0, targets.size() - 1) * 0.15
	var center := Vector2(1920 + direction * maxf(0, targets.size() - 1) * 180, 965)
	tween.set_parallel(true)
	tween.tween_property(views[actor], "position", actor_goal, profile.enter)
	tween.tween_property(camera, "position", center, profile.enter)
	tween.tween_property(camera, "zoom", Vector2.ONE * zoom, profile.enter)
	tween.tween_method(_focus, 0.0, 1.0, profile.enter)
	tween.chain().set_parallel(false).tween_callback(_impact)
	tween.tween_interval(0.055 if profile_name == "critical" else 0.035)
	tween.set_parallel(true)
	var drift: float = profile.drift * direction
	if definition.get("ranged", false): drift *= -0.5
	tween.tween_property(views[actor], "position:x", actor_goal.x + drift, profile.hold).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for id in targets:
		tween.tween_property(views[id], "position:x", views[id].position.x + direction * profile.drift * 0.5, profile.hold)
	tween.tween_property(camera, "rotation", direction * (0.012 if profile_name == "critical" else 0.004), profile.hold)
	tween.chain().set_parallel(false).tween_callback(_restore_pose)
	tween.set_parallel(true)
	for id in views: tween.tween_property(views[id], "position", homes[id], profile["return"]).set_trans(Tween.TRANS_SINE)
	tween.tween_property(camera, "position", Vector2(1920,1080), profile["return"])
	tween.tween_property(camera, "zoom", Vector2.ONE, profile["return"])
	tween.tween_property(camera, "rotation", 0.0, profile["return"])
	tween.tween_method(_focus, 1.0, 0.0, profile["return"])
	tween.chain().set_parallel(false).tween_callback(_complete)

func _impact() -> void:
	if impacted: return
	impacted = true
	impact_age = 0.0
	for event in record.events:
		if not views.has(event.get("target", "")): continue
		if event.type not in ["damage", "heal", "miss"]: continue
		var view = views[event.target]
		var effect = Effect.new()
		effect.kind = event.type
		effect.critical = event.get("critical", false)
		effect.direction = direction
		effect.position = Vector2(0, -view.body_height * 0.57)
		view.add_child(effect)
		effects.append(effect)
		if event.type == "damage": view.flash = 0.65
	impact.emit(record)

func _process(delta: float) -> void:
	if not busy: return
	elapsed += delta
	if impacted:
		impact_age += delta * speed
		for effect in effects:
			if is_instance_valid(effect):
				effect.age = impact_age
				effect.queue_redraw()
		if is_instance_valid(camera):
			var amplitude: float = float(profile.get("shake", 0)) * exp(-impact_age * 10.0)
			camera.offset = Vector2(sin(impact_age * 91), cos(impact_age * 113)) * amplitude if shake_enabled and has_damage else Vector2.ZERO
	if elapsed > 5.0:
		push_warning("Presentation watchdog recovered action")
		skip()

func _restore_pose() -> void:
	for view in views.values():
		if is_instance_valid(view):
			view.pose = "idle"
			view.z_index = 0
			view.cinematic = false
			view.modulate = Color.WHITE

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
	for effect in effects:
		if is_instance_valid(effect): effect.queue_free()
	effects.clear()
	_restore_pose()
	for id in homes:
		if views.has(id) and is_instance_valid(views[id]): views[id].position = homes[id]
	_focus(0.0)
	if is_instance_valid(camera):
		camera.position = Vector2(1920,1080)
		camera.zoom = Vector2.ONE
		camera.rotation = 0.0
		camera.offset = Vector2.ZERO
