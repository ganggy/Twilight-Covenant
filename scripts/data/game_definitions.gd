class_name GameDefinitions
extends RefCounted

## ระบบความหายากของตัวละคร (Rarity)
enum Rarity {
	R = 0,
	SR = 1,
	SSR = 2,
	LEGENDARY = 3
}

## ระบบธาตุ Dark Fantasy (Element)
enum Element {
	BLOOD = 0,   ## โลหิต (ชนะ NATURE, แพ้ STORM)
	NATURE = 1,  ## พงไพรต้องสาป (ชนะ STORM, แพ้ BLOOD)
	STORM = 2,   ## อสนีทมิฬ (ชนะ BLOOD, แพ้ NATURE)
	SHADOW = 3,  ## เงามืด (ชนะและแพ้ ASHEN)
	ASHEN = 4    ## เพลิงเถ้าถ่าน (ชนะและแพ้ SHADOW)
}

## ตำแหน่งในแถว (Row Position)
enum RowPos {
	FRONT = 0,
	BACK = 1
}

## รูปแบบการจัดแถว (Formation Style - เหมือน 7 Knights)
enum FormationType {
	BALANCED = 0,  ## สมดุล: หน้า 2 / หลัง 3 (หน้า DEF+15%, หลัง ATK+10%)
	OFFENSE = 1,   ## รุกฆาต: หน้า 1 / หลัง 4 (หน้า DEF+35%, หลัง ATK+20%)
	DEFENSE = 2,   ## ปราการ: หน้า 3 / หลัง 2 (หน้า DEF+20%, หลัง ATK+15%)
	ASSAULT = 3    ## จู่โจม: หน้า 4 / หลัง 1 (หน้า ATK+10%/DEF+10%, หลัง ATK+35%)
}

## ประเภทช่องในกระดานทอยลูกเต๋า
enum TileType {
	START = 0,
	MONSTER = 1,
	TREASURE = 2,
	TRAP = 3,
	SHRINE = 4,
	MINI_BOSS = 5,
	MAIN_BOSS = 6
}

static func get_rarity_name(rarity: Rarity) -> String:
	match rarity:
		Rarity.R: return "R (สามัญ)"
		Rarity.SR: return "SR (หายาก)"
		Rarity.SSR: return "SSR (มหากาพย์)"
		Rarity.LEGENDARY: return "Legendary (ตำนานมืด)"
	return "R"

static func get_rarity_short(rarity: Rarity) -> String:
	match rarity:
		Rarity.R: return "R"
		Rarity.SR: return "SR"
		Rarity.SSR: return "SSR"
		Rarity.LEGENDARY: return "LEGENDARY"
	return "R"

static func get_rarity_color(rarity: Rarity) -> Color:
	match rarity:
		Rarity.R: return Color(0.55, 0.65, 0.78)
		Rarity.SR: return Color(0.68, 0.42, 0.95)
		Rarity.SSR: return Color(0.95, 0.32, 0.38)
		Rarity.LEGENDARY: return Color(1.0, 0.78, 0.22)
	return Color.WHITE

static func get_element_name(elem: Element) -> String:
	match elem:
		Element.BLOOD: return "โลหิต (Blood)"
		Element.NATURE: return "พงไพรสาป (Blight)"
		Element.STORM: return "อสนีทมิฬ (Storm)"
		Element.SHADOW: return "เงามืด (Shadow)"
		Element.ASHEN: return "เพลิงเถ้า (Ashen)"
	return "ไร้ธาตุ"

static func get_element_color(elem: Element) -> Color:
	match elem:
		Element.BLOOD: return Color(0.88, 0.18, 0.25)
		Element.NATURE: return Color(0.25, 0.78, 0.42)
		Element.STORM: return Color(0.32, 0.62, 0.95)
		Element.SHADOW: return Color(0.62, 0.28, 0.88)
		Element.ASHEN: return Color(0.95, 0.58, 0.18)
	return Color.WHITE

## คำนวณตัวคูณชนะธาตุ/แพ้ธาตุ
static func get_element_multiplier(attacker: Element, defender: Element) -> float:
	if attacker == Element.BLOOD and defender == Element.NATURE:
		return 1.35
	if attacker == Element.NATURE and defender == Element.STORM:
		return 1.35
	if attacker == Element.STORM and defender == Element.BLOOD:
		return 1.35
	if (attacker == Element.SHADOW and defender == Element.ASHEN) or (attacker == Element.ASHEN and defender == Element.SHADOW):
		return 1.35

	if defender == Element.BLOOD and attacker == Element.NATURE:
		return 0.75
	if defender == Element.NATURE and attacker == Element.STORM:
		return 0.75
	if defender == Element.STORM and attacker == Element.BLOOD:
		return 0.75

	return 1.0

static func get_formation_name(f_type: FormationType) -> String:
	match f_type:
		FormationType.BALANCED: return "สมดุล (หน้า 2 / หลัง 3)"
		FormationType.OFFENSE: return "รุกฆาต (หน้า 1 / หลัง 4)"
		FormationType.DEFENSE: return "ปราการ (หน้า 3 / หลัง 2)"
		FormationType.ASSAULT: return "จู่โจม (หน้า 4 / หลัง 1)"
	return "สมดุล"

## คืนค่าว่า Slot ที่ 0..4 อยู่แถวหน้า (FRONT) หรือแถวหลัง (BACK) ตามรูปแบบการจัดแถว
static func get_slot_row(f_type: FormationType, slot_index: int) -> RowPos:
	match f_type:
		FormationType.BALANCED:
			# หน้า 2 (slot 0, 1), หลัง 3 (slot 2, 3, 4)
			return RowPos.FRONT if slot_index < 2 else RowPos.BACK
		FormationType.OFFENSE:
			# หน้า 1 (slot 0), หลัง 4 (slot 1, 2, 3, 4)
			return RowPos.FRONT if slot_index < 1 else RowPos.BACK
		FormationType.DEFENSE:
			# หน้า 3 (slot 0, 1, 2), หลัง 2 (slot 3, 4)
			return RowPos.FRONT if slot_index < 3 else RowPos.BACK
		FormationType.ASSAULT:
			# หน้า 4 (slot 0, 1, 2, 3), หลัง 1 (slot 4)
			return RowPos.FRONT if slot_index < 4 else RowPos.BACK
	return RowPos.BACK

static func get_formation_bonus(f_type: FormationType, row: RowPos) -> Dictionary:
	match f_type:
		FormationType.BALANCED:
			if row == RowPos.FRONT:
				return {"atk_mult": 1.0, "def_mult": 1.15}
			else:
				return {"atk_mult": 1.12, "def_mult": 1.0}
		FormationType.OFFENSE:
			if row == RowPos.FRONT:
				return {"atk_mult": 1.0, "def_mult": 1.35}
			else:
				return {"atk_mult": 1.22, "def_mult": 0.95}
		FormationType.DEFENSE:
			if row == RowPos.FRONT:
				return {"atk_mult": 1.05, "def_mult": 1.22}
			else:
				return {"atk_mult": 1.15, "def_mult": 1.0}
		FormationType.ASSAULT:
			if row == RowPos.FRONT:
				return {"atk_mult": 1.12, "def_mult": 1.10}
			else:
				return {"atk_mult": 1.35, "def_mult": 0.90}
	return {"atk_mult": 1.0, "def_mult": 1.0}
