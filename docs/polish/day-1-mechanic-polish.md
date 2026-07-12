# Crossroad Market — Day 1 Mechanic Polish

## 1. Purpose

Day 1 focuses on **mechanic polish without final art assets**. The project may still use placeholder visuals such as `ColorRect`, simple shapes, or temporary sprites. The goal is not to add new mechanics, but to make the existing mechanics more stable, readable, and ready for future Aseprite asset integration.

Main rule:

```text
Do not add new mechanics.
Polish the mechanics that already exist.
Prepare the project so final assets can be swapped in safely later.
```

This document is intended to guide AI Agent work. Every change should improve clarity, stability, feedback, or asset-readiness without expanding the gameplay scope.

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
- Improve temporary UI readability.
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

---

## 4. Existing Core Mechanics to Polish

## 4.1 Player Interaction Polish

Goal:

Make player actions readable, consistent, and safe.

Checklist:

- [ ] Player movement feels responsive.
- [ ] `interact` input works consistently.
- [ ] `take_shelf_item` input is clear and does not conflict with other actions.
- [ ] Player can identify when shelf, cashier, NPC, or supply box can be interacted with.
- [ ] Failed interaction gives feedback instead of silently doing nothing.
- [ ] Interaction priority is predictable.
- [ ] Player does not get stuck due to collision.
- [ ] Action locks from UI or notifications do not permanently block player control.

AI Agent rule:

```text
Do not add a new interaction system.
Improve only the clarity and reliability of existing interactions.
```

---

## 4.2 Shelf Mechanic Polish

Goal:

Make shelf logic stable for both player and NPC.

Checklist:

- [ ] Player can place valid item on matching shelf type.
- [ ] Wrong shelf placement gives clear feedback.
- [ ] Shelf slot limit is respected.
- [ ] Item leaves inventory when placed on shelf.
- [ ] Item leaves shelf when taken by NPC.
- [ ] Item can return to shelf when a checkout is rejected.
- [ ] Shelf visual placeholder is separated from collision and interaction shape.
- [ ] Shelf node structure is ready for Aseprite sprite replacement.

AI Agent rule:

```text
Do not add new shelf types for Day 1.
Focus on existing human shelf and ghost shelf behavior.
```

---

## 4.3 NPC Behavior Polish

Goal:

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

Checklist:

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

AI Agent rule:

```text
Avoid adding new states unless required to fix a bug.
Prefer clearer helper methods over large state rewrites.
```

---

## 4.4 Cashier / Checkout Polish

Goal:

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

Checklist:

- [ ] Cashier only processes a valid checkout NPC.
- [ ] Cashier tells player if no customer is waiting.
- [ ] Cashier tells player if customer is still walking.
- [ ] Scan mismatch gives clear feedback.
- [ ] Correct scan leads to checkout resolution.
- [ ] Normal paid checkout increases daily revenue.
- [ ] Checkout UI does not leave player action locked.
- [ ] Checkout state resets after payment, gift, refusal, or cancel.

AI Agent rule:

```text
Do not turn cashier into a new minigame.
Polish only the current scan-confirm-outcome flow.
```

---

## 5. Gooby Night Logic Polish

## 5.1 Design Purpose

Gooby is a story NPC, not a normal paying customer. The night Gooby event creates a trade-off:

```text
Choose trust with Gooby
OR
Choose daily revenue target through Slime consequence
```

This is a polish target because the logic already exists as a story checkout outcome. The goal is to make the consequence explicit and readable to the player.

---

## 5.2 Expected Gooby Flow

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

---

## 5.3 Option A — Give Item

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
- [ ] HUD trust label updates.
- [ ] Notification explains `+Trust` and `+0G` clearly.

---

## 5.4 Option B — Refuse Sale

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

---

## 5.5 Gooby Logic Test Cases

### Test Case GOO-01 — Give Gooby Item

Precondition:

```text
Current revenue: 40/50
Current phase: Night
Ghost shelf has Phantom Ice Cream
Gooby is at cashier
```

Steps:

```text
1. Interact with cashier.
2. Scan Phantom Ice Cream.
3. Confirm scan.
4. Choose Give Item (+Trust, +0G).
```

Expected result:

```text
Gooby exits.
Gooby Trust increases by +10.
Revenue remains 40/50.
Slime does not spawn.
Item is not returned to shelf.
```

---

### Test Case GOO-02 — Refuse Gooby

Precondition:

```text
Current revenue: 40/50
Current phase: Night
Ghost shelf has Phantom Ice Cream
Gooby is at cashier
```

Steps:

```text
1. Interact with cashier.
2. Scan Phantom Ice Cream.
3. Confirm scan.
4. Choose Refuse Sale (Return Item).
```

Expected result:

```text
Gooby exits.
Gooby Trust does not increase.
Phantom Ice Cream returns to ghost shelf.
Slime spawns.
Slime can buy Phantom Ice Cream.
Revenue becomes 50/50 after Slime checkout.
Daily target is achieved.
```

---

### Test Case GOO-03 — Slime Spawn Safety

Precondition:

```text
Gooby has already been refused once in the same night.
```

Steps:

```text
1. Try to trigger Gooby refusal again through repeated interaction or UI edge case.
```

Expected result:

```text
Only one Slime is spawned.
No duplicate Slime spawn occurs.
No duplicate revenue exploit occurs.
```

---

## 6. Feedback & Notification Polish

Goal:

Player should always understand what changed and why.

