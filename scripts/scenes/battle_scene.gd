extends Node3D

var _allies: Array[Dictionary] = []
var _enemies: Array[Dictionary] = []
var _battle_ended: bool = false
var _speed_scale: float = 1.0
var _cutscene_enabled: bool = true
var _forced_covenant_hero_id: String = ""

var _camera: Camera3D
var _default_cam_pos: Vector3 = Vector3(0, 4.6, 9.2)
var _default_cam_rot: Vector3 = Vector3(-21, 0, 0)
var _main_light: DirectionalLight3D
var _cutscene_light: OmniLight3D

var _combat_log: RichTextLabel
var _header_label: Label
var _skill_banner: Label
var _queue_hbox: HBoxContainer

## UI สำหรับคัทซีนการร่ายสกิล (7 Knights Style Cut-in Banner)
var _cutin_panel: PanelContainer
var _cutin_portrait: TextureRect
var _cutin_speaker_lbl: Label
var _cutin_skill_lbl: Label
var _cutin_quote_lbl: Label

func _ready() -> void:
	GameManager.ensure_initialized()
	if GameManager.main_hero_id == "":
		GameManager.select_starter_hero("hero_knight")

	_setup_3d_arena()
	_setup_ui()
	_spawn_combatants()
	_run_battle_loop()

func _make_dark_panel_style(bg_col: Color = Color(0.05, 0.03, 0.09, 0.85), border_col: Color = Color(0.72, 0.55, 0.24, 0.85)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border_col
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _setup_3d_arena() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.02, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.25, 0.46)
	env.ambient_light_energy = 1.3
	env.glow_enabled = true
	env.glow_intensity = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.04, 0.11)
	env.fog_density = 0.015
	var w_env := WorldEnvironment.new()
	w_env.environment = env
	add_child(w_env)

	_camera = Camera3D.new()
	_camera.position = _default_cam_pos
	_camera.rotation_degrees = _default_cam_rot
	_camera.fov = 46.0
	add_child(_camera)

	_main_light = DirectionalLight3D.new()
	_main_light.rotation_degrees = Vector3(-52, -18, 0)
	_main_light.light_color = Color(0.95, 0.84, 1.0)
	_main_light.light_energy = 1.65
	_main_light.shadow_enabled = true
	add_child(_main_light)

	_cutscene_light = OmniLight3D.new()
	_cutscene_light.light_energy = 0.0
	_cutscene_light.omni_range = 8.5
	add_child(_cutscene_light)

	# สร้างฉากสนามประลองดันเจี้ยน 3D
	ModelFactory.build_dark_dungeon_environment(self, 4, 2)

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var top_bar := PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 50)
	top_bar.add_theme_stylebox_override("panel", _make_dark_panel_style())
	root.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 14)
	top_bar.add_child(top_hbox)

	var hub_btn := Button.new()
	hub_btn.text = "◀ ถอยทัพกลับป้อมปราการ"
	hub_btn.pressed.connect(func():
		_battle_ended = true
		get_tree().change_scene_to_file("res://scenes/hub_scene.tscn")
	)
	top_hbox.add_child(hub_btn)

	_header_label = Label.new()
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.add_theme_font_size_override("font_size", 15)
	_header_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	top_hbox.add_child(_header_label)

	var cutscene_btn := Button.new()
	cutscene_btn.text = "🎬 คัทซีนร่ายสกิล: เปิด"
	cutscene_btn.modulate = Color(1.0, 0.88, 0.38)
	cutscene_btn.pressed.connect(func():
		_cutscene_enabled = not _cutscene_enabled
		cutscene_btn.text = "🎬 คัทซีนร่ายสกิล: %s" % ("เปิด" if _cutscene_enabled else "ย่อ")
	)
	top_hbox.add_child(cutscene_btn)

	var spd_btn := Button.new()
	spd_btn.text = "⏩ ความเร็ว: 1x"
	spd_btn.pressed.connect(func():
		_speed_scale = 2.0 if _speed_scale == 1.0 else 1.0
		spd_btn.text = "⏩ ความเร็ว: %dx" % int(_speed_scale)
	)
	top_hbox.add_child(spd_btn)

	_skill_banner = Label.new()
	_skill_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_skill_banner.offset_top = 56
	_skill_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_banner.add_theme_font_size_override("font_size", 22)
	_skill_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
	root.add_child(_skill_banner)

	# แบนเนอร์คัทซีนคาดหน้าจอตอนร่ายสกิลเพิ่มพลัง (Cut-in Banner)
	_cutin_panel = PanelContainer.new()
	_cutin_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_cutin_panel.offset_top = 88
	_cutin_panel.offset_bottom = 225
	_cutin_panel.offset_left = 140
	_cutin_panel.offset_right = -140
	_cutin_panel.visible = false
	_cutin_panel.add_theme_stylebox_override("panel", _make_dark_panel_style(Color(0.06, 0.02, 0.12, 0.94), Color(1.0, 0.78, 0.22, 0.98)))
	root.add_child(_cutin_panel)

	var cutin_hbox := HBoxContainer.new()
	cutin_hbox.add_theme_constant_override("separation", 20)
	_cutin_panel.add_child(cutin_hbox)

	_cutin_portrait = TextureRect.new()
	_cutin_portrait.custom_minimum_size = Vector2(118, 118)
	_cutin_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cutin_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cutin_hbox.add_child(_cutin_portrait)

	var cutin_vbox := VBoxContainer.new()
	cutin_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cutin_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cutin_vbox.add_theme_constant_override("separation", 4)
	cutin_hbox.add_child(cutin_vbox)

	_cutin_speaker_lbl = Label.new()
	_cutin_speaker_lbl.add_theme_font_size_override("font_size", 18)
	_cutin_speaker_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 1.0))
	cutin_vbox.add_child(_cutin_speaker_lbl)

	_cutin_skill_lbl = Label.new()
	_cutin_skill_lbl.add_theme_font_size_override("font_size", 26)
	_cutin_skill_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
	cutin_vbox.add_child(_cutin_skill_lbl)

	_cutin_quote_lbl = Label.new()
	_cutin_quote_lbl.add_theme_font_size_override("font_size", 15)
	_cutin_quote_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 0.98))
	cutin_vbox.add_child(_cutin_quote_lbl)

	var bot_panel := PanelContainer.new()
	bot_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_panel.custom_minimum_size = Vector2(0, 165)
	bot_panel.offset_top = -165
	bot_panel.add_theme_stylebox_override("panel", _make_dark_panel_style())
	root.add_child(bot_panel)

	var bot_vbox := VBoxContainer.new()
	bot_vbox.add_theme_constant_override("separation", 5)
	bot_panel.add_child(bot_vbox)

	var queue_title := Label.new()
	queue_title.text = "⚡ สกิลสุ่มอัตโนมัติ (Random Skill 5v5) — คลิกปุ่มด้านล่างเพื่อสั่งจองสกิลประสาน (Covenant Skill) ในเทิร์นถัดไป:"
	queue_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.98))
	bot_vbox.add_child(queue_title)

	_queue_hbox = HBoxContainer.new()
	_queue_hbox.add_theme_constant_override("separation", 8)
	bot_vbox.add_child(_queue_hbox)

	_combat_log = RichTextLabel.new()
	_combat_log.bbcode_enabled = true
	_combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bot_vbox.add_child(_combat_log)

