extends RefCounted
## Independently authored HUD; reads snapshots and delegates commands to the app.
var queue: HBoxContainer
var target_portrait: TextureRect
var target_title: Label
var target_detail: Label
var hover_skill: String = ""
var inspected: String = ""
var shown: Dictionary = {}

func picture(a, rect: Rect2) -> TextureRect:
	var p := TextureRect.new()
	p.position = rect.position
	p.size = rect.size
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.hud.add_child(p)
	return p

func line(a, rect: Rect2, color: Color) -> void:
	var p := ColorRect.new()
	p.position = rect.position
	p.size = rect.size
	p.color = color
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.hud.add_child(p)

func build(a) -> void:
	# Soft black edge bands replace opaque boxed panels; all dimensions are 4K.
	for i in range(16):
		line(a, Rect2(0, i * 14, 3840, 14), Color(0.015, 0.02, 0.02, 0.95 * (1.0 - i / 16.0)))
		line(a, Rect2(0, 1740 + i * 12, 3840, 12), Color(0.015, 0.02, 0.02, i / 16.0))
	line(a, Rect2(0, 1932, 3840, 228), Color("040606"))
	a.label(a.hud, "墓穴边界", Rect2(80, 32, 650, 70), 48, a.GOLD)
	a.label(a.hud, "余 烬 远 征  /  遭 遇 战", Rect2(82, 112, 650, 45), 28, a.MUTED)
	a.auto_button = a.button(a.hud, "自动：关", Rect2(1300, 45, 250, 82), a.toggle_auto)
	a.speed_button = a.button(a.hud, "速度 ×1", Rect2(1570, 45, 240, 82), a.toggle_speed)
	a.button(a.hud, "设置 / ESC", Rect2(1830, 45, 280, 82), a.show_pause)
	a.button(a.hud, "全屏", Rect2(2130, 45, 180, 82), a.toggle_fullscreen)
	a.round_label = a.label(a.hud, "", Rect2(2560, 40, 320, 90), 46, a.GOLD)
	queue = HBoxContainer.new()
	queue.position = Vector2(2890, 26)
	queue.size = Vector2(870, 125)
	queue.add_theme_constant_override("separation", 12)
	a.hud.add_child(queue)
	a.order_label = a.label(a.hud, "", Rect2(2560, 155, 1200, 40), 26, a.MUTED)
	a.order_label.clip_text = true
	a.hint = a.label(a.hud, "", Rect2(700, 245, 2440, 90), 44, a.GOLD)
	a.hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for x in [70, 2740]:
		line(a, Rect2(x, 1800, 1030, 2), Color("5a5546"))
		line(a, Rect2(x, 1900, 1030, 2), Color("343a35"))
	a.portrait = picture(a, Rect2(80, 1807, 125, 86))
	a.hero_title = a.label(a.hud, "当前行动", Rect2(235, 1815, 850, 70), 48, a.GOLD)
	a.hero_detail = a.label(a.hud, "", Rect2(90, 1920, 990, 185), 32)
	a.hero_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_portrait = picture(a, Rect2(2750, 1807, 125, 86))
	target_title = a.label(a.hud, "目标情报", Rect2(2900, 1815, 850, 70), 48, a.GOLD)
	target_detail = a.label(a.hud, "悬停或点击角色查看情报", Rect2(2760, 1920, 990, 185), 32, a.MUTED)
	target_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	a.preview_title = a.label(a.hud, "选择技能", Rect2(1170, 1775, 1500, 60), 40, a.GOLD)
	a.preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.skill_box = HBoxContainer.new()
	a.skill_box.position = Vector2(1220, 1850)
	a.skill_box.size = Vector2(700, 140)
	a.skill_box.add_theme_constant_override("separation", 18)
	a.hud.add_child(a.skill_box)
	var utilities := [["前移\nQ", "forward"], ["后撤\nE", "back"], ["坚守\nG", "defend"]]
	for i in utilities.size():
		var skill: String = utilities[i][1]
		var b = a.button(a.hud, utilities[i][0], Rect2(1950 + i * 160, 1850, 140, 140), func(): a.select_skill(skill))
		b.add_theme_font_size_override("font_size", 30)
		b.tooltip_text = a.rules.definitions.skills[skill].desc
	a.button(a.hud, "取消\n×", Rect2(2430, 1850, 140, 140), a.cancel_selection).add_theme_font_size_override("font_size", 30)
	a.preview_text = a.label(a.hud, "", Rect2(1170, 2000, 1500, 64), 30, a.GOLD)
	a.preview_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.confirm = a.button(a.hud, "确认行动  [SPACE]", Rect2(1510, 2075, 820, 70), a.submit_selected)
	a.confirm.add_theme_font_size_override("font_size", 30)
	a.log_label = a.label(a.hud, "", Rect2(80, 2115, 1030, 40), 24, a.MUTED)
	a.log_label.clip_text = true
	a.label(a.hud, "1–4 技能  ·  Q/E 换位  ·  G 坚守", Rect2(2760, 2115, 1010, 40), 25, a.MUTED)
	for child in a.hud.get_children():
		if child != a.hint: child.set_meta("focus_fade", 0.85 if child.position.y < 224 else 1.0)

