# Crossroad Market — Day 1 Mechanic Polish

## 1. Purpose

Day 1 focuses on **mechanic polish without final art assets**. The project may still use placeholder visuals such as `ColorRect`, simple shapes, or temporary sprites. The goal is not to add new mechanics, but to make the existing mechanics more stable, readable, testable, and ready for future Aseprite asset integration.

Main rule:

```text
Do not add new mechanics.
Polish the mechanics that already exist.
Prepare the project so final assets can be swapped in safely later.
```

This document is intended to guide AI Agent / Codex work. Every change should improve clarity, stability, feedback, onboarding, UI readability, or asset-readiness without expanding the gameplay scope.

---

## 2. Current Polish Context

The game already has a working core shop loop:

```text
Player collects stock
→ Player places item on shelf
→ NPC enters the store
→ NPC walks to shelf
→ NPC searches for item
→ NPC takes item
→ NPC queues at cashier
→ Player scans the item
→ Checkout outcome is resolved
→ NPC exits the store
→ Revenue, trust, or story consequence is updated
```

Day 1 polish should make this loop easier to understand and less fragile.

Important current issue discovered during playtest:

```text
Gooby Trust HUD overlaps other HUD elements.
Player guidance for new items / activities is still unclear.
There is not yet a dedicated task for navigation guidance, activity board, or objective hints.
```

---

## 3. Scope

### 3.1 In Scope

The following work is allowed:

- Stabilize existing player interaction.
- Stabilize existing NPC state flow.
- Improve shelf placement and shelf item feedback.
- Improve cashier scan and checkout clarity.
- Improve notification and dialogue feedback.
- Improve Gooby night choice logic.
- Improve trust/revenue feedback for Gooby.
- Fix temporary HUD layout issues, including overlapping labels.
- Add or improve lightweight objective guidance using existing mechanics.
- Add a simple activity / task board if it only explains existing actions.
- Prepare placeholder node structure for later sprite replacement.
- Add small helper methods only if they make existing logic clearer.
- Document mechanic behavior and expected outcomes.

### 3.2 Out of Scope

The following work is not allowed for Day 1:

- Adding new gameplay systems such as farming, crafting, skill tree, or store expansion.
- Adding new maps that are not needed for the current loop.
- Adding new story branches beyond the existing Gooby night choice.
- Adding complex relationship systems beyond simple trust tracking.
- Replacing all final assets before the asset pack is ready.
- Doing final animation polish that depends on final sprites.
- Reworking the whole project architecture at once.
- Adding a complex quest system.
- Adding a full minimap system.
- Adding a complex tutorial system with cutscenes.

If a proposed change creates a new way to play, it is likely a new mechanic. If it only explains, stabilizes, or clarifies an existing action, it can be treated as polish.

---

## 4. Recommended Execution Order

Use this document as a task spec. Do not ask Codex / AI Agent to execute everything at once.

```text
1 prompt = 1 task or 1 small subtask
```

Recommended order:

```text
Task 1  — Validate Gooby Night Choice
Task 2  — Polish HUD Layout and Trust Display
Task 3  — Polish Player Navigation and Objective Guidance
Task 4  — Polish Activity Board / Action Guidance
Task 5  — Polish NPC Flow
Task 6  — Polish Cashier Flow
Task 7  — Polish Shelf and Item Flow
Task 8  — Polish Feedback and Notifications
Task 9  — Review Core Loop
Task 10 — Prepare Asset-Ready Node Structure
Task 11 — Documentation Update
```

---

## 5. Task 1 — Validate Gooby Night Choice

### Goal

Validate the existing Gooby night branch. This task should be validation-first because the core logic is already implemented.

### Expected Flow

```text
Night phase starts
→ Gooby arrives
→ Gooby searches for Phantom Ice Cream
→ Gooby takes Phantom Ice Cream
→ Gooby queues at cashier
→ Player scans Phantom Ice Cream
→ Cashier shows Gooby-specific choice
```

