class_name SpriteGenerator
extends RefCounted

static var _cache: Dictionary = {}

## สร้าง ImageTexture สำหรับตัวละครและมอนสเตอร์ในธีม Dark Fantasy
static func get_unit_texture(archetype: String, primary_color: Color, secondary_color: Color, is_enemy: bool = false) -> ImageTexture:
	var key := "%s_%s_%s_%s" % [archetype, primary_color.to_html(), secondary_color.to_html(), str(is_enemy)]
	if _cache.has(key):
		return _cache[key]

	var w := 96
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# วงเวทย์เงาใต้เท้า (Dark Fantasy Shadow & Rune Ring)
	_draw_ellipse(img, 48, 114, 32, 9, Color(0.05, 0.02, 0.08, 0.75))
	_draw_ellipse_outline(img, 48, 114, 34, 10, Color(secondary_color.r, secondary_color.g, secondary_color.b, 0.65))

	# ออร่าด้านหลังตัวละคร
	_draw_ellipse(img, 48, 66, 30, 42, Color(secondary_color.r, secondary_color.g, secondary_color.b, 0.16))

	# ลำตัวและผ้าคลุม Dark Fantasy
	var cloak_color := primary_color.darkened(0.45)
	var armor_color := primary_color.lightened(0.1)
	var trim_color := secondary_color.lightened(0.25)

	# วาดผ้าคลุมหลัง
	_draw_triangle(img, Vector2i(48, 34), Vector2i(20, 108), Vector2i(76, 108), cloak_color)

	# วาดเกราะลำตัว
	_draw_rect(img, 34, 48, 28, 38, armor_color)
	_draw_rect_outline(img, 34, 48, 28, 38, trim_color)

	# วาดขา/เกราะขา
	_draw_rect(img, 36, 86, 10, 24, primary_color.darkened(0.25))
	_draw_rect(img, 50, 86, 10, 24, primary_color.darkened(0.25))

	# วาดเกราะไหล่
	_draw_circle(img, 31, 52, 9, armor_color.darkened(0.15))
	_draw_circle(img, 65, 52, 9, armor_color.darkened(0.15))

	# วาดศีรษะ / หมวกเหล็ก / ฮู้ด
	_draw_circle(img, 48, 32, 14, primary_color.darkened(0.3))
	_draw_circle(img, 48, 34, 10, Color(0.12, 0.10, 0.16)) # ใบหน้าในเงามืด

	# ดวงตาเรืองแสงตามธาตุ/ฝ่าย
	var eye_color := Color(1.0, 0.2, 0.25) if is_enemy else secondary_color.lightened(0.45)
	_draw_rect(img, 42, 32, 4, 3, eye_color)
	_draw_rect(img, 50, 32, 4, 3, eye_color)

	# วาดอาวุธและเอกลักษณ์ตามสายอาชีพ (Archetype)
	match archetype:
		"knight":
			# ดาบใหญ่โลหิต + โล่และเขาอัศวิน
			_draw_triangle(img, Vector2i(36, 22), Vector2i(30, 8), Vector2i(41, 18), trim_color)
			_draw_triangle(img, Vector2i(60, 22), Vector2i(66, 8), Vector2i(55, 18), trim_color)
			# ดาบใหญ่ด้านขวา
			_draw_rect(img, 72, 18, 7, 74, Color(0.78, 0.82, 0.90))
			_draw_rect(img, 66, 68, 19, 5, trim_color)
			# โล่ด้านซ้าย
			_draw_rect(img, 14, 48, 18, 34, armor_color.darkened(0.2))
			_draw_rect_outline(img, 14, 48, 18, 34, trim_color)
		"mage":
			# ฮู้ดจอมเวท + คทาเวทอเวจี
			_draw_triangle(img, Vector2i(48, 8), Vector2i(32, 34), Vector2i(64, 34), primary_color.darkened(0.2))
			_draw_rect(img, 74, 20, 4, 86, Color(0.45, 0.30, 0.22))
			_draw_circle(img, 76, 18, 9, secondary_color.lightened(0.3))
			_draw_circle(img, 76, 18, 5, Color.WHITE)
		"assassin":
			# ผ้าพันคอ + มีดคู่เงาทมิฬ
			_draw_triangle(img, Vector2i(14, 62), Vector2i(28, 56), Vector2i(24, 88), secondary_color.lightened(0.2))
			_draw_triangle(img, Vector2i(82, 62), Vector2i(68, 56), Vector2i(72, 88), secondary_color.lightened(0.2))
		"reaper":
			# เคียวแห่งความตาย
			_draw_rect(img, 72, 14, 4, 92, Color(0.32, 0.25, 0.38))
			_draw_triangle(img, Vector2i(74, 14), Vector2i(36, 26), Vector2i(74, 32), secondary_color.lightened(0.35))
		"cleric":
			# นักบุญหญิงมืด + วงแหวนศักดิ์สิทธิ์ทมิฬ
			_draw_ellipse_outline(img, 48, 16, 16, 6, Color(1.0, 0.88, 0.42))
			_draw_rect(img, 74, 28, 4, 72, Color(0.85, 0.78, 0.62))
			_draw_rect(img, 66, 38, 20, 4, Color(0.85, 0.78, 0.62))
		"boss":
			# บอสปีศาจขนาดใหญ่มีเขาและปีกทมิฬ
			_draw_triangle(img, Vector2i(34, 44), Vector2i(4, 16), Vector2i(14, 78), primary_color.darkened(0.35))
			_draw_triangle(img, Vector2i(62, 44), Vector2i(92, 16), Vector2i(82, 78), primary_color.darkened(0.35))
			_draw_triangle(img, Vector2i(38, 20), Vector2i(22, 2), Vector2i(44, 18), trim_color)
			_draw_triangle(img, Vector2i(58, 20), Vector2i(74, 2), Vector2i(52, 18), trim_color)
		_:
			# ปีศาจหรือนักรบทั่วไป
			_draw_rect(img, 72, 30, 5, 62, Color(0.65, 0.68, 0.75))

	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func _draw_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for py in range(max(0, y), min(img.get_height(), y + h)):
		for px in range(max(0, x), min(img.get_width(), x + w)):
			img.set_pixel(px, py, col)

