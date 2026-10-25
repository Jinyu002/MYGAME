extends SceneTree
const Rules = preload("res://battle/domain/battle_rules.gd")
const Catalog = preload("res://battle/presentation/art_catalog.gd")
var failures: Array = []
var checks: int = 0
var outcomes: Dictionary = {}
var total_rounds: int = 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func fresh(seed_value: int = 42):
	var r = Rules.new()
	r.start(seed_value)
	return r

func force_turn(r, id: String) -> void:
	r.current = id
	r.revision += 1

func run() -> void:
	for test_seed in range(100):
		var critical_rules = fresh(test_seed)
		force_turn(critical_rules, "duelist")
		critical_rules.units.guard.dodge = 100
		var predicted: Dictionary = critical_rules.preview("resolve", "guard")
		var hit: Dictionary = critical_rules.apply(critical_rules.command("resolve", "guard"))
		var damage_events: Array = hit.events.filter(func(e): return e.type == "damage")
		check(damage_events.size() == 1 and damage_events[0].critical, "guaranteed critical despite dodge seed %d" % test_seed)
		check(damage_events[0].amount >= predicted.min and damage_events[0].amount <= predicted.max and predicted.hit == 10000, "critical preview matches damage seed %d" % test_seed)
		critical_rules.units.duelist.used.resolve = 2
		check(critical_rules.targets("duelist", "resolve").is_empty(), "critical skill respects use limit")
	var r = fresh()
	check(r.validate_data().is_empty(), "default data validates")
	var bad: Dictionary = r.definitions.duplicate(true)
	bad.actors.append(bad.actors[0].duplicate())
	bad.skills.cut.accuracy = 10001
	check(Rules.new(bad).validate_data().size() >= 2, "duplicate and invalid probability rejected")
	check(r.teams[0].size() == 4 and r.teams[1].size() == 4, "4v4 initialization")
	force_turn(r, "warden")
	var before: Dictionary = r.snapshot()
	var rng_before: int = r.rng.state
	check(r.apply(r.command("cut", "bolter_b")).has("error"), "out of rank target rejected")
	check(r.snapshot() == before and r.rng.state == rng_before, "invalid command is mutation free")
	var stale: Dictionary = r.command("cut", "guard")
	stale.revision -= 1
	check(r.apply(stale).get("error") == "stale_command", "stale revision rejected")
	var wrong: Dictionary = r.command("cut", "guard")
	wrong.battle_id = "old"
	check(r.apply(wrong).get("error") == "wrong_battle", "wrong battle rejected")
	for i in range(20): r.preview("cut", "guard")
	check(r.rng.state == rng_before, "previews do not consume RNG")
	var cmd: Dictionary = r.command("cut", "guard")
	r.apply(cmd)
	var after: Dictionary = r.snapshot()
	check(r.apply(cmd).get("error") == "duplicate", "duplicate command rejected")
	check(r.snapshot() == after, "duplicate does not damage twice")
	check(r.damage_value(10, false, "guard") == 8, "armor and floor")
	check(r.damage_value(10, true, "guard") == 12, "critical then armor then floor")
	r.units.guard.status.guard = "guard"
	check(r.damage_value(10, false, "guard") == 5, "guard multiplicative reduction")
	r.units.guard.status.expose = 2
	check(r.damage_value(10, false, "guard") == 6, "expose clamps armor at zero")
	r = fresh()
	force_turn(r, "mender")
	r.units.warden.hp = 39
	r.apply(r.command("mend", "warden"))
	check(r.units.warden.hp == 40, "healing capped at max")
	check(r.units.mender.used.mend == 1, "limited skill tracks use")
	r.units.mender.used.mend = 3
	check(r.targets("mender", "mend").is_empty(), "spent skill unavailable")
	r.units.warden.hp = 0
	check(not "warden" in r.targets("mender", "cleanse"), "no healing dead target")
	r = fresh()
	force_turn(r, "duelist")
	r.apply(r.command("lunge", "guard"))
	check(r.rank_of("duelist") == 1 and r.rank_of("warden") == 2, "lunge swaps ranks")
	check(r.targets("duelist", "forward").is_empty(), "front boundary enforced")
	check(r.targets("mender", "back").is_empty(), "rear boundary enforced")
	r = fresh()
	r.units.duelist.status.bleed = 2
	r.units.duelist.hp = 3
	r.queue = ["duelist", "warden"]
	r.round_number = 1
	var dot: Dictionary = r.advance()
	check(r.units.duelist.hp == 0 and r.current.is_empty(), "lethal DOT skips action")
	check(r.rank_of("ranger") == 2, "death compresses ranks")
	check(dot.events.any(func(e): return e.type == "death"), "DOT death event exists")
	r = fresh()
	r.units.warden.status.stun = 1
	r.queue = ["warden", "warden"]
	r.round_number = 1
	r.advance()
	check(r.current.is_empty() and r.units.warden.status.get("immune") == 1, "stun skips and grants immunity")
	r.advance()
	check(r.current == "warden" and r.units.warden.status.has("immune"), "immune survives next turn start")
	r.apply(r.command("defend", "warden"))
	check(not r.units.warden.status.has("immune"), "immune expires after next completed action")
	r = fresh()
	force_turn(r, "warden")
	r.apply(r.command("cover", "mender"))
	check(r.units.mender.status.get("guard") == "warden", "guard stores source")
	r.queue = ["warden"]
	r.advance()
	check(not r.units.mender.status.has("guard"), "guard expires on source turn")
	r = fresh()
	force_turn(r, "ranger")
	r.definitions.skills.volley.accuracy = 10000
	r.units.bolter_a.dodge = 0
	r.units.bolter_b.dodge = 0
	r.units.bolter_a.hp = 1
	r.units.bolter_b.hp = 1
	var group: Dictionary = r.apply(r.command("volley", "bolter_a"))
	check(r.units.bolter_a.hp == 0 and r.units.bolter_b.hp == 0, "AOE locks target IDs through deaths")
	check(group.targets == ["bolter_a", "bolter_b"], "AOE ordered targets")
	r = fresh()
	for id in r.teams[1]: r.units[id].hp = 0
	r.advance()
	check(r.outcome == "victory", "victory detected")
	r = fresh()
	for id in r.teams[0]: r.units[id].hp = 0
	r.advance()
	check(r.outcome == "defeat", "defeat detected")
	r = fresh()
	for u in r.units.values(): u.hp = 0
	r.advance()
	check(r.outcome == "draw", "simultaneous wipe draw")
	r = fresh()
	r.round_number = 50
	r.advance()
	check(r.outcome == "draw", "round cap draw")
	r = fresh()
	r.retreat()
	check(r.result().outcome == "retreat", "retreat result")
	var original: Dictionary = r.result()
	r.retreat()
	check(r.result() == original, "terminal retreat stable")
	var first: Dictionary = simulate(777)
	var second: Dictionary = simulate(777)
	check(first == second, "identical seed and AI commands reproduce exact result")
	for seed_value in range(100):
		var result: Dictionary = simulate(seed_value)
		check(not result.outcome.is_empty(), "seed %d completes" % seed_value)
		outcomes[result.outcome] = outcomes.get(result.outcome, 0) + 1
		total_rounds += result.rounds
	# Resource replacement and fallback do not touch domain data.
	var art = Catalog.new()
	var base_texture: Texture2D = art.texture("warden")
	art.variant = true
	var replacement: Texture2D = art.texture("warden")
	check(base_texture != null and replacement != null and base_texture != replacement, "visual A/B resources load independently")
	check(art.texture("warden", "missing_test_pose") == replacement, "missing pose uses current idle fallback")
	print("TEST_REPORT ", JSON.stringify({"checks":checks, "failures":failures, "simulations":100, "outcomes":outcomes, "mean_rounds":total_rounds / 100.0}))
	quit(0 if failures.is_empty() else 1)

func simulate(seed_value: int) -> Dictionary:
	var r = fresh(seed_value)
	var safety := 0
	while r.outcome.is_empty() and safety < 1000:
		safety += 1
		if r.current.is_empty(): r.advance()
		else:
			var cmd: Dictionary = r.choose_ai()
			if cmd.is_empty(): break
			var record: Dictionary = r.apply(cmd)
			if record.has("error"): check(false, "AI produced illegal command")
	for u in r.units.values(): check(u.hp >= 0 and u.hp <= u.max_hp, "HP invariant seed %d" % seed_value)
	return r.result()
