# Crossroad Market — Day 1 Extended Polish and Store OS Draft

## 1. Purpose

This document defines the next Day 1 polish layer after the baseline mechanic polish tasks.

The goal is to improve clarity, interaction feel, NPC movement reliability, and the early Store OS concept without overbuilding a complex management system.

Core rule:

```text
Do not turn Day 1 into a full simulation system.
Implement clear, small, testable UI and interaction upgrades.
```

This file is intentionally separate from `docs/polish/day-1-mechanic-polish.md` because these tasks include both polish and light feature additions.

Use this document as a Codex task spec.

```text
1 prompt = 1 task.
Do not implement all tasks in one Codex run.
```

---

## 2. Final Direction

### 2.1 Store OS Concept

The Store OS is not intended to be a complex desktop simulation yet. It is a simple panel that contains multiple app panels.

Target Day 1 structure:

```text
Store OS
├── POS App
│   ├── cashier/customer request
│   ├── cart item list
│   ├── add/delete item buttons
│   ├── purchase total
│   └── basic income/outcome/profit display
│
└── Restock App Draft
    ├── item placeholder ColorRects
    ├── item name labels
    └── draft-only restock UI
```

Out of scope for this pass:

```text
- full multi-window OS behavior
- draggable windows
- complex dynamic pricing
- full restock economy
- full finance/accounting application
- persistent business analytics system
```

### 2.2 Hint Philosophy

Hints are intended to appear once, not repeatedly.

The player can later re-read hint/help information from a settings/help option if they forget.

Important distinction:

```text
One-time hint/tutorial:
- appears once per category or step
- uses a simple animated dialog
- can be skipped/advanced with touchpad/mouse click

Interaction prompt:
- compact object prompt may still appear when relevant
- should not become a long repeated tutorial
```

---

## 3. Recommended Execution Order

```text
Task 1 — Fix NPC Entry Position and Wall Collision
Task 2 — Polish Store Door CollisionShape2D and YSort
Task 3 — One-Time Hint Dialog with Click Skip
Task 4 — Cursor Hover Name Tooltip
Task 5 — Activity Board Completion Notification and Glow
Task 6 — Cashier POS Cart Add/Delete and Total Purchase
Task 7 — Store OS Shell with POS App and Restock App Draft
```

Run the movement/interaction tasks first before the Store OS work.

---

## 4. Task 1 — Fix NPC Entry Position and Wall Collision

### Goal

NPCs should enter the store from a believable door/entry position and should not pass through walls or blocked store geometry.

### Current Problem

```text
- NPC enter positioning is not aligned with the store entrance.
- NPCs may appear to walk through walls or scene boundaries.
- NPC movement may be using direct position movement without reliable collision handling.
```

### Expected Behavior

```text
NPC spawns near/at a valid entrance marker
→ walks through a safe route into the store
→ moves to shelf / queue / cashier using existing state flow
→ exits through a valid exit marker
```

NPCs should not visually or physically pass through walls.

### Implementation Direction

- Check `NPC.gd`, `NPC.tscn`, `Store.gd`, and Store scene markers.
- Ensure NPC has a valid `CharacterBody2D` / `CollisionShape2D` setup.
- Ensure wall/store boundary has collision via `StaticBody2D`, `TileMap` collision, or existing scene collision.
- Prefer waypoint-based safe movement for Day 1 instead of full pathfinding if pathfinding is not already stable.
- If NPC movement currently uses direct `global_position = move_toward(...)`, consider moving through `velocity` and `move_and_slide()` where appropriate.
- Add or align markers if needed:

```text
NPCEntryMarker
NPCExitMarker
NPCQueueMarker
NPCStorePathMarker / aisle marker
```

### Checklist

- [ ] NPC entry aligns with store entrance.
- [ ] NPC does not spawn inside wall/collision.
- [ ] NPC movement does not pass through walls.
- [ ] NPC can still reach shelf.
- [ ] NPC can still reach queue/cashier.
- [ ] NPC can still exit store.
- [ ] Existing NPC state machine is not rewritten unnecessarily.

### Codex Prompt

