class_name CashierDialogueLine
extends Resource

## One speaker-aware line shown inside the cashier UI after payment.

enum Speaker { CUSTOMER, PLAYER }

@export var speaker: Speaker = Speaker.CUSTOMER
@export_multiline var text: String = ""
@export_range(0, 31, 1) var portrait_frame: int = 0
