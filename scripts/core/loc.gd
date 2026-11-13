extends Node
## Loc (autoload): Persian-first localisation with RTL awareness.
## Strings live in assets/i18n/*.json so translators never touch code.

const SUPPORTED: Array = ["fa", "en"]
const DEFAULT_LANG: String = "fa"

var lang: String = DEFAULT_LANG
var _dicts: Dictionary = {}
var _fonts: Dictionary = {}
var _fallback: Dictionary = {}

func _ready() -> void:
	_load_lang("fa")
	_load_lang("en")
	_fallback = _dicts.get("en", {})
	_fonts["regular"] = _load_font("res://assets/fonts/Vazirmatn-Regular.ttf")
	_fonts["medium"] = _load_font("res://assets/fonts/Vazirmatn-Medium.ttf")
	_fonts["bold"] = _load_font("res://assets/fonts/Vazirmatn-Bold.ttf")
	_fonts["black"] = _load_font("res://assets/fonts/Vazirmatn-Black.ttf")

func _load_lang(code: String) -> void:
	var path: String = "res://assets/i18n/%s.json" % code
	if not FileAccess.file_exists(path):
		_dicts[code] = {}
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_dicts[code] = parsed if parsed is Dictionary else {}

func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path) as Font
	return null

func set_lang(code: String) -> void:
	if not SUPPORTED.has(code):
		code = DEFAULT_LANG
	lang = code

func toggle_lang() -> String:
	lang = "en" if lang == "fa" else "fa"
	return lang

func is_rtl() -> bool:
	return lang == "fa"

func direction() -> int:
	return Control.TEXT_DIRECTION_RTL if is_rtl() else Control.TEXT_DIRECTION_LTR

func text_align() -> int:
	return HORIZONTAL_ALIGNMENT_RIGHT if is_rtl() else HORIZONTAL_ALIGNMENT_LEFT

func t(key: String, params: Dictionary = {}) -> String:
	var table: Dictionary = _dicts.get(lang, {})
	var value: String = ""
	if table.has(key):
		value = String(table[key])
	elif _fallback.has(key):
		value = String(_fallback[key])
	else:
		value = key
	for k: String in params.keys():
		value = value.replace("{%s}" % k, str(params[k]))
	return value

func font(weight: String = "regular") -> Font:
	return _fonts.get(weight, _fonts.get("regular", null))

func font_regular() -> Font:
	return font("regular")

func font_bold() -> Font:
	return font("bold")

func font_black() -> Font:
	return font("black")

func font_medium() -> Font:
	return font("medium")
