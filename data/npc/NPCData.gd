class_name NPCData
extends Resource

enum VisitPhase { MORNING, DAY, NIGHT }
enum PatienceType { IMPATIENT, PATIENT, QUITTER }
enum NPCCategory { STORY, GENERIC }

# --- Core Identity ---
@export var npc_id: String = ""
@export var display_name: String = ""
@export var npc_category: NPCCategory = NPCCategory.GENERIC

# --- Schedule ---
@export var visit_phase: VisitPhase = VisitPhase.DAY
@export var visit_days: Array[int] = []
@export var spawn_order: int = 0
@export var patience_type: PatienceType = PatienceType.PATIENT

# --- Items ---
@export var favorite_items: Array[String] = []

# The amount of cash this customer puts on the counter during checkout.
# Leave this at 0 to use the cashier's sensible denomination fallback.
@export_range(0, 9999, 1) var checkout_cash: int = 0

# --- STORY NPC specific ---
@export var dialogue_set_id: String = ""   # references a DialogueSet resource
@export var event_set_id: String = ""    # references an event dialog set

# --- GENERIC NPC specific ---
@export var behavior_profile_id: String = ""  # references a BehaviorProfile resource
@export var spawn_chance: float = 1.0  # 0.0-1.0 probability to spawn per day

# --- Visuals ---
@export var portrait: Texture2D = null
@export var assets_path: String = ""