At this point, player chooses one of two options:

```text
Option A: Give Item
Option B: Refuse Sale
```

### Option A — Give Item

Expected behavior:

```text
Player gives Phantom Ice Cream to Gooby
→ Gooby does not pay with gold
→ Daily revenue does not increase
→ Gooby Trust increases
→ Gooby exits
→ Slime does not spawn
```

Expected result:

```text
Revenue remains 40/50
Gooby Trust increases by +10
Story relationship path improves
Daily target remains missed unless another revenue source exists
```

Checklist:

- [ ] Gooby gift option is visible in cashier UI.
- [ ] Gift option does not add gold.
- [ ] Gift option does not add daily revenue.
- [ ] Gift option increases Gooby trust.
- [ ] Gift option consumes the item.
- [ ] Gooby exits after receiving gift.
- [ ] Slime does not spawn after gift.
- [ ] HUD trust label updates without overlapping other HUD text.
- [ ] Notification explains `+Trust` and `+0G` clearly.

### Option B — Refuse Sale

Expected behavior:

```text
Player refuses Gooby
→ Gooby does not pay
→ Phantom Ice Cream returns to shelf
→ Gooby exits
→ Slime spawns
→ Slime searches for Phantom Ice Cream
→ Slime buys it normally
→ Revenue increases by 10G
```

Expected result:

```text
Revenue changes from 40/50 to 50/50 after Slime purchase
Daily target is achieved
Gooby trust does not increase
Story relationship path does not improve
```

Checklist:

- [ ] Refuse option is visible in cashier UI.
- [ ] Refuse option does not add gold directly from Gooby.
- [ ] Refuse option returns item to ghost shelf.
- [ ] Gooby exits after refusal.
- [ ] Slime spawns only once.
- [ ] Slime can find Phantom Ice Cream after it returns to shelf.
- [ ] Slime purchase adds revenue normally.
- [ ] Target can become `50G / 50G TARGET ACHIEVED`.
- [ ] Notification explains that another customer is coming.

### AI Agent Prompt

```text
Validate Task 1 — Gooby Night Choice from docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Jangan edit file kecuali bug ditemukan.
- Fokus existing Gooby gift/refuse flow.
- Pastikan revenue dan trust tetap reward path terpisah.
- Pastikan HUD trust tidak menimpa HUD lain.

Expected output:
- File yang dicek.
- Status Give Item.
- Status Refuse Sale.
- Status Slime path.
- Bug yang ditemukan.
- Apakah Task 1 bisa ditandai done.
```

---

## 6. Task 2 — Polish HUD Layout and Trust Display

### Goal

Fix HUD readability problems. The current trust display can overlap existing HUD elements, so HUD polish is now a required Day 1 task.

This is not a new mechanic. It is UI polish for already existing game state:

```text
Wallet
Daily revenue target
Time / phase / day
Gooby Trust
Notifications
```

### Design Requirements

HUD must be readable at the project viewport size:

```text
480x270
```

Recommended temporary layout:

```text
Top-left:
- Wallet
- Daily target

Top-center:
- Day
- Phase
- Time

Top-right:
- Gooby Trust

Bottom / lower center:
- Notification text
```

If the top-right area is too cramped, use a compact label:

```text
Trust: 10/100
```

instead of:

```text
Gooby Trust: 10/100
```

### Checklist

- [ ] Gooby Trust label does not overlap Wallet.
- [ ] Gooby Trust label does not overlap target display.
- [ ] Gooby Trust label does not overlap Day / Phase / Time.
- [ ] Trust label is readable at 480x270 viewport.
- [ ] Trust label updates after Give Item.
- [ ] Trust label remains visible but not distracting.
- [ ] Target display still updates correctly.
- [ ] Notification text still appears clearly.
- [ ] HUD uses stable positioning that can later be replaced with designed UI assets.
- [ ] No gameplay logic is moved into HUD.