func refresh_queue(a, state: Dictionary) -> void:
	shown = state
	for child in queue.get_children():
		queue.remove_child(child)
		child.queue_free()
	var ids: Array = []
	if not state.current.is_empty(): ids.append(state.current)
	for id in state.queue:
		if not id in ids and state.units[id].hp > 0: ids.append(id)
	for i in mini(ids.size(), 8):
		var u: Dictionary = state.units[ids[i]]
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(96, 120)
		var frame_style = a.box(Color("101512"), a.GOLD if i == 0 else Color("515951"), 3 if i == 0 else 1)
		frame_style.content_margin_left = 5
		frame_style.content_margin_right = 5
		frame.add_theme_stylebox_override("panel", frame_style)
		frame.tooltip_text = ("当前行动：" if i == 0 else "等待行动：") + u.name
		var face := TextureRect.new()
		face.texture = portrait_texture(a, u)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(face)
		queue.add_child(frame)

func portrait_texture(a, u: Dictionary) -> Texture2D:
	var texture: Texture2D = a.art.portrait(u.visual)
	if int(u.side) == 0: return texture
	# Reuse existing art through a display-only crop; no new asset or source writes.
	var crop := AtlasTexture.new()
	crop.atlas = texture
	crop.region = Rect2(0, 0, texture.get_width(), texture.get_height() * 0.4)
	return crop

func stats(u: Dictionary) -> String:
	return "%s\n生命 %d / %d    护甲 %d%%    速度 %d\n闪避 %d%%    抗流血 %d%%    抗眩晕 %d%%" % [u.role, u.hp, u.max_hp, u.armor, u.speed, u.dodge, u.bleed_resist, u.stun_resist]

func details(a) -> void:
	if shown.is_empty(): return
	var actor: String = shown.current
	if shown.units.has(actor): a.hero_detail.text = stats(shown.units[actor])
	var target: String = a.selected_target if not a.selected_target.is_empty() else (a.hovered if not a.hovered.is_empty() else inspected)
	if shown.units.has(target):
		var u: Dictionary = shown.units[target]
		target_title.text = u.name + (" · 已倒下" if u.hp <= 0 else "")
		target_portrait.texture = portrait_texture(a, u)
		target_detail.text = stats(u)
	else:
		target_title.text = "目标情报"
		target_portrait.texture = null
		target_detail.text = "悬停或点击角色查看情报\n选择技能与合法目标后，按空格确认。"
	var skill: String = hover_skill if not hover_skill.is_empty() else a.selected_skill
	a.preview_title.text = "选择技能" if skill.is_empty() else a.rules.definitions.skills[skill].name
	a.preview_text.text = "选择目标后显示命中与伤害预测"
	if skill.is_empty(): return
	var sk: Dictionary = a.rules.definitions.skills[skill]
	a.hero_detail.text = sk.desc + "\n发动位 %s  →  目标位 %s" % [str(sk.launch), str(sk.target)]
	if not target.is_empty() and target in a.rules.targets(a.rules.current, skill):
		var forecast: Dictionary = a.rules.preview(skill, target)
		if sk.kind in ["damage", "heal"]:
			a.preview_text.text = "命中 %d%%   ·   %s %d–%d   ·   暴击 %d%%" % [forecast.hit / 100, "治疗" if sk.kind == "heal" else "伤害", forecast.min, forecast.max, int(sk.get("crit", 0)) / 100]
		else: a.preview_text.text = "立即生效  ·  消耗本次行动"
		if not a.selected_target.is_empty(): a.preview_title.text += "  →  " + ("全体合法目标" if sk.get("all", false) else shown.units[target].name)
