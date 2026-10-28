class_name GameManager
extends RefCounted

## ข้อมูลตัวละครทั้งหมดในเกม (Database)
static var character_db: Dictionary = {}
static var _initialized: bool = false

## ตัวละครหลักที่ผู้เล่นเลือกตอนเริ่มเกม
static var main_hero_id: String = ""

## ตัวละครที่ผู้เล่นครอบครอง: hero_id -> Dictionary { level, exp, stars, shards }
static var owned_heroes: Dictionary = {}

## การจัดทีม 5 ตำแหน่ง (เก็บ hero_id 5 ช่อง)
static var active_team: Array[String] = ["", "", "", "", ""]

## รูปแบบการจัดแถวปัจจุบัน
static var current_formation: GameDefinitions.FormationType = GameDefinitions.FormationType.BALANCED

## ทรัพยากรของผู้เล่น
static var soul_gems: int = 1500       ## ศิลาพันธสัญญา (ใช้เปิดกาชา: 100 ต่อครั้ง / 900 ต่อ 10 ครั้ง)
static var dark_gold: int = 2000       ## ทองคำทมิฬ (ใช้อัปเกรดเลเวลและสเตตัส)
static var loaded_dice_count: int = 3  ## ลูกเต๋าต้องคำสาป (เลือกแต้มเดินได้เอง)

## สถานะของด่านกระดานลูกเต๋าปัจจุบัน
static var current_chapter: int = 1
static var board_position: int = 0
static var corruption_level: int = 0   ## เกจความมืด (เพิ่มขึ้นทุกครั้งที่ทอยลูกเต๋า)
static var board_tiles: Array[Dictionary] = []
static var board_in_progress: bool = false

## ข้อมูลการต่อสู้ที่กำลังจะเกิดขึ้น
static var pending_battle: Dictionary = {}
static var last_battle_won: bool = false

static func ensure_initialized() -> void:
	if _initialized and not character_db.is_empty():
		return
	_initialized = true
	_init_character_database()