### Suggested Implementation Direction

Preferred temporary solution:

```text
Create a dedicated HUD container for trust display.
Use alignment/anchors instead of raw overlapping positions where possible.
Keep trust update logic connected to RelationshipManager.
```

Do not overbuild a full HUD framework yet. This task is only to make the current HUD readable.

### Test Cases

#### HUD-01 — Default HUD

```text
Start game.
Expected:
Wallet, target, day, phase, time, and trust are all readable.
No label overlaps another label.
```

#### HUD-02 — Gooby Trust Update

```text
Give item to Gooby.
Expected:
Gooby Trust changes from 0/100 to 10/100.
HUD does not overlap after update.
```

#### HUD-03 — Target Achieved

```text
Reach 50/50 revenue.
Expected:
Target achieved text is readable and does not collide with trust label.
```

### AI Agent Prompt

```text
Analisa dan implementasikan Task 2 — Polish HUD Layout and Trust Display dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Fokus memperbaiki layout HUD yang sudah ada.
- Gooby Trust tidak boleh menimpa Wallet, Target, Day, Phase, atau Time.
- Jangan pindahkan gameplay logic ke HUD.
- Cek file HUD terkait dulu sebelum edit.

Expected output:
- File yang dicek.
- Penyebab overlap.
- Perubahan layout yang dibuat.
- Test HUD default.
- Test Gooby Trust update.
- Test target achieved.
```

---

## 7. Task 3 — Polish Player Navigation and Objective Guidance

### Goal

Make the player understand where to go and what to do next, especially when a new item, shelf, or activity becomes relevant.

This is polish because it explains existing actions. It should not create a new progression system.

### Current Problem

A new player may not know:

```text
- Where to take stock from.
- Which shelf should receive which item.
- When customers can come.
- What to do when ghost shelf / Phantom Ice Cream appears.
- What board or instruction source should be checked.
- What activity is currently expected.
```

### Allowed Guidance Types

Allowed:

```text
- Short objective text in HUD.
- Notification when a new activity becomes available.
- A simple board / sign that lists current available actions.
- Object interaction hint.
- One-line instruction after important discovery.
```

Not allowed:

```text
- Full quest system.
- Complex quest tracking with multiple quest states.
- New reward mechanics.
- New map navigation system.
- Large tutorial cutscene.
```

### Recommended Temporary Objective Flow

```text
Morning:
Objective: Bring the human shelf from storage.

After human shelf placed:
Objective: Stock the human shelf with normal items.

After enough human stock:
Objective: Check the storage corner.

After ghost shelf discovered:
Objective: Place the ghost shelf and stock Phantom Ice Cream.

After ghost shelf stocked:
Objective: Open the store and wait for night customers.

At night:
Objective: Serve Gooby at the cashier.

After refusing Gooby:
Objective: Wait for the next strange customer.
```

### Checklist

- [ ] Player gets a clear initial objective.
- [ ] Objective changes after shelf placement.
- [ ] Objective changes after stock placement.
- [ ] Objective changes after mystery / ghost shelf discovery.
- [ ] Objective tells player what to do with Phantom Ice Cream.
- [ ] Objective tells player to serve Gooby at night.
- [ ] Objective or notification explains what happens after refusing Gooby.
- [ ] Objective text is short enough for 480x270 viewport.
- [ ] Objective UI does not overlap existing HUD.
- [ ] Objective guidance does not add new mechanics.

### Test Cases

#### NAV-01 — First Objective

```text
Start Day 1.
Expected:
Player receives clear direction to bring human shelf from storage.
```

#### NAV-02 — Stocking Objective

```text
Place human shelf in store.
Expected:
Objective changes to stock the human shelf.
```

#### NAV-03 — Ghost Item Objective

```text
Unlock / discover ghost shelf flow.
Expected:
Objective explains what to do with the ghost shelf or Phantom Ice Cream.
```

#### NAV-04 — Night Objective