func _spawn_combatants() -> void:
	_allies.clear()
	_enemies.clear()

	var b_info: Dictionary = GameManager.pending_battle
	var b_type: String = str(b_info.get("battle_type", "normal"))
	var corr: int = int(b_info.get("corruption", GameManager.corruption_level))
	var chap: int = int(b_info.get("chapter", GameManager.current_chapter))

	var type_title: String = "ฝูงปีศาจดักซุ่ม"
	if b_type == "mini_boss":
		type_title = "★ MINI BOSS: ขุนพลอัศวินไร้เศียร ★"
	elif b_type == "main_boss":
		type_title = "☠ MAIN BOSS: จ้าวอสูรทมิฬแห่งหุบเขา ☠"

	_header_label.text = "  ⚔ ศึก 5v5: %s  |  แถว: %s  |  ความมืด: ระดับ %d" % [
		type_title, GameDefinitions.get_formation_name(GameManager.current_formation), corr
	]

	var syn: Dictionary = GameManager.get_team_synergy_summary()
	var syn_hp_bonus: float = float(syn["hp_bonus"])
	var syn_atk_bonus: float = float(syn["atk_bonus"])

	for i in range(5):
		var hid: String = GameManager.active_team[i]
		if hid == "" or not GameManager.character_db.has(hid):
			continue
		var cdata: Dictionary = GameManager.character_db[hid]
		var stats: Dictionary = GameManager.get_hero_computed_stats(hid)
		var row: GameDefinitions.RowPos = GameDefinitions.get_slot_row(GameManager.current_formation, i)
		var f_bonus: Dictionary = GameDefinitions.get_formation_bonus(GameManager.current_formation, row)
		var cov_ok: bool = GameManager.is_covenant_skill_active(hid, i, GameManager.active_team, GameManager.current_formation)

		var x_pos: float = -2.2 if row == GameDefinitions.RowPos.FRONT else -4.4
		var z_pos: float = (float(i) - 2.0) * 1.45
		var home_pos := Vector3(x_pos, 0.0, z_pos)

		var max_hp: int = int(round(float(stats["hp"]) * (1.0 + syn_hp_bonus)))
		var f_atk_mult: float = float(f_bonus["atk_mult"])
		var f_def_mult: float = float(f_bonus["def_mult"])

		var unit: Dictionary = _create_unit_node(
			hid,
			str(cdata["name"]).split(" ")[0],
			str(cdata["title"]),
			str(cdata["archetype"]),
			cdata["element"] as GameDefinitions.Element,
			row,
			home_pos,
			false,
			0.82,
			{
				"str": int(round(float(stats["str"]) * f_atk_mult * (1.0 + syn_atk_bonus))),
				"agi": int(stats["agi"]),
				"int": int(round(float(stats["int"]) * f_atk_mult * (1.0 + syn_atk_bonus))),
				"hp": max_hp,
				"max_hp": max_hp,
				"def": int(round(float(stats["def"]) * f_def_mult)),
				"stars": int(stats["stars"]),
				"skills": cdata["skills"],
				"covenant_skill": cdata["covenant_skill"],
				"covenant_active": cov_ok
			}
		)
		_allies.append(unit)

		var q_btn := Button.new()
		var u_name: String = str(unit["name"])
		q_btn.text = "%s %s" % [u_name, "★พร้อม!" if cov_ok else "(สกิลปกติ)"]
		q_btn.icon = ModelFactory.get_portrait_texture(str(cdata["archetype"]), false)
		q_btn.expand_icon = true
		q_btn.custom_minimum_size = Vector2(150, 36)
		q_btn.modulate = Color(1.0, 0.85, 0.35) if cov_ok else Color(0.82, 0.82, 0.88)
		var target_hid: String = hid
		var target_name: String = u_name
		q_btn.pressed.connect(func():
			_forced_covenant_hero_id = target_hid
			SoundManager.play_power_up_charge(self, false)
			_log("[color=#fbbf24]⚡ สั่งเน้นสกิลของ [b]%s[/b] ในเทิร์นถัดไป![/color]" % target_name)
		)
		_queue_hbox.add_child(q_btn)

	var scale_mult: float = (1.0 + float(chap - 1) * 0.25) * (1.0 + float(corr) * 0.08)
	var enemy_archetypes: Array[String] = ["knight", "assassin", "reaper", "mage", "assassin"]
	for i in range(5):
		var is_boss_slot: bool = (i == 2 and b_type in ["mini_boss", "main_boss"])
		var e_row: GameDefinitions.RowPos = GameDefinitions.RowPos.FRONT if i < 2 else GameDefinitions.RowPos.BACK
		var x_pos: float = 2.2 if e_row == GameDefinitions.RowPos.FRONT else 4.4
		var z_pos: float = (float(i) - 2.0) * 1.45
		var home_pos := Vector3(x_pos, 0.0, z_pos)

		var e_elem: GameDefinitions.Element = (i % 5) as GameDefinitions.Element
		var e_arch: String = enemy_archetypes[i]
		var e_name: String = "โครงกระดูกทมิฬ #%d" % (i + 1)
		var e_title: String = "นักรบวิญญาณอาฆาตแห่งหุบเขา"
		var hp_base: int = 250
		var atk_base: int = 24
		var model_scale: float = 0.80

		if is_boss_slot and b_type == "mini_boss":
			e_name = "★ขุนพลไร้เศียร★"
			e_title = "แม่ทัพปีศาจประจำด่านย่อย [Mini Boss]"
			e_arch = "reaper"
			hp_base = 580
			atk_base = 38
			model_scale = 1.12
		elif is_boss_slot and b_type == "main_boss":
			e_name = "☠จ้าวอสูรทมิฬ☠"
			e_title = "ราชันย์แห่งความมืดประจำด่านหลัก [Main Boss]"
			e_arch = "boss"
			hp_base = 860
			atk_base = 48
			model_scale = 1.28

		var final_hp: int = int(round(float(hp_base) * scale_mult))
		var final_atk: int = int(round(float(atk_base) * scale_mult))

		var enemy: Dictionary = _create_unit_node(
			"enemy_%d" % i,
			e_name,
			e_title,
			e_arch,
			e_elem,
			e_row,
			home_pos,
			true,
			model_scale,
			{
				"str": final_atk,
				"agi": randi_range(16, 30) + (6 if is_boss_slot else 0),
				"int": final_atk,
				"hp": final_hp,
				"max_hp": final_hp,
				"def": int(round(18.0 * scale_mult)),
				"stars": 3 if is_boss_slot else 1,
				"skills": [
					{"name": "คมดาบโครงกระดูก (Bone Slash)", "mult": 1.35, "stat": "str", "target": "single", "min_star": 1},
					{"name": "คลื่นคำสาปมืด (Dark Miasma)", "mult": 1.15, "stat": "int", "target": "aoe_3", "min_star": 1}
				],
				"covenant_skill": {
					"name": "☠ มหาคำสาปกลืนวิญญาณ (Boss Oblivion)",
					"mult": 1.65,
					"stat": "str",
					"target": "all"
				},
				"covenant_active": is_boss_slot
			}
		)
		_enemies.append(enemy)

