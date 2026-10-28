extends Node3D

var _stage_units_root: Node3D
var _ui_root: Control
var _top_bar_label: Label
var _status_toast: Label

var _starter_panel: PanelContainer
var _main_tabs_container: Control
var _team_panel: Control
var _gacha_panel: Control

var _selected_hero_id: String = ""
var _selected_slot_idx: int = 0
var _hero_detail_label: RichTextLabel
var _hero_list_vbox: VBoxContainer
var _slot_buttons: Array[Button] = []
var _formation_btn: Button
var _synergy_label: Label
var _gacha_result_box: RichTextLabel

func _ready() -> void:
	GameManager.ensure_initialized()
	_setup_3d_sanctuary()
	_setup_ui()

	if GameManager.main_hero_id == "":
		_starter_panel.visible = true
		_main_tabs_container.visible = false
	else:
		_selected_hero_id = GameManager.main_hero_id
		_starter_panel.visible = false
		_main_tabs_container.visible = true
		_refresh_all()

func _make_dark_panel_style(bg_col: Color = Color(0.06, 0.04, 0.10, 0.84), border_col: Color = Color(0.72, 0.55, 0.24, 0.85)) -> StyleBoxFlat:
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

func _setup_3d_sanctuary() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.02, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.26, 0.48)
	env.ambient_light_energy = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.05, 0.12)
	env.fog_density = 0.018
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.8, 7.2)
	cam.rotation_degrees = Vector3(-18, 0, 0)
	cam.fov = 46.0
	add_child(cam)

	var dir_light := DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-48, -22, 0)
	dir_light.light_color = Color(0.92, 0.82, 1.0)
	dir_light.light_energy = 1.6
	dir_light.shadow_enabled = true
	add_child(dir_light)

	# สร้างโถงปราสาทดันเจี้ยน 3D ด้วยโมเดล KayKit Dungeon Remastered
	ModelFactory.build_dark_dungeon_environment(self, 3, 2)

	# ประดับโล่ดาบทองคำและหีบสมบัติในโถงปราสาท
	add_child(ModelFactory.spawn_dungeon_prop("sword_shield_gold.gltf.glb", Vector3(0, 2.2, -6.05), Vector3.ZERO, Vector3.ONE * 1.3))
	add_child(ModelFactory.spawn_dungeon_prop("chest_gold.glb", Vector3(-3.8, 0.0, -3.2), Vector3(0, 25, 0), Vector3.ONE * 0.9))
	add_child(ModelFactory.spawn_dungeon_prop("chest.glb", Vector3(3.8, 0.0, -3.2), Vector3(0, -25, 0), Vector3.ONE * 0.9))

	_stage_units_root = Node3D.new()
	add_child(_stage_units_root)

