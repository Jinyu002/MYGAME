extends Control
## Application shell: commands in, immutable action records out, presentation barrier.
const Rules = preload("res://battle/domain/battle_rules.gd")
const Catalog = preload("res://battle/presentation/art_catalog.gd")
const ActorView = preload("res://battle/presentation/actor_view.gd")
const Stage = preload("res://battle/presentation/battle_stage.gd")
const Director = preload("res://battle/presentation/shot_director.gd")
const Sound = preload("res://battle/presentation/battle_audio.gd")
const GOLD := Color("cbb481")
const INK := Color("131a21")
const MUTED := Color("9da7ad")

var ui = preload("res://app/battle_hud.gd").new()
var rules = Rules.new()
var art = Catalog.new()
var director: Node
var sound: AudioStreamPlayer
var world: Node2D
var camera: Camera2D
var hud: Control
var modal: Control
var popup_layer: Control
var views: Dictionary = {}
var cards: Dictionary = {}
var hit_buttons: Dictionary = {}
var skill_buttons: Array = []
var skill_box: HBoxContainer
var portrait: TextureRect
var hero_title: Label
var hero_detail: Label
var preview_title: Label
var preview_text: Label
var hint: Label
var round_label: Label
var order_label: Label
var log_label: Label
var confirm: Button
var auto_button: Button
var speed_button: Button
var shake_button: Button
var sound_button: Button
var selected_skill: String = ""
var selected_target: String = ""
var hovered: String = ""
var running: bool = false
var locked: bool = true
var paused: bool = false
var autoplay: bool = false
var smoke: bool = false
var capture_only: bool = false
var capture_path: String = ""
var impact_captured: bool = false
var generation: int = 0
var seed_value: int = 4207
var logs: Array = []
var pending_record: Dictionary = {}
var last_result: Dictionary = {}
var font: SystemFont
var sample_times: Array = []
var total_elapsed: float = 0
var decision_token: int = 0
var benchmark: bool = false
var action_capture: bool = false
var feedback_tweens: Array[Tween] = []

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var theme_resource := Theme.new()
	theme_resource.default_font = font
	theme_resource.default_font_size = 38
	theme_resource.set_color("font_color", "Label", Color("e7e4db"))
	theme_resource.set_color("font_color", "Button", Color("e9e3d4"))
	theme_resource.set_color("font_disabled_color", "Button", Color("687078"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var color := Color("202931")
		if state == "hover": color = Color("374148")
		if state == "pressed": color = Color("494538")
		if state == "disabled": color = Color("161d24")
		theme_resource.set_stylebox(state, "Button", box(color, GOLD if state in ["focus", "pressed"] else Color("4c504c"), 2))
	theme = theme_resource
	world = Stage.new()
	add_child(world)
	camera = Camera2D.new()
	camera.position = Vector2(1920, 1080)
	world.add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.theme = theme_resource
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	director = Director.new()
	add_child(director)
	director.impact.connect(_impact)
	director.finished.connect(_presentation_done)
	director.focus_changed.connect(func(amount: float):
		for child in hud.get_children():
			if child is Control and child.has_meta("focus_fade"):
				child.modulate.a = 1.0 - amount * float(child.get_meta("focus_fade"))
		if is_instance_valid(hint): hint.position.y = lerpf(245, 1900, amount))
	sound = Sound.new()
	add_child(sound)
	build_hud()
	popup_layer = Control.new()
	popup_layer.size = Vector2(3840, 2160)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(popup_layer)
	modal = Control.new()
	modal.size = Vector2(3840, 2160)
	hud.add_child(modal)
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke": smoke = true
		if arg == "--benchmark": benchmark = true
		if arg == "--capture-action": action_capture = true
		if arg == "--capture-only": capture_only = true
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
		if arg == "--variant": art.variant = true
	if smoke or capture_only or benchmark or action_capture:
		autoplay = smoke or benchmark or action_capture
		director.speed = 5.0 if smoke else 1.0
		if benchmark:
			director.speed = 2.0
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		start_battle()
		if capture_only:
			await get_tree().create_timer(2.0).timeout
			await capture("ready")
			get_tree().quit()
	else: show_title()

func box(fill: Color, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	style.content_margin_right = 22
	return style

func panel(parent: Node, rect: Rect2, fill: Color = INK) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", box(fill, Color("42453f"), 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func label(parent: Node, text: String, rect: Rect2, size_value: int = 38, color: Color = Color("e7e4db")) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_size_override("font_size", size_value)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func build_hud() -> void:
	ui.build(self)

func home_position(side: int, rank_value: int) -> Vector2:
	return Vector2(1550 - (rank_value - 1) * 370 if side == 0 else 2290 + (rank_value - 1) * 370, 1580)

func clear_modal() -> void:
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	modal.visible = false

func make_modal(title: String, subtitle: String) -> Panel:
	clear_modal()
	modal.visible = true
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.035, 0.05, 0.86)
	shade.size = Vector2(3840, 2160)
	modal.add_child(shade)
	var p := panel(modal, Rect2(900, 400, 2040, 1350), Color("151e27"))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	label(p, "E M B E R   E X P E D I T I O N", Rect2(110, 88, 1820, 70), 32, GOLD)
	label(p, title, Rect2(110, 210, 1820, 150), 100)
	var sub := label(p, subtitle, Rect2(110, 405, 1810, 440), 44, MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return p

func show_title() -> void:
	running = false
	locked = true
	var p := make_modal("余烬之下，守住阵线。", "四名远征者，一场墓穴遭遇。\n前后阵位决定技能与目标；合理换位、控制和治疗。\n\n选技能 → 点角色 → 确认行动。\n快捷键：1–4 技能 · Q/E 换位 · G 坚守 · 空格确认")
	button(p, "进入战斗试炼", Rect2(110, 970, 1820, 130), start_battle)
	label(p, "本地测试版  0.4   /   参考美术临时使用 · 最终替换为原创", Rect2(110, 1170, 1820, 70), 30, GOLD)

func start_battle() -> void:
	generation += 1
	decision_token += 1
	clear_feedback()
	director.cleanup()
	director.set_process(true)
	for child in popup_layer.get_children():
		popup_layer.remove_child(child)
		child.queue_free()
	paused = false
	clear_modal()
	for v in views.values(): v.queue_free()
	for c in cards.values(): c.queue_free()
	for b in hit_buttons.values(): b.queue_free()
	views.clear()
	cards.clear()
	hit_buttons.clear()
	rules.start(seed_value, "battle-%d" % generation)
	logs.clear()
	impact_captured = false
	selected_skill = ""
	selected_target = ""
	ui.hover_skill = ""
	ui.inspected = ""
	hovered = ""
	running = true
	locked = true
	for id in rules.units:
		var u: Dictionary = rules.units[id]
		var v = ActorView.new()
		v.setup(art, u.visual, int(u.side))
		v.presentation_speed = director.speed
		v.position = home_position(int(u.side), rules.rank_of(id))
		world.add_child(v)
		views[id] = v
		var card := panel(hud, Rect2(v.position.x - 165, 1620, 330, 130), Color.TRANSPARENT)
		card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		card.set_meta("focus_fade", 1.0)
		cards[id] = card
		var click := button(hud, "", Rect2(v.position.x - 170, 720, 340, 890), func(): choose_target(id))
		for state in ["normal", "hover", "pressed", "focus", "disabled"]: click.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		click.focus_mode = Control.FOCUS_NONE
		click.mouse_entered.connect(func(): hovered = id; refresh_preview())
		click.mouse_exited.connect(func(): hovered = ""; refresh_preview())
		hit_buttons[id] = click
	# Modal must remain above newly created cards and hit regions.
	hud.move_child(modal, hud.get_child_count() - 1)
	refresh()
	call_deferred("next_turn")

func next_turn() -> void:
	if not running or paused: return
	if not rules.outcome.is_empty(): show_result(); return
	locked = true
	var record: Dictionary = rules.advance()
	refresh()
	if not record.is_empty() and not record.events.is_empty():
		present(record)
	else:
		ready_for_command()

func ready_for_command() -> void:
	if not running or paused: return
	if not rules.outcome.is_empty(): show_result(); return
	if rules.current.is_empty(): call_deferred("next_turn"); return
	locked = false
	selected_skill = ""
	selected_target = ""
	refresh()
	if rules.units[rules.current].side == 1 or autoplay:
		var token := generation
		decision_token += 1
		var decision := decision_token
		locked = true
		refresh()
		await get_tree().create_timer(0.16 if smoke else 0.55).timeout
		if token != generation or decision != decision_token or paused or not running: return
		perform(rules.choose_ai())

func present(record: Dictionary) -> void:
	locked = true
	pending_record = record
	refresh(record.before)
	var skill: String = record.get("skill", "")
	if not skill.is_empty(): hint.text = rules.units[record.actor].name + "  /  " + rules.definitions.skills[skill].name
	director.play(record, views, camera)

func perform(cmd: Dictionary) -> void:
	if cmd.is_empty(): return
	var record: Dictionary = rules.apply(cmd)
	if record.has("error"):
		logs.append("指令未执行：" + record.error)
		ready_for_command()
		return
	selected_skill = ""
	selected_target = ""
	present(record)

func _impact(record: Dictionary) -> void:
	ui.shown = record.after
	ui.details(self)
	refresh_cards(record.after)
	var audible := false
	var popup_counts: Dictionary = {}
	for e in record.events:
		var text: String = ""
		var color := Color("e8d2b4")
		match e.type:
			"damage":
				text = ("暴击!  " if e.critical else "") + "−" + str(e.amount)
				color = Color("efb468") if e.critical else Color("f2ddd2")
				audible = true
			"heal": text = "+" + str(e.amount); color = Color("95d4bb"); audible = true
			"miss": text = "闪避"; color = MUTED
			"status": text = e.detail; color = GOLD
			"death":
				text = "倒下"
				color = Color("bb665a")
				if views.has(e.target): feedback_tween(views[e.target]).tween_property(views[e.target], "modulate:a", 0.0, 0.35)
			"move": text = "换位"; color = MUTED
			"round":
				logs.append("第 %d 轮开始" % e.amount)
		if not text.is_empty() and views.has(e.target):
			var stack: int = popup_counts.get(e.target, 0)
			popup_counts[e.target] = stack + 1
			popup(text, views[e.target].position + Vector2(0, -views[e.target].body_height - 50 - stack * 110), color)
			logs.append(rules.units[e.target].name + " " + text)
	if audible:
		var heal: bool = record.events.any(func(e): return e.type == "heal")
		var crit: bool = record.events.any(func(e): return e.get("critical", false))
		sound.hit(heal, crit)
	update_log()
	if (smoke or action_capture) and not impact_captured and not record.get("skill", "").is_empty():
		impact_captured = true
		await capture("impact")
		if action_capture: get_tree().quit()

func feedback_tween(owner_node: Node) -> Tween:
	feedback_tweens = feedback_tweens.filter(func(t): return t.is_valid())
	var t := owner_node.create_tween().set_speed_scale(director.speed)
	feedback_tweens.append(t)
	return t

func pause_feedback(value: bool) -> void:
	for t in feedback_tweens:
		if t.is_valid():
			if value: t.pause()
			else: t.play()
	for view in views.values(): view.presentation_paused = value
	sound.stream_paused = value

func clear_feedback() -> void:
	for t in feedback_tweens:
		if t.is_valid(): t.kill()
	feedback_tweens.clear()
	pause_feedback(false)
	for child in popup_layer.get_children():
		popup_layer.remove_child(child)
		child.queue_free()

func popup(text: String, pos: Vector2, color: Color) -> void:
	var canvas_pos := world.get_canvas_transform() * pos
	canvas_pos.x = clampf(canvas_pos.x, 350, 3490)
	canvas_pos.y = clampf(canvas_pos.y, 350, 1360)
	var p := label(popup_layer, text, Rect2(canvas_pos - Vector2(350, 0), Vector2(700, 130)), 70, color)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_theme_color_override("font_outline_color", Color("070b10"))
	p.add_theme_constant_override("outline_size", 13)
	var t := feedback_tween(p).set_parallel(true)
	t.tween_property(p, "position:y", p.position.y - 90, 0.9)
	t.tween_property(p, "modulate:a", 0.0, 0.4).set_delay(0.5)
	t.chain().tween_callback(p.queue_free)

func _presentation_done() -> void:
	clear_feedback()
	if not running: return
	refresh()
	if paused: return
	if not rules.outcome.is_empty(): show_result(); return
	if rules.current.is_empty(): call_deferred("next_turn")
	else: ready_for_command()

func refresh(state: Dictionary = {}) -> void:
	if rules.units.is_empty(): return
	ui.hover_skill = ""
	var shown: Dictionary = state if not state.is_empty() else rules.snapshot()
	var displayed_actor: String = shown.current
	round_label.text = "回合  %02d" % rules.round_number
	ui.refresh_queue(self, shown)
	var names: Array = []
	if not rules.current.is_empty(): names.append("▶ " + rules.units[rules.current].name)
	for id in rules.queue: names.append(rules.units[id].name)
	order_label.text = "   ›   ".join(names)
	for id in views:
		var u: Dictionary = shown.units[id]
		var v = views[id]
		v.alive = u.hp > 0
		v.visible = u.hp > 0
		if u.hp > 0 and not director.busy:
			v.position = home_position(int(u.side), shown.teams[int(u.side)].find(id) + 1)
		v.active = id == displayed_actor
		v.targetable = not locked and not selected_skill.is_empty() and id in rules.targets(rules.current, selected_skill)
		v.chosen = id == selected_target
		var b: Button = hit_buttons[id]
		b.visible = u.hp > 0
		b.position.x = v.position.x - 170
		b.tooltip_text = "%s\n生命 %d/%d · 护甲 %d%% · 速度 %d" % [u.name, u.hp, u.max_hp, u.armor, u.speed]
	refresh_cards(shown)
	for child in skill_box.get_children():
		skill_box.remove_child(child)
		child.queue_free()
	skill_buttons.clear()
	if not displayed_actor.is_empty():
		var u: Dictionary = shown.units[displayed_actor]
		portrait.texture = art.portrait(u.visual)
		hero_title.text = u.name
		hero_detail.text = "%s\n生命 %d / %d\n护甲 %d%%   速度 %d\n阵位 %d  ·  %s" % [u.role, u.hp, u.max_hp, u.armor, u.speed, rules.rank_of(u.id), "我方行动" if u.side == 0 else "敌方行动"]
		for i in u.skills.size():
			var sk_id: String = u.skills[i]
			var sk: Dictionary = rules.definitions.skills[sk_id]
			var remaining: String = "  %d/%d" % [int(sk.limit) - int(u.used.get(sk_id, 0)), sk.limit] if sk.has("limit") else ""
			var b := Button.new()
			b.custom_minimum_size = Vector2(155, 140)
			var icon_style := box(Color("0d1412"), Color("606154"), 2)
			icon_style.content_margin_left = 8
			icon_style.content_margin_right = 8
			b.add_theme_stylebox_override("normal", icon_style)
			if u.side == 0: b.icon = art.skill_icon(u.visual, int(sk.get("icon_index", mini(i, 2))))
			else: b.icon = art.portrait(u.visual)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width", 120)
			label(b, str(i + 1), Rect2(112, 2, 36, 40), 28, GOLD)
			if not remaining.is_empty(): label(b, remaining.strip_edges(), Rect2(8, 97, 135, 38), 26, GOLD)
			b.mouse_entered.connect(func(): ui.hover_skill = sk_id; refresh_preview())
			b.mouse_exited.connect(func(): ui.hover_skill = ""; refresh_preview())
			b.focus_entered.connect(func(): ui.hover_skill = sk_id; refresh_preview())
			b.focus_exited.connect(func(): ui.hover_skill = ""; refresh_preview())
			b.disabled = locked or u.side != 0 or rules.targets(u.id, sk_id).is_empty()
			b.tooltip_text = sk.name + "\n" + sk.desc + "\n发动位 " + str(sk.launch) + " → 目标位 " + str(sk.target)
			if rules.targets(u.id, sk_id).is_empty(): b.tooltip_text += "\n不可用：阵位不符、目标不存在或次数耗尽"
			if sk_id == selected_skill: b.add_theme_stylebox_override("normal", box(Color("413b2d"), GOLD, 3))
			b.pressed.connect(func(): select_skill(sk_id))
			skill_box.add_child(b)
			skill_buttons.append(b)
		if not director.busy: hint.text = ("敌方正在选择行动…" if u.side == 1 else ("自动战斗中" if autoplay else "选择技能，再选择高亮目标"))
	else:
		hero_title.text = "战况推进"
		hero_detail.text = "正在结算状态与行动顺序"
		if not director.busy: hint.text = "阵线重整"
	auto_button.text = "自动：开" if autoplay else "自动：关"
	refresh_preview()
	update_log()

func refresh_cards(state: Dictionary) -> void:
	for id in cards:
		var p: Panel = cards[id]
		var u: Dictionary = state.units[id]
		p.visible = u.hp > 0
		if u.hp <= 0: continue
		var rank_value: int = state.teams[int(u.side)].find(id) + 1
		p.position.x = home_position(int(u.side), rank_value).x - 165
		for child in p.get_children():
			p.remove_child(child)
			child.queue_free()
		var name_label := label(p, "%d  %s" % [rank_value, u.name], Rect2(15, 7, 300, 38), 28, GOLD if u.side == 0 else Color("c4a19a"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bar := ColorRect.new()
		bar.position = Vector2(20, 53)
		bar.size = Vector2(290, 14)
		bar.color = Color("352c2c")
		p.add_child(bar)
		var fill := ColorRect.new()
		fill.size = Vector2(290 * float(u.hp) / u.max_hp, 14)
		fill.color = Color("a33e3e") if u.side == 1 else Color("668c80")
		bar.add_child(fill)
		var statuses: Array = []
		for key in u.status:
			statuses.append({"bleed":"流血", "stun":"晕", "guard":"守", "expose":"破甲", "immune":"抗晕"}.get(key, key))
		label(p, "%d/%d  %s" % [u.hp, u.max_hp, " ".join(statuses)], Rect2(20, 76, 295, 40), 26)

func select_skill(id: String) -> void:
	if locked or paused or not running or rules.current.is_empty() or rules.units[rules.current].side != 0: return
	if rules.targets(rules.current, id).is_empty():
		logs.append("该技能当前不可用：检查阵位、目标或剩余次数")
		update_log()
		return
	selected_skill = id
	selected_target = rules.current if rules.definitions.skills[id].get("self", false) else ""
	refresh()

func choose_target(id: String) -> void:
	if locked or paused or not running: return
	ui.inspected = id
	refresh_preview()
	if selected_skill.is_empty(): return
	if id in rules.targets(rules.current, selected_skill):
		selected_target = id
		refresh()

func refresh_preview() -> void:
	confirm.disabled = locked or selected_skill.is_empty() or selected_target.is_empty() or paused
	ui.details(self)

func submit_selected() -> void:
	if confirm.disabled or locked or paused: return
	locked = true
	perform(rules.command(selected_skill, selected_target))

func cancel_selection() -> void:
	if locked: return
	selected_skill = ""
	selected_target = ""
	refresh()

func update_log() -> void:
	while logs.size() > 100: logs.pop_front()
	log_label.text = "  /  ".join(logs.slice(maxi(0, logs.size() - 3)))

func toggle_auto() -> void:
	autoplay = not autoplay
	refresh()
	if autoplay and running and not locked and not paused: ready_for_command()

func toggle_speed() -> void:
	director.speed = 2.0 if director.speed == 1.0 else 1.0
	if director.tween and director.tween.is_valid(): director.tween.set_speed_scale(director.speed)
	for t in feedback_tweens:
		if t.is_valid(): t.set_speed_scale(director.speed)
	for view in views.values(): view.presentation_speed = director.speed
	speed_button.text = "速度 ×%d" % director.speed

func toggle_fullscreen() -> void:
	var full: bool = DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func show_pause() -> void:
	if not running: return
	decision_token += 1
	paused = true
	pause_feedback(true)
	if director.tween and director.tween.is_valid(): director.tween.pause()
	director.set_process(false)
	var p := make_modal("整备与设置", "当前行动已暂停。恢复后继续同一次结算。\n震动、声音与演出速度不会影响战斗结果。\n\n换装验证仅替换守卫的外观，规则数据不变。")
	shake_button = button(p, "镜头震动：" + ("开" if director.shake_enabled else "关"), Rect2(110, 770, 560, 95), func():
		director.shake_enabled = not director.shake_enabled
		shake_button.text = "镜头震动：" + ("开" if director.shake_enabled else "关"))
	sound_button = button(p, "声音：" + ("开" if sound.enabled else "关"), Rect2(720, 770, 560, 95), func():
		sound.enabled = not sound.enabled
		sound_button.text = "声音：" + ("开" if sound.enabled else "关"))
	button(p, "切换守卫外观", Rect2(1330, 770, 600, 95), func(): art.variant = not art.variant)
	button(p, "继续战斗", Rect2(110, 920, 1820, 110), resume_battle)
	button(p, "重新开始", Rect2(110, 1080, 850, 100), func(): director.set_process(true); start_battle())
	button(p, "撤退…", Rect2(1010, 1080, 920, 100), confirm_retreat)

func resume_battle() -> void:
	paused = false
	pause_feedback(false)
	clear_modal()
	director.set_process(true)
	if director.busy:
		if director.tween and director.tween.is_valid(): director.tween.play()
	elif rules.current.is_empty(): next_turn()
	else: ready_for_command()

func confirm_retreat() -> void:
	var p := make_modal("确认撤离？", "本场战斗将以撤退结束。\n此测试版不产生永久损失，可以重新挑战。")
	button(p, "返回设置", Rect2(110, 970, 850, 120), show_pause)
	button(p, "确认撤退", Rect2(1010, 970, 920, 120), func():
		director.cleanup()
		director.set_process(true)
		paused = false
		rules.retreat()
		show_result())

func show_result() -> void:
	if not running: return
	running = false
	locked = true
	clear_feedback()
	director.cleanup()
	director.set_process(true)
	for child in popup_layer.get_children():
		popup_layer.remove_child(child)
		child.queue_free()
	last_result = rules.result()
	var titles := {"victory":"余烬未熄。", "defeat":"阵线已失守。", "draw":"战局陷入僵持。", "retreat":"撤离墓穴。"}
	var lines: Array = []
	for id in ["warden", "duelist", "ranger", "mender"]:
		var u: Dictionary = rules.units[id]
		lines.append("%s   %d / %d" % [u.name, u.hp, u.max_hp])
	var p := make_modal(titles.get(rules.outcome, "战斗结束"), "第 %d 轮结束   ·   随机种子 %d\n\n%s\n\n尝试不同的集火、治疗与换位顺序。" % [rules.round_number, seed_value, "     ".join(lines)])
	button(p, "再次挑战", Rect2(110, 970, 850, 120), start_battle)
	button(p, "返回标题", Rect2(1010, 970, 920, 120), show_title)
	label(p, "这是一场独立试炼。重试可以尝试另一种策略。", Rect2(110, 1170, 1820, 65), 30, MUTED)
	if smoke:
		await get_tree().create_timer(0.3).timeout
		await capture("result")
		print("SMOKE_RESULT ", JSON.stringify({"outcome":rules.outcome, "rounds":rules.round_number, "actions":rules.history.size(), "seed":seed_value}))
		get_tree().quit()
	elif benchmark:
		await get_tree().create_timer(0.2).timeout
		start_battle()

func capture(suffix: String) -> void:
	if capture_path.is_empty(): return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var output := capture_path + "_" + suffix + ".png"
	var error := img.save_png(output)
	print("CAPTURE ", output, " ", img.get_size(), " error=", error)

func _process(delta: float) -> void:
	total_elapsed += delta
	if benchmark:
		if total_elapsed > 10: sample_times.append(delta * 1000.0)
		if total_elapsed >= 70:
			benchmark = false
			sample_times.sort()
			print("BENCHMARK_REPORT ", JSON.stringify({"resolution":str(get_viewport().get_texture().get_image().get_size()), "logical_size":str(get_viewport().get_visible_rect().size), "samples":sample_times.size(), "duration_seconds":60, "p95_ms":sample_times[int(sample_times.size() * 0.95)], "p99_ms":sample_times[int(sample_times.size() * 0.99)], "static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "cpu":OS.get_processor_name(), "gpu":RenderingServer.get_video_adapter_name()}))
			get_tree().quit()
	if smoke:
		if total_elapsed > 10: sample_times.append(delta * 1000.0)
		if total_elapsed > 120:
			push_error("SMOKE_TIMEOUT")
			get_tree().quit(2)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_F11: toggle_fullscreen()
		KEY_ESCAPE:
			if paused: resume_battle()
			elif not selected_skill.is_empty(): cancel_selection()
			else: show_pause()
		KEY_SPACE: submit_selected()
		KEY_Q: select_skill("forward")
		KEY_E: select_skill("back")
		KEY_G: select_skill("defend")
		KEY_1, KEY_2, KEY_3, KEY_4:
			if not rules.current.is_empty():
				var index: int = event.keycode - KEY_1
				if index < rules.units[rules.current].skills.size(): select_skill(rules.units[rules.current].skills[index])
