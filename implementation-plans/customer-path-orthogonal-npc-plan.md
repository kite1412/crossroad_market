# Customer Path and Orthogonal NPC Movement Implementation Plan

## 1. Purpose

This implementation plan defines the customer path polish for Day 1.

The goal is to make customer/NPC movement more natural for a classic pixel RPG / farming-shop style game by using a controlled path marker setup, preventing shelf placement on customer routes, and making NPC movement use only horizontal and vertical movement segments.

Core rule:

```text
NPC customers should not glide diagonally across the store.
NPC movement should feel like classic 4-directional pixel RPG movement.
```

This plan is intended for Codex implementation after the current Task 1 NPC movement/collision work is stable.

---

## 2. Design Direction

### 2.1 Movement Style

NPC movement should be restricted to orthogonal route segments:

```text
Allowed:
- horizontal movement
- vertical movement

Not allowed:
- direct diagonal movement from one point to another
```

If an NPC needs to travel from one point to another where both X and Y differ, the path must be split into an L-shaped route.

Example:

```text
From A to B diagonally:
A ───── corner
        │
        │
        B
```

Instead of:

```text
A
 \ 
  \ 
   B
```

This is more natural for the intended visual style because it matches the feel of older Harvest Moon / Story of Seasons-like movement patterns.

---

## 3. Marker Setup

Use a small number of controlled Marker2D nodes.

Recommended setup:

```text
NPCPathMarkers
├── NPCPathEntry
├── NPCPathAisle
├── NPCPathCashier
└── NPCQueueMarker
```

Optional existing marker:

```text
NPCExitMarker
```

### 3.1 NPCPathEntry

Purpose:

```text
- customer entry route point
- route point for leaving the store
- should be near the customer entrance/door, but not inside wall collision
```

### 3.2 NPCPathAisle

Purpose:

```text
- central walking route inside the store
- bridge between entry, shelf access, and cashier
- prevents NPC from cutting diagonally through the room
```

### 3.3 NPCPathCashier

Purpose:

```text
- approach point before cashier/queue
- used after customer takes item from shelf
- prevents NPC from returning unnecessarily to the front-door path marker
```

### 3.4 NPCQueueMarker

Purpose:

```text
- final customer queue/checkout target
- may reuse existing NPCQueueMarker if already present
```

### 3.5 NPCExitMarker

Purpose:

```text
- final exit/despawn target
- optional if NPCPathEntry already works as exit point, but preferred for clarity
```

---

## 4. Customer Path Visual and No-Drop Zones

Create customer path zones as simple horizontal/vertical route segments.

Recommended scene structure:

```text
Store
├── NPCPathMarkers
│   ├── NPCPathEntry
│   ├── NPCPathAisle
│   ├── NPCPathCashier
│   └── NPCQueueMarker
│
└── CustomerPathZones
    ├── EntryToAisle
    │   ├── Visual
    │   └── CollisionShape2D
    ├── AisleToCashier
    │   ├── Visual
    │   └── CollisionShape2D
    └── CashierToQueue
        ├── Visual
        └── CollisionShape2D
```

Recommended node type for each zone:

```text
Area2D
├── Polygon2D or ColorRect-like visual
└── CollisionShape2D
```

Important:

```text
CustomerPathZones must not be StaticBody2D.
They should not physically block the player.
They are only used for shelf placement validation and optional visual guidance.
```

### 4.1 Visual Behavior

The path visual should not always clutter the scene.

Recommended behavior:

```text
Player not carrying shelf
→ customer path visual hidden

Player carrying shelf
→ customer path visual visible / semi-transparent

Player drops shelf successfully
→ customer path visual hidden

Player enters Storage/Yard
→ customer path visual hidden
```

Suggested visual style:

```text
- semi-transparent warm color
- low alpha
- rectangular horizontal/vertical path segments
- no diagonal path visuals
```

---

## 5. No-Drop Rule