```text
Analisa dan implementasikan Task 1 — Fix NPC Entry Position and Wall Collision dari docs/polish/day-1-extended-polish-and-store-os.md.

Batasan:
- Jangan rewrite seluruh NPC state machine.
- Jangan tambah fitur pathfinding kompleks jika waypoint cukup.
- Fokus entry position, wall collision, dan movement safety.
- NPC harus tetap bisa mengikuti flow: enter → shelf → queue/cashier → exit.
- Jangan ubah Gooby/Slime story logic.

File yang dicek:
- scripts/npc/NPC.gd
- scenes/npc/NPC.tscn
- scripts/locations/store/Store.gd
- Store scene / markers / wall collision

Expected output:
- Penyebab NPC positioning/wall collision bermasalah.
- File/scene yang diubah.
- Marker/collision yang ditambah atau disesuaikan.
- Test NPC normal masuk store, antre, checkout, exit.
- Test Gooby/Slime tetap berjalan.
```

---

## 5. Task 2 — Polish Store Door CollisionShape2D and YSort

### Goal

Door interaction area in the store should be precise and visually consistent with the door position.

### Current Problem

```text
- Door collision / interaction area feels too large.
- Player can trigger or see door prompt from positions that feel inaccurate.
- Door depth/YSort may not match the player/object visual layering.
```

### Expected Behavior

```text
Player stands near the actual door area
→ prompt appears
→ press E to enter/exit
→ door area does not feel oversized
```

Door interaction must still work while the player is carrying a shelf if the door is part of the core shelf movement loop.

### Implementation Direction

Recommended door node structure:

```text
Door
├── VisualRoot
│   └── Sprite/ColorRect
├── InteractionArea
│   └── CollisionShape2D
└── EntryMarker / ReturnMarker
```

Recommended starting interaction shape:

```text
Width: door width + small margin
Height: small standing zone in front of door
```

If door visual is 32x32, start around:

```text
36x24 or 40x28
```

### Checklist

- [ ] Store door interaction area is smaller and precise.
- [ ] Door prompt appears only near the door.
- [ ] Press E transition still works.
- [ ] Door works while carrying shelf when required.
- [ ] Player does not instantly re-trigger transition after return.
- [ ] Door visual layering/YSort feels correct.

### Codex Prompt

```text
Analisa dan implementasikan Task 2 — Polish Store Door CollisionShape2D and YSort dari docs/polish/day-1-extended-polish-and-store-os.md.

Batasan:
- Jangan ubah core transition flow.
- Door tetap pakai press E, bukan auto transition.
- Door harus tetap bisa dipakai saat player membawa shelf jika itu bagian core loop.
- Fokus ukuran CollisionShape2D / InteractionArea dan visual depth/YSort.

File/scene yang dicek:
- Store scene door nodes
- StorageDoor / YardDoor / related return markers
- Player interaction priority if needed

Expected output:
- Door area sebelum/sesudah.
- Perubahan CollisionShape2D / marker / z_index atau y_sort.
- Test masuk storage/yard dengan dan tanpa membawa shelf.
```

---

## 6. Task 3 — One-Time Hint Dialog with Click Skip

### Goal

Replace repeated long guidance triggered by object collision/proximity with one-time hint dialogs.

Hints should appear once per category/step and be skippable with mouse/touchpad click.

### Important Design Rule

```text
Long hint/tutorial = once only.
Compact interaction prompt = can still appear when relevant.
```

### Expected Behavior

```text
First time player encounters a new interaction category
→ animated hint dialog appears
→ player can click/tap touchpad to continue/skip
→ hint is marked as seen
→ future encounters do not show the long hint again
```

Example hint categories:

```text
- supply_box_take_stock
- shelf_pickup
- shelf_place
- shelf_stock
- cashier_interaction
- activity_board
- door_transition
```

### Settings/Help Note

Because hints appear once, the player should be able to re-read general help later from a settings/help option.

For this task, it is acceptable to implement the hint storage flag and leave the full settings/help panel as a simple placeholder if not already available.

### Animation Direction

Simple animation only:

```text
- fade in
- slight slide up or scale in
- click/touchpad press closes or advances
- fade out
```

### Checklist

- [ ] Long hints appear only once per category.
- [ ] Hint can be skipped/closed by mouse/touchpad click.
- [ ] Hint does not block permanently.
- [ ] Hint state prevents repeated spam.
- [ ] Compact prompts still work separately if already implemented.
- [ ] Help/settings placeholder exists or future hook is documented.

