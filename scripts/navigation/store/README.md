# Store Navigation Architecture

The Store navigation runtime is split into independent layers. `StoreNpcRoutes`
remains the compatibility facade used by existing NPC state flows.

## Planning pipeline

```text
StoreNavigationRequest
        |
        v
Direct line / local Theta*
        |
        v
Semantic macro graph
        |
        +--> Reverse Dijkstra shared-goal next-hop field
        |
        +--> D* Lite incremental repair after shelf changes
        |
        v
Local Theta* segment materialization
        |
        v
Dirty-region-aware route cache
        |
        v
NPC local avoidance during movement
```

## Responsibilities

- `StoreNavigationRequest.gd`
  - One data contract for position, shelf, queue, cashier, and exit requests.
  - Contains all route flags and cache-relevant agent data.
- `StoreNavigationCostPolicy.gd`
  - Owns distance, turn, queue-lane, occupancy, and role preference costs.
  - Default values live in `data/navigation/store_navigation_cost_policy.tres`.
- `StoreDynamicObstacleTracker.gd`
  - Tracks installed shelves and produces revisioned dirty rectangles.
  - Never treats NPCs as graph topology.
- `StoreSemanticGraph.gd`
  - Small macro graph built from named Store markers and virtual Store regions.
  - Queue roles remain explicit instead of being inferred from nearest points.
- `StoreThetaStarRuntimePlanner.gd`
  - Any-angle local planner over Store placement anchors.
  - Direct line-of-sight is always attempted before grid expansion.
- `StoreReverseDijkstraCache.gd`
  - Shared next-hop field for stable goals such as queue slots and exit.
- `StoreDStarLitePlanner.gd`
  - Repairs semantic search values after dirty regions change edge costs.
- `StoreRouteCache.gd`
  - Reuses routes whose segments do not intersect changes since their revision.
- `StoreLocalAvoidance.gd`
  - Temporary wait/sidestep behavior for NPC-to-NPC conflicts.
  - Does not invalidate the global graph.
- `StoreNavigationRuntimeService.gd`
  - Orchestrates the layers and retries semantic alternatives when a local
    segment cannot be materialized.

## Gameplay invariants

1. Shelf access points are still selected by the bounded legacy access resolver.
   The layered service owns movement to that point.
2. A source shelf may be ignored only on the first egress segment.
3. A target shelf may be ignored only at the final access endpoint.
4. Queue index determines the semantic queue lane:
   - index 0 -> `StorePathQueueFrontRight` -> `StorePathQueueFront`
   - index 1 -> `StorePathQueueBack1Right` -> `StorePathQueueBack1`
   - index 2 -> `StorePathQueueBack2Right` -> `StorePathQueueBack2`
5. Back-queue routes must not use `StorePathQueueFront` as an intermediate node.
6. `StorePathQueueFront` is the customer service standing point.
   `StorePathCashier` is a facing target, not a standing target.
7. NPC collisions are handled by local avoidance, not by rebuilding semantic
   topology every frame.
8. A moved shelf repairs only routes and shelf-access metadata intersecting its
   dirty regions.
9. If layered planning cannot resolve a request, the compatibility facade may
   use the optimized legacy graph as a safety fallback.

## Extension rules

- Add new destination semantics through `StoreNavigationRequest`, not a new
  independent pathfinding pipeline.
- Add tuning values to `StoreNavigationCostPolicy`, not directly to Dijkstra,
  D* Lite, or Theta*.
- Add permanent Store lanes as named Marker2D roles.
- Add temporary actor behavior to local avoidance.
- Preserve cache keys whenever a new value can alter collision or route cost.
