class_name PlayerInteraction
extends RefCounted



static func get_storage_door_type(area: Area2D) -> String:
	if area == null:
		return ""

	if area.has_meta("door_type"):
		return str(area.get_meta("door_type"))

	match String(area.name):
		"StorageDoor", "StorageDoor_Normal":
			return "normal"
		"StorageDoor2", "StorageDoor_Mystery":
			return "mistery"
		"HomeDoor":
			return "home"
		"ReturnDoor":
			return "return"
		_:
			return ""


static func get_interaction_priority(target: Node) -> int:
	if target is Cashier:
		return 0

	if target is NPC:
		return 1

	if target is SupplyBox:
		return 2

	if target is Shelf:
		return 3

	if target is ActivityBoard:
		return 4

	if target is OpenCloseBoard:
		return 5

	if target is SleepBed:
		return 6

	if target is StorageRestockTerminal:
		return 7

	if target is RestockPackage:
		return 8

	if target is NpcFeedbackBoard:
		return 9

	return 999