static func _init_character_database() -> void:
	character_db.clear()

	# ==========================================
	# 1. ตัวละครหลักเริ่มต้น 3 สาย (STARTER MAIN HEROES)
	# ==========================================
	_register_hero({
		"id": "hero_knight",
		"name": "อัลริค (Alric - อัศวินโลหิตวิปลาส)",
		"title": "ผู้ถือครองดาบพันธสัญญาโลหิต",
		"is_starter": true,
		"archetype": "knight",
		"rarity": GameDefinitions.Rarity.SSR,
		"element": GameDefinitions.Element.BLOOD,
		"primary_color": Color(0.55, 0.12, 0.16),
		"secondary_color": Color(0.95, 0.22, 0.28),
		"base_stats": {"str": 34, "agi": 20, "int": 14, "hp": 420, "def": 32},
		"lore": "อดีตแม่ทัพผู้ทำพันธสัญญากับอสูรโลหิตเพื่อปกป้องอาณาจักรที่ล่มสลาย ดาบของเขาจะสูบเลือดศัตรูมาเยียวยาพันธมิตร",
		"skills": [
			{"name": "ผ่าจันทร์สีเลือด (Crimson Cleave)", "mult": 1.65, "stat": "str", "target": "single", "min_star": 1, "desc": "ฟาดฟันศัตรูแถวหน้าอย่างรุนแรงด้วยพลัง STR และฟื้นฟู HP ตนเอง 20%"},
			{"name": "ปราการโลหิตทมิฬ (Blood Aegis)", "mult": 1.15, "stat": "str", "target": "aoe_3", "min_star": 2, "desc": "[ปลดล็อก 2★] กวาดดาบใส่ศัตรู 3 ตัว พร้อมเพิ่ม DEF ให้ทีมตนเอง"}
		],
		"covenant_skill": {
			"name": "★ พิพากษาพันธสัญญาโลหิต (Covenant Reckoning)",
			"condition_type": "front_and_element",
			"req_row": GameDefinitions.RowPos.FRONT,
			"req_element": GameDefinitions.Element.BLOOD,
			"req_count": 2,
			"mult": 2.35,
			"stat": "str",
			"target": "all",
			"desc": "[เงื่อนไข: ยืนแถวหน้า + มีธาตุโลหิตในทีมอย่างน้อย 2 คน] ระเบิดคลื่นดาบโลหิตโจมตีศัตรูทั้งหมด 235% STR และดูดเลือดให้ทั้งทีม!"
		}
	})

	_register_hero({
		"id": "hero_mage",
		"name": "เซราฟิน่า (Seraphina - แม่มดอเวจี)",
		"title": "ผู้ร่ายบทเพลงแห่งเถ้าถ่าน",
		"is_starter": true,
		"archetype": "mage",
		"rarity": GameDefinitions.Rarity.SSR,
		"element": GameDefinitions.Element.ASHEN,
		"primary_color": Color(0.28, 0.16, 0.42),
		"secondary_color": Color(0.98, 0.55, 0.18),
		"base_stats": {"str": 12, "agi": 24, "int": 40, "hp": 310, "def": 18},
		"lore": "จอมเวทผู้เผาผลาญดวงวิญญาณของตนเองด้วยเพลิงเถ้าถ่านโบราณ ทุกคาถาของเธอสามารถกวาดล้างกองทัพปีศาจได้ในพริบตา",
		"skills": [
			{"name": "ศรเพลิงวิญญาณ (Ashen Bolt)", "mult": 1.55, "stat": "int", "target": "aoe_3", "min_star": 1, "desc": "ยิงศรเพลิงเถ้าถ่านโจมตีศัตรู 3 ตัวด้วยพลังเวท INT"},
			{"name": "อุกกาบาตดับสูญ (Abyssal Meteor)", "mult": 1.35, "stat": "int", "target": "all", "min_star": 2, "desc": "[ปลดล็อก 2★] เรียกฝนอุกกาบาตเผาผลาญศัตรูทั้งสนามรบ"}
		],
		"covenant_skill": {
			"name": "★ มหาเวทสุริยุปราคาทมิฬ (Cataclysm of Ash)",
			"condition_type": "back_and_offense",
			"req_row": GameDefinitions.RowPos.BACK,
			"req_element": GameDefinitions.Element.ASHEN,
			"req_count": 1,
			"mult": 2.50,
			"stat": "int",
			"target": "all",
			"desc": "[เงื่อนไข: ยืนแถวหลัง + มีตัวละครแถวหน้าอย่างน้อย 1 คนคอยคุ้มกัน] ร่ายมหาเวทเพลิงอเวจีทำลายล้างศัตรูทั้งหมด 250% INT!"
		}
	})

	_register_hero({
		"id": "hero_assassin",
		"name": "เวกซ์ (Vex - คมมีดเงาสังหาร)",
		"title": "เพชฌฆาตไร้เงาแห่งรัตติกาล",
		"is_starter": true,
		"archetype": "assassin",
		"rarity": GameDefinitions.Rarity.SSR,
		"element": GameDefinitions.Element.SHADOW,
		"primary_color": Color(0.16, 0.14, 0.24),
		"secondary_color": Color(0.68, 0.25, 0.95),
		"base_stats": {"str": 30, "agi": 38, "int": 16, "hp": 330, "def": 20},
		"lore": "นักฆ่าผู้หลอมรวมร่างเข้ากับเงามืดแห่งหุบเขาอเวจี ความเร็วของเขาสูงจนศัตรูสิ้นใจก่อนจะได้เห็นคมมีด",
		"skills": [
			{"name": "เชือดคอไร้เสียง (Silent Fang)", "mult": 1.85, "stat": "agi", "target": "backline", "min_star": 1, "desc": "พุ่งทะลวงไปสังหารศัตรูแถวหลังด้วยความเร็ว AGI"},
			{"name": "ระบำมีดหมื่นเงา (Phantom Dance)", "mult": 1.45, "stat": "agi", "target": "aoe_3", "min_star": 2, "desc": "[ปลดล็อก 2★] แยกร่างเงาปามีดสังหารศัตรู 3 ตัวพร้อมกัน"}
		],
		"covenant_skill": {
			"name": "★ พันธสัญญาเงาปลิดชีพ (Umbral Execution)",
			"condition_type": "back_and_element",
			"req_row": GameDefinitions.RowPos.BACK,
			"req_element": GameDefinitions.Element.SHADOW,
			"req_count": 2,
			"mult": 2.65,
			"stat": "agi",
			"target": "single_lowest",
			"desc": "[เงื่อนไข: ยืนแถวหลัง + มีธาตุเงามืดในทีมอย่างน้อย 2 คน] ลอบสังหารเป้าหมายและกระจายความเสียหายเงาใส่ศัตรูรอบข้าง 265% AGI!"
		}
	})

	# ==========================================
	# 2. ตัวละครในตู้กาชา (GACHA HERO POOL: R, SR, SSR, LEGENDARY)
	# ==========================================
	_register_hero({
		"id": "gacha_vanguard_r",
		"name": "กอร์ดอน (Gordon - ทหารยามศิลา)",
		"title": "โล่หน้าด่านผู้ไม่เคยถอย",
		"is_starter": false,
		"archetype": "knight",
		"rarity": GameDefinitions.Rarity.R,
		"element": GameDefinitions.Element.NATURE,
		"primary_color": Color(0.25, 0.38, 0.28),
		"secondary_color": Color(0.45, 0.78, 0.50),
		"base_stats": {"str": 22, "agi": 15, "int": 10, "hp": 390, "def": 30},
		"lore": "ทหารผ่านศึกผู้สวมเกราะไม้โบราณต้องคำสาป แม้จะเป็นเพียงนักรบสามัญแต่ความอดทนของเขาไม่เป็นรองใคร",
		"skills": [
			{"name": "กระแทกโล่หนาม (Thorn Bash)", "mult": 1.40, "stat": "str", "target": "single", "min_star": 1, "desc": "ใช้โล่กระแทกศัตรูแถวหน้าและเพิ่มป้องกันตัวเอง"},
			{"name": "รากไม้พันธนาการ (Root Wall)", "mult": 1.15, "stat": "str", "target": "aoe_3", "min_star": 3, "desc": "[ปลดล็อก 3★] เรียกรากไม้โจมตีศัตรู 3 ตัว"}
		],
		"covenant_skill": {
			"name": "★ ป้อมปราการพงไพร (Blight Bastion)",
			"condition_type": "front_only",
			"req_row": GameDefinitions.RowPos.FRONT,
			"req_element": GameDefinitions.Element.NATURE,
			"req_count": 1,
			"mult": 1.80,
			"stat": "str",
			"target": "aoe_3",
			"desc": "[เงื่อนไข: ยืนแถวหน้า] ระเบิดพลังเกราะหนามโจมตี 3 เป้าหมายและฮีลตัวเอง!"
		}
	})

	_register_hero({
		"id": "gacha_archer_r",
		"name": "ลีร่า (Lyra - นักธนูสายหมอก)",
		"title": "ผู้เฝ้ามองจากป่าต้องสาป",
		"is_starter": false,
		"archetype": "assassin",
		"rarity": GameDefinitions.Rarity.R,
		"element": GameDefinitions.Element.STORM,
		"primary_color": Color(0.20, 0.32, 0.48),
		"secondary_color": Color(0.38, 0.75, 0.98),
		"base_stats": {"str": 24, "agi": 29, "int": 14, "hp": 280, "def": 16},
		"lore": "พรานสาวผู้ใช้ลูกธนูอาบสายฟ้าทมิฬ ยิงปลิดชีพปีศาจจากระยะไกลได้อย่างแม่นยำ",
		"skills": [
			{"name": "ศรอัสนี (Storm Arrow)", "mult": 1.50, "stat": "agi", "target": "single", "min_star": 1, "desc": "ยิงธนูสายฟ้าใส่เป้าหมายเดี่ยว"},
			{"name": "ห่าฝนศรสายฟ้า (Volley of Sparks)", "mult": 1.20, "stat": "agi", "target": "aoe_3", "min_star": 3, "desc": "[ปลดล็อก 3★] ยิงธนูกวาดศัตรู 3 ตัว"}
		],
		"covenant_skill": {
			"name": "★ ศรทะลวงเมฆา (Cloudpiercer)",
			"condition_type": "back_only",
			"req_row": GameDefinitions.RowPos.BACK,
			"req_element": GameDefinitions.Element.STORM,
			"req_count": 1,
			"mult": 1.95,
			"stat": "agi",
			"target": "backline",
			"desc": "[เงื่อนไข: ยืนแถวหลัง] ยิงศรสายฟ้าขั้นสุดยอดเจาะเกราะแถวหลังศัตรู!"
		}
	})

	_register_hero({
		"id": "gacha_cultist_r",
		"name": "มาลัส (Malus - นักบวชเถ้าถ่าน)",
		"title": "ผู้สวดภาวนาต่อดวงอาทิตย์ที่ดับสูญ",
		"is_starter": false,
		"archetype": "mage",
		"rarity": GameDefinitions.Rarity.R,
		"element": GameDefinitions.Element.ASHEN,
		"primary_color": Color(0.38, 0.22, 0.16),
		"secondary_color": Color(0.90, 0.48, 0.20),
		"base_stats": {"str": 14, "agi": 18, "int": 28, "hp": 290, "def": 17},
		"lore": "สาวกลัทธิเถ้าถ่านที่ใช้ไฟมืดแผดเผาศัตรูในระยะไกล",
		"skills": [
			{"name": "ลูกไฟทมิฬ (Dark Ember)", "mult": 1.45, "stat": "int", "target": "single", "min_star": 1, "desc": "ปล่อยลูกไฟโจมตีศัตรู 1 ตัว"},
			{"name": "คลื่นเถ้าถ่าน (Ash Wave)", "mult": 1.20, "stat": "int", "target": "aoe_3", "min_star": 3, "desc": "[ปลดล็อก 3★] สาดคลื่นไฟใส่ศัตรู 3 ตัว"}
		],
		"covenant_skill": {
			"name": "★ พิธีกรรมเผาผลาญ (Ritual of Cinders)",
			"condition_type": "back_only",
			"req_row": GameDefinitions.RowPos.BACK,
			"req_element": GameDefinitions.Element.ASHEN,
			"req_count": 1,
			"mult": 1.85,
			"stat": "int",
			"target": "all",
			"desc": "[เงื่อนไข: ยืนแถวหลัง] จุดระเบิดเถ้าถ่านโจมตีศัตรูทั้งหมด!"
		}
	})

	_register_hero({
		"id": "gacha_cleric_sr",
		"name": "เอเลน่า (Elena - นักบุญหญิงโลหิต)",
		"title": "ผู้เยียวยาด้วยหยาดน้ำตาสีชาด",
		"is_starter": false,
		"archetype": "cleric",
		"rarity": GameDefinitions.Rarity.SR,
		"element": GameDefinitions.Element.BLOOD,
		"primary_color": Color(0.48, 0.14, 0.24),
		"secondary_color": Color(1.0, 0.42, 0.55),
		"base_stats": {"str": 16, "agi": 24, "int": 34, "hp": 350, "def": 24},
		"lore": "นักบุญหญิงผู้ถูกขับไล่จากวิหารศักดิ์สิทธิ์ เธอใช้เวทโลหิตสูบพลังชีวิตศัตรูมารักษาบาดแผลให้เพื่อนร่วมทีม",
		"skills": [
			{"name": "พรโลหิตฟื้นฟู (Crimson Grace)", "mult": 1.35, "stat": "int", "target": "heal_all", "min_star": 1, "desc": "ฟื้นฟู HP ให้พันธมิตรทั้งทีม พร้อมสร้างความเสียหายเวทใส่ศัตรู"},
			{"name": "โซ่ตรวนสีชาด (Scarlet Chains)", "mult": 1.50, "stat": "int", "target": "aoe_3", "min_star": 2, "desc": "[ปลดล็อก 2★] ตรึงศัตรู 3 ตัวด้วยโซ่เลือดและดูด HP มาให้ทีม"}
		],
		"covenant_skill": {
			"name": "★ มหาวิหารโลหิตนิรันดร์ (Sanctuary of Blood)",
			"condition_type": "back_and_element",
			"req_row": GameDefinitions.RowPos.BACK,
			"req_element": GameDefinitions.Element.BLOOD,
			"req_count": 2,
			"mult": 2.10,
			"stat": "int",
			"target": "heal_all",
			"desc": "[เงื่อนไข: ยืนแถวหลัง + มีธาตุโลหิตในทีม 2 คน] ฟื้นฟู HP ทั้งทีมอย่างมหาศาลและโจมตีศัตรูทุกตัว!"
		}
	})

	_register_hero({
		"id": "gacha_berserker_sr",
		"name": "ครอว์ (Kraw - นักรบคลั่งอสนีทมิฬ)",
		"title": "อสูรศึกผู้ฉีกกระชากสายฟ้า",
		"is_starter": false,
		"archetype": "knight",
		"rarity": GameDefinitions.Rarity.SR,
		"element": GameDefinitions.Element.STORM,
		"primary_color": Color(0.18, 0.28, 0.52),
		"secondary_color": Color(0.35, 0.85, 1.0),
		"base_stats": {"str": 35, "agi": 26, "int": 12, "hp": 370, "def": 25},
		"lore": "นักรบผู้ถูกสายฟ้าสีดำผ่ากลางสมรภูมิแต่รอดชีวิตมาได้พร้อมพละกำลังเหนือมนุษย์",
		"skills": [
			{"name": "ขวานผ่าอัสนี (Thunder Cleaver)", "mult": 1.65, "stat": "str", "target": "single", "min_star": 1, "desc": "จามขวานสายฟ้าใส่เป้าหมายอย่างรุนแรง"},
			{"name": "พายุคลั่งทมิฬ (Berserk Tempest)", "mult": 1.35, "stat": "str", "target": "aoe_3", "min_star": 2, "desc": "[ปลดล็อก 2★] หมุนตัวฟาดสายฟ้าใส่ศัตรู 3 ตัว"}
		],
		"covenant_skill": {
			"name": "★ ทัณฑ์สายฟ้าอเวจี (Abyssal Thunderstrike)",
			"condition_type": "front_only",
			"req_row": GameDefinitions.RowPos.FRONT,
			"req_element": GameDefinitions.Element.STORM,
			"req_count": 1,
			"mult": 2.20,
			"stat": "str",
			"target": "all",
			"desc": "[เงื่อนไข: ยืนแถวหน้า] กระโดดทุบพื้นปล่อยสายฟ้าทมิฬช็อตศัตรูทั้งสนามรบ!"
		}
	})

	_register_hero({
		"id": "gacha_druid_sr",
		"name": "ซิลวานัส (Sylvanus - ผู้พิทักษ์ซากพงไพร)",
		"title": "จ้าวแห่งหนามพิษและเงาไม้",
		"is_starter": false,
		"archetype": "mage",
		"rarity": GameDefinitions.Rarity.SR,
		"element": GameDefinitions.Element.NATURE,
		"primary_color": Color(0.16, 0.35, 0.22),
		"secondary_color": Color(0.32, 0.92, 0.48),
		"base_stats": {"str": 18, "agi": 23, "int": 33, "hp": 340, "def": 23},
		"lore": "วิญญาณผู้พิทักษ์ป่าที่แปดเปื้อนคำสาป เขาใช้พิษและหนามทมิฬกัดกร่อนศัตรูจากภายใน",
		"skills": [
			{"name": "หนามพิษสังหาร (Venom Briars)", "mult": 1.50, "stat": "int", "target": "aoe_3", "min_star": 1, "desc": "เสกหนามพิษทิ่มแทงศัตรู 3 ตัว"},
			{"name": "ละอองมรณะ (Plague Spores)", "mult": 1.30, "stat": "int", "target": "all", "min_star": 2, "desc": "[ปลดล็อก 2★] โปรยสปอร์พิษโจมตีศัตรูทั้งหมด"}
		],
		"covenant_skill": {
			"name": "★ ป่าต้องสาปกลืนวิญญาณ (Devouring Grove)",
			"condition_type": "back_only",
			"req_row": GameDefinitions.RowPos.BACK,
			"req_element": GameDefinitions.Element.NATURE,
			"req_count": 1,
			"mult": 2.15,
			"stat": "int",
			"target": "all",
			"desc": "[เงื่อนไข: ยืนแถวหลัง] เรียกพงไพรต้องสาปกลืนกินศัตรูทั้งหมดและฟื้นฟูทีม!"
		}
	})

	_register_hero({
		"id": "gacha_reaper_ssr",
		"name": "มอร์กาน่า (Morgana - ยมทูตเคียวเงา)",
		"title": "ผู้เก็บเกี่ยววิญญาณแห่งพันธสัญญา",
		"is_starter": false,
		"archetype": "reaper",
		"rarity": GameDefinitions.Rarity.SSR,
		"element": GameDefinitions.Element.SHADOW,
		"primary_color": Color(0.22, 0.10, 0.35),
		"secondary_color": Color(0.85, 0.25, 0.98),
		"base_stats": {"str": 36, "agi": 36, "int": 28, "hp": 380, "def": 26},
		"lore": "ยมทูตสาวผู้ถือเคียวจันทราทมิฬ ทุกครั้งที่เคียวของเธอตวัดผ่าน วิญญาณของศัตรูจะถูกฉีกกระชากโดยไม่อาจฟื้นคืน",
		"skills": [
			{"name": "เคียวเกี่ยววิญญาณ (Soul Harvest)", "mult": 1.75, "stat": "agi", "target": "aoe_3", "min_star": 1, "desc": "ตวัดเคียวเงาโจมตีศัตรู 3 ตัวและดูดเลือดตนเอง"},
			{"name": "ประตูสู่นรกภูมิ (Nether Gate)", "mult": 1.50, "stat": "agi", "target": "all", "min_star": 2, "desc": "[ปลดล็อก 2★] เปิดประตูมิติเงาโจมตีศัตรูทั้งสนาม"}
		],
		"covenant_skill": {
			"name": "★ พิพากษาแห่งยมโลก (Death's Final Decree)",
			"condition_type": "any_with_element",
			"req_row": GameDefinitions.RowPos.FRONT,
			"req_element": GameDefinitions.Element.SHADOW,
			"req_count": 2,
			"mult": 2.60,
			"stat": "agi",
			"target": "all",
			"desc": "[เงื่อนไข: มีธาตุเงามืดในทีมอย่างน้อย 2 คน] อัญเชิญเคียวยักษ์แห่งความตายกวาดล้างศัตรูทั้งหมด 260% AGI!"
		}
	})

	_register_hero({
		"id": "gacha_archdemon_leg",
		"name": "มาลาคอร์ (Malakor - จักรพรรดิอสูรสุริยะทมิฬ)",
		"title": "ราชันย์แห่งพันธสัญญาโบราณ [Legendary]",
		"is_starter": false,
		"archetype": "boss",
		"rarity": GameDefinitions.Rarity.LEGENDARY,
		"element": GameDefinitions.Element.ASHEN,
		"primary_color": Color(0.45, 0.08, 0.12),
		"secondary_color": Color(1.0, 0.82, 0.18),
		"base_stats": {"str": 46, "agi": 38, "int": 46, "hp": 520, "def": 36},
		"lore": "ตัวตนระดับตำนานผู้ยืนอยู่เหนือเหล่าปีศาจและมนุษย์ ผู้ครอบครองทั้งเพลิงเถ้าถ่านและพลังทำลายล้างแห่งอเวจี",
		"skills": [
			{"name": "หอกสุริยะทมิฬ (Black Sun Lance)", "mult": 2.00, "stat": "str", "target": "aoe_3", "min_star": 1, "desc": "พุ่งหอกเพลิงทองคำทมิฬทะลวงศัตรู 3 เป้าหมายอย่างรุนแรง"},
			{"name": "บัลลังก์วันสิ้นโลก (Apocalypse Throne)", "mult": 1.75, "stat": "int", "target": "all", "min_star": 2, "desc": "[ปลดล็อก 2★] ปลดปล่อยคลื่นพลังราชันย์อสูรใส่ศัตรูทั้งสนามรบ"}
		],
		"covenant_skill": {
			"name": "★ มหาพันธสัญญาจักรพรรดิทมิฬ (Sovereign Twilight)",
			"condition_type": "legendary_presence",
			"req_row": GameDefinitions.RowPos.FRONT,
			"req_element": GameDefinitions.Element.ASHEN,
			"req_count": 1,
			"mult": 3.10,
			"stat": "str",
			"target": "all",
			"desc": "[เงื่อนไขพิเศษ Legendary: จัดทีมครบ 5 คน] เรียกสุริยุปราคาทมิฬถล่มศัตรูทั้งสนาม 310% และฮีลทั้งทีม!"
		}
	})

	_register_hero({
		"id": "gacha_valkyrie_leg",
		"name": "แอสเทรีย (Astrea - วาลคิรีปีกโลหิตตกสวรรค์)",
		"title": "เทวทูตผู้ถูกย้อมด้วยเลือด [Legendary]",
		"is_starter": false,
		"archetype": "knight",
		"rarity": GameDefinitions.Rarity.LEGENDARY,
		"element": GameDefinitions.Element.BLOOD,
		"primary_color": Color(0.65, 0.10, 0.22),
		"secondary_color": Color(1.0, 0.88, 0.35),
		"base_stats": {"str": 44, "agi": 42, "int": 35, "hp": 490, "def": 38},
		"lore": "อดีตเทวทูตผู้ฉีกปีกสีขาวของตนเองทิ้งเพื่อลงมาทำสงครามในหุบเขามืด หอกของเธอไม่เคยพลาดเป้า",
		"skills": [
			{"name": "หอกสวรรค์วิปลาส (Fallen Paradiso)", "mult": 1.95, "stat": "str", "target": "aoe_3", "min_star": 1, "desc": "แทงหอกแสงสีเลือดใส่ศัตรู 3 ตัวพร้อมเพิ่มพลังป้องกันทั้งทีม"},
			{"name": "พิพากษาปีกสีชาด (Crimson Judgement)", "mult": 1.70, "stat": "str", "target": "all", "min_star": 2, "desc": "[ปลดล็อก 2★] โบยบินขึ้นฟ้าแล้วพุ่งลงมาถล่มศัตรูทั้งหมด"}
		],
		"covenant_skill": {
			"name": "★ เพลงสวดเทวทูตตกสวรรค์ (Requiem of the Fallen)",
			"condition_type": "legendary_presence",
			"req_row": GameDefinitions.RowPos.FRONT,
			"req_element": GameDefinitions.Element.BLOOD,
			"req_count": 1,
			"mult": 3.00,
			"stat": "str",
			"target": "all",
			"desc": "[เงื่อนไขพิเศษ Legendary: จัดทีมครบ 5 คน] ปลดปล่อยแสงสีเลือดล้างบางศัตรูทั้งหมด 300% และฟื้นฟู HP ทีม!"
		}
	})

