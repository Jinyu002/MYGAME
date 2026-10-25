extends SceneTree
var failures: Array = []
var checks: int = 0
var app

func _init() -> void:
	call_deferred("run")

func check(condition: bool, name: String) -> void:
	checks += 1
	if not condition:
		failures.append(name)
		push_error(name)

func run() -> void:
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.modal.visible and not app.running, "title is initial screen")
	app.start_battle()
	await process_frame
	if app.director.busy: app.director.skip()
	await process_frame
	check(app.running and not app.locked and app.rules.current == "duelist", "initial hero turn reaches command UI")
	var revision: int = app.rules.revision
	app.skill_buttons[0].pressed.emit()
	check(app.selected_skill == "slash" and app.confirm.disabled, "skill button needs target confirmation")
	app.hit_buttons.guard.pressed.emit()
	check(app.selected_target == "guard" and not app.confirm.disabled, "actor hit region selects legal target")
	check(app.preview_text.text.contains("命中"), "preview displays actual chance")
	app.confirm.pressed.emit()
	check(app.rules.revision == revision + 1 and app.director.busy and app.locked, "confirm commits once and enters presentation barrier")
	app.submit_selected()
	check(app.rules.revision == revision + 1, "repeat confirm during presentation ignored")
	app.show_pause()
	check(app.paused and not app.director.is_processing(), "pause stops presentation watchdog")
	var paused_revision: int = app.rules.revision
	await create_timer(0.1).timeout
	check(app.rules.revision == paused_revision, "pause does not change rule state")
	app.resume_battle()
	app.director.skip()
	await process_frame
	check(not app.director.busy, "skip cleans up presentation")
	check(app.camera.zoom == Vector2.ONE and app.camera.offset == Vector2.ZERO, "camera restored")
	var old_generation: int = app.generation
	app.start_battle()
	await process_frame
	if app.director.busy: app.director.skip()
	check(app.generation == old_generation + 1, "restart changes battle generation")
	await create_timer(0.7).timeout
	check(app.rules.units.guard.hp == app.rules.units.guard.max_hp, "old AI timer cannot damage restarted battle")
	var domain_before: Dictionary = app.rules.snapshot()
	app.art.variant = true
	app.refresh()
	check(app.rules.snapshot() == domain_before, "visual replacement does not alter battle state")
	check(app.views.warden.catalog.texture("warden").resource_path.ends_with("warden_variant.png"), "view resolves replacement asset")
	app.show_pause()
	app.confirm_retreat()
	check(app.paused and app.modal.visible and app.rules.outcome.is_empty(), "retreat requires explicit confirmation")
	app.rules.retreat()
	app.paused = false
	app.show_result()
	check(app.last_result.outcome == "retreat" and not app.running, "result output and screen available")
	# Exercise recovery when a timeline cannot reach its normal completion.
	app.start_battle()
	await process_frame
	if app.director.busy: app.director.skip()
	app.select_skill("slash")
	app.choose_target("guard")
	app.submit_selected()
	app.director.tween.kill()
	app.director.elapsed = 5.1
	app.director._process(0.01)
	check(not app.director.busy and app.camera.zoom == Vector2.ONE, "watchdog recovers a killed timeline")
	print("INTEGRATION_REPORT ", JSON.stringify({"checks":checks, "failures":failures}))
	app.running = false
	app.director.cleanup()
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
