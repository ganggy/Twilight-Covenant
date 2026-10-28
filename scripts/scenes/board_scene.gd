extends Node3D

var _tiles_3d: Array[Node3D] = []
var _player_token: Node3D
var _camera: Camera3D

var _info_label: Label
var _event_log: RichTextLabel
var _roll_btn: Button
var _loaded_btns_hbox: HBoxContainer
var _is_moving: bool = false

func _ready() -> void:
	GameManager.ensure_initialized()
	if GameManager.main_hero_id == "":
		GameManager.select_starter_hero("hero_knight")
	if GameManager.board_tiles.is_empty():
		GameManager.generate_new_board(1)

	_setup_3d_board()
	_setup_ui()
	_update_ui_state()

	if not GameManager.pending_battle.is_empty():
		var b_type: String = str(GameManager.pending_battle.get("battle_type", "normal"))
		GameManager.pending_battle.clear()
		if GameManager.last_battle_won:
			_append_log("[color=#4ade80][b]⚔ ชัยชนะ![/b] กองทัพของคุณสังหารศัตรูในช่องที่ %d สำเร็จ![/color]" % GameManager.board_position)
			if b_type == "main_boss":
				_append_log("[color=#fbbf24][b]👑 พิชิตบอสประจำด่านที่ %d สำเร็จ! ปลดล็อกด่านถัดไปและรับรางวัลใหญ่![/b][/color]" % GameManager.current_chapter)
				GameManager.generate_new_board(GameManager.current_chapter + 1)
				get_tree().reload_current_scene()
				return
		else:
			_append_log("[color=#f87171][b]☠ พ่ายแพ้...[/b] ทีมของคุณถอยร่นกลับมาตั้งหลักและค่าความมืดเพิ่มขึ้น![/color]")

func _make_dark_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.09, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.72, 0.55, 0.24, 0.85)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _get_tile_3d_pos(idx: int) -> Vector3:
	@warning_ignore("integer_division")
	var row: int = idx / 4
	var col: int = idx % 4
	if row % 2 == 1:
		col = 3 - col
	var x: float = (float(col) - 1.5) * 2.85
	var z: float = (1.5 - float(row)) * 2.55
	return Vector3(x, 0.0, z)