func _create_unit_node(uid: String, uname: String, utitle: String, arch: String, elem: GameDefinitions.Element, row: GameDefinitions.RowPos, pos: Vector3, is_enemy: bool, model_scale: float, stats: Dictionary) -> Dictionary:
	var root_node := Node3D.new()
	root_node.position = pos
	add_child(root_node)

	var elem_col: Color = GameDefinitions.get_element_color(elem)
	var char_model: Node3D = ModelFactory.spawn_character_3d(uid, arch, elem_col, is_enemy, model_scale)
	char_model.rotation_degrees = Vector3(0, -90, 0) if is_enemy else Vector3(0, 90, 0)
	root_node.add_child(char_model)

	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 2.25 * model_scale + 0.35, 0)
	lbl.font_size = 22
	lbl.outline_size = 8
	root_node.add_child(lbl)

	var unit_dict: Dictionary = {
		"id": uid,
		"name": uname,
		"title": utitle,
		"archetype": arch,
		"element": elem,
		"row": row,
		"is_enemy": is_enemy,
		"home_pos": pos,
		"root": root_node,
		"model": char_model,
		"label": lbl,
		"stats": stats,
		"alive": true
	}
	_update_unit_overhead_label(unit_dict)
	return unit_dict

func _update_unit_overhead_label(u: Dictionary) -> void:
	var st: Dictionary = u["stats"]
	var cur_hp: int = int(st["hp"])
	var max_hp: int = int(st["max_hp"])
	var hp_pct: int = int(round(float(cur_hp) / float(max(1, max_hp)) * 100.0))
	var u_row: GameDefinitions.RowPos = u["row"]
	var row_tag: String = "หน้า" if u_row == GameDefinitions.RowPos.FRONT else "หลัง"
	var cov_active: bool = bool(st["covenant_active"])
	var cov_tag: String = " ★" if cov_active else ""
	var u_elem: GameDefinitions.Element = u["element"]
	var el_short: String = GameDefinitions.get_element_name(u_elem).split(" ")[0]
	var lbl: Label3D = u["label"]
	lbl.text = "%s [%s/%s]%s\nHP: %d/%d (%d%%)" % [
		str(u["name"]), row_tag, el_short, cov_tag, cur_hp, max_hp, hp_pct
	]
	if bool(u["is_enemy"]):
		lbl.modulate = Color(1.0, 0.58, 0.58)
	else:
		lbl.modulate = Color(1.0, 0.92, 0.45) if cov_active else Color(0.65, 0.98, 0.78)