static func _register_hero(data: Dictionary) -> void:
	character_db[data["id"]] = data

## เริ่มต้นเกมเมื่อผู้เล่นเลือก Hero หลัก
static func select_starter_hero(hero_id: String) -> void:
	ensure_initialized()
	main_hero_id = hero_id
	owned_heroes.clear()
	active_team = ["", "", "", "", ""]

	_unlock_or_add_shards(hero_id, 2)
	_unlock_or_add_shards("gacha_vanguard_r", 1)
	_unlock_or_add_shards("gacha_archer_r", 1)
	_unlock_or_add_shards("gacha_cultist_r", 1)
	_unlock_or_add_shards("gacha_cleric_sr", 1)

	active_team[0] = main_hero_id
	active_team[1] = "gacha_vanguard_r"
	active_team[2] = "gacha_archer_r"
	active_team[3] = "gacha_cultist_r"
	active_team[4] = "gacha_cleric_sr"

	generate_new_board(1)

static func _unlock_or_add_shards(hero_id: String, initial_stars: int = 1) -> Dictionary:
	ensure_initialized()
	if not owned_heroes.has(hero_id):
		owned_heroes[hero_id] = {
			"level": 1,
			"exp": 0,
			"stars": initial_stars,
			"shards": 0,
			"bonus_str": 0,
			"bonus_agi": 0,
			"bonus_int": 0,
			"bonus_hp": 0,
			"bonus_def": 0
		}
		return {"is_new": true, "shards_gained": 0}
	else:
		var rarity: GameDefinitions.Rarity = character_db[hero_id]["rarity"]
		var shard_gain: int = 15
		match rarity:
			GameDefinitions.Rarity.R: shard_gain = 15
			GameDefinitions.Rarity.SR: shard_gain = 25
			GameDefinitions.Rarity.SSR: shard_gain = 40
			GameDefinitions.Rarity.LEGENDARY: shard_gain = 60
		var cur_shards: int = int(owned_heroes[hero_id]["shards"])
		owned_heroes[hero_id]["shards"] = cur_shards + shard_gain
		return {"is_new": false, "shards_gained": shard_gain}