func _setup_3d_board() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.02, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.24, 0.44)
	env.ambient_light_energy = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.04, 0.11)
	env.fog_density = 0.014
	var w_env := WorldEnvironment.new()
	w_env.environment = env
	add_child(w_env)

	_camera = Camera3D.new()
	_camera.position = Vector3(0, 8.6, 8.8)
	_camera.rotation_degrees = Vector3(-44, 0, 0)
	_camera.fov = 46.0
	add_child(_camera)

	var dlight := DirectionalLight3D.new()
	dlight.rotation_degrees = Vector3(-55, 25, 0)
	dlight.light_color = Color(0.90, 0.80, 1.0)
	dlight.light_energy = 1.55
	dlight.shadow_enabled = true
	add_child(dlight)

	# สร้างฉากดันเจี้ยน 3D รอบกระดาน
	ModelFactory.build_dark_dungeon_environment(self, 3, 2)

	_tiles_3d.clear()
	for i in range(GameManager.board_tiles.size()):
		var tdata: Dictionary = GameManager.board_tiles[i]
		var t_type: GameDefinitions.TileType = tdata["type"]
		var is_cleared: bool = bool(tdata["cleared"])
		var pos: Vector3 = _get_tile_3d_pos(i)

		var tile_root := Node3D.new()
		tile_root.position = pos
		add_child(tile_root)

		# แท่นหินดันเจี้ยน 3D ประจำช่อง
		var tile_mesh: Node3D = ModelFactory.spawn_dungeon_prop(
			"floor_tile_small_decorated.gltf.glb",
			Vector3(0, 0.06, 0),
			Vector3.ZERO,
			Vector3(0.95, 1.4, 0.95)
		)
		tile_root.add_child(tile_mesh)

		# ขอบเรืองแสงบอกประเภทช่อง
		var indicator := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.05, 0.10, 2.05)
		var mat := StandardMaterial3D.new()
		var t_col: Color = _get_tile_color(t_type)
		mat.albedo_color = t_col
		mat.emission_enabled = true
		mat.emission = t_col
		mat.emission_energy_multiplier = 0.65
		box.material = mat
		indicator.mesh = box
		indicator.position = Vector3(0, 0.03, 0)
		tile_root.add_child(indicator)

		var lbl := Label3D.new()
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0, 1.85, 0)
		lbl.font_size = 22
		lbl.outline_size = 8
		lbl.text = "#%d %s" % [i, _get_tile_short_label(t_type)]
		tile_root.add_child(lbl)

		# วางโมเดล 3D ประจำช่องเหตุการณ์
		if not is_cleared:
			match t_type:
				GameDefinitions.TileType.TREASURE:
					tile_root.add_child(ModelFactory.spawn_dungeon_prop("chest_gold.glb", Vector3(0, 0.18, 0), Vector3.ZERO, Vector3.ONE * 0.72))
				GameDefinitions.TileType.TRAP:
					tile_root.add_child(ModelFactory.spawn_dungeon_prop("floor_tile_big_spikes.glb", Vector3(0, 0.14, 0), Vector3.ZERO, Vector3.ONE * 0.45))
				GameDefinitions.TileType.SHRINE:
					tile_root.add_child(ModelFactory.spawn_dungeon_prop("candle_triple.gltf.glb", Vector3(0, 0.18, 0), Vector3.ZERO, Vector3.ONE * 1.15))
				GameDefinitions.TileType.MONSTER:
					var m_3d: Node3D = ModelFactory.spawn_character_3d("enemy", "knight", Color(0.65, 0.22, 0.85), true, 0.50)
					m_3d.position = Vector3(0, 0.18, -0.2)
					tile_root.add_child(m_3d)
				GameDefinitions.TileType.MINI_BOSS:
					var mb_3d: Node3D = ModelFactory.spawn_character_3d("mini_boss", "reaper", Color(1.0, 0.42, 0.15), true, 0.75)
					mb_3d.position = Vector3(0, 0.18, 0)
					tile_root.add_child(mb_3d)
					lbl.position = Vector3(0, 2.35, 0)
					lbl.modulate = Color(1.0, 0.72, 0.25)
				GameDefinitions.TileType.MAIN_BOSS:
					var boss_3d: Node3D = ModelFactory.spawn_character_3d("main_boss", "boss", Color(1.0, 0.15, 0.25), true, 0.92)
					boss_3d.position = Vector3(0, 0.18, 0)
					tile_root.add_child(boss_3d)
					lbl.position = Vector3(0, 2.65, 0)
					lbl.modulate = Color(1.0, 0.35, 0.35)

		_tiles_3d.append(tile_root)

	# สร้างโมเดล 3D ตัวละครหลักของผู้เล่นบนกระดาน
	var cdata: Dictionary = GameManager.character_db[GameManager.main_hero_id]
	var el_col: Color = GameDefinitions.get_element_color(cdata["element"] as GameDefinitions.Element)
	_player_token = ModelFactory.spawn_character_3d(
		GameManager.main_hero_id,
		str(cdata["archetype"]),
		el_col,
		false,
		0.72
	)
	_player_token.position = _get_tile_3d_pos(GameManager.board_position) + Vector3(0, 0.18, 0.32)
	add_child(_player_token)