func _rebuild_3d_team_preview() -> void:
	for child in _stage_units_root.get_children():
		child.queue_free()

	if GameManager.main_hero_id == "":
		return

	for i in range(5):
		var hid: String = GameManager.active_team[i]
		var row: GameDefinitions.RowPos = GameDefinitions.get_slot_row(GameManager.current_formation, i)
		var z_pos: float = 1.15 if row == GameDefinitions.RowPos.FRONT else -1.15
		var x_pos: float = (float(i) - 2.0) * 1.55

		# แท่นหินดันเจี้ยน 3D ใต้เท้าแต่ละตำแหน่ง
		var tile_pedestal: Node3D = ModelFactory.spawn_dungeon_prop(
			"floor_tile_small_decorated.gltf.glb",
			Vector3(x_pos, 0.02, z_pos),
			Vector3.ZERO,
			Vector3(0.72, 1.2, 0.72)
		)
		_stage_units_root.add_child(tile_pedestal)

		if hid != "" and GameManager.character_db.has(hid):
			var cdata: Dictionary = GameManager.character_db[hid]
			var el_col: Color = GameDefinitions.get_element_color(cdata["element"] as GameDefinitions.Element)
			var char_3d: Node3D = ModelFactory.spawn_character_3d(
				hid,
				str(cdata["archetype"]),
				el_col,
				false,
				0.82
			)
			char_3d.position = Vector3(x_pos, 0.08, z_pos)
			_stage_units_root.add_child(char_3d)

			if hid == _selected_hero_id:
				ModelFactory.play_character_anim(char_3d, "Cheer", false)

			var stats: Dictionary = GameManager.get_hero_computed_stats(hid)
			var cov_active: bool = GameManager.is_covenant_skill_active(hid, i, GameManager.active_team, GameManager.current_formation)
			var lbl := Label3D.new()
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(x_pos, 2.35, z_pos)
			lbl.font_size = 24
			lbl.outline_size = 8
			var short_name: String = str(cdata["name"]).split(" ")[0]
			lbl.text = "%s\n[%s★ Lv.%d]%s" % [
				short_name,
				str(stats.get("stars", 1)),
				int(stats.get("level", 1)),
				"\n★ สกิลประสานพร้อม!" if cov_active else ""
			]
			lbl.modulate = Color(1.0, 0.88, 0.32) if cov_active else Color.WHITE
			_stage_units_root.add_child(lbl)

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_ui_root)

	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.custom_minimum_size = Vector2(0, 54)
	top_panel.add_theme_stylebox_override("panel", _make_dark_panel_style())
	_ui_root.add_child(top_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 16)
	top_panel.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "  ⚔ TWILIGHT COVENANT"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.35))
	top_hbox.add_child(title_lbl)

	_top_bar_label = Label.new()
	_top_bar_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top_bar_label.add_theme_font_size_override("font_size", 15)
	top_hbox.add_child(_top_bar_label)

	var btn_team_tab := Button.new()
	btn_team_tab.text = "🛡 จัดทีม 5v5 & อัปเกรด"
	btn_team_tab.pressed.connect(func():
		_team_panel.visible = true
		_gacha_panel.visible = false
	)
	top_hbox.add_child(btn_team_tab)

	var btn_gacha_tab := Button.new()
	btn_gacha_tab.text = "🔮 อัญเชิญกาชา (Gacha)"
	btn_gacha_tab.pressed.connect(func():
		_team_panel.visible = false
		_gacha_panel.visible = true
	)
	top_hbox.add_child(btn_gacha_tab)

	var btn_board := Button.new()
	btn_board.text = "🎲 ออกศึกทอยเต๋า (ด่านดันเจี้ยน 3D) ▶"
	btn_board.modulate = Color(1.0, 0.78, 0.32)
	btn_board.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/board_scene.tscn")
	)
	top_hbox.add_child(btn_board)

	_status_toast = Label.new()
	_status_toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status_toast.offset_top = -30
	_status_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_toast.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	_ui_root.add_child(_status_toast)

	_main_tabs_container = Control.new()
	_main_tabs_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_tabs_container.offset_top = 58
	_main_tabs_container.offset_bottom = -32
	_ui_root.add_child(_main_tabs_container)

	_build_team_and_upgrade_panel()
	_build_gacha_panel()
	_build_starter_selection_modal()

