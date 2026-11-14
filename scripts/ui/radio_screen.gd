extends Control
## MUDRO Radio — the garage radio.
##
## Plays the built-in project-synthesised station and any validated content pack
## that the player has sideloaded. The attribution line of the current track is
## always visible when one exists, because a pack track without a displayed
## attribution is not allowed to play (docs/RADIO_CONTENT_POLICY.md §5).

var _model: RadioModel = RadioModel.new()
var _player: AudioStreamPlayer
var _title_label: Label
var _artist_label: Label
var _attr_label: Label
var _pack_label: Label
var _play_button: Button
var _playing: bool = false

func _ready() -> void:
	UIKit.root(self)
	_model.enabled = SettingsService.radio_enabled
	_model.volume = SettingsService.radio_volume
	_model.scan()
	# Start on the first track so the now-playing panel is never empty while the
	# list below is clearly populated.
	_model.select(0)
	_build()
	_play_current(false)

func _build() -> void:
	var bg := MenuBackground.new()
	add_child(bg)
	bg.setup("quarry", false)
	# The menu backdrop is deliberately bright; the radio panels need a dark bed to
	# stay readable over it.
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.04, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 14)
	margin.add_child(root_box)

	# --- header ---------------------------------------------------------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root_box.add_child(header)
	var back := UIKit.button(Loc.t("back"), false, "arrow_right" if Loc.is_rtl() else "arrow_left")
	back.custom_minimum_size = Vector2(150, 54)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: Router.goto("res://scenes/menus/main_menu.tscn"))
	header.add_child(back)
	var titles := UIKit.vbox(0)
	titles.add_child(UIKit.title(Loc.t("nav_radio_title"), 44))
	titles.add_child(UIKit.caption(Loc.t("nav_radio_sub")))
	header.add_child(titles)
	header.add_child(UIKit.spacer(0))

	# --- now playing ----------------------------------------------------
	var now := UIKit.panel(14)
	root_box.add_child(now)
	var now_box := UIKit.vbox(8)
	now.add_child(now_box)
	now_box.add_child(UIKit.caption(Loc.t("nav_radio_now")))
	_title_label = UIKit.label("—", 30, UIKit.IVORY, "black")
	now_box.add_child(_title_label)
	_artist_label = UIKit.caption("")
	now_box.add_child(_artist_label)
	_attr_label = UIKit.paragraph("", 15, UIKit.AMBER)
	_attr_label.visible = false
	now_box.add_child(_attr_label)
	_pack_label = UIKit.caption("")
	now_box.add_child(_pack_label)

	var transport := UIKit.hbox(10)
	now_box.add_child(transport)
	var prev := UIKit.button("|<", false)
	prev.custom_minimum_size = Vector2(84, 52)
	prev.pressed.connect(_on_previous)
	transport.add_child(prev)
	_play_button = UIKit.button(Loc.t("nav_radio_play"), true, "play")
	_play_button.custom_minimum_size = Vector2(160, 52)
	_play_button.pressed.connect(_on_toggle_play)
	transport.add_child(_play_button)
	var next := UIKit.button(">|", false)
	next.custom_minimum_size = Vector2(84, 52)
	next.pressed.connect(_on_next)
	transport.add_child(next)
	transport.add_child(UIKit.spacer(0))
	var mute := UIKit.button(Loc.t("radio_mute"), false, "sound")
	mute.pressed.connect(_on_toggle_enabled)
	transport.add_child(mute)

	# --- track list -----------------------------------------------------
	root_box.add_child(UIKit.caption(Loc.t("nav_radio_library")))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 178)
	root_box.add_child(scroll)
	var list := UIKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i: int in range(_model.playlist.size()):
		list.add_child(_track_row(i))

	# --- packs ----------------------------------------------------------
	root_box.add_child(UIKit.caption(Loc.t("nav_radio_pack_title")))
	var pack_panel := UIKit.panel(12, true)
	root_box.add_child(pack_panel)
	var pack_box := UIKit.vbox(4)
	pack_panel.add_child(pack_box)
	var accepted: Array[RadioPack] = _model.accepted_packs()
	var rejected: Array[RadioPack] = _model.rejected_packs()
	if accepted.is_empty() and rejected.is_empty():
		pack_box.add_child(UIKit.paragraph(Loc.t("radio_pack_missing"), 14, UIKit.MUTED))
	for pack: RadioPack in accepted:
		pack_box.add_child(UIKit.stat_row(
			"%s  ·  %s" % [pack.display_name, pack.author],
			Loc.t("nav_radio_count", {"n": pack.track_count()}), UIKit.TEAL))
	for pack: RadioPack in rejected:
		pack_box.add_child(UIKit.stat_row(pack.pack_id, Loc.t("radio_pack_rejected"), UIKit.RED))
		pack_box.add_child(UIKit.paragraph(pack.reject_reason, 13, UIKit.RED))

	# --- player ---------------------------------------------------------
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = linear_to_db(maxf(_model.volume, 0.001))
	_player.finished.connect(_on_finished)
	add_child(_player)

	_refresh()