func _get_tile_color(t_type: GameDefinitions.TileType) -> Color:
	match t_type:
		GameDefinitions.TileType.START: return Color(0.22, 0.45, 0.65)
		GameDefinitions.TileType.MONSTER: return Color(0.38, 0.18, 0.52)
		GameDefinitions.TileType.TREASURE: return Color(0.85, 0.65, 0.15)
		GameDefinitions.TileType.TRAP: return Color(0.75, 0.14, 0.18)
		GameDefinitions.TileType.SHRINE: return Color(0.18, 0.68, 0.52)
		GameDefinitions.TileType.MINI_BOSS: return Color(0.90, 0.38, 0.12)
		GameDefinitions.TileType.MAIN_BOSS: return Color(0.95, 0.10, 0.22)
	return Color.GRAY

func _get_tile_short_label(t_type: GameDefinitions.TileType) -> String:
	match t_type:
		GameDefinitions.TileType.START: return "จุดเริ่มต้น"
		GameDefinitions.TileType.MONSTER: return "⚔ ปีศาจ"
		GameDefinitions.TileType.TREASURE: return "🎁 สมบัติ"
		GameDefinitions.TileType.TRAP: return "🩸 กับดัก"
		GameDefinitions.TileType.SHRINE: return "🕯 แท่นบูชา"
		GameDefinitions.TileType.MINI_BOSS: return "👹 MINI BOSS"
		GameDefinitions.TileType.MAIN_BOSS: return "☠ MAIN BOSS"
	return ""

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var top_bar := PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 52)
	top_bar.add_theme_stylebox_override("panel", _make_dark_panel_style())
	root.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 16)
	top_bar.add_child(top_hbox)

	var back_btn := Button.new()
	back_btn.text = "◀ กลับป้อมปราการ (จัดทีม / เปิดกาชา)"
	back_btn.pressed.connect(func():
		if not _is_moving:
			get_tree().change_scene_to_file("res://scenes/hub_scene.tscn")
	)
	top_hbox.add_child(back_btn)

	_info_label = Label.new()
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 15)
	top_hbox.add_child(_info_label)

	var reset_btn := Button.new()
	reset_btn.text = "🔄 รีเซ็ตด่าน"
	reset_btn.pressed.connect(func():
		if not _is_moving:
			GameManager.generate_new_board(GameManager.current_chapter)
			get_tree().reload_current_scene()
	)
	top_hbox.add_child(reset_btn)

	var bottom_panel := PanelContainer.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.custom_minimum_size = Vector2(0, 165)
	bottom_panel.offset_top = -165
	bottom_panel.add_theme_stylebox_override("panel", _make_dark_panel_style())
	root.add_child(bottom_panel)

	var bot_hbox := HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 16)
	bottom_panel.add_child(bot_hbox)

	_event_log = RichTextLabel.new()
	_event_log.bbcode_enabled = true
	_event_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_log.text = "[b]🎲 กระดานสำรวจหุบเขามืด 3D[/b]\nทอยลูกเต๋าเพื่อเดินสำรวจด่าน หากผ่านช่อง [color=#fbbf24]Mini Boss (#7)[/color] หรือ [color=#f87171]Main Boss (#15)[/color] จะต้องเข้าปะทะทันที!"
	bot_hbox.add_child(_event_log)

	var dice_vbox := VBoxContainer.new()
	dice_vbox.custom_minimum_size = Vector2(420, 0)
	dice_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_vbox.add_theme_constant_override("separation", 6)
	bot_hbox.add_child(dice_vbox)

	_roll_btn = Button.new()
	_roll_btn.text = "🎲 ทอยลูกเต๋าแห่งโชคชะตา (สุ่ม 1 - 6)"
	_roll_btn.custom_minimum_size = Vector2(0, 48)
	_roll_btn.modulate = Color(1.0, 0.85, 0.35)
	_roll_btn.pressed.connect(func():
		if not _is_moving:
			var roll: int = randi_range(1, 6)
			_execute_dice_move(roll, false)
	)
	dice_vbox.add_child(_roll_btn)

	var loaded_lbl := Label.new()
	loaded_lbl.text = "🎯 ใช้ลูกเต๋าต้องคำสาป (เลือกแต้มเดินได้ดั่งใจ):"
	loaded_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_vbox.add_child(loaded_lbl)

	_loaded_btns_hbox = HBoxContainer.new()
	_loaded_btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_loaded_btns_hbox.add_theme_constant_override("separation", 6)
	dice_vbox.add_child(_loaded_btns_hbox)

	for step in range(1, 7):
		var b := Button.new()
		b.text = "เดิน %d" % step
		b.custom_minimum_size = Vector2(58, 34)
		var s: int = step
		b.pressed.connect(func():
			if not _is_moving:
				if GameManager.loaded_dice_count <= 0:
					_append_log("[color=#f87171]ลูกเต๋าต้องคำสาปหมดแล้ว! (หาเพิ่มได้จากหีบสมบัติหรือชนะมินิบอส)[/color]")
					return
				GameManager.loaded_dice_count -= 1
				_execute_dice_move(s, true)
		)
		_loaded_btns_hbox.add_child(b)

