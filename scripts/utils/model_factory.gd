class_name ModelFactory
extends RefCounted

static var _scene_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _char_shader: Shader = null
static var _dungeon_shader: Shader = null

static func load_glb(res_path: String) -> PackedScene:
	if _scene_cache.has(res_path):
		return _scene_cache[res_path]
	if ResourceLoader.exists(res_path):
		var ps: PackedScene = load(res_path) as PackedScene
		if ps != null:
			_scene_cache[res_path] = ps
			return ps
	return null

static func get_portrait_texture(archetype: String, is_enemy: bool = false) -> Texture2D:
	# ใช้ภาพอาร์ต Dark Fantasy แท้ๆ ก่อน หากยังไม่มีจึง fallback ไปที่ภาพเดิม
	var dark_path: String = "res://assets/portraits/dark_knight.jpg"
	if is_enemy:
		match archetype:
			"mage": dark_path = "res://assets/portraits/dark_reaper.jpg"
			"assassin": dark_path = "res://assets/portraits/dark_assassin.jpg"
			"reaper", "boss": dark_path = "res://assets/portraits/dark_boss.jpg"
			_: dark_path = "res://assets/portraits/dark_boss.jpg"
	else:
		match archetype:
			"knight": dark_path = "res://assets/portraits/dark_knight.jpg"
			"mage": dark_path = "res://assets/portraits/dark_mage.jpg"
			"assassin": dark_path = "res://assets/portraits/dark_assassin.jpg"
			"cleric": dark_path = "res://assets/portraits/dark_cleric.jpg"
			"reaper": dark_path = "res://assets/portraits/dark_reaper.jpg"
			"boss": dark_path = "res://assets/portraits/dark_boss.jpg"
			_: dark_path = "res://assets/portraits/dark_knight.jpg"

	if _tex_cache.has(dark_path):
		return _tex_cache[dark_path]

	# โหลดจากไฟล์ภาพบนดิสก์โดยตรง (รองรับทั้งไฟล์ที่ import แล้วและเพิ่งสร้างใหม่)
	var abs_dark_path: String = ProjectSettings.globalize_path(dark_path)
	if FileAccess.file_exists(abs_dark_path):
		var img := Image.load_from_file(abs_dark_path)
		if img != null and not img.is_empty():
			var itex := ImageTexture.create_from_image(img)
			_tex_cache[dark_path] = itex
			return itex

	if ResourceLoader.exists(dark_path):
		var tex: Texture2D = load(dark_path) as Texture2D
		if tex != null:
			_tex_cache[dark_path] = tex
			return tex

	# Fallback
	var fallback_path: String = "res://assets/portraits/knight.png"
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path) as Texture2D
	return SpriteGenerator.get_unit_texture(archetype, Color.DARK_SLATE_BLUE, Color.GOLD, is_enemy)

static func get_character_glb_path(hero_id: String, archetype: String, is_enemy: bool = false) -> String:
	if is_enemy:
		match archetype:
			"mage": return "res://assets/models/characters/Skeleton_Mage.glb"
			"assassin": return "res://assets/models/characters/Skeleton_Rogue.glb"
			"reaper", "boss": return "res://assets/models/characters/Skeleton_Warrior.glb"
			_: return "res://assets/models/characters/Skeleton_Minion.glb"

	match hero_id:
		"hero_knight", "gacha_vanguard_r", "gacha_valkyrie_leg":
			return "res://assets/models/characters/Knight.glb"
		"hero_mage", "gacha_cultist_r", "gacha_cleric_sr":
			return "res://assets/models/characters/Mage.glb"
		"hero_assassin":
			return "res://assets/models/characters/Rogue_Hooded.glb"
		"gacha_archer_r", "gacha_druid_sr":
			return "res://assets/models/characters/Rogue.glb"
		"gacha_berserker_sr", "gacha_archdemon_leg":
			return "res://assets/models/characters/Barbarian.glb"
		"gacha_reaper_ssr":
			return "res://assets/models/characters/Skeleton_Mage.glb"

	match archetype:
		"knight": return "res://assets/models/characters/Knight.glb"
		"mage", "cleric": return "res://assets/models/characters/Mage.glb"
		"assassin": return "res://assets/models/characters/Rogue_Hooded.glb"
		"reaper": return "res://assets/models/characters/Skeleton_Mage.glb"
		"boss": return "res://assets/models/characters/Barbarian.glb"
	return "res://assets/models/characters/Knight.glb"

