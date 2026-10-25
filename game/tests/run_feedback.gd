extends SceneTree
## Regression for the observed pause/death defects, using the real HUD callbacks.
var app
var failures: Array = []
var checks: int = 0

func _init() -> void: call_deferred("run")

func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures.append(name)
		push_error(name)

func snapshot() -> Array:
	var popup = app.popup_layer.get_child(0)
	return [app.rules.revision, app.director.elapsed, app.camera.position,
		popup.position, popup.modulate, app.views.guard.modulate, app.views.guard.flash]

func run() -> void:
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	for skip_action in [false, true]:
		app.start_battle()
		await process_frame
		if app.director.busy: app.director.skip()
		await process_frame
		var state: Dictionary = app.rules.snapshot()
		var after: Dictionary = state.duplicate(true)
		after.units.guard.hp = 0
		app.present({"actor":"duelist", "skill":"slash", "targets":["guard"], "before":state, "after":after,
			"events":[{"type":"damage","target":"guard","amount":32,"critical":true},{"type":"death","target":"guard"}]})
		await app.director.impact
		await process_frame
		app.show_pause()
		var first := snapshot()
		await create_timer(0.25).timeout
		check(first == snapshot(), "all impact feedback frozen for 250ms")
		check(app.sound.stream_paused, "audio paused")
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.pressed = true
		app._unhandled_key_input(key)
		check(not app.paused and not app.sound.stream_paused, "Escape resumes feedback")
		app.running = false # Synthetic after state must not be replaced by domain fixture.
		if skip_action: app.director.skip()
		var disappeared := false
		var resurrected := false
		while app.director.busy:
			await process_frame
			var view = app.views.guard
			if not view.visible or view.modulate.a < 0.01: disappeared = true
			if disappeared and view.visible and view.modulate.a > 0.99: resurrected = true
		check(not resurrected and not app.views.guard.visible, "death remains hidden after recovery/skip")
		check(app.feedback_tweens.is_empty() and app.popup_layer.get_child_count() == 0, "completion releases feedback")
	app.start_battle()
	await process_frame
	if app.director.busy: app.director.skip()
	await process_frame
	check(app.views.guard.visible and not app.views.guard.presentation_paused, "restart creates visible unpaused actors")
	var state: Dictionary = app.rules.snapshot()
	app.present({"actor":"ranger", "skill":"shot", "targets":["guard"], "before":state, "after":state,
		"events":[{"type":"damage","target":"guard","amount":8,"critical":true}]})
	check(app.director.profile.gap == app.director.config.profiles.ranged.gap, "ranged critical preserves range")
	app.show_pause()
	var pos: Vector2 = app.views.ranger.position
	await create_timer(0.25).timeout
	check(app.views.ranger.position == pos and not app.director.impacted, "pre-impact pause freezes approach")
	app.resume_battle()
	await app.director.impact
	app.toggle_speed()
	check(app.views.ranger.presentation_speed == 2.0, "actor clock follows speed")
	app.show_pause()
	app.start_battle()
	check(not app.paused and app.director.is_processing() and app.feedback_tweens.is_empty(), "restart from paused impact releases old clocks")
	app.running = false
	app.director.cleanup()
	print("FEEDBACK_REPORT ", JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