### Codex Prompt

```text
Analisa dan implementasikan Task 3 — One-Time Hint Dialog with Click Skip dari docs/polish/day-1-extended-polish-and-store-os.md.

Batasan:
- Jangan buat tutorial system besar.
- Jangan spam hint setiap player menyentuh CollisionShape2D.
- Hint panjang muncul sekali per category/step.
- Hint bisa di-skip dengan mouse/touchpad click.
- Compact interaction prompt boleh tetap ada.
- Jangan merusak cashier/activity board modal lock.

File yang dicek:
- Player interaction/hint logic
- HUD hint/notification code
- existing one-time guidance flags
- project input map for mouse click if needed

Expected output:
- Daftar hint category.
- Cara state hint once-only disimpan.
- Animasi hint dialog.
- Cara click/touchpad skip bekerja.
- Test hint muncul sekali dan tidak looping.
```

---

## 7. Task 4 — Cursor Hover Name Tooltip

### Goal

Item/object names should appear when the mouse cursor hovers over the item/object, not only when the player body enters a `CollisionShape2D` / interaction area.

### Current Problem

```text
Object name feedback exists, but it is tied too strongly to player proximity/collision.
```

### Expected Behavior

```text
Mouse cursor hovers over object/item
→ tooltip appears with object/item name
→ tooltip animates in
→ tooltip hides when cursor leaves
```

This should be separate from keyboard/player proximity prompts.

### Tooltip Style

Simple UI:

```text
Item Name
```

Animation:

```text
fade in 0.1s–0.2s
slight upward offset or scale in
fade out on mouse exit
```

### Scope

Apply to important Day 1 interactables:

```text
- items on shelf
- shelf objects
- supply boxes
- cashier
- activity board
- doors if appropriate
```

### Checklist

- [ ] Tooltip uses mouse/cursor hover, not player body collision.
- [ ] Tooltip shows correct object/item name.
- [ ] Tooltip hides on mouse exit.
- [ ] Tooltip has simple animation.
- [ ] Player proximity prompt remains separate.
- [ ] Does not block gameplay input.

### Codex Prompt

```text
Analisa dan implementasikan Task 4 — Cursor Hover Name Tooltip dari docs/polish/day-1-extended-polish-and-store-os.md.

Batasan:
- Jangan gunakan player body_entered sebagai hover trigger.
- Gunakan mouse_entered/mouse_exited pada Area2D atau pendekatan Godot yang sesuai.
- Tooltip hanya untuk nama object/item.
- Jangan campur dengan tutorial one-time hint.
- Jangan merusak compact interaction prompt.

File/scene yang dicek:
- Shelf / item interaction areas
- SupplyBox
- Cashier
- ActivityBoard
- Door nodes if needed
- HUD tooltip label or new lightweight tooltip UI

Expected output:
- Object yang diberi cursor hover.
- Cara tooltip mendapat nama object/item.
- Animasi tooltip.
- Test hover item, shelf, cashier, board.
```

---

## 8. Task 5 — Activity Board Completion Notification and Glow

### Goal

The player should know when a task is completed and should be guided to notice the Activity Board.

### Current Problem

```text
- Activity Board exists, but task completion is not obvious enough.
- Player can complete an objective without knowing the task has advanced.
- Activity Board needs visual attention feedback.
```

### Expected Behavior

```text
Player completes a Day 1 step
→ HUD task completion notification appears
→ Activity Board glows/fades around its sides
→ next task/objective becomes available
```

### Simple HUD Notification

Example:

```text
Task Complete!
Human Shelf placed.
Check the Activity Board.
```

Notification should be small and non-blocking.

### Activity Board Glow

Visual direction:

```text
- simple outline/glow around board sides
- fade in/out animation
- repeat 2–3 times
- hidden after animation
```

Possible board task milestones:

```text
1. Human shelf placed in store
2. Human shelf stocked
3. Normal customers served / Day revenue progress
4. Mystery/ghost shelf discovered
5. Ghost shelf placed/stocked
6. Gooby/Slime branch resolved
```

Do not build a complex quest system in this task.