When the player tries to place a carried shelf, the store should reject placement if the target shelf body overlaps any customer path zone.

Expected behavior:

```text
Player carries shelf
→ path visual appears
→ player presses Q on customer path zone
→ shelf is not placed
→ player keeps carrying shelf
→ alert appears: "Keep the customer path clear."
```

### 5.1 Alert Cooldown

The alert should not spam every frame or every repeated Q press.

Use a 1-second cooldown for the alert only.

Important:

```text
Cooldown affects only the notification.
Cooldown does not affect validation.
Shelf placement must always be blocked on customer path zones.
```

Suggested variables:

```gdscript
const CUSTOMER_PATH_ALERT_COOLDOWN_MS: int = 1000
var _last_customer_path_alert_msec: int = 0
```

Suggested helper:

```gdscript
func _can_show_customer_path_alert() -> bool:
    var now := Time.get_ticks_msec()

    if now - _last_customer_path_alert_msec < CUSTOMER_PATH_ALERT_COOLDOWN_MS:
        return false

    _last_customer_path_alert_msec = now
    return true
```

### 5.2 Validation Order

Suggested shelf drop validation order:

```text
1. Storage door no-drop
2. Yard door no-drop
3. Customer path no-drop
4. Cashier flow no-drop
5. Physics collision
6. Reachability
7. Allow placement
```

Customer path should be separate from cashier flow.

Reason:

```text
- Customer path = walking lane through store
- Cashier flow = checkout/queue/counter area
```

They can overlap visually near cashier, but the logic should remain readable.

---

## 6. Orthogonal Route Algorithm

### 6.1 Core Helper: Orthogonal Route

Add a helper that converts any point-to-point travel into horizontal/vertical route points.

Suggested helper:

```gdscript
func _make_orthogonal_route(from_pos: Vector2, to_pos: Vector2, horizontal_first: bool = true) -> Array[Vector2]:
    var route: Array[Vector2] = []

    if from_pos.distance_to(to_pos) <= 2.0:
        return route

    var corner := Vector2(to_pos.x, from_pos.y) if horizontal_first else Vector2(from_pos.x, to_pos.y)

    if from_pos.distance_to(corner) > 2.0:
        route.append(corner)

    if corner.distance_to(to_pos) > 2.0:
        route.append(to_pos)

    return route
```

This prevents direct diagonal movement when moving between two arbitrary positions.

### 6.2 Why Not Diagonal?

Diagonal movement can look like sliding/gliding in a pixel RPG if diagonal animations are not available.

For this project, the expected style is:

```text
- walk left/right
- walk up/down
- turn at corners
- follow readable store lanes
```

---

## 7. NPC Routing Plan

NPC should not own the full path strategy. Store should provide route points. NPC should simply follow them.

### 7.1 Store Responsibilities

Store.gd should own:

```text
- marker references
- customer path zones
- route calculation
- nearest marker selection
- customer path visual visibility
- customer path no-drop validation
```

Recommended functions:

```gdscript
func get_npc_entry_route_to_shelf(shelf_position: Vector2) -> Array[Vector2]
func get_npc_route_to_cashier_from(from_position: Vector2) -> Array[Vector2]
func get_npc_exit_route_from_cashier() -> Array[Vector2]
func _get_nearest_npc_path_marker(position: Vector2, markers: Array[Marker2D]) -> Marker2D
func _make_orthogonal_route(from_pos: Vector2, to_pos: Vector2, horizontal_first: bool = true) -> Array[Vector2]
func _is_shelf_drop_on_customer_path(object_rect: Rect2) -> bool
func _set_customer_path_visual_visible(is_visible: bool) -> void
```

### 7.2 NPC Responsibilities

NPC.gd should own:

```text
- current route point list
- moving to next route point
- switching state when route is complete
```

NPC.gd should not hardcode store path strategy if Store.gd can provide route points.

Recommended NPC helper names:

```gdscript
func _set_route_points(points: Array[Vector2]) -> void
func _has_route_points() -> bool
func _get_current_route_target() -> Vector2
func _advance_route_if_reached() -> void
```

---

## 8. Route Flow

### 8.1 NPC Entering Store

Expected route:

```text
NPCPathEntry
→ NPCPathAisle
→ orthogonal route to shelf position
```

Pseudo-flow:

```gdscript
func get_npc_entry_route_to_shelf(shelf_position: Vector2) -> Array[Vector2]:
    var route: Array[Vector2] = []

    if npc_path_entry != null:
        route.append(npc_path_entry.global_position)

    if npc_path_aisle != null:
        route.append(npc_path_aisle.global_position)

    var start := route[-1] if not route.is_empty() else shelf_position
    route.append_array(_make_orthogonal_route(start, shelf_position, true))

    return route
```

### 8.2 NPC Moving From Shelf to Cashier

Problem to solve:

```text
After taking an item, NPC should not always return to the front-door/store-path marker.
NPC should choose the nearest useful marker and then head to cashier.
```

Expected route:

```text
current NPC/shelf position
→ nearest of [NPCPathAisle, NPCPathCashier]
→ NPCPathCashier
→ NPCQueueMarker
```

Pseudo-flow:

```gdscript
func get_npc_route_to_cashier_from(from_position: Vector2) -> Array[Vector2]:
    var route: Array[Vector2] = []

    var nearest := _get_nearest_npc_path_marker(from_position, [
        npc_path_aisle,
        npc_path_cashier
    ])

    if nearest != null:
        route.append_array(_make_orthogonal_route(from_position, nearest.global_position, true))

    if npc_path_cashier != null and nearest != npc_path_cashier:
        var start := route[-1] if not route.is_empty() else from_position
        route.append_array(_make_orthogonal_route(start, npc_path_cashier.global_position, true))

    if npc_queue_marker != null:
        var start := route[-1] if not route.is_empty() else from_position
        route.append_array(_make_orthogonal_route(start, npc_queue_marker.global_position, true))

    return route
```

### 8.3 NPC Exiting Store

Expected route:

```text
cashier/queue
→ NPCPathCashier
→ NPCPathAisle
→ NPCPathEntry
→ NPCExitMarker
```

Pseudo-flow:

```gdscript
func get_npc_exit_route_from_cashier() -> Array[Vector2]:
    var route: Array[Vector2] = []

    if npc_path_cashier != null:
        route.append(npc_path_cashier.global_position)

    if npc_path_aisle != null:
        route.append(npc_path_aisle.global_position)

    if npc_path_entry != null:
        route.append(npc_path_entry.global_position)

    if npc_exit_marker != null:
        route.append(npc_exit_marker.global_position)

    return route
```

---

## 9. Route Following Rule

The NPC should follow route points one by one.

Important:

```text
Even if a route point is diagonal from the NPC's current position, the route should already be expanded into orthogonal corner points by Store.gd.
```

NPC movement should keep the current CharacterBody2D / move_and_slide logic if it exists.

If NPC currently moves directly with `global_position.move_toward`, convert carefully only if necessary.

Do not rewrite the whole state machine.

---

## 10. Customer Path Zone Construction

### 10.1 Manual First

For Day 1, prefer manual zone placement in `Store.tscn`.

Reason:

```text
- easier to tune visually
- easier to move in the Godot editor
- avoids overbuilding automatic path-zone generation
- gives the designer direct control over no-drop areas
```

Recommended zones:

```text
EntryToAisle
AisleToCashier
CashierToQueue
```

Each zone should have:

```text
- Area2D root
- CollisionShape2D for Rect2 validation
- simple visual child
```

### 10.2 No Diagonal Zones

Do not create diagonal customer path zones.

If the visual path needs to turn, use multiple orthogonal rectangles.

Example:

