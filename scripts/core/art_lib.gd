class_name ArtLib
extends RefCounted
## Cached texture access with a graceful fallback. Every art path is optional:
## a missing SVG must never crash a race, it just degrades to code-drawn shapes.

static var _cache: Dictionary = {}

static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[path] = tex
	return tex

static func control(name: String) -> Texture2D:
	return _load("res://assets/ui/controls/%s.svg" % name)

static func icon(name: String) -> Texture2D:
	return _load("res://assets/ui/icons/%s.svg" % name)

static func env(environment: String, layer: String) -> Texture2D:
	var path: String = "res://assets/environments/%s/%s.svg" % [environment, layer]
	if ResourceLoader.exists(path):
		return _load(path)
	# Black Ridge and any future region can borrow a neighbour's ground texture
	# rather than rendering an untextured polygon.
	if layer == "ground" and ResourceLoader.exists("res://assets/environments/canyon/ground.svg"):
		return _load("res://assets/environments/canyon/ground.svg")
	return null

static func decor(environment: String, kind: String) -> Texture2D:
	var specific: String = "res://assets/environments/%s/%s.svg" % [environment, kind]
	if ResourceLoader.exists(specific):
		return _load(specific)
	return _load("res://assets/environments/common/%s.svg" % kind)