### Checklist

- [ ] HUD notification appears when a task completes.
- [ ] Notification is non-blocking.
- [ ] Activity Board glows after task completion.
- [ ] Glow hides after animation.
- [ ] Board remains interactable.
- [ ] Objective/task text stays in sync.
- [ ] No repeated notification spam for already-completed task.

### Codex Prompt

```text
Analisa dan implementasikan Task 5 — Activity Board Completion Notification and Glow dari docs/polish/day-1-extended-polish-and-store-os.md.

Batasan:
- Jangan buat full quest system kompleks.
- Fokus Day 1 milestone existing.
- Notification sederhana di HUD.
- Activity Board glow sederhana di sisi/outline board.
- Glow fade in/out 2–3 kali, lalu hidden.
- Jangan spam notification untuk task yang sama.

File yang dicek:
- Store objective/progression code
- ActivityBoard scene/script
- HUD notification code
- existing _update_objective / milestone functions

Expected output:
- Milestone yang dideteksi.
- Cara task complete notification ditampilkan.
- Cara Activity Board glow dibuat.
- Test task 1 selesai, board glow, next task update.
```

---

## 9. Task 6 — Cashier POS Cart Add/Delete and Total Purchase

### Goal

Cashier/POS panel should support item cart management with Add and Delete buttons, and correctly calculate the customer purchase total.

### Current Direction

The current cashier panel is a good base for the POS app. This task should polish it into a simple POS cart, not a full store OS yet.

### Expected Behavior

```text
Open cashier/POS panel
→ customer request appears
→ player selects/scans item
→ click Add
→ item appears in cart list
→ total updates
→ player can delete incorrect item
→ receive payment completes checkout if cart is valid
```

### Day 1 Scope

Keep it simple:

```text
- Add item button
- Delete item button per cart row
- Total purchase value
- Basic validation against customer request
- No quantity system unless already easy
- No discount/tax system
- No complex multi-item customer unless existing NPC shopping list already supports it
```

### Validation Rules

```text
Cart empty:
- Cannot receive payment.
- Show: Add an item first.

Wrong item:
- Prevent checkout or show warning.
- Show: This customer did not ask for that item.

Correct item:
- Total uses item sell price.
- Receive Payment completes checkout.
```

For Gooby gift/refuse flow, preserve the existing story choice logic.

### Checklist

- [ ] Add button adds selected/scanned item to cart.
- [ ] Delete button removes item from cart.
- [ ] Total updates after add/delete.
- [ ] Empty cart cannot complete checkout.
- [ ] Wrong item does not complete normal checkout.
- [ ] Correct item completes normal checkout.
- [ ] Gooby gift/refuse flow still works.
- [ ] UI remains readable at target resolution.

### Codex Prompt

```text
Analisa dan implementasikan Task 6 — Cashier POS Cart Add/Delete and Total Purchase dari docs/polish/day-1-extended-polish-and-store-os.md.

Batasan:
- Jangan buat full Store OS dulu.
- Fokus cashier/POS cart di panel cashier existing.
- Tambahkan Add dan Delete item.
- Total pembelian customer harus update dengan benar.
- Jangan tambah quantity/discount/tax kecuali sudah sangat sederhana.
- Jangan merusak Gooby gift/refuse flow.
- Jangan merusak normal checkout.

File yang dicek:
- scripts/ui/cashier/Cashier.gd
- cashier scene/panel UI
- NPC cart/request logic
- ItemData sell_price
- EconomyManager revenue update

Expected output:
- Flow cashier sebelum/sesudah.
- Struktur cart item list.
- Logic Add/Delete.
- Logic total.
- Validasi correct/wrong/empty cart.
- Test normal NPC checkout dan Gooby branch.
```

---

## 10. Task 7 — Store OS Shell with POS App and Restock App Draft

### Goal

Create a simple Store OS panel that contains app panels. This should feel like a small shop management OS, not a full complex desktop system.

### Clarified Design

The Store OS is a panel that contains multiple app panels.

For Day 1, only two apps are required:

```text
1. POS App
2. Restock App Draft
```

The POS App can reuse or wrap the existing cashier panel logic.

The Restock App is only a draft UI for now.

### Expected Structure

