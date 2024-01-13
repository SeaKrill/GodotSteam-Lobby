extends Node

var canvas
var output

func _ready():
	var _canvas = CanvasLayer.new()
	var _scroll = ScrollContainer.new()
	var _output = RichTextLabel.new()
	
	_canvas.layer = 105
	
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_child(_canvas)
	_canvas.add_child(_scroll)
	_scroll.add_child(_output)
	
	canvas = _canvas
	output = _output
	
	canvas.hide()
	
func _unhandled_input(event):
	if event.is_action_pressed("console"):
		canvas.visible = !canvas.visible

func add_log(_log: String):
	output.append_text("%s\n" % _log)