```text
Night starts with ghost shelf ready.
Expected:
Objective explains that strange customers may arrive and player should use cashier.
```

### AI Agent Prompt

```text
Analisa dan implementasikan Task 3 — Polish Player Navigation and Objective Guidance dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan tambah mechanic baru.
- Jangan buat quest system kompleks.
- Fokus objective/hint untuk existing core loop.
- Pastikan text tidak menimpa HUD lain.
- Cek Store, HUD, dan notification flow sebelum edit.

Expected output:
- File yang dicek.
- Titik gameplay yang belum punya arahan.
- Objective/hint yang ditambahkan.
- Test tiap perubahan objective.
- Risiko overlap UI.
```

---

## 8. Task 4 — Polish Activity Board / Action Guidance

### Goal

Add or polish a simple **activity board** / **shop board** / **instruction board** that helps the player know available actions.

This is optional if objective HUD is already enough, but it is useful if the player needs a stable place to check what to do.

### Design Purpose

The board should answer:

```text
What can I do right now?
Where should I go next?
What item or shelf is relevant now?
```

### Recommended Board Content

The board should show short, current-action text such as:

```text
Today's Work
- Bring shelf from storage
- Stock human shelf
- Serve customers at cashier
```

After ghost flow begins:

```text
Strange Notes
- Check the dark storage corner
- Place the ghost shelf
- Stock Phantom Ice Cream
- Watch the store at night
```

During Gooby branch:

```text
Night Choice
- Give item: Trust +, Revenue 0G
- Refuse sale: Item returns, another customer may come
```

### Implementation Boundary

Allowed:

```text
- A simple interactable board.
- A simple panel with static or state-based text.
- Reuse existing notification/objective state.
```

Not allowed:

```text
- New quest reward system.
- New task completion economy.
- New unlock system.
- Complex journal UI.
```

### Checklist

- [ ] Board exists or current guidance alternative is documented.
- [ ] Board explains current activity clearly.
- [ ] Board text updates at major existing milestones if implemented.
- [ ] Board does not introduce new gameplay requirements.
- [ ] Board UI can be closed safely.
- [ ] Board does not permanently lock input.
- [ ] Board does not conflict with cashier UI.
- [ ] Board can be replaced with final board sprite later.

### Test Cases

#### BOARD-01 — Open Board

```text
Interact with board.
Expected:
Board panel opens and shows current guidance.
```

#### BOARD-02 — Close Board

```text
Close board panel.
Expected:
Player control returns normally.
```

#### BOARD-03 — Updated Guidance

```text
Reach ghost shelf / Gooby flow.
Expected:
Board text reflects the current existing activity.
```

### AI Agent Prompt

```text
Analisa Task 4 — Polish Activity Board / Action Guidance dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan edit file dulu.
- Jangan tambah mechanic baru.
- Tentukan apakah objective HUD sudah cukup atau perlu simple board.
- Jika board perlu dibuat, rancang implementasi kecil yang tidak menjadi quest system kompleks.

Expected output:
- Apakah board diperlukan sekarang.
- File/scene yang akan terdampak.
- Rencana UI board sederhana.
- Risiko scope creep.
- Test case yang perlu dijalankan.
```

---

## 9. Task 5 — Polish NPC Flow

### Goal

Make NPC flow understandable from entrance to exit.

Expected NPC state flow:

```text
ENTER
→ WALK_TO_SHELF
→ SEARCH_ITEM
→ TAKE_ITEM
→ WAIT_IN_QUEUE
→ CHECKOUT
→ EXIT
```

### Checklist

- [ ] NPC spawns at entrance.
- [ ] NPC walks to the correct shelf type.
- [ ] NPC does not exit without clear reason.
- [ ] NPC pauses/searches briefly at shelf.
- [ ] NPC takes item if available.
- [ ] NPC gives dialogue if item is missing.
- [ ] NPC joins queue after taking item.
- [ ] NPC only enters checkout when first in queue.
- [ ] NPC exits after checkout outcome is resolved.
- [ ] NPC does not remain in queue after leaving.
- [ ] Story NPC outcome can differ from normal purchase outcome.
- [ ] Gooby and Slime still follow readable NPC movement flow.

