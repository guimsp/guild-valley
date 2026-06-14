# Skill: 2D Physics & 3/4 Oblique Sorting

This document outlines physics and rendering sorting rules to maintain depth realism in a **low top-down (3/4 oblique view)** perspective.

---

## 📐 Perspective & Sorting Origin

Because this is a **low top-down (3/4 oblique view)** pixel art game, proper Y-sorting is mandatory to ensure characters and objects display correctly relative to structures (houses, stalls, barriers).

1. **Boots/Base Pivot (0,0)**:
   - Every physical entity (Player, NPC, Monster) and interactable object (MarketStall, CraftingBench, house obstacles) **MUST** align its scene origin `(0, 0)` at its physical feet or base contact point.
2. **Sprite Offsets**:
   - The visual sprite nodes (e.g., `AnimatedSprite2D` or `Sprite2D`) must be offset vertically using their `position` or `offset` properties (e.g. `position = Vector2(0, -80)`).
   - This ensures the sprite center draws above the floor while keeping its physics/position origin at `(0, 0)` on the ground.

---

## 🗂️ Y-Sorting Setup

1. **Enable Y-Sorting on Scenes**:
   - The root viewport level node (e.g., `World`, `HouseInterior`) must have `y_sort_enabled = true`.
2. **Enable Y-Sorting on Entities**:
   - All mobile entities and structures (Player, NPCs, MarketStall) must have `y_sort_enabled = true`.
   - Ensure they are instanced as direct children of a node that has Y-sorting active.
3. **TileMap Sorting**:
   - TileMap layers that represent ground elements (grass, sand) should have Y-sorting disabled.
   - TileMap layers that represent wall and height elements (fences, trees) must have Y-sorting enabled.

---

## 📦 Collision Footprints

1. **Base Footprints Only**:
   - Collision shapes (`CollisionShape2D` or `CollisionPolygon2D`) for solid objects must only cover their "contact footprint" on the ground (e.g., a flat capsule or rectangle at the base).
   - **Do not** extend the physics collider upward to match the visual height of the building or object. This allows characters to walk behind roofs and walls smoothly.
