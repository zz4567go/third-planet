extends Node
## Шины Music и SFX (посыл на Master). Громкости сохраняются в user://audio_settings.cfg

const SETTINGS_PATH := "user://audio_settings.cfg"
const SECTION := "audio"
const KEY_MUSIC := "music_linear"
const KEY_SFX := "sfx_linear"

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_load()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func set_bus_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	linear = clampf(linear, 0.0, 1.0)
	if linear < 0.001:
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func get_bus_linear(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 1.0
	var db := AudioServer.get_bus_volume_db(idx)
	if db <= -79.0:
		return 0.0
	return clampf(db_to_linear(db), 0.0, 1.0)


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value(SECTION, KEY_MUSIC, get_bus_linear("Music"))
	cf.set_value(SECTION, KEY_SFX, get_bus_linear("SFX"))
	cf.save(SETTINGS_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		set_bus_linear("Music", 0.85)
		set_bus_linear("SFX", 0.95)
		return
	set_bus_linear("Music", float(cf.get_value(SECTION, KEY_MUSIC, 0.85)))
	set_bus_linear("SFX", float(cf.get_value(SECTION, KEY_SFX, 0.95)))