### AI Agent Rule

```text
Avoid adding new states unless required to fix a bug.
Prefer clearer helper methods over large state rewrites.
```

---

## 10. Task 6 — Polish Cashier / Checkout Flow

### Goal

Make checkout behavior clear for normal NPCs and story NPCs.

Normal customer flow:

```text
NPC waits at cashier
→ Player scans requested item
→ Player confirms scan
→ Player receives payment
→ Revenue increases
→ NPC exits
```

### Checklist

- [ ] Cashier only processes a valid checkout NPC.
- [ ] Cashier tells player if no customer is waiting.
- [ ] Cashier tells player if customer is still walking.
- [ ] Scan mismatch gives clear feedback.
- [ ] Correct scan leads to checkout resolution.
- [ ] Normal paid checkout increases daily revenue.
- [ ] Gooby checkout uses Gooby choice panel instead of normal payment.
- [ ] Checkout UI does not leave player action locked.
- [ ] Checkout state resets after payment, gift, refusal, or cancel.
- [ ] Repeated Enter/interact input does not accidentally choose a Gooby branch.

### AI Agent Rule

```text
Do not turn cashier into a new minigame.
Polish only the current scan-confirm-outcome flow.
```

---

## 11. Task 7 — Polish Shelf and Item Flow

### Goal

Make shelf logic stable for both player and NPC.

### Checklist

- [ ] Player can place valid item on matching shelf type.
- [ ] Wrong shelf placement gives clear feedback.
- [ ] Shelf slot limit is respected.
- [ ] Item leaves inventory when placed on shelf.
- [ ] Item leaves shelf when taken by NPC.
- [ ] Item can return to shelf when a checkout is rejected.
- [ ] Returned Phantom Ice Cream can be found by Slime.
- [ ] No item duplication happens after Gooby refusal.
- [ ] No item loss happens after Gooby gift.
- [ ] Shelf visual placeholder is separated from collision and interaction shape.
- [ ] Shelf node structure is ready for Aseprite sprite replacement.

### AI Agent Rule

```text
Do not add new shelf types for Day 1.
Focus on existing human shelf and ghost shelf behavior.
```

---

## 12. Task 8 — Polish Feedback and Notifications

### Goal

Player should always understand what changed and why.

### Checklist

- [ ] Notification appears when item is picked up.
- [ ] Notification appears when item is placed on shelf.
- [ ] Notification appears when item is incompatible with shelf.
- [ ] Notification appears when cashier has no valid customer.
- [ ] Notification appears when scan mismatch happens.
- [ ] Notification appears when Gooby cannot pay.
- [ ] Notification appears when Gooby trust increases.
- [ ] Notification appears when refusing Gooby triggers the next consequence.
- [ ] Notification duration is readable.
- [ ] Notification does not permanently block input.
- [ ] Notification does not cover critical cashier choices.
- [ ] Notification does not overlap objective text or trust label.

Suggested text examples:

```text
Gooby Trust +10 | No revenue gained.
Refused Gooby. The item returns to the shelf... something else is coming.
Daily target achieved.
```

---

## 13. Task 9 — Review Core Loop

### Goal

Review the full playable loop after the focused polish tasks are done.

### Checklist

- [ ] Player can start Day 1 and understand first action.
- [ ] Player can bring shelf from storage.
- [ ] Player can stock human shelf.
- [ ] Human customers can buy items.
- [ ] Ghost shelf / mystery flow can be reached.
- [ ] Gooby arrives at night.
- [ ] Gooby gift path works.
- [ ] Gooby refuse → Slime path works.
- [ ] Daily target can be missed or achieved depending on branch.
- [ ] HUD remains readable throughout the flow.
- [ ] Player never loses control due to stuck UI state.