func _run_battle_loop() -> void:
	_log("[b]🔥 เริ่มการต่อสู้ 5v5! แต่ละรอบตัวละครจะร่ายคัทซีนปลุกพลังพร้อมเสียงคำรามและพุ่งเข้าปะทะ! 🔥[/b]")
	await get_tree().create_timer(0.8).timeout

	var round_num: int = 1
	while not _battle_ended:
		_log("\n[b]--- รอบการรบที่ %d ---[/b]" % round_num)

		var turn_order: Array[Dictionary] = []
		for a in _allies:
			if bool(a["alive"]):
				turn_order.append(a)
		for e in _enemies:
			if bool(e["alive"]):
				turn_order.append(e)

		turn_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["stats"]["agi"]) > int(b["stats"]["agi"])
		)

		if _forced_covenant_hero_id != "":
			for idx in range(turn_order.size()):
				if str(turn_order[idx]["id"]) == _forced_covenant_hero_id:
					var picked: Dictionary = turn_order[idx]
					turn_order.remove_at(idx)
					turn_order.push_front(picked)
					break

		for actor in turn_order:
			if not bool(actor["alive"]) or _battle_ended:
				continue

			var is_en: bool = bool(actor["is_enemy"])
			var op_team: Array[Dictionary] = _enemies if not is_en else _allies
			var my_team: Array[Dictionary] = _allies if not is_en else _enemies
			if _count_alive(op_team) == 0:
				break

			await _execute_unit_turn(actor, my_team, op_team)

			if _count_alive(_enemies) == 0:
				_finish_battle(true)
				return
			elif _count_alive(_allies) == 0:
				_finish_battle(false)
				return

		round_num += 1
		await get_tree().create_timer(0.30 / _speed_scale).timeout

func _get_battle_cry_quote(actor: Dictionary, is_covenant: bool) -> String:
	if bool(actor["is_enemy"]):
		if is_covenant:
			return "\"จงจมลงสู่ห้วงอเวจีชั่วนิรันดร์!!\""
		var e_quotes: Array[String] = [
			"\"กร๊ากกกก! วิญญาณของพวกเจ้าต้องเป็นของข้า!\"",
			"\"ความมืดจะกลืนกินแสงสว่างสุดท้ายของเจ้า!\"",
			"\"คมดาบโครงกระดูกจะฉีกกระชากเนื้อของพวกเจ้า!\""
		]
		return e_quotes[randi() % e_quotes.size()]

	var arch: String = str(actor["archetype"])
	if is_covenant:
		return "\"ด้วยนามแห่งพันธสัญญามืด... จงรับการพิพากษาสูงสุด!!\""
	match arch:
		"knight": return "\"คมดาบโลหิตเล่มนี้ จะผ่าศัตรูให้สิ้นซาก!\""
		"mage": return "\"เปลวเพลิงแห่งเถ้าถ่านเอ๋ย จงเผาผลาญทุกสรรพสิ่ง!\""
		"assassin": return "\"ไร้เสียง ไร้เงา... ลมหายใจสุดท้ายของเจ้ามาถึงแล้ว!\""
		"cleric": return "\"หยาดเลือดศักดิ์สิทธิ์จะเยียวยาพันธมิตรและลงทัณฑ์อสูร!\""
		"reaper": return "\"เคียวแห่งรัตติกาลจะเก็บเกี่ยวดวงวิญญาณของเจ้า!\""
		_: return "\"เพื่อพันธสัญญาแห่งสนธยา... บุกทะลวง!!\""

