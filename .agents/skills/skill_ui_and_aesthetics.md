# Skill: UI Aesthetics & Micro-Animations

This document outlines design and interactive specifications to keep the interface looking polished, modern, and alive.

---

## 🎨 Theme & Glassmorphism

1. **Dark Color Palette**:
   - Background panels: Semi-transparent dark colors: `Color(0.1, 0.1, 0.14, 0.94)` or `#1c1c24e0`.
   - Glowing accent borders: Neon teal (`#3da670`), gold (`#e0ba3b`), or light electric blue (`#3d9beb`).
2. **Glassmorphic Panels**:
   - Utilize a `PanelContainer` styled with a `StyleBoxFlat`.
   - Set border width to `2px` and add rounded corners (`corner_radius = 6` to `12px`).
   - Enable drop shadows (`shadow_size = 4` to `8px`, `shadow_color = Color(0, 0, 0, 0.4)`).

---

## 📈 Micro-Animations & Tweens

Interactive elements must feel alive. Implement the following micro-animations programmatically via `create_tween()`:

1. **Button Hover Scaling**:
   - On `mouse_entered` (if button is not disabled), scale up from `1.0` to `1.04` or `1.05` over `0.08s`.
   - On `mouse_exited`, scale back down to `1.0` over `0.08s`.
   - Ensure the button's `pivot_offset` is set to `custom_minimum_size / 2.0` (center) for uniform scaling.
2. **Successful Operations (Flashes)**:
   - When a transaction succeeds, flash the item row or text green: tween `modulate` to `Color(0.4, 1.0, 0.4)` and back to `Color(1, 1, 1)` over `0.2s`.
3. **Failed Operations (Shakes & Red Flashes)**:
   - When an operation is blocked (e.g. insufficient gold/level), flash red `Color(1.0, 0.4, 0.4)` and shake the container horizontally by shifting its `position.x` by `+-5px` back and forth over `0.2s`, returning to baseline.
4. **Floating Popups**:
   - When granting XP or item notifications, spawn a floating text label at the interaction point.
   - Animate the label's `position.y` upward by `40px` and animate its `modulate:a` (alpha) from `1.0` to `0.0` over `0.8s`, then `queue_free()` the label.

---

## 📐 Layout Rules

1. **Scroll Containment**:
   - Wrap lists and grids in `ScrollContainers` to avoid screen boundaries overflow.
2. **Responsive Growth**:
   - Set child components to use `SIZE_EXPAND_FILL` instead of hardcoding pixel coordinates so that layouts adapt cleanly to different window aspect ratios.
3. **Avoid Overlapping on Hover/Focus Scale**:
   - Use subtle scale factors (e.g., `1.03` max) to prevent scaling elements from overlapping adjacent container elements.
   - Ensure scaled controls center their pivot offset dynamically by connecting the `resized` signal to a handler setting `pivot_offset = size / 2.0`.
   - Provide generous horizontal/vertical container separation (at least `16px`) when elements support focus-scaling.

---

## 🕹️ Keyboard Focus Navigation & Input Rules

To ensure keyboard-only (WASD/QE/F) playability, all visual interfaces must implement:

1. **Directional WASD Focus Wiring**:
   - Godot does not auto-link focus paths across separate container nodes or dynamic grids. Programmatically assign `focus_neighbor_left`, `focus_neighbor_right`, `focus_neighbor_top`, and `focus_neighbor_bottom` to all focusable elements.
   - Setup horizontal bridges between layout columns (e.g., inventory grid slots to career panel tabs).
2. **Unified Select/Confirm Input (F Key)**:
   - Intercept the `"interact"` action (mapped to `F`) in `_input(event)` or `_gui_input(event)`.
   - If a button/element is focused, trigger its press action (e.g., `focused_button.pressed.emit()`) or forward the selection event.
3. **Category Tab Swapping (Q/E Keys)**:
   - Use `Q` (previous) and `E` (next) to cycle through category tabs (e.g., Market stalls, Build menu categories, Building ledger tabs).
   - Maintain a clear visual selection style/highlight on the active category header.
4. **Focused Modals & Dialog Protection**:
   - When dialog/modal overlays appear (e.g. quantity selectors), lock or grab focus to the modal control elements immediately.
   - Pressing `F` inside a popup should trigger the focused button, or fall back to confirming the primary dialog transaction.

---

## ⚡ Low-Friction Input & UX Speed Thresholds
- **Elimination of Modal Confirmation Bloat:** Do not generate popup dialog menus or confirmation modals for high-frequency, repetitive player actions (such as moving single item units between warehouse storage, market counters, or player inventories).
- **Architecture Resolution:** Prioritize standard, continuous input modifiers and mouse shortcuts to accelerate UI manipulation:
  * Left-Click: Execute primary target action (e.g., transfer 1 unit to Player).
  * Right-Click: Execute secondary alternative action (e.g., transfer 1 unit to Stall window).
  * Shift + Click: Execute stack modifier action (e.g., transfer max quantity instantly).

---

## 🎮 Controller & Keyboard Friendly Window Design

When designing and creating UI windows, always prioritize controller and keyboard friendliness:

1. **No Dropdown Menus (OptionButton)**:
   - Never use dropdown menus unless explicitly requested by the user. Dropdowns are notoriously difficult to navigate and interact with using a controller/keyboard.
   - Instead, use grid selection popups (similar to the trade route waypoint item selector), card grids, or toggle buttons.
2. **No Top-Right X Buttons**:
   - Do not add "X" close buttons in the top-right corner of windows.
   - Windows must be closed using the Escape key (`ui_cancel`) or a dedicated, centered "Close" button positioned at the bottom footer of the window for mouse users.
3. **Always Configure Focus Neighbors**:
   - Manually wire up the focus neighbors (`focus_neighbor_left`, etc.) dynamically or in the scene file to ensure focus moves predictably with WASD/D-pad navigation.

