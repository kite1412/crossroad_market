class_name BlueprintData
extends Resource

enum BlueprintType {
	IMMEDIATE_LEAVE,  # Impatient: leave if item not found
	QUEUE_ASK,       # Patient: wait in queue to ask about item
	BROWSE_BUY       # Quitter: browse alternatives then decide
}

# Each mood level maps to a full dialog set
# Mood 0 = IMPATIENT, Mood 1 = PATIENT, Mood 2 = QUITTER
var mood_dialogs: Dictionary = {}

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _init() -> void:
	_setup_default_dialogs()

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_default_dialogs() -> void:
	# --- IMMEDIATE_LEAVE (Impatient) ---
	mood_dialogs[BlueprintType.IMMEDIATE_LEAVE] = {
		0: {  # impatient mood
			"search": "%s, I'll take it.",
			"not_found": "Hmm... nothing here. Later.",
			"checkout": "I want to buy this. %dG.",
			"done": "Finally. Goodbye.",
			"queue_too_long": "Queue is too long... I'll come back later.",
			"checkout_wait": "This is taking too long. Goodbye."
		},
		1: {  # patient mood
			"search": "Ah, %s! Looks good.",
			"not_found": "Hmm... %s isn't here. I can wait a bit.",
			"checkout": "I'd like to buy %s. %dG please.",
			"done": "Thanks! See you.",
			"queue_too_long": "Queue is too long... I'll come back later.",
			"checkout_wait": "Is anyone here?"
		},
		2: {  # quitter mood
			"search": "%s? Maybe I'll get this one.",
			"not_found": "No %s... I'll browse around.",
			"checkout": "I'll take %s. %dG.",
			"done": "Thanks! I'll be back.",
			"queue_too_long": "This queue is too long...",
			"checkout_wait": "I'll wait... but not too long."
		}
	}

	# --- QUEUE_ASK ---
	mood_dialogs[BlueprintType.QUEUE_ASK] = {
		0: {
			"search": "%s! I'll take it.",
			"not_found": "Is there any %s...? I'll wait here.",
			"checkout": "Here's %dG for %s.",
			"done": "Got it. Thanks!",
			"queue_too_long": "Still waiting... I need to go.",
			"checkout_wait": "Is anyone here? I don't have all day."
		},
		1: {
			"search": "%s... I'll take one please.",
			"not_found": "Do you have %s in stock? I'll wait.",
			"checkout": "I'd like to buy %s. %dG.",
			"done": "Thank you so much!",
			"queue_too_long": "Still in queue... I'll be patient.",
			"checkout_wait": "Hello? I'd like to check out please."
		},
		2: {
			"search": "Oh, %s! I'll take it.",
			"not_found": "No %s? I'll ask at the counter.",
			"checkout": "I'll take %s. Here, %dG.",
			"done": "Great, thanks! See you!",
			"queue_too_long": "I should go... maybe next time.",
			"checkout_wait": "Hmm... I'll keep waiting a little."
		}
	}

	# --- BROWSE_BUY ---
	mood_dialogs[BlueprintType.BROWSE_BUY] = {
		0: {
			"search": "Found %s, I'll get it.",
			"not_found": "No %s... I'll look at what else is here.",
			"checkout": "%s for %dG. Here you go.",
			"done": "Good. See you around.",
			"queue_too_long": "Too many people... I'll skip this.",
			"checkout_wait": "How long is this going to take?"
		},
		1: {
			"search": "%s, I was looking for this!",
			"not_found": "Hmm, no %s... let me check other shelves.",
			"checkout": "I'll take %s please. %dG.",
			"done": "Thanks! Have a good day.",
			"queue_too_long": "The queue is long but I don't mind waiting.",
			"checkout_wait": "No rush, I'll wait here."
		},
		2: {
			"search": "%s! Perfect, I'll take it.",
			"not_found": "No %s... hmm, what about this one instead?",
			"checkout": "%s, %dG. Keep the change if you want~",
			"done": "Nice, thanks! I'll come again!",
			"queue_too_long": "I think I'll come back another time...",
			"checkout_wait": "I don't mind waiting a bit longer..."
		}
	}

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_dialog(blueprint_type: BlueprintType, mood: int, key: String) -> String:
	if not mood_dialogs.has(blueprint_type):
		return ""
	if not mood_dialogs[blueprint_type].has(mood):
		return ""
	return mood_dialogs[blueprint_type][mood].get(key, "")