static func _draw_rect_outline(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for px in range(max(0, x), min(img.get_width(), x + w)):
		if y >= 0 and y < img.get_height():
			img.set_pixel(px, y, col)
		if y + h - 1 >= 0 and y + h - 1 < img.get_height():
			img.set_pixel(px, y + h - 1, col)
	for py in range(max(0, y), min(img.get_height(), y + h)):
		if x >= 0 and x < img.get_width():
			img.set_pixel(x, py, col)
		if x + w - 1 >= 0 and x + w - 1 < img.get_width():
			img.set_pixel(x + w - 1, py, col)

static func _draw_circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	var r2 := r * r
	for py in range(max(0, cy - r), min(img.get_height(), cy + r + 1)):
		for px in range(max(0, cx - r), min(img.get_width(), cx + r + 1)):
			var dx := px - cx
			var dy := py - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(px, py, col)

static func _draw_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for py in range(max(0, cy - ry), min(img.get_height(), cy + ry + 1)):
		for px in range(max(0, cx - rx), min(img.get_width(), cx + rx + 1)):
			var nx := float(px - cx) / float(rx)
			var ny := float(py - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				var existing := img.get_pixel(px, py)
				img.set_pixel(px, py, existing.blend(col))

static func _draw_ellipse_outline(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for deg in range(0, 360, 2):
		var rad := deg_to_rad(float(deg))
		var px := int(round(cx + cos(rad) * rx))
		var py := int(round(cy + sin(rad) * ry))
		if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
			img.set_pixel(px, py, col)

static func _draw_triangle(img: Image, p1: Vector2i, p2: Vector2i, p3: Vector2i, col: Color) -> void:
	var min_x: int = max(0, min(p1.x, min(p2.x, p3.x)))
	var max_x: int = min(img.get_width() - 1, max(p1.x, max(p2.x, p3.x)))
	var min_y: int = max(0, min(p1.y, min(p2.y, p3.y)))
	var max_y: int = min(img.get_height() - 1, max(p1.y, max(p2.y, p3.y)))

	for py in range(min_y, max_y + 1):
		for px in range(min_x, max_x + 1):
			var pt := Vector2(px, py)
			if _point_in_triangle(pt, Vector2(p1), Vector2(p2), Vector2(p3)):
				img.set_pixel(px, py, col)

static func _point_in_triangle(pt: Vector2, v1: Vector2, v2: Vector2, v3: Vector2) -> bool:
	var d1 := _sign(pt, v1, v2)
	var d2 := _sign(pt, v2, v3)
	var d3 := _sign(pt, v3, v1)
	var has_neg := (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos := (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)

static func _sign(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
