extends Node
## SceneRouter (autoload): scene changes with a short cinematic fade.

signal scene_entered(path: String)

var _layer: CanvasLayer
var _rect: ColorRect
var _busy: bool = false

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "TransitionLayer"
	_layer.layer = 128
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.color = Color(0.027, 0.031, 0.037, 1.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_layer.add_child(_rect)

func goto(path: String, fade_time: float = 0.24) -> void:
	if _busy:
		return
	_busy = true
	await _fade(1.0, fade_time)
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: cannot load %s (%d)" % [path, err])
		await _fade(0.0, fade_time)
		_busy = false
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade(0.0, fade_time)
	_busy = false
	scene_entered.emit(path)

func _fade(target: float, time: float) -> void:
	if _rect == null:
		return
	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_rect, "modulate:a", target, maxf(time, 0.01))
	await tw.finished