func _track_row(index: int) -> Control:
	var track: Dictionary = _model.playlist[index]
	var row := Button.new()
	row.alignment = HORIZONTAL_ALIGNMENT_RIGHT if Loc.is_rtl() else HORIZONTAL_ALIGNMENT_LEFT
	var title: String = String(track["title_fa"] if Loc.lang == "fa" else track["title_en"])
	var suffix: String = ""
	if String(track["bucket"]) != "A":
		suffix = "  ·  %s" % String(track["license_id"])
	row.text = "%02d   %s   ·  %s%s" % [index + 1, title, String(track["artist"]), suffix]
	row.custom_minimum_size = Vector2(0, 48)
	row.add_theme_font_size_override("font_size", 18)
	row.pressed.connect(_on_pick.bind(index))
	return row

func _refresh() -> void:
	var track: Dictionary = _model.current_track()
	if track.is_empty():
		_title_label.text = Loc.t("nav_radio_empty")
		_artist_label.text = ""
		_attr_label.visible = false
		_pack_label.text = ""
		return
	_title_label.text = _model.title(Loc.lang)
	_artist_label.text = String(track["artist"])
	var attr: String = _model.attribution_line()
	_attr_label.text = attr
	_attr_label.visible = not attr.is_empty()
	var pack_id: String = String(track["pack_id"])
	_pack_label.text = Loc.t("radio_builtin") if pack_id.is_empty() \
		else Loc.t("radio_pack_from", {"id": pack_id})
	_play_button.text = Loc.t("radio_pause") if _playing else Loc.t("nav_radio_play")

func _play_current(autoplay: bool = true) -> void:
	var track: Dictionary = _model.current_track()
	if track.is_empty():
		_player.stream = null
		_playing = false
		_refresh()
		return
	var path: String = String(track["path"])
	var stream: AudioStream = null
	if path.begins_with("res://"):
		stream = load(path) as AudioStream
	else:
		stream = _load_external(path)
	if stream == null:
		_playing = false
		_refresh()
		return
	_player.stream = stream
	if autoplay and _model.enabled:
		_player.play()
		_playing = true
	else:
		_playing = false
	_refresh()

## Packs live outside res://, so their audio is read from disk and wrapped in an
## AudioStreamWAV. Refusing anything that is not a readable audio file keeps the
## loader honest: a corrupted pack cannot crash the radio.
func _load_external(path: String) -> AudioStream:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	if path.get_extension().to_lower() == "wav":
		var wav := AudioStreamWAV.new()
		if not _decode_wav(bytes, wav):
			push_warning("Radio: could not decode %s" % path)
			return null
		if bool(_model.current_track().get("loop", false)):
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.data.size() / 2)
		return wav
	var ogg: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(path)
	return ogg as AudioStream

## Minimal RIFF/WAVE reader for 16-bit PCM, which is what the pack format accepts
## besides OGG. Anything else is refused rather than played as noise.
func _decode_wav(bytes: PackedByteArray, out: AudioStreamWAV) -> bool:
	if bytes.size() < 44:
		return false
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return false
	if bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return false
	var pos: int = 12
	var channels: int = 1
	var rate: int = 22050
	var bits: int = 16
	var data: PackedByteArray = PackedByteArray()
	while pos + 8 <= bytes.size():
		var chunk_id: String = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(pos + 4)
		var body: int = pos + 8
		if chunk_id == "fmt " and body + 16 <= bytes.size():
			channels = bytes.decode_u16(body + 2)
			rate = int(bytes.decode_u32(body + 4))
			bits = bytes.decode_u16(body + 14)
		elif chunk_id == "data":
			var end: int = mini(body + size, bytes.size())
			data = bytes.slice(body, end)
			break
		pos = body + size + (size & 1)
	if data.is_empty() or bits != 16:
		return false
	out.format = AudioStreamWAV.FORMAT_16_BITS
	out.mix_rate = rate
	out.stereo = channels == 2
	out.data = data
	return true

func _on_pick(index: int) -> void:
	_model.select(index)
	_play_current(true)

func _on_next() -> void:
	_model.next_track()
	_play_current(true)

func _on_previous() -> void:
	_model.previous_track()
	_play_current(true)

func _on_toggle_play() -> void:
	if _player.stream == null:
		_play_current(true)
		return
	if _playing:
		_player.stop()
		_playing = false
	else:
		_player.play()
		_playing = true
	_refresh()

func _on_toggle_enabled() -> void:
	_model.enabled = not _model.enabled
	SettingsService.set_radio_enabled(_model.enabled)
	if not _model.enabled:
		_player.stop()
		_playing = false
	elif _player.stream != null:
		_player.play()
		_playing = true
	_refresh()

func _on_finished() -> void:
	if _model.playable_count() <= 1:
		_playing = false
		_refresh()
		return
	_model.next_track()
	_play_current(true)

func _exit_tree() -> void:
	if _player != null:
		_player.stop()