## สร้าง Shader สำหรับเปลี่ยนโมเดลการ์ตูนให้กลายเป็นเกราะเหล็กดำทมิฬ + ขอบแสงไฟอเวจี (Dark Souls / Gothic Armor Shader)
static func _get_dark_character_shader() -> Shader:
	if _char_shader != null:
		return _char_shader
	_char_shader = Shader.new()
	_char_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D base_tex : source_color, filter_linear_mipmap;
uniform vec4 dark_armor_tint : source_color = vec4(0.10, 0.08, 0.14, 1.0);
uniform vec4 rim_glow_color : source_color = vec4(0.95, 0.18, 0.25, 1.0);
uniform float rim_power : hint_range(1.0, 8.0) = 2.6;
uniform float rim_intensity : hint_range(0.0, 5.0) = 1.85;

void fragment() {
	vec4 tex_col = texture(base_tex, UV);
	float luma = dot(tex_col.rgb, vec3(0.299, 0.587, 0.114));
	// ดูดสีการ์ตูนสดใสออก และบีบ Contrast ให้กลายเป็นเกราะเหล็กดำ/ผ้าคลุมทมิฬ
	vec3 desaturated = mix(vec3(luma), tex_col.rgb, 0.28);
	vec3 obsidian = pow(desaturated, vec3(1.85)) * 0.42;
	vec3 final_albedo = mix(obsidian, dark_armor_tint.rgb * luma * 1.35, 0.55);

	ALBEDO = final_albedo;
	METALLIC = 0.78;
	ROUGHNESS = 0.26;

	// ขอบแสง Fresnel Rim Light เรืองแสงตามธาตุ Dark Fantasy
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	// ส่วนที่สว่างมากบนอาวุธ/ขอบเกราะให้เรืองแสงรูนธาตุ
	float rune_mask = smoothstep(0.68, 0.92, luma) * 0.45;
	EMISSION = rim_glow_color.rgb * (fresnel * rim_intensity + rune_mask * 1.4);
}
"""
	return _char_shader

static func _get_dark_dungeon_shader() -> Shader:
	if _dungeon_shader != null:
		return _dungeon_shader
	_dungeon_shader = Shader.new()
	_dungeon_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D base_tex : source_color, filter_linear_mipmap;

void fragment() {
	vec4 tex_col = texture(base_tex, UV);
	float luma = dot(tex_col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(vec3(luma), tex_col.rgb, 0.35);
	// ย้อมหินดันเจี้ยนให้เป็นหินโบราณสีดำอมม่วงเปียกชื้น
	ALBEDO = pow(desat, vec3(1.65)) * vec3(0.38, 0.34, 0.46);
	METALLIC = 0.35;
	ROUGHNESS = 0.42;
}
"""
	return _dungeon_shader

static func _apply_dark_shader_recursive(node: Node, elem_color: Color, is_enemy: bool) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			for surf_idx in range(mi.mesh.get_surface_count()):
				var orig_mat: Material = mi.get_active_material(surf_idx)
				var smat := ShaderMaterial.new()
				smat.shader = _get_dark_character_shader()
				if orig_mat is BaseMaterial3D:
					var bmat: BaseMaterial3D = orig_mat as BaseMaterial3D
					if bmat.albedo_texture != null:
						smat.set_shader_parameter("base_tex", bmat.albedo_texture)
				var armor_tint: Color = Color(0.14, 0.05, 0.08) if is_enemy else elem_color.darkened(0.68)
				var glow_col: Color = Color(1.0, 0.15, 0.22) if is_enemy else elem_color.lightened(0.15)
				smat.set_shader_parameter("dark_armor_tint", armor_tint)
				smat.set_shader_parameter("rim_glow_color", glow_col)
				smat.set_shader_parameter("rim_intensity", 2.1 if is_enemy else 1.75)
				mi.set_surface_override_material(surf_idx, smat)

	for child in node.get_children():
		_apply_dark_shader_recursive(child, elem_color, is_enemy)

