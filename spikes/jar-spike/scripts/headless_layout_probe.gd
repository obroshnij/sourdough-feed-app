extends SceneTree
## qa-engineer probe (test-plan OD-11): does Control layout resolve under --headless?
## Run: Godot --headless --path spikes/jar-spike -s res://scripts/headless_layout_probe.gd

var _frames: int = 0
var _box: VBoxContainer
var _label: Label
var _button: Button


func _initialize() -> void:
	root.size = Vector2i(390, 844)
	# The headless root window stays 64 x 64 whatever size is set, so the UI
	# under test lives in a fixed-size frame instead of the window.
	var frame := Control.new()
	frame.size = Vector2(390, 844)
	root.add_child(frame)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(_box)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.text = "This is a deliberately long line of text that has to wrap several times inside a 390 unit wide portrait window so we can count its lines."
	_box.add_child(_label)
	_button = Button.new()
	_button.text = "OK"
	_button.custom_minimum_size = Vector2(48, 48)
	_box.add_child(_button)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	print("PROBE root.size=%s window=%s" % [str(root.size), str(DisplayServer.window_get_size())])
	print("PROBE vbox size=%s rect=%s" % [str(_box.size), str(_box.get_global_rect())])
	print("PROBE label size=%s rect=%s lines=%d" % [str(_label.size), str(_label.get_global_rect()), _label.get_line_count()])
	print("PROBE button size=%s rect=%s" % [str(_button.size), str(_button.get_global_rect())])
	return true