func _build_starter_selection_modal() -> void:
	_starter_panel = PanelContainer.new()
	_starter_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_starter_panel.add_theme_stylebox_override("panel", _make_dark_panel_style(Color(0.04, 0.02, 0.07, 0.90)))
	_ui_root.add_child(_starter_panel)

	var center_vbox := VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 16)
	_starter_panel.add_child(center_vbox)

	var header := Label.new()
	header.text = "⚔ เลือก HERO หลักแห่งพันธสัญญามืด (Main Hero Selection) ⚔"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32))
	center_vbox.add_child(header)

	var sub := Label.new()
	sub.text = "Hero หลักที่คุณเลือกจะเป็นผู้นำทัพที่ต้องลงสนามรบ 5v5 เสมอ พร้อมโมเดล 3D และสกิลประสานเงื่อนไขเฉพาะตัว"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_vbox.add_child(sub)

	var cards_hbox := HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 22)
	center_vbox.add_child(cards_hbox)

	var starter_ids: Array[String] = ["hero_knight", "hero_mage", "hero_assassin"]
	for hid in starter_ids:
		var cdata: Dictionary = GameManager.character_db[hid]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(350, 460)
		var s_col: Color = cdata["secondary_color"]
		card.add_theme_stylebox_override("panel", _make_dark_panel_style(Color(0.08, 0.05, 0.14, 0.92), s_col))
		cards_hbox.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		card.add_child(vbox)

		var tex_rect := TextureRect.new()
		tex_rect.texture = ModelFactory.get_portrait_texture(str(cdata["archetype"]), false)
		tex_rect.custom_minimum_size = Vector2(140, 140)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(tex_rect)

		var name_lbl := Label.new()
		name_lbl.text = str(cdata["name"])
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", s_col.lightened(0.35))
		vbox.add_child(name_lbl)

		var info := RichTextLabel.new()
		info.bbcode_enabled = true
		info.fit_content = true
		info.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var bstats: Dictionary = cdata["base_stats"]
		var cov: Dictionary = cdata["covenant_skill"]
		info.text = "[b]ธาตุ:[/b] %s\n[b]สเตตัสเริ่มต้น:[/b] STR %d | AGI %d | INT %d | HP %d | DEF %d\n\n[color=#cbd5e1]%s[/color]\n\n[color=#fbbf24][b]%s[/b]\n%s[/color]" % [
			GameDefinitions.get_element_name(cdata["element"]),
			int(bstats["str"]), int(bstats["agi"]), int(bstats["int"]), int(bstats["hp"]), int(bstats["def"]),
			str(cdata["lore"]),
			str(cov["name"]), str(cov["desc"])
		]
		vbox.add_child(info)

		var pick_btn := Button.new()
		var short_n: String = str(cdata["name"]).split(" ")[0]
		pick_btn.text = "⚔ ทำพันธสัญญากับ %s" % short_n
		pick_btn.custom_minimum_size = Vector2(0, 42)
		pick_btn.modulate = Color(1.0, 0.85, 0.35)
		var picked_hid: String = hid
		pick_btn.pressed.connect(func():
			GameManager.select_starter_hero(picked_hid)
			_selected_hero_id = picked_hid
			_starter_panel.visible = false
			_main_tabs_container.visible = true
			SoundManager.play_battle_cry(self, picked_hid, str(cdata["archetype"]), false, true)
			SoundManager.play_power_up_charge(self, true)
			_refresh_all()
			_show_toast("เลือก Hero หลักสำเร็จ! ชมทีม 3D ของคุณกลางโถงปราสาท หรือกดออกศึกทอยเต๋าได้เลย!")
		)
		vbox.add_child(pick_btn)