## ลำดับคัทซีนการร่ายเพิ่มพลัง เสียงร้องก่อนออกสกิล และการพุ่งเข้าปะทะ
func _execute_unit_turn(actor: Dictionary, my_team: Array[Dictionary], op_team: Array[Dictionary]) -> void:
	var st: Dictionary = actor["stats"]
	var actor_id: String = str(actor["id"])
	var actor_name: String = str(actor["name"])
	var actor_title: String = str(actor["title"])
	var actor_arch: String = str(actor["archetype"])
	var is_en: bool = bool(actor["is_enemy"])
	var actor_model: Node3D = actor["model"]
	var actor_root: Node3D = actor["root"]
	var actor_elem: GameDefinitions.Element = actor["element"]
	var elem_col: Color = GameDefinitions.get_element_color(actor_elem)

	var chosen_skill: Dictionary = {}
	var is_covenant_cast: bool = false

	if bool(st["covenant_active"]) and (actor_id == _forced_covenant_hero_id or randf() < 0.42):
		chosen_skill = st["covenant_skill"]
		is_covenant_cast = true
		if actor_id == _forced_covenant_hero_id:
			_forced_covenant_hero_id = ""
	else:
		var unlocked_skills: Array = []
		var all_sk: Array = st["skills"]
		for sk in all_sk:
			if int(st["stars"]) >= int(sk.get("min_star", 1)):
				unlocked_skills.append(sk)
		if unlocked_skills.is_empty():
			unlocked_skills = all_sk
		chosen_skill = unlocked_skills[randi() % unlocked_skills.size()]

	var sk_name: String = str(chosen_skill["name"])
	_skill_banner.text = "⚡ %s ร่ายสกิล: %s!" % [actor_name, sk_name]
	_skill_banner.modulate = Color(1.0, 0.85, 0.25) if is_covenant_cast else elem_col.lightened(0.35)

	# =========================================================================
	# PHASE 1: ฉากคัทซีนการร่ายเพิ่มพลัง + เสียงร้องปลุกพลังก่อนออกสกิล (Power-Up Cutscene)
	# =========================================================================
	SoundManager.play_battle_cry(self, actor_id, actor_arch, is_en, is_covenant_cast)
	SoundManager.play_power_up_charge(self, is_covenant_cast)

	# แสดง Cut-in Banner คาดหน้าจอพร้อมคำพูดปลุกพลัง
	_show_cutin_banner(actor_name, actor_title, sk_name, _get_battle_cry_quote(actor, is_covenant_cast), actor_arch, is_en, elem_col, is_covenant_cast)

	# ตัวละครเล่นท่ายกอาวุธ/ร่ายมนตราปลุกพลัง + เสกเสาแสงเวทมนตร์และออร่าพุ่งขึ้นรอบตัว
	ModelFactory.play_character_anim(actor_model, "PowerUp", false)
	var aura_vfx: Node3D = _spawn_powerup_pillar_vfx(actor_root.position, elem_col, is_covenant_cast)

	if _cutscene_enabled:
		# ซูมกล้อง 3D เข้าไปหาผู้ร่ายในมุมต่ำเฉียง (Heroic Low-Angle Cutscene Camera)
		var dir_facing: float = 1.0 if not is_en else -1.0
		var cam_focus_pos: Vector3 = actor_root.position + Vector3(dir_facing * 2.35, 1.55, 2.55)
		var look_target: Vector3 = actor_root.position + Vector3(dir_facing * 0.35, 1.25, 0.0)

		_main_light.light_energy = 0.45
		_cutscene_light.position = actor_root.position + Vector3(dir_facing * 1.2, 2.4, 1.2)
		_cutscene_light.light_color = elem_col.lightened(0.25)
		_cutscene_light.light_energy = 5.5 if is_covenant_cast else 3.8

		var cam_tw := create_tween()
		cam_tw.tween_property(_camera, "position", cam_focus_pos, 0.22 / _speed_scale).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await cam_tw.finished
		_camera.look_at(look_target, Vector3.UP)

		var charge_wait: float = (0.58 if is_covenant_cast else 0.38) / _speed_scale
		await get_tree().create_timer(charge_wait).timeout
	else:
		await get_tree().create_timer(0.22 / _speed_scale).timeout

	_cutin_panel.visible = false
	if is_instance_valid(aura_vfx):
		aura_vfx.queue_free()

	# =========================================================================
	# PHASE 2: พุ่งทะยานเข้าโจมตี + เสียงเหวี่ยงอาวุธ + กล้องแพนตามจังหวะปะทะ
	# =========================================================================
	var targets: Array[Dictionary] = _pick_targets(op_team, str(chosen_skill.get("target", "single")))
	var primary_tgt_pos: Vector3 = Vector3.ZERO
	if not targets.is_empty():
		var first_t_root: Node3D = targets[0]["root"]
		primary_tgt_pos = first_t_root.position

	var dir: float = 1.0 if not is_en else -1.0
	var home_p: Vector3 = actor["home_pos"]
	var stat_key: String = str(chosen_skill.get("stat", "str"))
	var target_mode: String = str(chosen_skill.get("target", "single"))
	var is_magic_cast: bool = (stat_key == "int" or actor_arch in ["mage", "cleric"])

	var cast_pos: Vector3 = home_p + Vector3(dir * 1.55, 0.0, 0.0)
	if not is_magic_cast and not targets.is_empty():
		# สายประชิดพุ่งเข้าไปฟันถึงหน้าเป้าหมาย!
		cast_pos = primary_tgt_pos + Vector3(-dir * 1.35, 0.0, 0.0)

	# แพนกล้องกลับมาเห็นจังหวะปะทะอย่างทรงพลัง
	if _cutscene_enabled:
		var action_cam_pos: Vector3 = Vector3(primary_tgt_pos.x * 0.35, 3.6, 7.6)
		var action_tw := create_tween()
		action_tw.tween_property(_camera, "position", action_cam_pos, 0.16 / _speed_scale)
		action_tw.parallel().tween_property(_camera, "rotation_degrees", Vector3(-19, 0, 0), 0.16 / _speed_scale)

	ModelFactory.play_character_anim(actor_model, "Run", false)
	SoundManager.play_weapon_whoosh(self)

	var tw := create_tween()
	tw.tween_property(actor_root, "position", cast_pos, 0.18 / _speed_scale)
	await tw.finished

	# เล่นท่าฟันดาบ / หมุนตัวฟาด / ร่ายมหาเวท
	if is_magic_cast:
		ModelFactory.play_character_anim(actor_model, "Spell", false)
	elif target_mode in ["all", "aoe_3"] or is_covenant_cast:
		ModelFactory.play_character_anim(actor_model, "Attack_Spin", false)
	else:
		ModelFactory.play_character_anim(actor_model, "Attack_Melee", false)

	_spawn_skill_vfx_ring(actor_root.position + Vector3(dir * 0.9, 0.6, 0), elem_col, is_covenant_cast)

	var raw_power: float = float(st.get(stat_key, st["str"])) * float(chosen_skill.get("mult", 1.4))

	if target_mode == "heal_all":
		for ally in my_team:
			if bool(ally["alive"]):
				var heal_amt: int = int(round(raw_power * 1.15))
				var cur_h: int = int(ally["stats"]["hp"])
				var max_h: int = int(ally["stats"]["max_hp"])
				ally["stats"]["hp"] = min(max_h, cur_h + heal_amt)
				_update_unit_overhead_label(ally)
				var a_root: Node3D = ally["root"]
				_spawn_floating_text(a_root.position + Vector3(0, 2.2, 0), "+%d HP" % heal_amt, Color(0.35, 0.98, 0.55))
		_log("[color=#4ade80]✨ %s ร่าย [b]%s[/b] ฟื้นฟูพลังชีวิตให้ทั้งทีม![/color]" % [actor_name, sk_name])

	# =========================================================================
	# PHASE 3: จังหวะปะทะเป้าหมาย + เสียงปะทะหนักหน่วง + กล้องสั่นสะเทือน
	# =========================================================================
	var any_advantage: bool = false
	for tgt in targets:
		if not bool(tgt["alive"]):
			continue
		var tgt_elem: GameDefinitions.Element = tgt["element"]
		var elem_mult: float = GameDefinitions.get_element_multiplier(actor_elem, tgt_elem)
		if elem_mult > 1.05:
			any_advantage = true
		var def_mit: float = 100.0 / (100.0 + float(tgt["stats"]["def"]))
		var dmg: int = int(max(12.0, round(raw_power * elem_mult * def_mit * randf_range(0.92, 1.08))))

		var cur_t_hp: int = int(tgt["stats"]["hp"])
		tgt["stats"]["hp"] = max(0, cur_t_hp - dmg)
		_update_unit_overhead_label(tgt)

		var elem_tag: String = ""
		var pop_col := Color(1.0, 0.92, 0.85)
		if elem_mult > 1.05:
			elem_tag = " [ชนะธาตุ!]"
			pop_col = Color(1.0, 0.78, 0.20)
		elif elem_mult < 0.95:
			elem_tag = " [แพ้ธาตุ]"
			pop_col = Color(0.65, 0.75, 0.88)

		var t_root: Node3D = tgt["root"]
		var t_model: Node3D = tgt["model"]
		var tgt_name: String = str(tgt["name"])

		_spawn_hit_burst_vfx(t_root.position + Vector3(0, 1.0, 0), elem_col, is_covenant_cast)
		_spawn_floating_text(t_root.position + Vector3(0, 2.25, 0), "-%d%s" % [dmg, elem_tag], pop_col)
		_log("⚔ [b]%s[/b] ใช้ [color=#fbbf24]%s[/color] โจมตี [b]%s[/b] เสียหาย [color=#f87171]%d[/color]%s" % [
			actor_name, sk_name, tgt_name, dmg, elem_tag
		])

		if int(tgt["stats"]["hp"]) <= 0:
			tgt["alive"] = false
			ModelFactory.play_character_anim(t_model, "Death", false)
			lbl_fade_out(tgt["label"] as Label3D)
			_log("[color=#94a3b8]💀 %s สิ้นชีพในสนามรบ![/color]" % tgt_name)
		else:
			ModelFactory.play_character_anim(t_model, "Hit", false)
			_restore_idle_later(t_model, 0.48 / _speed_scale)

	# เล่นเสียงปะทะคมดาบ/ระเบิดเวท และสั่นกล้องตามความรุนแรง
	SoundManager.play_heavy_impact(self, is_magic_cast, is_covenant_cast or any_advantage)
	await _shake_camera(0.32 if is_covenant_cast else 0.16, 0.22 / _speed_scale)

	await get_tree().create_timer(0.28 / _speed_scale).timeout

	# คืนค่าแสงไฟและมุมกล้องกลับสู่ปกติ พร้อมถอยตัวละครกลับเข้าแถว
	_main_light.light_energy = 1.65
	_cutscene_light.light_energy = 0.0

	var tw_back := create_tween()
	tw_back.tween_property(actor_root, "position", home_p, 0.16 / _speed_scale)
	tw_back.parallel().tween_property(_camera, "position", _default_cam_pos, 0.20 / _speed_scale)
	tw_back.parallel().tween_property(_camera, "rotation_degrees", _default_cam_rot, 0.20 / _speed_scale)
	await tw_back.finished
	ModelFactory.play_character_anim(actor_model, "Idle", true)

