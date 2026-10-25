extends SceneTree
## Synthetic resolved records exercise the renderer without altering combat rules.
var checks: int = 0
var failures: Array = []
var app
var impacts: int = 0
var completions: int = 0

func _init() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func run() -> void:
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.start_battle()
	if app.director.busy: app.director.skip()
	app.running = false
	app.director.impact.connect(func(_r): impacts += 1)
	app.director.finished.connect(func(): completions += 1)
	var cases := [
		["duelist", "resolve", ["guard"], "damage", true, "critical"],
		["duelist", "slash", ["guard"], "damage", false, "melee"],
		["warden", "cut", ["raider"], "damage", false, "melee"],
		["duelist", "lunge", ["guard"], "damage", false, "melee"],
		["duelist", "feint", ["raider"], "damage", false, "melee"],
		["bolter_a", "shove", ["warden"], "damage", false, "melee"],
		["ranger", "volley", ["bolter_a", "bolter_b"], "damage", false, "ranged"],
		["warden", "bash", ["guard"], "damage", true, "critical"],
		["mender", "mend", ["duelist"], "heal", false, "support"],
		["ranger", "shot", ["raider"], "miss", false, "ranged"],
		["guard", "strike", ["warden"], "damage", false, "melee"],
		["raider", "rake", ["duelist"], "damage", false, "melee"],
		["bolter_a", "bolt", ["ranger"], "damage", false, "ranged"],
		["duelist", "forward", ["duelist"], "move", false, "move"]
	]
	var index := 0
	for item in cases:
		var state: Dictionary = app.rules.snapshot()
		var events: Array = []
		for target in item[2]: events.append({"target":target, "type":item[3], "amount":8, "critical":item[4]})
		var record := {"actor":item[0], "skill":item[1], "targets":item[2], "events":events, "before":state, "after":state.duplicate(true)}
		app.director.play(record, app.views, app.camera)
		app.hint.text = app.rules.definitions.skills[item[1]].name
		check(app.director.profile_name == item[5], "profile " + item[1])
		await create_timer(0.24).timeout
		if item[5] != "move":
			check(app.director.curtain.visible and app.camera.zoom.x > 1.0, "focus " + item[1])
			check(app.views[item[0]].pose == app.director.config.poses[item[1]], "pose " + item[1])
			check(app.art.texture(app.views[item[0]].visual_id, app.views[item[0]].pose) != null, "asset " + item[1])
			app.director.tween.pause()
			app.director.set_process(false)
			var age: float = app.director.impact_age
			await create_timer(0.06).timeout
			check(app.director.impact_age == age, "effect pause " + item[1])
			app.director.set_process(true)
			app.director.tween.play()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("res://../artifacts/profile_%s.png" % item[1])
		await create_timer(1.8).timeout
		index += 1
		check(not app.director.busy and impacts == index and completions == index, "single completion " + item[1])
		check(not app.director.curtain.visible and app.director.effects.is_empty(), "effect cleanup " + item[1])
		check(app.camera.zoom == Vector2.ONE and app.camera.rotation == 0.0, "camera cleanup " + item[1])
	var render_size: String = "headless; no visual validation"
	if DisplayServer.get_name() != "headless": render_size = str(root.get_texture().get_image().get_size())
	print("PRESENTATION_REPORT ", JSON.stringify({"checks":checks,"failures":failures,"render_size":render_size}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