static func get_hero_computed_stats(hero_id: String) -> Dictionary:
	ensure_initialized()
	if not character_db.has(hero_id):
		return {}
	var base: Dictionary = character_db[hero_id]["base_stats"]
	var save: Dictionary = owned_heroes.get(hero_id, {
		"level": 1, "stars": 1, "shards": 0,
		"bonus_str": 0, "bonus_agi": 0, "bonus_int": 0, "bonus_hp": 0, "bonus_def": 0
	})
	var lvl: int = int(save["level"])
	var stars: int = int(save["stars"])
	var star_mult: float = 1.0 + float(stars - 1) * 0.22
	var lvl_mult: float = 1.0 + float(lvl - 1) * 0.08

	return {
		"str": int(round((float(base["str"]) * lvl_mult + float(save["bonus_str"])) * star_mult)),
		"agi": int(round((float(base["agi"]) * lvl_mult + float(save["bonus_agi"])) * star_mult)),
		"int": int(round((float(base["int"]) * lvl_mult + float(save["bonus_int"])) * star_mult)),
		"hp": int(round((float(base["hp"]) * lvl_mult + float(save["bonus_hp"])) * star_mult)),
		"def": int(round((float(base["def"]) * lvl_mult + float(save["bonus_def"])) * star_mult)),
		"level": lvl,
		"stars": stars,
		"shards": int(save.get("shards", 0))
	}