```text
Store OS Panel
├── Header
│   └── title: Store OS
├── App Tabs / App Buttons
│   ├── POS
│   └── Restock
└── App Content Area
    ├── POS App content
    └── Restock App content
```

### POS App Content

Should include the cashier/POS functionality from Task 6:

```text
- customer name
- request text
- cart item list
- add/delete item controls
- total
- receive payment / Gooby choice actions
- simple income/outcome/profit display if safe
```

Basic finance display may be small:

```text
Income: 40G
Outcome: 0G
Profit: 40G
```

If `outcome` is not implemented yet, show it as `0G` or placeholder.

### Restock App Draft

Draft only:

```text
Restock App
- item placeholder ColorRect
- item name label under each item
- optional disabled Restock button
- text: Restock system draft
```

Use current placeholder art style. No final asset required.

### Price Setup Note

The long-term idea is that item prices are not fully configured at the very start of Day 1 until the player initializes/setup the store.

For this task, avoid breaking the existing economy.

Recommended Day 1 draft:

```text
- Keep existing ItemData sell_price for checkout logic.
- Add UI copy/placeholder indicating price setup concept.
- Do not set all prices to 0 unless the entire checkout flow is updated safely.
```

Optional simple implementation:

```text
First POS open:
Show: Store prices initialized from default setup.
```

Do not implement manual per-item pricing yet unless explicitly requested later.

### Checklist

- [ ] Store OS panel exists.
- [ ] POS app/tab exists.
- [ ] Restock app/tab exists.
- [ ] POS app preserves cashier checkout logic.
- [ ] Restock app shows ColorRect item placeholders and labels.
- [ ] UI is not overbuilt into full desktop/window manager.
- [ ] Existing cashier flow remains playable.
- [ ] Existing economy is not broken by price setup concept.

### Codex Prompt

```text
Analisa dan implementasikan Task 7 — Store OS Shell with POS App and Restock App Draft dari docs/polish/day-1-extended-polish-and-store-os.md.

Batasan:
- Jangan buat OS kompleks.
- Store OS cukup panel yang berisi app panels.
- Hanya buat 2 app untuk Day 1: POS App dan Restock App Draft.
- POS App boleh reuse/wrap cashier panel existing.
- Restock App hanya draft UI dengan ColorRect item dan label nama item.
- Jangan implement full restock economy dulu.
- Jangan implement manual dynamic pricing penuh dulu.
- Jangan set semua price jadi 0 jika akan merusak checkout.
- Pertahankan ItemData sell_price untuk core checkout.

File yang dicek:
- Cashier UI/script
- HUD/modal layer
- ItemDatabase/ItemData for item names/prices
- scenes/ui or existing UI structure

Expected output:
- Struktur Store OS panel.
- Cara POS App terhubung ke cashier flow.
- Cara Restock App draft menampilkan item ColorRect + label.
- Cara income/outcome/profit ditampilkan sederhana.
- Catatan price setup masih draft/placeholder.
- Test POS normal checkout, Gooby flow, Restock tab visible.
```

---

## 11. Non-Goals for This Document

Do not implement these yet unless requested in a later task:

```text
- full dynamic price editing
- stock purchase supplier system
- full accounting/finance app
- draggable OS windows
- multi-day persistent store analytics
- full quest/task graph editor
- full NavigationAgent2D rewrite if waypoint movement is enough
```

---

## 12. Suggested Local Validation

After each task, run a focused manual test:

```text
- Start Day 1.
- Move player around store, storage, and cashier.
- Check door interaction.
- Check one-time hints.
- Hover mouse over objects/items.
- Complete at least one activity board milestone.
- Serve one normal NPC.
- Test Gooby branch if cashier/POS changed.
```

If using Godot headless validation, keep sandbox-safe paths:

```bash
mkdir -p .codex/godot-home .codex/godot-data .codex/godot-cache .codex/godot-config

HOME="$PWD/.codex/godot-home" \
XDG_DATA_HOME="$PWD/.codex/godot-data" \
XDG_CACHE_HOME="$PWD/.codex/godot-cache" \
XDG_CONFIG_HOME="$PWD/.codex/godot-config" \
godot --headless --path . --quit
```

Use `godot4` instead of `godot` if that is the installed binary.
