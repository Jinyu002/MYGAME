extends SceneTree
## Independent diagnostic fixture. Run only in a disposable game copy.
var app
var results: Array = []

func _init() -> void: call_deferred("run")

func run() -> void:
	for unified in [false, true]:
		app = load("res://app/main.tscn").instantiate()
		root.add_child(app)
		await process_frame
		app.start_battle()
		await process_frame
		if app.director.busy: app.director.skip()
		await process_frame
		var before: Dictionary = app.rules.snapshot()
		var after: Dictionary = before.duplicate(true)
		after.units.guard.hp = 0
		app.present({"actor":"duelist", "skill":"slash", "targets":["guard"], "before":before, "after":after,
			"events":[{"type":"damage","target":"guard","amount":32,"critical":true},{"type":"death","target":"guard"}]})
		await app.director.impact
		await process_frame
		app.show_pause()
		# Prototype: pause the scene clock, while allowing the modal to receive input.
		if unified:
			app.modal.process_mode = Node.PROCESS_MODE_ALWAYS
			paused = true
		var first := snapshot()
		await create_timer(0.25, true).timeout
		var second := snapshot()
		results.append({"prototype":unified,"before":first,"after":second,"all_frozen":first == second})
		paused = false
		app.resume_battle()
		app.running = false
		var reached_invisible := false
		var restored_before_finish := false
		while app.director.busy:
			await process_frame
			if app.views.guard.modulate.a < 0.01: reached_invisible = true
			if reached_invisible and app.views.guard.modulate.a > 0.99 and app.director.busy:
				restored_before_finish = true
		results[-1]["dead_restored_before_finish"] = restored_before_finish
		await process_frame
		app.queue_free()
		await process_frame
	print("PAUSE_PROBE ", JSON.stringify(results))
	# Both paths now freeze after the production feedback-clock fix.
	quit(0 if results.all(func(r): return r.all_frozen and not r.dead_restored_before_finish) else 1)

func snapshot() -> Dictionary:
	var popup = app.popup_layer.get_child(0)
	return {"revision":app.rules.revision,"director_time":app.director.elapsed,
		"popup_y":popup.position.y,"popup_alpha":popup.modulate.a,
		"death_alpha":app.views.guard.modulate.a,"flash":app.views.guard.flash}
