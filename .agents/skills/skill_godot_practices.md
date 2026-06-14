# Skill: GDScript & Scene Architecture (Godot 4.6)

This document contains best practices for writing clean, compiler-safe scripts and scenes in Guild Valley.

---

## ⚡ Autoload Singletons

Autoloads in Godot 4 require special attention due to project startup compiling order.

1. **No Class Names for Autoloads**:
   - **Do not** add `class_name` to scripts registered as Autoloads in `project.godot` (e.g. `GameState`, `TransitionScreen`).
   - Redundant `class_name` lines on Autoload scripts trigger `Class hides an autoload singleton` compile errors. Access singletons strictly via their project settings registration name.
2. **Never Instanced Manually**:
   - **Never** instantiate an Autoload singleton in code using `.new()` or `load().new()`. Godot instantiates them automatically at launch.
3. **Dynamic References inside Autoloads**:
   - Because Autoloads are compiled first, they cannot statically type-hint custom classes that are loaded later in the pipeline.
   - If an Autoload script needs to reference or instantiate a custom class (e.g., player inventory), leave the variable untyped or use built-in types (e.g., `var player_inventory: Node`).
   - Load and instantiate dynamically at runtime using `load("path").new()`.

---

## 🎮 Input Map Configuration

1. **Prefer Editor Bindings**:
   - Establish and configure game controls via the Godot Editor UI under **Project -> Project Settings -> Input Map**.
2. **Dynamic Fallbacks**:
   - When programmatically setting up key bindings in code (e.g., to ensure out-of-the-box playability), **always** wrap them in a safety check:
     ```gdscript
     if not InputMap.has_action("my_action"):
         InputMap.add_action("my_action")
         # add events...
     ```
   - **Do not override** pre-existing actions in the InputMap, as this will erase customized deadzones, controls, or events configured in the editor.

---

## 🔒 Node Access & Tree Safety

1. **Child Node References**:
   - Always reference scene child nodes using `@onready var node_name = $ChildNode` or `@onready var node_name = %UniqueChildNode`.
2. **Tree Scope Checking**:
   - If referencing nodes in parent scenes or separate viewport structures, utilize `get_node_or_null()` instead of static `$Path` markers.
   - Check if the target node exists using `if target_node:` before calling its properties or methods to prevent runtime crashes.

---

## 📝 Documentation & Task Integrity

Whenever modifying existing systems, adding new features, or improving game mechanics:
1. **Synchronize Documentation**:
   - Update matching markdown documentation files (`.agents/skills/`, `walkthrough.md`, `task.md`) to accurately reflect code changes, new setup locations, or modified pricing/career rules.
   - Never let developer manuals, checklists, or walkthroughs get out of sync with actual codebase implementations.
2. **Mark Tasks in Real-time**:
   - Ensure the `task.md` checklists are updated as steps are executed, so that progress is always transparent and verifiable.