### AI Agent Prompt

```text
Review Task 9 — Review Core Loop dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan edit file dulu.
- Jangan tambah mechanic baru.
- Jalankan review berdasarkan mechanic yang sudah ada.
- Fokus menemukan friction point, UI overlap, atau bug.

Expected output:
- Status core loop dari awal sampai transaksi malam.
- Bagian yang sudah stabil.
- Bagian yang masih rawan.
- Rekomendasi task kecil berikutnya.
```

---

## 14. Task 10 — Prepare Asset-Ready Node Structure

### Goal

Prepare scenes so placeholder visuals can be swapped with Aseprite assets later without breaking mechanics.

### Checklist

- [ ] Visual nodes are separated from logic nodes.
- [ ] Placeholder visuals are grouped under a stable visual root where possible.
- [ ] Collision shapes do not depend directly on placeholder size.
- [ ] Interaction areas remain stable when sprite changes.
- [ ] Scene node names are stable.
- [ ] Script does not depend directly on `ColorRect` for gameplay logic.
- [ ] `Sprite2D` or `AnimatedSprite2D` replacement path is clear.
- [ ] Temporary UI / board / HUD layout can later be replaced by final UI assets.

Recommended pattern:

```text
NPC
├── VisualRoot
│   ├── PlaceholderRect
│   └── AnimatedSprite2D
├── NameLabel
├── DialogBubble
├── CollisionShape2D
└── InteractionArea
```

### AI Agent Rule

```text
Do not replace final assets yet.
Prepare the structure so replacement is easy later.
```

---

## 15. Task 11 — Documentation Update

### Goal

Keep this file useful as an AI Agent task spec.

### Checklist

- [ ] Mark tasks as done / partially done / pending when appropriate.
- [ ] Add discovered bugs to the relevant task section.
- [ ] Add new test cases if playtest reveals missing cases.
- [ ] Remove or rewrite tasks that are already fully completed.
- [ ] Keep Day 1 scope focused on polish, not feature expansion.

### AI Agent Prompt

```text
Update Task 11 — Documentation Update dari docs/polish/day-1-mechanic-polish.md.

Batasan:
- Jangan ubah mechanic.
- Update dokumentasi berdasarkan hasil validasi terakhir.
- Tandai task yang sudah done, partially done, dan pending.
- Tambahkan catatan bug/follow-up jika ada.
```

---

## 16. Definition of Done — Day 1

Day 1 can be considered done when:

- [ ] No new major mechanic was added.
- [ ] Core shop loop can be played from setup to checkout.
- [ ] Gooby gift path works and gives trust without revenue.
- [ ] Gooby refuse path works and enables Slime revenue path.
- [ ] Trust label does not overlap HUD.
- [ ] Player has clear objective guidance for current activity.
- [ ] New item / ghost item activity is explained through objective, notification, or board.
- [ ] NPC flow is stable enough for playtest.
- [ ] Cashier UI cleans up after each checkout outcome.
- [ ] Shelf/item flow does not duplicate or lose items incorrectly.
- [ ] Temporary UI is readable at 480x270.
- [ ] Project remains ready for Aseprite asset integration.

---

## 17. Suggested Trello / Branch Naming

Trello activities:

```text
validate_gooby_night_choice_day_1
polish_hud_trust_layout_day_1
polish_player_navigation_objective_day_1
polish_activity_board_guidance_day_1
polish_npc_flow_day_1
polish_cashier_flow_day_1
polish_shelf_item_flow_day_1
review_core_loop_day_1
prepare_asset_ready_node_structure_day_1
```

Branch:

```text
polish/day-1-mechanic-polish
```

Suggested commit messages:

```text
docs: expand day 1 mechanic polish tasks
fix: prevent trust hud overlap
feat: add lightweight objective guidance for existing loop
chore: document Gooby night choice validation
refactor: prepare placeholder visuals for asset integration
```