static func is_covenant_skill_active(hero_id: String, slot_index: int, team_ids: Array[String], formation: GameDefinitions.FormationType) -> bool:
	ensure_initialized()
	if not character_db.has(hero_id):
		return false
	var c_skill: Dictionary = character_db[hero_id].get("covenant_skill", {})
	if c_skill.is_empty():
		return false

	var my_row: GameDefinitions.RowPos = GameDefinitions.get_slot_row(formation, slot_index)
	var cond_type: String = str(c_skill.get("condition_type", ""))
	var req_elem: GameDefinitions.Element = c_skill.get("req_element", GameDefinitions.Element.BLOOD)
	var req_count: int = int(c_skill.get("req_count", 1))

	var elem_count: int = 0
	var valid_members: int = 0
	var front_count: int = 0
	for i in range(team_ids.size()):
		var tid: String = team_ids[i]
		if tid != "" and character_db.has(tid):
			valid_members += 1
			if character_db[tid]["element"] == req_elem:
				elem_count += 1
			if GameDefinitions.get_slot_row(formation, i) == GameDefinitions.RowPos.FRONT:
				front_count += 1

	match cond_type:
		"front_and_element":
			return my_row == GameDefinitions.RowPos.FRONT and elem_count >= req_count
		"back_and_element":
			return my_row == GameDefinitions.RowPos.BACK and elem_count >= req_count
		"back_and_offense":
			return my_row == GameDefinitions.RowPos.BACK and front_count >= 1
		"front_only":
			return my_row == GameDefinitions.RowPos.FRONT
		"back_only":
			return my_row == GameDefinitions.RowPos.BACK
		"any_with_element":
			return elem_count >= req_count
		"legendary_presence":
			return valid_members >= 5
	return true