Checklist:

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

Suggested text examples:

```text
Gooby Trust +10 | No revenue gained.
Refused Gooby. The item returns to the shelf... something else is coming.
Daily target achieved.
```

---

## 7. HUD Polish

Goal:

HUD should show key state changes clearly during polish.

Checklist:

- [ ] Gold display updates when revenue changes.
- [ ] Daily target display updates from `40G / 50G` to `50G / 50G`.
- [ ] Target achieved text appears when target is reached.
- [ ] Gooby trust display exists.
- [ ] Gooby trust display updates after gift.
- [ ] HUD layout remains readable with placeholder UI.

Temporary HUD target:

```text
Wallet: 40G
40G / 50G
Gooby Trust: 10/100
```

---

## 8. Asset-Ready Structure Polish

Goal:

Prepare scenes so placeholder visuals can be swapped with Aseprite assets later without breaking mechanics.

Checklist:

- [ ] Visual nodes are separated from logic nodes.
- [ ] Placeholder visuals are grouped under a stable visual root where possible.
- [ ] Collision shapes do not depend directly on `ColorRect` size.
- [ ] Interaction areas remain stable even when visuals change.
- [ ] NPC node structure can accept `AnimatedSprite2D` later.
- [ ] Shelf node structure can accept item sprites later.
- [ ] Cashier and HUD UI can be visually replaced without changing checkout logic.

Recommended structure for NPC:

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

Recommended rule:

```text
Scripts should target stable gameplay nodes, not temporary ColorRect visuals.
```

---

## 9. Day 1 Task List

## Task 1 — Freeze Mechanic Scope

- [ ] Confirm the mechanic scope for Day 1.
- [ ] Mark new mechanics as out of scope.
- [ ] Focus only on polish and stability.

Output:

```text
Mechanic scope is locked.
```

---

## Task 2 — Review Core Loop

- [ ] Test item pickup.
- [ ] Test shelf placement.
- [ ] Test NPC entering store.
- [ ] Test NPC finding item.
- [ ] Test NPC queue.
- [ ] Test cashier scan.
- [ ] Test normal checkout.
- [ ] Test Gooby checkout.
- [ ] Test Slime consequence.

Output:

```text
Core loop bugs and friction points are documented.
```

---

## Task 3 — Polish Gooby Night Choice

- [ ] Confirm Gooby appears at night.
- [ ] Confirm Gooby takes Phantom Ice Cream.
- [ ] Confirm cashier shows Gooby choice panel.
- [ ] Confirm Give Item increases trust and gives no revenue.
- [ ] Confirm Refuse Sale returns item and spawns Slime.
- [ ] Confirm Slime can buy the returned item.
- [ ] Confirm target can reach 50/50 through Slime.

Output:

```text
Gooby story checkout choice is clear, stable, and testable.
```

---

## Task 4 — Polish Player Feedback

- [ ] Add or improve feedback for failed interaction.
- [ ] Add or improve feedback for wrong shelf.
- [ ] Add or improve feedback for Gooby choice.
- [ ] Add or improve feedback for target reached.

Output:

```text
Player understands the result of each major action.
```

---

## Task 5 — Polish Asset-Ready Nodes

- [ ] Identify placeholder visuals that will be replaced.
- [ ] Ensure visuals are separated from collision and interaction area.
- [ ] Add stable visual root nodes if needed.
- [ ] Avoid direct logic dependency on temporary visuals.

Output:

```text
Project is safer for future Aseprite asset integration.
```

---

## Task 6 — Documentation Update

- [ ] Document files changed.
- [ ] Document mechanic polished.
- [ ] Document Gooby expected behavior.
- [ ] Document known bugs.
- [ ] Document next steps for Day 2.

Output:

```text
AI Agent work is traceable and reproducible.
```

---

## 10. Definition of Done

Day 1 is considered done when:

- [ ] No new major mechanic is added.
- [ ] Existing core loop can be completed.
- [ ] Normal customer checkout works.
- [ ] Gooby gift path works.
- [ ] Gooby refuse path works.
- [ ] Slime consequence works.
- [ ] Daily target can be missed or achieved based on player choice.
- [ ] Gooby trust can increase through gift path.
- [ ] HUD communicates revenue and trust.
- [ ] Placeholder structure is safer for future asset replacement.
- [ ] Bugs and next tasks are documented.

---

## 11. Notes for AI Agent

Rules for future AI Agent changes:

```text
1. Do not add new mechanics unless explicitly requested.
2. Treat Gooby night choice as existing story mechanic polish.
3. Keep revenue and trust as separate reward paths.
4. Gift path should improve trust but not revenue.
5. Refuse path should enable Slime revenue but not trust.
6. Avoid duplicate Slime spawn.
7. Avoid hardcoding UI behavior in too many places.
8. Keep placeholder visuals replaceable.
9. Document all behavior changes.
```

If unsure whether a change is allowed:

```text
If the change makes an existing mechanic clearer, safer, or easier to test, it is polish.
If the change adds a new gameplay loop, system, or feature branch, it is out of scope.
```

---

## 12. Suggested Commit Messages

Documentation only:

```text
docs: update day 1 mechanic polish with Gooby night logic
```

Logic polish:

```text
refactor: clarify Gooby gift and refusal checkout outcomes
```

Bug fix:

```text
fix: prevent duplicate slime spawn after Gooby refusal
```

HUD polish:

```text
feat: show Gooby trust during night story checkout
```