func _build_team_and_upgrade_panel() -> void:
	_team_panel = HBoxContainer.new()
	_team_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_team_panel.add_theme_constant_override("separation", 10)
	_main_tabs_container.add_child(_team_panel)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(290, 0)
	left_panel.add_theme_stylebox_override("panel", _make_dark_panel_style())
	_team_panel.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_vbox)

	var left_title := Label.new()
	left_title.text = "📜 กองทัพในครอบครอง"
	left_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))
	left_vbox.add_child(left_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)

	_hero_list_vbox = VBoxContainer.new()
	_hero_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_hero_list_vbox)

	var center_col := VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.alignment = BoxContainer.ALIGNMENT_END
	_team_panel.add_child(center_col)

	var formation_box := PanelContainer.new()
	formation_box.add_theme_stylebox_override("panel", _make_dark_panel_style(Color(0.05, 0.03, 0.09, 0.80)))
	center_col.add_child(formation_box)

	var form_vbox := VBoxContainer.new()
	form_vbox.add_theme_constant_override("separation", 5)
	formation_box.add_child(form_vbox)

	var form_top_hbox := HBoxContainer.new()
	form_vbox.add_child(form_top_hbox)

	_formation_btn = Button.new()
	_formation_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formation_btn.pressed.connect(func():
		GameManager.current_formation = ((int(GameManager.current_formation) + 1) % 4) as GameDefinitions.FormationType
		_refresh_all()
		_show_toast("เปลี่ยนรูปแบบแถวเป็น: %s" % GameDefinitions.get_formation_name(GameManager.current_formation))
	)
	form_top_hbox.add_child(_formation_btn)

	_synergy_label = Label.new()
	_synergy_label.add_theme_font_size_override("font_size", 13)
	_synergy_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.72))
	form_vbox.add_child(_synergy_label)

	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 6)
	form_vbox.add_child(slots_hbox)

	_slot_buttons.clear()
	for i in range(5):
		var sbtn := Button.new()
		sbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sbtn.custom_minimum_size = Vector2(0, 56)
		var idx: int = i
		sbtn.pressed.connect(func():
			_selected_slot_idx = idx
			if _selected_hero_id != "":
				var res: Dictionary = GameManager.assign_hero_to_slot(idx, _selected_hero_id)
				_show_toast(str(res["msg"]))
				_refresh_all()
		)
		slots_hbox.add_child(sbtn)
		_slot_buttons.append(sbtn)

	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(340, 0)
	right_panel.add_theme_stylebox_override("panel", _make_dark_panel_style())
	_team_panel.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	_hero_detail_label = RichTextLabel.new()
	_hero_detail_label.bbcode_enabled = true
	_hero_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(_hero_detail_label)

	var upg_hbox := HBoxContainer.new()
	upg_hbox.add_theme_constant_override("separation", 8)
	right_vbox.add_child(upg_hbox)

	var btn_lvl := Button.new()
	btn_lvl.text = "⬆ อัปเลเวล (+Status)"
	btn_lvl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_lvl.custom_minimum_size = Vector2(0, 38)
	btn_lvl.pressed.connect(func():
		if _selected_hero_id != "":
			var r: Dictionary = GameManager.upgrade_hero_level(_selected_hero_id)
			if bool(r["ok"]):
				SoundManager.play_power_up_charge(self, false)
			_show_toast(str(r["msg"]))
			_refresh_all()
	)
	upg_hbox.add_child(btn_lvl)

	var btn_star := Button.new()
	btn_star.text = "★ อัปดาว (ปลดสกิล)"
	btn_star.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_star.custom_minimum_size = Vector2(0, 38)
	btn_star.modulate = Color(1.0, 0.85, 0.35)
	btn_star.pressed.connect(func():
		if _selected_hero_id != "":
			var r: Dictionary = GameManager.upgrade_hero_star(_selected_hero_id)
			if bool(r["ok"]):
				SoundManager.play_power_up_charge(self, true)
			_show_toast(str(r["msg"]))
			_refresh_all()
	)
	upg_hbox.add_child(btn_star)

func _build_gacha_panel() -> void:
	_gacha_panel = PanelContainer.new()
	_gacha_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gacha_panel.add_theme_stylebox_override("panel", _make_dark_panel_style(Color(0.05, 0.03, 0.09, 0.90)))
	_gacha_panel.visible = false
	_main_tabs_container.add_child(_gacha_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_gacha_panel.add_child(vbox)

	var title := Label.new()
	title.text = "🔮 แท่นอัญเชิญวิญญาณพันธสัญญามืด (Dark Covenant Gacha)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 1.0))
	vbox.add_child(title)

	var rates := Label.new()
	rates.text = "อัตราอัญเชิญ: Legendary (4.5%) | SSR (15.5%) | SR (34%) | R (46%) — หากได้ตัวละครซ้ำจะแปลงเป็นเศษวิญญาณ (Soul Shards) เพื่อใช้อัปดาว ★"
	rates.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rates)

	var btns_hbox := HBoxContainer.new()
	btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(btns_hbox)

	var btn_1 := Button.new()
	btn_1.text = "🔮 อัญเชิญ 1 ครั้ง (100 ศิลา)"
	btn_1.custom_minimum_size = Vector2(240, 48)
	btn_1.pressed.connect(func(): _do_gacha(1))
	btns_hbox.add_child(btn_1)

	var btn_10 := Button.new()
	btn_10.text = "🔥 อัญเชิญ 10 ครั้ง (900 ศิลา - ลดราคา!)"
	btn_10.custom_minimum_size = Vector2(300, 48)
	btn_10.modulate = Color(1.0, 0.82, 0.35)
	btn_10.pressed.connect(func(): _do_gacha(10))
	btns_hbox.add_child(btn_10)

	_gacha_result_box = RichTextLabel.new()
	_gacha_result_box.bbcode_enabled = true
	_gacha_result_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gacha_result_box.text = "[center]กดปุ่มด้านบนเพื่ออัญเชิญสหายแห่งความมืดเข้าสู่กองทัพของคุณ...[/center]"
	vbox.add_child(_gacha_result_box)