static func get_team_synergy_summary() -> Dictionary:
	ensure_initialized()
	var counts: Dictionary = {}
	for hero_id in active_team:
		if hero_id != "" and character_db.has(hero_id):
			var el: int = int(character_db[hero_id]["element"])
			counts[el] = int(counts.get(el, 0)) + 1

	var atk_bonus: float = 0.0
	var hp_bonus: float = 0.0
	var active_texts: Array[String] = []

	for el in counts.keys():
		var c: int = int(counts[el])
		if c >= 2:
			var el_name: String = GameDefinitions.get_element_name(el as GameDefinitions.Element)
			var bonus_a: float = 0.08 * float(c - 1)
			var bonus_h: float = 0.10 * float(c - 1)
			atk_bonus += bonus_a
			hp_bonus += bonus_h
			active_texts.append("%s x%d (ATK+%d%%, HP+%d%%)" % [el_name, c, int(bonus_a * 100.0), int(bonus_h * 100.0)])

	if active_texts.is_empty():
		active_texts.append("คละธาตุรอบด้าน (AGI ทั้งทีม +10%)")

	return {
		"atk_bonus": atk_bonus,
		"hp_bonus": hp_bonus,
		"descriptions": active_texts
	}

static func upgrade_hero_level(hero_id: String) -> Dictionary:
	ensure_initialized()
	if not owned_heroes.has(hero_id):
		return {"ok": false, "msg": "ยังไม่ได้ครอบครองตัวละครนี้"}
	var save: Dictionary = owned_heroes[hero_id]
	var cur_lvl: int = int(save["level"])
	var cost: int = 120 + cur_lvl * 80
	if dark_gold < cost:
		return {"ok": false, "msg": "ทองคำทมิฬไม่พอ (ต้องการ %d)" % cost}

	dark_gold -= cost
	save["level"] = cur_lvl + 1
	save["bonus_str"] = int(save["bonus_str"]) + randi_range(2, 4)
	save["bonus_agi"] = int(save["bonus_agi"]) + randi_range(2, 4)
	save["bonus_int"] = int(save["bonus_int"]) + randi_range(2, 4)
	save["bonus_hp"] = int(save["bonus_hp"]) + randi_range(18, 32)
	save["bonus_def"] = int(save["bonus_def"]) + randi_range(2, 3)
	return {"ok": true, "msg": "อัปเกรดเลเวลเป็น Lv.%d และเพิ่ม Status สำเร็จ!" % int(save["level"])}