```text
Wrong:
Entry ───── diagonal line ───── Aisle

Correct:
Entry ───── horizontal segment
                         │
                         │ vertical segment
                         Aisle
```

---

## 11. Customer Path Visual Visibility

In Store.gd, track whether the player is carrying a shelf.

Suggested logic:

```gdscript
func _process(_delta: float) -> void:
    ...
    _update_customer_path_visual_visibility()
```

Suggested helper:

```gdscript
func _update_customer_path_visual_visibility() -> void:
    if _current_storage != null or _current_yard != null or _is_transitioning:
        _set_customer_path_visual_visible(false)
        return

    var carried_object := _get_carried_object_from_player()
    _set_customer_path_visual_visible(carried_object != null)
```

This ensures the guide only appears when placement matters.

---

## 12. Shelf Drop Validation Against Customer Path

Suggested helper:

```gdscript
func _is_shelf_drop_on_customer_path(object_rect: Rect2) -> bool:
    var zones := get_tree().get_nodes_in_group("customer_path_zones")

    for zone in zones:
        if not zone is Area2D:
            continue

        if not _is_descendant_of(zone, self):
            continue

        var zone_rect := _get_area_rect(zone as Area2D)

        if zone_rect.size == Vector2.ZERO:
            continue

        if object_rect.intersects(zone_rect):
            return true

    return false
```

Add each CustomerPathZone Area2D to group:

```text
customer_path_zones
```

Then update `_evaluate_shelf_drop_restriction()`:

```gdscript
if _is_shelf_drop_on_customer_path(object_rect):
    return _make_drop_restriction(
        true,
        DROP_REJECTION_CUSTOMER_PATH,
        "Keep the customer path clear.",
        object_rect,
        false
    )
```

If using notification cooldown, the rejection can include a type and the feedback function can throttle that specific message.

---

## 13. Alert Cooldown Integration

Add rejection type:

```gdscript
const DROP_REJECTION_CUSTOMER_PATH: StringName = &"customer_path"
```

In feedback:

```gdscript
func _show_drop_restriction_feedback(restriction: Dictionary) -> void:
    var type: StringName = restriction.get("type", DROP_REJECTION_NONE)
    var message := str(restriction.get("message", "I can't place the shelf here."))

    if type == DROP_REJECTION_CUSTOMER_PATH:
        if _can_show_customer_path_alert():
            _show_notification(message, 0.9)
        return

    ... existing warning/notification flow ...
```

This prevents repeated spam while still blocking placement.

---

## 14. Files to Check

Codex should inspect these files before editing:

```text
scenes/locations/Store.tscn
scripts/locations/store/Store.gd
scripts/npc/NPC.gd
scenes/npc/NPC.tscn
scripts/npc/behavior/NPCShoppingBehavior.gd
scripts/npc/behavior/NPCQueueSystem.gd
```

Optional files if relevant:

```text
scripts/locations/Storage.gd
scripts/player/Player.gd
scripts/ui/HUD.gd
```

---

## 15. Implementation Steps

### Step 1 — Scene Marker Setup

Add or align:

```text
NPCPathMarkers/NPCPathEntry
NPCPathMarkers/NPCPathAisle
NPCPathMarkers/NPCPathCashier
NPCPathMarkers/NPCQueueMarker
NPCExitMarker if needed
```

Keep existing markers if already present, but rename or map them clearly in Store.gd.

### Step 2 — Customer Path Zones

Add:

```text
CustomerPathZones/EntryToAisle
CustomerPathZones/AisleToCashier
CustomerPathZones/CashierToQueue
```

Each zone:

```text
Area2D
├── visual child
└── CollisionShape2D
```

Add each zone to group:

```text
customer_path_zones
```

### Step 3 — Store Route API

Add Store.gd route helpers:

```text
get_npc_entry_route_to_shelf
get_npc_route_to_cashier_from
get_npc_exit_route_from_cashier
_make_orthogonal_route
_get_nearest_npc_path_marker
```