func _show_cutin_banner(speaker: String, title: String, skill_name: String, quote: String, arch: String, is_en: bool, elem_col: Color, is_covenant: bool) -> void:
	_cutin_portrait.texture = ModelFactory.get_portrait_texture(arch, is_en)
	var prefix: String = "★ ท่าไม้ตายพันธสัญญา (COVENANT AWAKENING) ★" if is_covenant else "⚡ ปลุกพลังร่ายสกิล (SKILL UNLEASHED)"
	_cutin_speaker_lbl.text = "%s — %s (%s)" % [prefix, speaker, title]
	_cutin_skill_lbl.text = "🔥 %s 🔥" % skill_name
	_cutin_quote_lbl.text = quote
	_cutin_panel.add_theme_stylebox_override("panel", _make_dark_panel_style(
		Color(0.06, 0.02, 0.12, 0.94),
		Color(1.0, 0.85, 0.22, 1.0) if is_covenant else elem_col.lightened(0.25)
	))
	_cutin_panel.visible = true
	_cutin_panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_cutin_panel, "modulate:a", 1.0, 0.12 / _speed_scale)

## สร้างเสาแสงเวทมนตร์ 3D + วงแหวนรูนหมุนวน + พาร์ติเคิลพุ่งขึ้นรอบตัวละครตอนชาร์จเพิ่มพลัง
func _spawn_powerup_pillar_vfx(pos: Vector3, col: Color, is_covenant: bool) -> Node3D:
	var vfx_root := Node3D.new()
	vfx_root.position = pos
	add_child(vfx_root)

	# 1. เสาแสงพลังงานพุ่งขึ้นฟ้า (Glowing Cylinder Pillar)
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.15 if is_covenant else 0.80
	cyl.bottom_radius = 1.25 if is_covenant else 0.90
	cyl.height = 5.5
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(col.r, col.g, col.b, 0.32)
	p_mat.emission_enabled = true
	p_mat.emission = col.lightened(0.25)
	p_mat.emission_energy_multiplier = 3.8 if is_covenant else 2.2
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = p_mat
	pillar.mesh = cyl
	pillar.position = Vector3(0, 2.75, 0)
	pillar.scale = Vector3(0.2, 1.0, 0.2)
	vfx_root.add_child(pillar)

	# 2. วงแหวนเวทมนตร์พุ่งขึ้นตามลำตัว (Rising Magic Rings)
	for r_idx in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.75 + float(r_idx) * 0.25
		torus.outer_radius = 0.95 + float(r_idx) * 0.30
		var r_mat := StandardMaterial3D.new()
		r_mat.albedo_color = col.lightened(0.35)
		r_mat.emission_enabled = true
		r_mat.emission = col.lightened(0.35)
		r_mat.emission_energy_multiplier = 4.5
		torus.material = r_mat
		ring.mesh = torus
		ring.position = Vector3(0, 0.1 + float(r_idx) * 0.4, 0)
		vfx_root.add_child(ring)

		var r_tw := create_tween()
		r_tw.tween_property(ring, "position:y", 2.4 + float(r_idx) * 0.6, 0.45 / _speed_scale)
		r_tw.parallel().tween_property(ring, "scale", Vector3.ONE * 1.45, 0.45 / _speed_scale)

	# 3. ละอองพลังงานพุ่งกระจาย (CPUParticles3D)
	var particles := CPUParticles3D.new()
	particles.amount = 36 if is_covenant else 20
	particles.lifetime = 0.55
	particles.explosiveness = 0.25
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.08
	p_mesh.height = 0.16
	var pt_mat := StandardMaterial3D.new()
	pt_mat.albedo_color = col.lightened(0.4)
	pt_mat.emission_enabled = true
	pt_mat.emission = col.lightened(0.4)
	pt_mat.emission_energy_multiplier = 4.0
	p_mesh.material = pt_mat
	particles.mesh = p_mesh
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.95
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 28.0
	particles.gravity = Vector3(0, 4.5, 0)
	particles.initial_velocity_min = 2.5
	particles.initial_velocity_max = 5.2
	particles.emitting = true
	vfx_root.add_child(particles)

	var p_tw := create_tween()
	p_tw.tween_property(pillar, "scale", Vector3(1.15, 1.0, 1.15), 0.25 / _speed_scale)
	return vfx_root