func _execute_dice_move(steps: int, is_loaded: bool) -> void:
	_is_moving = true
	_roll_btn.disabled = true

	GameManager.corruption_level += 1
	var dice_tag: String = "ลูกเต๋าต้องคำสาป" if is_loaded else "ลูกเต๋าโชคชะตา"
	_append_log("🎲 ทอย%s ได้ [b][color=#fbbf24]%d แต้ม![/color][/b] (เกจความมืดเพิ่มขึ้นเป็น %d)" % [dice_tag, steps, GameManager.corruption_level])

	ModelFactory.play_character_anim(_player_token, "Run", true)
	SoundManager.play_weapon_whoosh(self)

	var current_idx: int = GameManager.board_position
	for _s in range(steps):
		if current_idx >= GameManager.board_tiles.size() - 1:
			break
		current_idx += 1
		GameManager.board_position = current_idx

		var target_pos: Vector3 = _get_tile_3d_pos(current_idx) + Vector3(0, 0.18, 0.32)
		var dir_vec: Vector3 = target_pos - _player_token.position
		dir_vec.y = 0
		if dir_vec.length_squared() > 0.01:
			_player_token.look_at(_player_token.position - dir_vec, Vector3.UP)

		var tw := create_tween()
		tw.tween_property(_player_token, "position", target_pos + Vector3(0, 0.45, 0), 0.15)
		tw.tween_property(_player_token, "position", target_pos, 0.13)
		await tw.finished
		SoundManager.play_weapon_whoosh(self)
		_update_ui_state()

		var check_tile: Dictionary = GameManager.board_tiles[current_idx]
		var c_type: GameDefinitions.TileType = check_tile["type"]
		if c_type in [GameDefinitions.TileType.MINI_BOSS, GameDefinitions.TileType.MAIN_BOSS] and not bool(check_tile["cleared"]):
			_append_log("[color=#f87171][b]⚠ บอสขวางเส้นทางข้างหน้า! ไม่สามารถเดินข้ามไปได้![/b][/color]")
			break

	ModelFactory.play_character_anim(_player_token, "Idle", true)
	_player_token.rotation_degrees = Vector3.ZERO
	await get_tree().create_timer(0.25).timeout
	_trigger_tile_event(GameManager.board_position)