static func upgrade_hero_star(hero_id: String) -> Dictionary:
	ensure_initialized()
	if not owned_heroes.has(hero_id):
		return {"ok": false, "msg": "ยังไม่ได้ครอบครองตัวละครนี้"}
	var save: Dictionary = owned_heroes[hero_id]
	var cur_stars: int = int(save["stars"])
	if cur_stars >= 6:
		return {"ok": false, "msg": "ตัวละครนี้ถึงระดับสูงสุด 6★ แล้ว!"}

	var req_shards: int = cur_stars * 20
	var cur_shards: int = int(save["shards"])
	if cur_shards < req_shards:
		return {"ok": false, "msg": "เศษวิญญาณไม่พอ (มี %d / ต้องการ %d ชิ้น จากการเปิดกาชาหรือชนะบอส)" % [cur_shards, req_shards]}

	save["shards"] = cur_shards - req_shards
	save["stars"] = cur_stars + 1
	return {"ok": true, "msg": "ปลุกพลังขึ้นเป็น %d★ สำเร็จ! สเตตัสและสกิลพัฒนาขึ้น!" % int(save["stars"])}

static func roll_gacha(count: int) -> Dictionary:
	ensure_initialized()
	var cost: int = 100 if count == 1 else 900
	if soul_gems < cost:
		return {"ok": false, "msg": "ศิลาพันธสัญญาไม่พอ! (ต้องการ %d Gems)" % cost, "results": []}

	soul_gems -= cost
	var results: Array[Dictionary] = []

	for _i in range(count):
		var roll: float = randf() * 100.0
		var target_rarity: GameDefinitions.Rarity = GameDefinitions.Rarity.R
		if roll < 4.5:
			target_rarity = GameDefinitions.Rarity.LEGENDARY
		elif roll < 20.0:
			target_rarity = GameDefinitions.Rarity.SSR
		elif roll < 54.0:
			target_rarity = GameDefinitions.Rarity.SR
		else:
			target_rarity = GameDefinitions.Rarity.R

		var candidates: Array[String] = []
		for hid in character_db.keys():
			if character_db[hid]["rarity"] == target_rarity:
				candidates.append(str(hid))
		if candidates.is_empty():
			for hid in character_db.keys():
				candidates.append(str(hid))

		var picked_id: String = candidates[randi() % candidates.size()]
		var unlock_info: Dictionary = _unlock_or_add_shards(picked_id, 1)
		results.append({
			"hero_id": picked_id,
			"name": character_db[picked_id]["name"],
			"rarity": character_db[picked_id]["rarity"],
			"element": character_db[picked_id]["element"],
			"is_new": unlock_info["is_new"],
			"shards_gained": unlock_info["shards_gained"]
		})

	return {"ok": true, "msg": "อัญเชิญพันธสัญญาสำเร็จ!", "results": results}