## เอฟเฟกต์ระเบิดปะทะใส่เป้าหมาย (Impact Burst & Slash Flash)
func _spawn_hit_burst_vfx(pos: Vector3, col: Color, is_big: bool) -> void:
	var burst := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.45
	sph.height = 0.90
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.80, 0.85)
	mat.emission_enabled = true
	mat.emission = col.lightened(0.35)
	mat.emission_energy_multiplier = 5.0 if is_big else 3.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sph.material = mat
	burst.mesh = sph
	burst.position = pos
	add_child(burst)

	var target_scale: float = 3.2 if is_big else 2.0
	var tw := create_tween()
	tw.tween_property(burst, "scale", Vector3.ONE * target_scale, 0.24 / _speed_scale)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.24 / _speed_scale)
	tw.tween_callback(burst.queue_free)

## สั่นกล้องตอนอาวุธหรือสกิลกระแทกเป้าหมาย
func _shake_camera(intensity: float, duration: float) -> void:
	var base_pos: Vector3 = _camera.position
	var steps: int = 6
	var step_time: float = duration / float(steps)
	for _i in range(steps):
		_camera.position = base_pos + Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			0.0
		)
		await get_tree().create_timer(step_time).timeout
	_camera.position = base_pos

func _restore_idle_later(model_node: Node3D, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(model_node):
		ModelFactory.play_character_anim(model_node, "Idle", true)

func lbl_fade_out(lbl: Label3D) -> void:
	if lbl == null or not is_instance_valid(lbl):
		return
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 0.15, 0.5)

