class_name CashierConversationData
extends Resource

## A customer's cashier conversation for one specific in-game day.

@export_range(1, 9999, 1) var day: int = 1
@export var customer_id: String = ""
@export_multiline var opening_line: String = ""
@export var post_payment_dialogue: Array[CashierDialogueLine] = []
@export var player_exit_dialogue: Array[String] = []
@export var wait_for_customer_exit: bool = false