### Step 4 — NPC Route Following

Adjust NPC.gd so it can follow route arrays before continuing to its final target.

Do not rewrite state machine.

Add minimal route queue behavior.

### Step 5 — No-Drop Validation

Add customer path rejection to shelf drop validation.

Make sure player keeps carrying shelf when rejected.

### Step 6 — Path Visual Visibility

Show path visual only while carrying shelf.

Hide on:

```text
- successful shelf placement
- entering Storage
- entering Yard
- transition
- no carried shelf
```

### Step 7 — Manual Tests

Run all acceptance tests below.

---

## 16. Acceptance Tests

### NPC Movement

```text
1. Normal customer enters store.
2. Customer walks via entry/aisle route.
3. Customer reaches a shelf.
4. Customer takes item.
5. Customer does not return unnecessarily to front-door marker.
6. Customer chooses nearest useful marker from shelf position.
7. Customer moves to cashier using horizontal/vertical route.
8. Customer queues/checkouts normally.
9. Customer exits via aisle/entry/exit route.
10. No direct diagonal glide is visible.
```

### Shelf Placement

```text
1. Player carries shelf.
2. Customer path visual appears.
3. Player presses Q on customer path.
4. Shelf is not placed.
5. Player remains carrying shelf.
6. Alert appears: "Keep the customer path clear."
7. Repeated Q within 1 second does not spam alert.
8. Q after 1 second can show alert again.
9. Player can place shelf outside customer path.
10. Cashier/door no-drop logic still works.
```

### Visual

```text
1. Path visual is hidden when not carrying shelf.
2. Path visual appears while carrying shelf.
3. Path visual is horizontal/vertical only.
4. Path visual does not cover the whole store.
5. Path visual hides when entering Storage/Yard.
```

### Story Regression

```text
1. Normal Day customers still work.
2. Gooby event still works.
3. Slime follow-up still works.
4. Checkout queue still works.
```

---

## 17. Codex Prompt

Use this prompt when ready to implement:

```text
Implement customer path marker routing and no-drop placement zones based on implementation-plans/customer-path-orthogonal-npc-plan.md.

Main requirements:
- Use 3–4 controlled Marker2D nodes.
- NPC customer movement must be orthogonal only: horizontal and vertical route segments.
- Do not allow direct diagonal NPC movement across the store.
- Use L-shaped route points when target movement would otherwise be diagonal.
- Add simple customer path visual zones using horizontal/vertical segments.
- Show customer path visual only while player carries a shelf.
- Prevent shelf placement on customer path zones.
- If player tries to place shelf on path, reject drop and show "Keep the customer path clear." with 1 second alert cooldown.
- Store.gd should own route calculation.
- NPC.gd should only follow route points.
- Do not rewrite the entire NPC state machine.
- Do not add NavigationAgent2D unless absolutely necessary.
- Do not break cashier, Gooby, Slime, Storage, or Yard flows.

Files to inspect first:
- scenes/locations/Store.tscn
- scripts/locations/store/Store.gd
- scripts/npc/NPC.gd
- scenes/npc/NPC.tscn
- scripts/npc/behavior/NPCShoppingBehavior.gd
- scripts/npc/behavior/NPCQueueSystem.gd

Expected output:
- Marker setup used.
- Route algorithm explanation.
- How diagonal movement was prevented.
- Customer path no-drop implementation.
- Alert cooldown implementation.
- Files changed.
- Manual test results.
```

---

## 18. Final Recommendation

Use this Day 1 setup:

```text
NPCPathEntry
NPCPathAisle
NPCPathCashier
NPCQueueMarker
```

Use this movement rule:

```text
All NPC route segments must be horizontal or vertical.
Any diagonal target must be split into an L-shaped route.
```

Use this placement rule:

```text
Customer path zones are no-drop zones for shelves, not physical walls.
```

This keeps the system simple, controllable, readable, and appropriate for a classic pixel shop simulation style.