static func assign_hero_to_slot(slot_idx: int, hero_id: String) -> Dictionary:
	ensure_initialized()
	if slot_idx < 0 or slot_idx >= 5:
		return {"ok": false, "msg": "ตำแหน่งไม่ถูกต้อง"}

	var current_in_slot: String = active_team[slot_idx]
	if current_in_slot == main_hero_id and hero_id != main_hero_id:
		var existing_idx: int = active_team.find(hero_id)
		if existing_idx != -1:
			active_team[existing_idx] = main_hero_id
			active_team[slot_idx] = hero_id
			return {"ok": true, "msg": "สลับตำแหน่ง Hero หลักไปยังช่องที่ %d แล้ว" % (existing_idx + 1)}
		else:
			return {"ok": false, "msg": "กฎพันธสัญญา: Hero หลักต้องอยู่ในทีมออกรบเสมอ! (เลือกช่องอื่นแทน)"}

	var prev_idx: int = active_team.find(hero_id)
	if prev_idx != -1 and prev_idx != slot_idx:
		active_team[prev_idx] = active_team[slot_idx]

	active_team[slot_idx] = hero_id
	return {"ok": true, "msg": "จัดวาง %s ลงตำแหน่งที่ %d สำเร็จ!" % [str(character_db[hero_id]["name"]), slot_idx + 1]}

static func generate_new_board(chapter: int) -> void:
	ensure_initialized()
	current_chapter = chapter
	board_position = 0
	corruption_level = 0
	board_in_progress = true
	board_tiles.clear()

	for i in range(16):
		var t_type: GameDefinitions.TileType = GameDefinitions.TileType.MONSTER
		var title: String = "ฝูงปีศาจเงา"
		var desc: String = "ปีศาจที่ดักซุ่มอยู่ในความมืด"

		if i == 0:
			t_type = GameDefinitions.TileType.START
			title = "แท่นศิลาพันธสัญญา (จุดเริ่มต้น)"
			desc = "จุดเริ่มต้นของการเดินทางในด่านที่ %d" % chapter
		elif i == 7:
			t_type = GameDefinitions.TileType.MINI_BOSS
			title = "★ มินิบอส: ขุนพลอัศวินไร้เศียร ★"
			desc = "บอสประจำด่านย่อย! เอาชนะเพื่อรับศิลาพันธสัญญาและลูกเต๋าต้องคำสาป"
		elif i == 15:
			t_type = GameDefinitions.TileType.MAIN_BOSS
			title = "☠ บอสหลัก: จ้าวอสูรทมิฬแห่งหุบเขา ☠"
			desc = "บอสประจำด่านหลัก! ต้องใช้ทีม 5 คนที่แข็งแกร่งเพื่อพิชิตด่านนี้"
		elif i in [3, 11]:
			t_type = GameDefinitions.TileType.TREASURE
			title = "หีบสมบัติต้องสาป"
			desc = "รับทองคำทมิฬ ศิลาสุ่มกาชา หรือเศษวิญญาณอัปดาว"
		elif i in [5, 13]:
			t_type = GameDefinitions.TileType.SHRINE
			title = "แท่นบูชาเพลิงวิญญาณ"
			desc = "ชำระล้างค่าความมืด และมอบเศษวิญญาณให้ Hero หลัก"
		elif i in [4, 10]:
			t_type = GameDefinitions.TileType.TRAP
			title = "กับดักหนามโลหิต"
			desc = "พื้นที่อาถรรพ์ เพิ่มเกจความมืดและอาจเรียกปีศาจจู่โจม!"
		else:
			t_type = GameDefinitions.TileType.MONSTER
			title = "ปีศาจดักซุ่ม (ช่องที่ %d)" % i
			desc = "ต่อสู้กับกองทัพปีศาจ 5 ตัวเพื่อชิงค่าประสบการณ์และทอง"

		board_tiles.append({
			"index": i,
			"type": t_type,
			"title": title,
			"desc": desc,
			"cleared": (i == 0)
		})
