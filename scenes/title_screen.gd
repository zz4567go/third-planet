extends Control

@onready var _settings: PanelContainer = $SettingsLayer/SettingsPanel
@onready var _music_slider: HSlider = $SettingsLayer/SettingsPanel/Margin/VBox/MusicRow/HSlider
@onready var _sfx_slider: HSlider = $SettingsLayer/SettingsPanel/Margin/VBox/SFXRow/HSlider


func _ready() -> void:
	if OS.has_feature("android"):
		$CenterContainer/VBox/ExitButton.visible = false

	_music_slider.value = GameAudio.get_bus_linear("Music")
	_sfx_slider.value = GameAudio.get_bus_linear("SFX")

	$CenterContainer/VBox/PlayButton.pressed.connect(_on_play_pressed)
	$CenterContainer/VBox/SettingsButton.pressed.connect(_open_settings)
	$CenterContainer/VBox/ExitButton.pressed.connect(_on_exit_pressed)
	$SettingsLayer/SettingsPanel/Margin/VBox/CloseButton.pressed.connect(_close_settings)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_placeholder.tscn")


func _open_settings() -> void:
	_settings.visible = true


func _close_settings() -> void:
	_settings.visible = false
	GameAudio.save()


func _on_music_changed(v: float) -> void:
	GameAudio.set_bus_linear("Music", v)
	GameAudio.save()


func _on_sfx_changed(v: float) -> void:
	GameAudio.set_bus_linear("SFX", v)
	GameAudio.save()


func _on_exit_pressed() -> void:
	get_tree().quit()
