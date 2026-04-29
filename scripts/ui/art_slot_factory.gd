class_name ArtSlotFactory
extends RefCounted

const ArtCatalogScript = preload("res://scripts/content/art_catalog.gd")

var _catalog: ArtCatalogScript

func _init(catalog: ArtCatalogScript) -> void:
	_catalog = catalog

func create_slot(art_id: String, size: Vector2, fallback_title: String = "", fallback_subtitle: String = "") -> Control:
	var row := _catalog.art_by_id(art_id) if _catalog != null else {}
	var title := String(row.get("placeholder_title", fallback_title))
	var subtitle := String(row.get("placeholder_subtitle", fallback_subtitle))
	var tint_a := _parse_color(String(row.get("tint_a", "283042")), Color(0.16, 0.19, 0.26))
	var tint_b := _parse_color(String(row.get("tint_b", "6d86c9")), Color(0.43, 0.53, 0.79))
	var path := String(row.get("path", ""))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_panel(tint_a.darkened(0.2), tint_b, 12))

	if path != "" and ResourceLoader.exists(path):
		var texture := load(path)
		if texture is Texture2D:
			var rect := TextureRect.new()
			rect.texture = texture
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			rect.custom_minimum_size = size
			panel.add_child(rect)
			return panel

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var title_label := Label.new()
	title_label.text = title if title != "" else art_id
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.modulate = Color(0.98, 0.98, 1.0)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.modulate = Color(0.78, 0.86, 0.98)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(subtitle_label)

	return panel

func _parse_color(hex: String, fallback: Color) -> Color:
	var clean := hex.strip_edges()
	if clean == "":
		return fallback
	if not clean.begins_with("#"):
		clean = "#" + clean
	return Color.html(clean)

func _style_panel(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = border
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

