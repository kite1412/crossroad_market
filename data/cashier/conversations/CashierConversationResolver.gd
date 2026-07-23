class_name CashierConversationResolver
extends RefCounted

const CONVERSATION_ROOT := "res://data/cashier/conversations"


static func get_conversation(day: int, customer_id: String) -> CashierConversationData:
	var normalized_customer_id := customer_id.strip_edges().to_lower()
	if (
		day < 1
		or normalized_customer_id.is_empty()
		or normalized_customer_id.contains("/")
		or normalized_customer_id.contains("\\")
		or normalized_customer_id.contains("..")
	):
		return null

	var candidate_ids: Array[String] = [normalized_customer_id]
	var visit_marker := "_day_%d_visit_" % day
	var visit_marker_index := normalized_customer_id.rfind(visit_marker)
	if visit_marker_index > 0:
		var visit_number := normalized_customer_id.substr(
			visit_marker_index + visit_marker.length()
		)
		if visit_number.is_valid_int():
			candidate_ids.append(normalized_customer_id.left(visit_marker_index))

	for candidate_id in candidate_ids:
		var resource_path := "%s/day_%d/%s.tres" % [
			CONVERSATION_ROOT,
			day,
			candidate_id,
		]
		if not ResourceLoader.exists(resource_path):
			continue

		var conversation := load(resource_path) as CashierConversationData
		if conversation == null:
			continue
		if conversation.day != day or conversation.customer_id != candidate_id:
			push_warning(
				"Cashier conversation metadata does not match its path: %s" % resource_path
			)
			continue
		return conversation

	return null


static func get_conditional_conversation(
	day: int,
	customer_number: int,
	shown_conversation_ids: Dictionary
) -> CashierConversationData:
	if day < 1 or customer_number < 1:
		return null

	var directory_path := "%s/day_%d/conditional" % [CONVERSATION_ROOT, day]
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return null

	var resource_names: Array[String] = []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".tres"):
			resource_names.append(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	resource_names.sort()

	for resource_name in resource_names:
		var resource_path := "%s/%s" % [directory_path, resource_name]
		var conversation := load(resource_path) as CashierConversationData
		if conversation == null:
			continue
		if conversation.day != day or conversation.conversation_id.is_empty():
			push_warning(
				"Conditional cashier conversation metadata is invalid: %s" % resource_path
			)
			continue
		if shown_conversation_ids.has(conversation.conversation_id):
			continue
		if customer_number < conversation.minimum_customer_number:
			continue
		return conversation

	return null
