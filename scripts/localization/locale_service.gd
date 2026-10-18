extends Node
## JSON-пакеты: встроенные, рядом со сборкой и в пользовательском каталоге.
## При экспорте locales/**/*.json должны входить в фильтр нересурсных файлов.

signal locale_changed(code: String)

const DEFAULT_LOCALE := "ru"

var current_locale: String = DEFAULT_LOCALE
var available_locales: Dictionary = {}

var _catalogs: Dictionary = {}
var _reported_missing: Dictionary = {}


func _ready() -> void:
	_discover_root("res://locales")
	if not OS.has_feature("editor"):
		_discover_root(OS.get_executable_path().get_base_dir().path_join("locales"))
	_discover_root("user://locales")
	if not _catalogs.has(DEFAULT_LOCALE):
		push_error("Не найден базовый языковой пакет ru.")
	set_locale(DEFAULT_LOCALE)


func set_locale(code: String) -> void:
	var selected := code
	if not _catalogs.has(selected):
		push_warning("Не найден языковой пакет '%s'; используется ru." % selected)
		selected = DEFAULT_LOCALE
	current_locale = selected
	locale_changed.emit(current_locale)


func text(key: String, parameters: Dictionary = {}) -> String:
	var selected: Dictionary = _catalogs.get(current_locale, {})
	var fallback: Dictionary = _catalogs.get(DEFAULT_LOCALE, {})
	var value: String = selected.get(key, fallback.get(key, ""))
	if not selected.has(key) and not fallback.has(key):
		if not _reported_missing.has(key):
			_reported_missing[key] = true
			push_error("Отсутствует ключ локализации: %s" % key)
		return "[%s]" % key
	return value.format(parameters)


func _discover_root(root: String) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	var folders := directory.get_directories()
	folders.sort()
	for folder: String in folders:
		var path := root.path_join(folder)
		var metadata_path := path.path_join("locale.json")
		if not FileAccess.file_exists(metadata_path):
			continue
		var metadata := _read_json(metadata_path)
		var code: String = str(metadata.get("code", "")).strip_edges()
		var locale_name: String = str(metadata.get("name", "")).strip_edges()
		if code.is_empty() or locale_name.is_empty():
			push_warning("У языкового пакета отсутствуют code или name: %s" % metadata_path)
			continue
		var catalog: Dictionary = _catalogs.get(code, {})
		_load_texts(path, catalog)
		_catalogs[code] = catalog
		available_locales[code] = metadata


func _load_texts(path: String, catalog: Dictionary, depth: int = 0) -> void:
	# Ограничение защищает от зацикленных ссылок во внешних языковых пакетах.
	if depth > 8:
		push_warning("Слишком глубокая вложенность языкового пакета: %s" % path)
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	var files := directory.get_files()
	files.sort()
	for filename: String in files:
		if filename == "locale.json" or filename.get_extension().to_lower() != "json":
			continue
		var values := _read_json(path.path_join(filename))
		for key: Variant in values:
			if key is String and values[key] is String:
				catalog[key] = values[key]
			else:
				push_warning("Ожидается строковый ключ и текст в %s: %s" % [filename, key])
	var folders := directory.get_directories()
	folders.sort()
	for folder: String in folders:
		_load_texts(path.path_join(folder), catalog, depth + 1)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Не удалось открыть языковой файл: %s" % path)
		return {}
	var parser := JSON.new()
	var result := parser.parse(file.get_as_text())
	if result != OK or not parser.data is Dictionary:
		push_warning("Некорректный JSON в %s, строка %d: %s" % [
			path, parser.get_error_line(), parser.get_error_message(),
		])
		return {}
	return parser.data