func _spawn_skill_vfx_ring(pos: Vector3, col: Color, is_big: bool) -> void:
	var vfx := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.45
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 4.5 if is_big else 2.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	torus.material = mat
	vfx.mesh = torus
	vfx.position = pos
	add_child(vfx)

	var max_sc: float = 4.5 if is_big else 2.6
	var tw := create_tween()
	tw.tween_property(vfx, "scale", Vector3.ONE * max_sc, 0.35 / _speed_scale)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35 / _speed_scale)
	tw.tween_callback(vfx.queue_free)

func _pick_targets(op_team: Array[Dictionary], mode: String) -> Array[Dictionary]:
	var alive_list: Array[Dictionary] = []
	var front_list: Array[Dictionary] = []
	var back_list: Array[Dictionary] = []

	for u in op_team:
		if bool(u["alive"]):
			alive_list.append(u)
			if u["row"] == GameDefinitions.RowPos.FRONT:
				front_list.append(u)
			else:
				back_list.append(u)

	if alive_list.is_empty():
		return []

	match mode:
		"all", "heal_all":
			return alive_list
		"aoe_3":
			alive_list.shuffle()
			return alive_list.slice(0, min(3, alive_list.size()))
		"backline":
			var pool: Array[Dictionary] = back_list if not back_list.is_empty() else alive_list
			return [pool[randi() % pool.size()]]
		"single_lowest":
			alive_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["stats"]["hp"]) < int(b["stats"]["hp"])
			)
			return [alive_list[0]]
		_:
			var pool: Array[Dictionary] = front_list if not front_list.is_empty() else alive_list
			return [pool[randi() % pool.size()]]

func _spawn_floating_text(pos: Vector3, txt: String, col: Color) -> void:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.text = txt
	l.font_size = 28
	l.outline_size = 8
	l.modulate = col
	add_child(l)

	var tw := create_tween()
	tw.tween_property(l, "position", pos + Vector3(0, 1.25, 0), 0.55)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.55)
	tw.tween_callback(l.queue_free)

func _count_alive(team: Array[Dictionary]) -> int:
	var c: int = 0
	for u in team:
		if bool(u["alive"]):
			c += 1
	return c

func _finish_battle(won: bool) -> void:
	_battle_ended = true
	GameManager.last_battle_won = won
	_cutin_panel.visible = false

	var b_info: Dictionary = GameManager.pending_battle
	var b_type: String = str(b_info.get("battle_type", "normal"))
	var tile_idx: int = int(b_info.get("tile_index", GameManager.board_position))

	if won:
		SoundManager.play_power_up_charge(self, true)
		for a in _allies:
			if bool(a["alive"]):
				ModelFactory.play_character_anim(a["model"] as Node3D, "Cheer", true)

		var gold_reward: int = 250 + GameManager.corruption_level * 40
		var gem_reward: int = 60
		if b_type == "mini_boss":
			gold_reward += 350
			gem_reward += 150
			GameManager.loaded_dice_count += 2
		elif b_type == "main_boss":
			gold_reward += 800
			gem_reward += 400
			GameManager.loaded_dice_count += 3

		GameManager.dark_gold += gold_reward
		GameManager.soul_gems += gem_reward
		if tile_idx >= 0 and tile_idx < GameManager.board_tiles.size():
			GameManager.board_tiles[tile_idx]["cleared"] = true

		_skill_banner.text = "🏆 ชัยชนะ! ได้รับ +%d ทองคำทมิฬ และ +%d ศิลาพันธสัญญา!" % [gold_reward, gem_reward]
		_skill_banner.modulate = Color(0.35, 0.98, 0.55)
		_log("\n[color=#4ade80][b]🏆 ชัยชนะ! กำลังพากองทัพกลับสู่กระดานสำรวจ...[/b][/color]")
	else:
		_skill_banner.text = "☠ พ่ายแพ้... จงไปอัปดาวและจัดแถวทีมใหม่!"
		_skill_banner.modulate = Color(0.98, 0.35, 0.35)
		_log("\n[color=#f87171][b]☠ กองทัพพ่ายแพ้... กำลังถอยกลับสู่กระดานสำรวจ...[/b][/color]")

	await get_tree().create_timer(2.4).timeout
	get_tree().change_scene_to_file("res://scenes/board_scene.tscn")

func _log(msg: String) -> void:
	_combat_log.text += "\n" + msg
	_combat_log.scroll_to_line(_combat_log.get_line_count() - 1)