func _do_gacha(count: int) -> void:
	var res: Dictionary = GameManager.roll_gacha(count)
	_show_toast(str(res["msg"]))
	if not bool(res["ok"]):
		return

	var lines: Array[String] = ["[center][b]✨ ผลการอัญเชิญพันธสัญญา (%d ครั้ง) ✨[/b][/center]\n" % count]
	var res_list: Array = res["results"]
	for item in res_list:
		var r_col: String = GameDefinitions.get_rarity_color(item["rarity"]).to_html(false)
		var r_short: String = GameDefinitions.get_rarity_short(item["rarity"])
		var el_name: String = GameDefinitions.get_element_name(item["element"])
		var status_str: String = "[color=#4ade80][ตัวละครใหม่!][/color]" if bool(item["is_new"]) else "[color=#fbbf24][ซ้ำ -> +%d เศษวิญญาณอัปดาว][/color]" % int(item["shards_gained"])
		lines.append("• [color=#%s][b][%s] %s[/b][/color] (%s) %s" % [r_col, r_short, str(item["name"]), el_name, status_str])

	_gacha_result_box.text = "\n".join(lines)
	_refresh_all()

func _refresh_all() -> void:
	_top_bar_label.text = "💎 ศิลา: %d  |  🪙 ทองทมิฬ: %d  |  🎲 เต๋าสาป: %d" % [
		GameManager.soul_gems, GameManager.dark_gold, GameManager.loaded_dice_count
	]

	if GameManager.main_hero_id == "":
		return

	_rebuild_3d_team_preview()

	for child in _hero_list_vbox.get_children():
		child.queue_free()

	for hid_key in GameManager.owned_heroes.keys():
		var hid: String = str(hid_key)
		var cdata: Dictionary = GameManager.character_db[hid]
		var stats: Dictionary = GameManager.get_hero_computed_stats(hid)
		var in_team_idx: int = GameManager.active_team.find(hid)
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = ModelFactory.get_portrait_texture(str(cdata["archetype"]), false)
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(0, 42)
		var r_short: String = GameDefinitions.get_rarity_short(cdata["rarity"])
		var main_tag: String = " [หลัก]" if hid == GameManager.main_hero_id else ""
		var slot_tag: String = " [ช่อง %d]" % (in_team_idx + 1) if in_team_idx != -1 else ""
		var short_name: String = str(cdata["name"]).split(" ")[0]
		btn.text = "[%s] %s (%d★ Lv.%d)%s%s" % [
			r_short, short_name, int(stats["stars"]), int(stats["level"]), main_tag, slot_tag
		]
		btn.modulate = GameDefinitions.get_rarity_color(cdata["rarity"]).lightened(0.25)
		btn.pressed.connect(func():
			_selected_hero_id = hid
			_refresh_all()
			_show_toast("เลือก %s แล้ว (คลิกปุ่มช่องทีม 1-5 ด้านล่างเพื่อจัดลงตำแหน่งที่ต้องการ)" % short_name)
		)
		_hero_list_vbox.add_child(btn)

	_formation_btn.text = "🔄 รูปแบบจัดแถว (Formation): %s (คลิกเพื่อเปลี่ยน)" % GameDefinitions.get_formation_name(GameManager.current_formation)
	var syn: Dictionary = GameManager.get_team_synergy_summary()
	var desc_arr: Array = syn["descriptions"]
	_synergy_label.text = "🔥 บัฟธาตุทีม: " + " | ".join(PackedStringArray(desc_arr))

	for i in range(5):
		var hid: String = GameManager.active_team[i]
		var row: GameDefinitions.RowPos = GameDefinitions.get_slot_row(GameManager.current_formation, i)
		var row_str: String = "หน้า" if row == GameDefinitions.RowPos.FRONT else "หลัง"
		var h_name: String = "ว่าง"
		if hid != "" and GameManager.character_db.has(hid):
			h_name = str(GameManager.character_db[hid]["name"]).split(" ")[0]
		var cov_ok: bool = GameManager.is_covenant_skill_active(hid, i, GameManager.active_team, GameManager.current_formation)
		_slot_buttons[i].text = "#%d [%s]\n%s%s" % [i + 1, row_str, h_name, " ★" if cov_ok else ""]
		_slot_buttons[i].modulate = Color(1.0, 0.85, 0.35) if cov_ok else Color.WHITE

	_refresh_hero_detail()

