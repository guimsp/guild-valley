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