static func _apply_dark_dungeon_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			for surf_idx in range(mi.mesh.get_surface_count()):
				var orig_mat: Material = mi.get_active_material(surf_idx)
				if orig_mat is BaseMaterial3D:
					var bmat: BaseMaterial3D = orig_mat as BaseMaterial3D
					var smat := ShaderMaterial.new()
					smat.shader = _get_dark_dungeon_shader()
					if bmat.albedo_texture != null:
						smat.set_shader_parameter("base_tex", bmat.albedo_texture)
					mi.set_surface_override_material(surf_idx, smat)
	for child in node.get_children():
		_apply_dark_dungeon_recursive(child)

## ติดตั้งอุปกรณ์เสริม Dark Fantasy (ดวงตาไฟนรก, วงแหวนสุริยะทมิฬ/เขาอสูร, และควันเงาทมิฬ)
static func _attach_dark_fantasy_accents(wrapper: Node3D, model_inst: Node3D, hero_id: String, archetype: String, elem_color: Color, is_enemy: bool, scale_factor: float) -> void:
	var glow_col: Color = Color(1.0, 0.16, 0.20) if is_enemy else elem_color.lightened(0.25)

	# 1. ดวงตาเรืองแสงไฟอเวจีใต้หมวกเหล็ก/ฮู้ด (Abyssal Glowing Eyes)
	var head_bone: Node3D = model_inst.find_child("Head", true, false) as Node3D
	var eye_parent: Node3D = head_bone if head_bone != null else model_inst
	var eye_y: float = 0.35 if head_bone != null else 1.75
	var eye_z: float = 0.38 if head_bone != null else 0.35

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = glow_col
	eye_mat.emission_enabled = true
	eye_mat.emission = glow_col
	eye_mat.emission_energy_multiplier = 6.0

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var esph := SphereMesh.new()
		esph.radius = 0.048
		esph.height = 0.075
		esph.material = eye_mat
		eye.mesh = esph
		eye.position = Vector3(side * 0.13, eye_y, eye_z)
		eye_parent.add_child(eye)

	# 2. วงแหวนสุริยะทมิฬและหนามอสูรด้านหลัง (Dark Souls / Seven Knights Awakened Back Halo)
	var is_special: bool = (hero_id in ["hero_knight", "hero_mage", "hero_assassin", "gacha_reaper_ssr", "gacha_archdemon_leg", "gacha_valkyrie_leg"]) or (archetype in ["boss", "reaper"])
	if is_special:
		var halo_mesh := MeshInstance3D.new()
		var h_torus := TorusMesh.new()
		h_torus.inner_radius = 0.52 * scale_factor
		h_torus.outer_radius = 0.60 * scale_factor
		var h_mat := StandardMaterial3D.new()
		h_mat.albedo_color = Color(0.08, 0.04, 0.12)
		h_mat.emission_enabled = true
		h_mat.emission = glow_col
		h_mat.emission_energy_multiplier = 3.2
		h_torus.material = h_mat
		halo_mesh.mesh = h_torus
		halo_mesh.rotation_degrees = Vector3(90, 0, 0)
		halo_mesh.position = Vector3(0, 1.55 * scale_factor, -0.35 * scale_factor)
		wrapper.add_child(halo_mesh)

	# 3. ควันเงามืดและสะเก็ดไฟอเวจีลอยขึ้นจากร่างตัวละครตลอดเวลา (Shadow Miasma & Ember Aura)
	var miasma := CPUParticles3D.new()
	miasma.amount = 14
	miasma.lifetime = 1.2
	var m_mesh := SphereMesh.new()
	m_mesh.radius = 0.09 * scale_factor
	m_mesh.height = 0.18 * scale_factor
	var m_mat := StandardMaterial3D.new()
	m_mat.albedo_color = Color(0.05, 0.02, 0.08, 0.65)
	m_mat.emission_enabled = true
	m_mat.emission = glow_col.darkened(0.35)
	m_mat.emission_energy_multiplier = 1.8
	m_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_mesh.material = m_mat
	miasma.mesh = m_mesh
	miasma.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	miasma.emission_sphere_radius = 0.48 * scale_factor
	miasma.direction = Vector3(0, 1, 0)
	miasma.spread = 20.0
	miasma.gravity = Vector3(0, 1.2, 0)
	miasma.initial_velocity_min = 0.3
	miasma.initial_velocity_max = 0.8
	miasma.position = Vector3(0, 0.7 * scale_factor, 0)
	miasma.emitting = true
	wrapper.add_child(miasma)