func _trigger_tile_event(tile_idx: int) -> void:
	var tile: Dictionary = GameManager.board_tiles[tile_idx]
	var t_type: GameDefinitions.TileType = tile["type"]

	match t_type:
		GameDefinitions.TileType.TREASURE:
			var gems: int = randi_range(90, 160)
			var gold: int = randi_range(200, 380)
			GameManager.soul_gems += gems
			GameManager.dark_gold += gold
			ModelFactory.play_character_anim(_player_token, "Cheer", false)
			if randf() < 0.45:
				GameManager.loaded_dice_count += 1
				_append_log("[color=#fbbf24]🎁 เปิดหีบสมบัติต้องสาป! ได้รับ +%d ศิลาพันธสัญญา, +%d ทองคำทมิฬ และ +1 ลูกเต๋าต้องคำสาป![/color]" % [gems, gold])
			else:
				_append_log("[color=#fbbf24]🎁 เปิดหีบสมบัติต้องสาป! ได้รับ +%d ศิลาพันธสัญญา และ +%d ทองคำทมิฬ![/color]" % [gems, gold])
			tile["cleared"] = true
			_is_moving = false
			_roll_btn.disabled = false
			_update_ui_state()

		GameDefinitions.TileType.SHRINE:
			GameManager.corruption_level = max(0, GameManager.corruption_level - 2)
			var cur_sh: int = int(GameManager.owned_heroes[GameManager.main_hero_id]["shards"])
			GameManager.owned_heroes[GameManager.main_hero_id]["shards"] = cur_sh + 10
			ModelFactory.play_character_anim(_player_token, "Spell", false)
			_append_log("[color=#4ade80]🕯 แท่นบูชาเพลิงวิญญาณ! ชำระล้างความมืดลง 2 ระดับ และมอบเศษวิญญาณ +10 ชิ้นให้ Hero หลัก![/color]")
			tile["cleared"] = true
			_is_moving = false
			_roll_btn.disabled = false
			_update_ui_state()

		GameDefinitions.TileType.TRAP:
			GameManager.corruption_level += 2
			ModelFactory.play_character_anim(_player_token, "Hit", false)
			_append_log("[color=#f87171]🩸 เหยียบกับดักหนามโลหิต! ความมืดพุ่งสูงขึ้น +2 และเรียกฝูงปีศาจออกมาจู่โจม![/color]")
			await get_tree().create_timer(0.6).timeout
			_start_battle("normal", tile_idx)

		GameDefinitions.TileType.MONSTER:
			_append_log("[color=#c084fc]⚔ เผชิญหน้าฝูงปีศาจดักซุ่มที่ช่อง #%d! เตรียมจัดทัพ 5v5 เข้าปะทะ![/color]" % tile_idx)
			await get_tree().create_timer(0.6).timeout
			_start_battle("normal", tile_idx)

		GameDefinitions.TileType.MINI_BOSS:
			_append_log("[color=#fb923c][b]👹 ปะทะบอสประจำด่านเล็ก (Mini Boss): ขุนพลอัศวินไร้เศียร![/b][/color]")
			await get_tree().create_timer(0.7).timeout
			_start_battle("mini_boss", tile_idx)

		GameDefinitions.TileType.MAIN_BOSS:
			_append_log("[color=#f87171][b]☠ ปะทะบอสประจำด่านหลัก (Main Boss): จ้าวอสูรทมิฬแห่งหุบเขา![/b][/color]")
			await get_tree().create_timer(0.7).timeout
			_start_battle("main_boss", tile_idx)

		_:
			_is_moving = false
			_roll_btn.disabled = false
			_update_ui_state()

func _start_battle(b_type: String, tile_idx: int) -> void:
	GameManager.pending_battle = {
		"battle_type": b_type,
		"tile_index": tile_idx,
		"chapter": GameManager.current_chapter,
		"corruption": GameManager.corruption_level
	}
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")

func _append_log(bbcode_line: String) -> void:
	_event_log.text += "\n" + bbcode_line
	_event_log.scroll_to_line(_event_log.get_line_count() - 1)

func _update_ui_state() -> void:
	_info_label.text = "🏰 ด่านที่ %d  |  📍 ช่อง: %d/15  |  🌑 ความมืด: %d (+%d%% พลังปีศาจ & รางวัล)  |  🎲 เต๋าสาป: %d  |  💎 ศิลา: %d" % [
		GameManager.current_chapter,
		GameManager.board_position,
		GameManager.corruption_level,
		GameManager.corruption_level * 8,
		GameManager.loaded_dice_count,
		GameManager.soul_gems
	]
