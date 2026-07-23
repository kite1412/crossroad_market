class_name CashierConversationData
extends Resource

## A customer-specific or conditional cashier conversation for one in-game day.

@export_range(1, 9999, 1) var day: int = 1
@export var conversation_id: String = ""
@export var customer_id: String = ""
@export_range(1, 9999, 1) var minimum_customer_number: int = 1
@export_multiline var opening_line: String = ""
@export var post_payment_dialogue: Array[CashierDialogueLine] = []
@export var player_exit_dialogue: Array[String] = []
@export var wait_for_customer_exit: bool = false