## เสกตัวละคร 3D สไตล์ Dark Fantasy พร้อมเกราะเหล็กทมิฬ ดวงตาเรืองแสง และวงเวทย์ใต้เท้า
static func spawn_character_3d(hero_id: String, archetype: String, elem_color: Color, is_enemy: bool = false, scale_factor: float = 0.85) -> Node3D:
	var wrapper := Node3D.new()

	# วงเวทย์เรืองแสงใต้เท้าตามสีธาตุ Dark Fantasy
	var ring_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.56 * scale_factor
	torus.outer_radius = 0.68 * scale_factor
	var ring_mat := StandardMaterial3D.new()
	var glow_col: Color = Color(1.0, 0.16, 0.22) if is_enemy else elem_color
	ring_mat.albedo_color = glow_col
	ring_mat.emission_enabled = true
	ring_mat.emission = glow_col
	ring_mat.emission_energy_multiplier = 2.6
	torus.material = ring_mat
	ring_mesh.mesh = torus
	ring_mesh.position = Vector3(0, 0.04, 0)
	wrapper.add_child(ring_mesh)

	var glb_path: String = get_character_glb_path(hero_id, archetype, is_enemy)
	var ps: PackedScene = load_glb(glb_path)
	if ps != null:
		var model_inst: Node3D = ps.instantiate() as Node3D
		model_inst.name = "Model3D"
		# ปรับสัดส่วนให้สูงเพรียวสมจริง ไม่ดูเตี้ยตันหัวโตแบบการ์ตูน
		model_inst.scale = Vector3(0.76 * scale_factor, 1.14 * scale_factor, 0.76 * scale_factor)
		wrapper.add_child(model_inst)

		# ลง Dark Gothic Armor Shader ทับทั้งตัวและอาวุธ
		_apply_dark_shader_recursive(model_inst, elem_color, is_enemy)
		# ติดดวงตาไฟนรก วงแหวนสุริยะทมิฬ และออร่าควันดำ
		_attach_dark_fantasy_accents(wrapper, model_inst, hero_id, archetype, elem_color, is_enemy, scale_factor)

		play_character_anim(wrapper, "Idle", true)
	else:
		var spr := Sprite3D.new()
		spr.texture = get_portrait_texture(archetype, is_enemy)
		spr.pixel_size = 0.004
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.position = Vector3(0, 1.1, 0)
		wrapper.add_child(spr)

	return wrapper