func _refresh_hero_detail() -> void:
	if _selected_hero_id == "" or not GameManager.character_db.has(_selected_hero_id):
		_hero_detail_label.text = "เลือกตัวละครทางซ้ายเพื่อดูข้อมูล..."
		return

	var cdata: Dictionary = GameManager.character_db[_selected_hero_id]
	var stats: Dictionary = GameManager.get_hero_computed_stats(_selected_hero_id)
	var slot_idx: int = GameManager.active_team.find(_selected_hero_id)
	var cov_active: bool = false
	if slot_idx != -1:
		cov_active = GameManager.is_covenant_skill_active(_selected_hero_id, slot_idx, GameManager.active_team, GameManager.current_formation)

	var skills_text: String = ""
	var sk_list: Array = cdata["skills"]
	for sk in sk_list:
		var unlocked: bool = int(stats["stars"]) >= int(sk["min_star"])
		var col: String = "#4ade80" if unlocked else "#94a3b8"
		skills_text += "• [color=%s][b]%s[/b]: %s[/color]\n" % [col, str(sk["name"]), str(sk["desc"])]

	var cov: Dictionary = cdata["covenant_skill"]
	var cov_status: String = "[color=#4ade80][ทำงานแล้ว!][/color]" if cov_active else "[color=#f87171][ยังไม่ครบเงื่อนไข][/color]"

	_hero_detail_label.text = "[b][font_size=17]%s[/font_size][/b]\n[color=#cbd5e1]%s[/color]\n" % [str(cdata["name"]), str(cdata["title"])] + \
		"[b]ระดับ:[/b] %s  |  [b]ธาตุ:[/b] %s\n" % [GameDefinitions.get_rarity_name(cdata["rarity"]), GameDefinitions.get_element_name(cdata["element"])] + \
		"[b]ดาว:[/b] %d★ (เศษวิญญาณ: %d/%d)  |  [b]Lv.%d[/b]\n\n" % [int(stats["stars"]), int(stats["shards"]), int(stats["stars"]) * 20, int(stats["level"])] + \
		"[b]Status:[/b] STR %d | AGI %d | INT %d | HP %d | DEF %d\n\n" % [int(stats["str"]), int(stats["agi"]), int(stats["int"]), int(stats["hp"]), int(stats["def"])] + \
		"[b]สกิลสุ่ม (Random Skills):[/b]\n%s\n" % skills_text + \
		"[b][color=#fbbf24]%s[/color][/b] %s\n%s\n\n[i][color=#94a3b8]%s[/color][/i]" % [str(cov["name"]), cov_status, str(cov["desc"]), str(cdata["lore"])]

func _show_toast(msg: String) -> void:
	_status_toast.text = "🔔 " + msg
