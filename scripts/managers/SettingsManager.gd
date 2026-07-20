## Scalable game-settings manager.
## Stores all runtime settings in a single Dictionary and persists them to disk.
## Any system can read/write settings via get_value / set_value using a dot-path key.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal setting_changed(key: String, value: Variant)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const SETTINGS_PATH: String = "user://settings.cfg"

# Difficulty presets
enum Difficulty { EASY, MEDIUM, HARD }

# Patience timer durations (seconds) per difficulty
const PATIENCE_DURATION := {
	Difficulty.EASY: 15.0,
	Difficulty.MEDIUM: 10.0,
	Difficulty.HARD: 7.0,
}

# ---------------------------------------------------------------------------
# Default values – add new settings here
# ---------------------------------------------------------------------------
const DEFAULTS: Dictionary = {
	"difficulty": Difficulty.MEDIUM,
}

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
var _settings: Dictionary = {}


func _ready() -> void:
	_settings = DEFAULTS.duplicate(true)
	_load()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Get any setting by its key. Returns default if key is unknown.
func get_value(key: String) -> Variant:
	if _settings.has(key):
		return _settings[key]
	return null


## Set a setting and emit change signal. Persists automatically.
func set_value(key: String, value: Variant) -> void:
	var old_value: Variant = _settings.get(key)
	_settings[key] = value
	if old_value != value:
		setting_changed.emit(key, value)
	_save()


## Convenience – current difficulty enum value.
func get_difficulty() -> Difficulty:
	return _settings.get("difficulty", Difficulty.MEDIUM) as Difficulty


## Convenience – patience duration for the current difficulty.
func get_patience_duration() -> float:
	var diff: Difficulty = get_difficulty()
	return PATIENCE_DURATION.get(diff, PATIENCE_DURATION[Difficulty.MEDIUM])


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _save() -> void:
	var config := ConfigFile.new()
	for key in _settings:
		config.set_value("game", key, _settings[key])
	config.save(SETTINGS_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key in DEFAULTS:
		if config.has_section_key("game", key):
			_settings[key] = config.get_value("game", key)