static func play_character_anim(unit_wrapper: Node3D, anim_type: String, loop_idle: bool = false) -> void:
	if unit_wrapper == null or not is_instance_valid(unit_wrapper):
		return
	var ap: AnimationPlayer = unit_wrapper.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return

	var candidates: Array[String] = []
	match anim_type:
		"Idle":
			candidates = ["2H_Melee_Idle", "Idle", "Unarmed_Idle"]
		"Walk", "Run":
			candidates = ["Running_A", "Walking_A", "Jump_Full_Short"]
		"PowerUp":
			candidates = ["Spellcast_Raise", "Spellcast_Long", "Cheer", "2H_Melee_Attack_Spin"]
		"Attack_Melee":
			candidates = ["2H_Melee_Attack_Slice", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop", "Dualwield_Melee_Attack_Slice"]
		"Attack_Spin":
			candidates = ["2H_Melee_Attack_Spin", "Dualwield_Melee_Attack_Slice", "Spellcast_Long"]
		"Spell":
			candidates = ["Spellcast_Shoot", "Spellcast_Raise", "Spellcast_Long", "1H_Melee_Attack_Slice_Diagonal"]
		"Hit":
			candidates = ["Hit_A", "Hit_B"]
		"Death":
			candidates = ["Death_A", "Death_B"]
		"Cheer":
			candidates = ["Cheer", "Jump_Full_Short"]
		_:
			candidates = [anim_type, "Idle"]

	var picked: String = ""
	var anim_list: PackedStringArray = ap.get_animation_list()
	for c in candidates:
		if c in anim_list:
			picked = c
			break

	if picked == "" and anim_list.size() > 0:
		picked = anim_list[0]

	if picked != "":
		var anim_res: Animation = ap.get_animation(picked)
		if anim_res != null and loop_idle:
			anim_res.loop_mode = Animation.LOOP_LINEAR
		ap.play(picked)

static func spawn_dungeon_prop(file_name: String, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scale_val: Vector3 = Vector3.ONE, apply_dark_stone: bool = true) -> Node3D:
	var path: String = "res://assets/models/dungeon/" + file_name
	var ps: PackedScene = load_glb(path)
	if ps == null:
		return Node3D.new()
	var inst: Node3D = ps.instantiate() as Node3D
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.scale = scale_val
	if apply_dark_stone:
		_apply_dark_dungeon_recursive(inst)
	return inst

static func build_dark_dungeon_environment(parent: Node3D, width_tiles: int = 5, depth_tiles: int = 3) -> void:
	var env_root := Node3D.new()
	env_root.name = "DungeonEnvironment3D"
	parent.add_child(env_root)

	for gx in range(-width_tiles, width_tiles + 1):
		for gz in range(-depth_tiles, depth_tiles + 1):
			var tile_file: String = "floor_tile_large.gltf.glb"
			if (gx + gz) % 3 == 0:
				tile_file = "floor_tile_large_rocks.gltf.glb"
			var floor_inst: Node3D = spawn_dungeon_prop(tile_file, Vector3(float(gx) * 4.0, -0.05, float(gz) * 4.0))
			env_root.add_child(floor_inst)

	var back_z: float = -float(depth_tiles) * 3.2
	for wx in range(-width_tiles, width_tiles + 1):
		var wall_file: String = "wall_arched.gltf.glb" if wx % 2 == 0 else "wall_archedwindow_gated.gltf.glb"
		var w_inst: Node3D = spawn_dungeon_prop(wall_file, Vector3(float(wx) * 4.0, 0.0, back_z))
		env_root.add_child(w_inst)

		if wx % 2 == 0:
			var banner: Node3D = spawn_dungeon_prop("banner_triple_red.gltf.glb", Vector3(float(wx) * 4.0, 1.8, back_z + 0.35), Vector3.ZERO, Vector3.ONE, false)
			env_root.add_child(banner)
		else:
			var torch: Node3D = spawn_dungeon_prop("torch_lit.gltf.glb", Vector3(float(wx) * 4.0, 2.1, back_z + 0.45), Vector3.ZERO, Vector3.ONE, false)
			env_root.add_child(torch)
			var fire_light := OmniLight3D.new()
			fire_light.position = Vector3(float(wx) * 4.0, 2.4, back_z + 0.85)
			fire_light.light_color = Color(0.98, 0.35, 0.16)
			fire_light.light_energy = 2.6
			fire_light.omni_range = 8.0
			env_root.add_child(fire_light)

	for px in [-width_tiles * 2.2, width_tiles * 2.2]:
		for pz in [-3.5, 2.5]:
			var pillar: Node3D = spawn_dungeon_prop("pillar_decorated.gltf.glb", Vector3(float(px), 0.0, float(pz)))
			env_root.add_child(pillar)
			var candle: Node3D = spawn_dungeon_prop("candle_triple.gltf.glb", Vector3(float(px) * 0.85, 0.05, float(pz) + 0.6), Vector3.ZERO, Vector3.ONE, false)
			env_root.add_child(candle)
