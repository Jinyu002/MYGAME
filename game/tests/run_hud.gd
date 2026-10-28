extends SceneTree
var app
var checks: int = 0
var failures: Array = []

func _init() -> void: call_deferred("run")

func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures.append(name)
		push_error(name)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://../artifacts/hud_%dx%d_%s.png" % [img.get_width(), img.get_height(), name])

func run() -> void:
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.start_battle()
	await process_frame
	if app.director.busy: app.director.skip()
	await process_frame
	check(app.ui.queue.get_child_count() == 8, "queue displays all living current and waiting actors")
	check(app.skill_buttons.size() == 4, "four skills visible")
	check(app.skill_buttons[-1].get_global_rect().end.x < 1950, "skill row does not overlap utilities")
	await capture("ready")
	var before: Dictionary = app.rules.snapshot()
	app.choose_target("guard")
	check(app.ui.target_title.text == app.rules.units.guard.name and app.selected_target.is_empty(), "inspect without committing target")
	app.skill_buttons[3].mouse_entered.emit()
	check(app.preview_title.text == "决意突刺" and app.hero_detail.text.contains("必定暴击"), "hover explains real skill")
	check(app.rules.snapshot() == before and app.confirm.disabled, "hover and inspection are read-only")
	await capture("hover")
	app.skill_buttons[3].mouse_exited.emit()
	app.select_skill("resolve")
	app.choose_target("guard")
	check(not app.confirm.disabled and app.preview_text.text.contains("暴击 100%"), "selected target exposes guaranteed critical forecast")
	await capture("selected")
	app.show_pause()
	app.submit_selected()
	check(app.rules.snapshot() == before, "pause prevents confirm")
	app.resume_battle()
	app.select_skill("resolve")
	app.choose_target("guard")
	app.submit_selected()
	check(app.rules.revision == before.revision + 1, "confirm still commits exactly once")
	await app.director.impact
	app.running = false
	app.director.skip()
	app.start_battle()
	check(app.ui.inspected.is_empty() and app.ui.hover_skill.is_empty(), "restart clears inspection state")
	app.running = false
	app.director.cleanup()
	print("HUD_REPORT ", JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
