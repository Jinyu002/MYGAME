extends RefCounted
## Pure battle rules. No nodes, textures, timers, or animation callbacks.

var definitions: Dictionary
var units: Dictionary = {}
var teams: Array = [[], []]
var queue: Array = []
var current: String = ""
var round_number: int = 0
var revision: int = 0
var outcome: String = ""
var battle_id: String = ""
var battle_seed: int = 0
var rng := RandomNumberGenerator.new()
var ai_rng := RandomNumberGenerator.new()
var seen: Dictionary = {}
var history: Array = []

func _init(data: Dictionary = {}) -> void:
	definitions = _normalize(data if not data.is_empty() else JSON.parse_string(FileAccess.get_file_as_string("res://content/battle.json")))

func _normalize(value):
	# Godot JSON numbers are floats; rank membership uses exact Variant types.
	if value is float: return int(value)
	if value is Array:
		var result: Array = []
		for item in value: result.append(_normalize(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = _normalize(value[key])
		return result
	return value

func validate_data() -> Array:
	var errors: Array = []
	var ids: Dictionary = {}
	for u in definitions.get("actors", []):
		if ids.has(u.id): errors.append("duplicate actor: " + u.id)
		ids[u.id] = true
		if u.hp <= 0 or not u.side in [0, 1]: errors.append("invalid actor: " + u.id)
		for sk in u.skills:
			if not definitions.skills.has(sk): errors.append("missing skill: " + sk)
	for id in definitions.get("skills", {}):
		var s: Dictionary = definitions.skills[id]
		if s.min < 0 or s.max < s.min: errors.append("invalid damage: " + id)
		for field in ["accuracy", "crit", "chance"]:
			if s.get(field, 0) < 0 or s.get(field, 0) > 10000: errors.append("invalid probability: " + id)
		for field in ["launch", "target"]:
			for rank_value in s[field]:
				if not rank_value in [1, 2, 3, 4]: errors.append("invalid rank: " + id)
	return errors

func start(seed_value: int, id: String = "demo") -> void:
	assert(validate_data().is_empty())
	units.clear()
	teams = [[], []]
	queue.clear()
	current = ""
	round_number = 0
	revision = 0
	outcome = ""
	seen.clear()
	history.clear()
	battle_id = id
	battle_seed = seed_value
	rng.seed = seed_value
	ai_rng.seed = seed_value ^ 73471
	for d in definitions.actors:
		var u: Dictionary = d.duplicate(true)
		u.max_hp = int(u.hp)
		u.hp = int(u.hp)
		u.status = {}
		u.used = {}
		units[u.id] = u
		teams[int(u.side)].append(u.id)

func rank_of(id: String) -> int:
	return teams[int(units[id].side)].find(id) + 1

func available_skills(id: String) -> Array:
	return units[id].skills + ["defend", "forward", "back"]

func targets(id: String, skill_id: String) -> Array:
	if not units.has(id) or units[id].hp <= 0 or not definitions.skills.has(skill_id): return []
	if not skill_id in available_skills(id): return []
	var u: Dictionary = units[id]
	var sk: Dictionary = definitions.skills[skill_id]
	if not rank_of(id) in sk.launch: return []
	if u.used.get(skill_id, 0) >= sk.get("limit", 999): return []
	if sk.kind == "move":
		var dest: int = rank_of(id) - 1 + int(sk.self_move)
		return [id] if dest >= 0 and dest < teams[int(u.side)].size() else []
	if sk.get("self", false): return [id]
	var side: int = int(u.side) if sk.get("friendly", false) else 1 - int(u.side)
	var result: Array = []
	for target_id in teams[side]:
		if units[target_id].hp > 0 and rank_of(target_id) in sk.target: result.append(target_id)
	return result

func hit_chance(skill_id: String, target_id: String) -> int:
	var s: Dictionary = definitions.skills[skill_id]
	if s.get("friendly", false) or s.get("sure_hit", false): return 10000
	return clampi(int(s.accuracy) - int(units[target_id].dodge) * 100, 500, 10000)

func damage_value(base: int, critical: bool, target_id: String) -> int:
	var u: Dictionary = units[target_id]
	var armor: int = clampi(int(u.armor) - (20 if u.status.has("expose") else 0), 0, 60)
	var value: float = base * (1.5 if critical else 1.0) * (1.0 - armor / 100.0)
	if u.status.has("guard"): value *= 0.65
	return maxi(1, int(floor(value))) if base > 0 else 0

func preview(skill_id: String, target_id: String) -> Dictionary:
	var sk: Dictionary = definitions.skills[skill_id]
	var low: int = int(sk.min)
	var high: int = int(sk.max)
	if sk.kind == "damage":
		var guaranteed_crit: bool = int(sk.get("crit", 0)) == 10000
		low = damage_value(low, guaranteed_crit, target_id)
		high = damage_value(high, guaranteed_crit, target_id)
	return {"hit":hit_chance(skill_id, target_id), "min":low, "max":high}

func snapshot() -> Dictionary:
	return {"units":units.duplicate(true), "teams":teams.duplicate(true), "round":round_number, "current":current, "queue":queue.duplicate(), "outcome":outcome, "revision":revision}

func _event(events: Array, type: String, source: String, target: String, amount: int = 0, detail: String = "", critical: bool = false) -> void:
	events.append({"type":type, "source":source, "target":target, "amount":amount, "detail":detail, "critical":critical})

func _compact() -> void:
	for side in [0, 1]:
		teams[side] = teams[side].filter(func(id): return units[id].hp > 0)
	queue = queue.filter(func(id): return units[id].hp > 0)
	for u in units.values():
		if u.status.has("guard") and units[u.status.guard].hp <= 0: u.status.erase("guard")

func _check_end() -> void:
	_compact()
	if teams[0].is_empty() and teams[1].is_empty(): outcome = "draw"
	elif teams[1].is_empty(): outcome = "victory"
	elif teams[0].is_empty(): outcome = "defeat"
	if not outcome.is_empty(): current = ""

func _finish(id: String) -> void:
	for key in ["expose", "immune"]:
		if units[id].status.has(key):
			units[id].status[key] -= 1
			if units[id].status[key] <= 0: units[id].status.erase(key)
	current = ""
	_check_end()

func advance() -> Dictionary:
	if not outcome.is_empty() or not current.is_empty(): return {}
	_check_end()
	if not outcome.is_empty(): return {}
	var before := snapshot()
	var events: Array = []
	if queue.is_empty():
		if round_number >= 50:
			outcome = "draw"
			return {"before":before, "after":snapshot(), "events":[], "actor":"", "skill":""}
		round_number += 1
		var rolls: Array = []
		for side in teams:
			for id in side: rolls.append({"id":id, "speed":units[id].speed + rng.randi_range(0, 3), "tie":rng.randi()})
		rolls.sort_custom(func(a, b):
			if a.speed != b.speed: return a.speed > b.speed
			if a.tie != b.tie: return a.tie > b.tie
			return a.id < b.id)
		for r in rolls: queue.append(r.id)
		_event(events, "round", "", "", round_number)
	current = queue.pop_front()
	var actor_id := current
	for other in units.values():
		if other.status.get("guard", "") == current: other.status.erase("guard")
	var u: Dictionary = units[current]
	if u.status.has("bleed"):
		var lost: int = mini(3, u.hp)
		u.hp -= lost
		u.status.bleed -= 1
		if u.status.bleed <= 0: u.status.erase("bleed")
		_event(events, "damage", current, current, lost, "流血")
		if u.hp <= 0: _event(events, "death", current, current)
	_check_end()
	if u.hp <= 0:
		current = ""
	elif outcome.is_empty() and u.status.has("stun"):
		u.status.erase("stun")
		u.status.immune = 2
		_event(events, "status", actor_id, actor_id, 0, "眩晕 · 跳过行动")
		_finish(actor_id)
	revision += 1
	var record := {"before":before, "after":snapshot(), "events":events, "actor":actor_id, "skill":""}
	history.append(record.duplicate(true))
	return record

func command(skill_id: String, target_id: String) -> Dictionary:
	return {"battle_id":battle_id, "command_id":"%s:%d" % [battle_id, revision], "revision":revision, "actor":current, "skill":skill_id, "target":target_id}

func apply(cmd: Dictionary) -> Dictionary:
	if cmd.get("battle_id", "") != battle_id: return {"error":"wrong_battle"}
	if seen.has(cmd.get("command_id", "")): return {"error":"duplicate"}
	if not outcome.is_empty() or current.is_empty() or cmd.get("actor", "") != current: return {"error":"not_your_turn"}
	if cmd.get("revision", -1) != revision: return {"error":"stale_command"}
	var sk_id: String = cmd.get("skill", "")
	var target_id: String = cmd.get("target", "")
	var valid := targets(current, sk_id)
	if not target_id in valid: return {"error":"invalid_target"}
	seen[cmd.command_id] = true
	var before := snapshot()
	var actor_id := current
	var actor: Dictionary = units[actor_id]
	var sk: Dictionary = definitions.skills[sk_id]
	var events: Array = []
	actor.used[sk_id] = actor.used.get(sk_id, 0) + 1
	var affected: Array = valid if sk.get("all", false) else [target_id]
	for tid in affected:
		var target: Dictionary = units[tid]
		if sk.kind == "heal":
			var healed: int = mini(rng.randi_range(int(sk.min), int(sk.max)), target.max_hp - target.hp)
			target.hp += healed
			_event(events, "heal", actor_id, tid, healed)
			if sk.get("cure", false):
				target.status.erase("bleed")
				_event(events, "status", actor_id, tid, 0, "净创")
		elif sk.kind == "guard":
			target.status.guard = actor_id
			_event(events, "status", actor_id, tid, 0, "坚守")
		elif sk.kind == "damage":
			if rng.randi_range(0, 9999) >= hit_chance(sk_id, tid):
				_event(events, "miss", actor_id, tid)
				continue
			var base := rng.randi_range(int(sk.min), int(sk.max))
			var critical: bool = rng.randi_range(0, 9999) < int(sk.crit)
			var dealt: int = mini(damage_value(base, critical, tid), target.hp)
			target.hp -= dealt
			_event(events, "damage", actor_id, tid, dealt, "", critical)
			if target.hp <= 0:
				_event(events, "death", actor_id, tid)
			else:
				if sk.has("effect"):
					var effect: String = sk.effect
					var resist: int = int(target.get(effect + "_resist", 0)) * 100
					if effect == "stun" and target.status.has("immune"): resist = 10000
					var chance: int = clampi(int(sk.chance) - resist, 0, 10000)
					if rng.randi_range(0, 9999) < chance:
						target.status[effect] = 1 if effect == "stun" else 2
						_event(events, "status", actor_id, tid, 0, {"stun":"眩晕", "bleed":"流血", "expose":"破甲"}[effect])
					else: _event(events, "status", actor_id, tid, 0, "免疫" if chance == 0 else "抵抗")
				if sk.has("push"): _move(tid, int(sk.push), events)
	if sk.has("self_move"): _move(actor_id, int(sk.self_move), events)
	_finish(actor_id)
	revision += 1
	var record := {"actor":actor_id, "skill":sk_id, "targets":affected.duplicate(), "events":events, "before":before, "after":snapshot()}
	history.append(record.duplicate(true))
	return record

func _move(id: String, direction: int, events: Array) -> void:
	var team: Array = teams[int(units[id].side)]
	var index: int = team.find(id)
	var dest: int = clampi(index + direction, 0, team.size() - 1)
	if index != dest:
		var other = team[dest]
		team[dest] = id
		team[index] = other
		_event(events, "move", id, id, direction)

func choose_ai() -> Dictionary:
	if current.is_empty(): return {}
	var actor: Dictionary = units[current]
	var best: Dictionary = {}
	var best_score: float = -INF
	for sk_id in available_skills(current):
		var sk: Dictionary = definitions.skills[sk_id]
		for tid in targets(current, sk_id):
			var target: Dictionary = units[tid]
			var score: float = ai_rng.randf() * 0.5
			if sk.kind == "damage":
				var expected: float = damage_value(int((sk.min + sk.max) / 2), false, tid) * hit_chance(sk_id, tid) / 10000.0
				score += expected
				if expected >= target.hp: score += 30
				if sk.has("effect") and not target.status.has(sk.effect): score += 4
				if sk.get("all", false): score *= targets(current, sk_id).size()
			elif sk.kind == "heal":
				score += minf(target.max_hp - target.hp, (sk.min + sk.max) / 2.0) * 1.5
				if target.hp < target.max_hp * 0.4: score += 12
				if sk.get("cure", false) and target.status.has("bleed"): score += 7
			elif sk.kind == "guard":
				score -= 4
				if actor.id == "guard" and actor.hp < actor.max_hp * 0.3 and actor.used.get("defend", 0) == 0: score += 30
			elif sk.kind == "move":
				score -= 2
				# Find the closest rank that unlocks an offensive skill.
				var now_rank := rank_of(current)
				var new_rank: int = now_rank + int(sk.self_move)
				for own in actor.skills:
					var attack: Dictionary = definitions.skills[own]
					if attack.kind == "damage" and new_rank in attack.launch and not now_rank in attack.launch: score += 4
			if score > best_score:
				best_score = score
				best = command(sk_id, tid)
	return best

func retreat() -> void:
	if outcome.is_empty():
		outcome = "retreat"
		current = ""
		revision += 1

func result() -> Dictionary:
	return {"battle_id":battle_id, "seed":battle_seed, "outcome":outcome, "rounds":round_number, "version":definitions.version, "participants":units.duplicate(true)}
