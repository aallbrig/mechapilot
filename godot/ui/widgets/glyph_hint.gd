class_name GlyphHint
extends HFlowContainer
## A prompt line such as "[Enter] select": each glyph is drawn as a key cap,
## followed by its words. It wraps on narrow screens.


func _init() -> void:
	alignment = FlowContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"h_separation", 10)
	add_theme_constant_override(&"v_separation", 6)


## Shows `segments`, replacing what was shown before.
func show_segments(segments: Array[InputGlyphs.Segment]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for segment: InputGlyphs.Segment in segments:
		var chip: PanelContainer = PanelContainer.new()
		chip.theme_type_variation = &"GlyphChip"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(UiBuild.label(segment.glyph, &"GlyphLabel"))
		add_child(chip)
		add_child(UiBuild.label(segment.words, &"HintLabel"))


## The text shown, glyphs in brackets: "[Enter] select" (for tests and logs).
func text() -> String:
	var parts: PackedStringArray = []
	for child: Node in get_children():
		if child is PanelContainer:
			var glyph: Label = child.get_child(0) as Label
			var _added: bool = parts.append("[%s]" % glyph.text)
		elif child is Label:
			var _added: bool = parts.append((child as Label).text)
	return " ".join(parts)
