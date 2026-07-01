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

## 🗄️ Decoupled Data & Resource Databases

1. **No Data Databases in UI/HUD Scripts**:
   - **Never** store database structures (like definitions of items, buildings, NPC dialogue, or recipes) as constants, hardcoded dictionaries, or static arrays inside UI scripts or Hud controllers.
   - UI elements must only handle rendering, event signals, and user interaction. They are not data models.
2. **Utilize Custom Resources (`.tres`)**:
   - Save dataset entries as individual custom Resource files (inheriting from a `Resource` script like `BuildingData` or `ItemData`).
   - Define variables with `@export` so properties can be modified easily via the Godot Inspector.
3. **Dynamic Initialization / Auto-Loading**:
   - Use dynamic directory scanning (`DirAccess.open()`) in an autoload singleton (like `GameState`) to find and parse all `.tres` files at startup.
   - Handle runtime `.remap` suffixes for safety in compiled/exported games by stripping `.remap` from file names before invoking `load()`.
4. **Type-Safety & Dot-Notation**:
   - Type-hint database collections (e.g. `var build_database: Array[BuildingData] = []`).
   - Query databases via properties (`item.cost`, `item.env`) rather than dictionary string keys (`item["cost"]`, `item["env"]`) to ensure compiler-safety and clear schema definition.

---

## 📝 Documentation & Task Integrity

Whenever modifying existing systems, adding new features, or improving game mechanics:
1. **Synchronize Documentation**:
   - Update matching markdown documentation files (`.agents/skills/`, `walkthrough.md`, `task.md`) to accurately reflect code changes, new setup locations, or modified pricing/career rules.
   - Never let developer manuals, checklists, or walkthroughs get out of sync with actual codebase implementations.
2. **Mark Tasks in Real-time**:
   - Ensure the `task.md` checklists are updated as steps are executed, so that progress is always transparent and verifiable.

---

## 🛑 Anti-Duplication & Composition Over Inheritance
- **Strict No-Copy Rule:** Never copy-paste identical variables, setups, components, or lifecycle hooks across parallel, distinct feature scripts (e.g., copying the same data structures into bakery.gd, smelter.gd, loom.gd).
- **Architecture Resolution:** If multiple entities require identical logic, variables, or interfaces, you must implement it in one of two ways:
  1. Inheritance: Create a strongly-typed base class (e.g., base_production_building.gd) that houses the shared code, forcing specific variants to extend it.
  2. Componentization: Abstract the system into a separate, lightweight Node component (e.g., strongbox_component.gd, inventory_component.gd) that can be instanced as a child.

## 💾 Data Integrity & Serialization Compliance
- **Explicit Variable Declarations:** All persistent gameplay data, simulation metrics, tracking dictionaries, and item logs must be explicitly declared at the class scope with clear static typing where possible.
- **Metadata Ban:** Never use Godot's built-in Object metadata functions (set_meta(), get_meta(), has_meta()) to track core simulation status, worker statistics, or ledger logs. All gameplay states must be fully visible to the script scope to ensure a robust, reliable save/load serialization system.

## 🌐 Scalable Group & Manager Topography
- **Horizontal Group Design:** Global management singletons (like game_state.gd) must never maintain hardcoded list checks for explicit sub-categories of nodes (e.g., looping separately through groups named "Bakeries", "Mills", "Smelters" to execute a daily reset).
- **Architecture Resolution:** All relative entities must join a singular, master structural group (e.g., "production_buildings"). The global manager will trigger generic lifecycle calls (e.g., get_tree().call_group("production_buildings", "clear_daily_stats")), and individual nodes will utilize polymorphism to execute their specific variations locally.

---

## 📏 Systemic Architecture Rules & Project Constraints

### 🛑 1. Code File Constraints & Refactoring Triggers
- **Absolute File Size Limit:** No single GDScript (`.gd`) file may ever exceed 500 lines of code.
- **Refactoring Trigger:** If a feature request, bug fix, or modification threatens to push a file past 400 lines, you MUST halt generation immediately. State the structural bottleneck to the user and propose an architectural plan to break the file apart into smaller, decoupled child nodes or standalone components.
- **Truncation Safety:** Never use shortcut placeholding comments like `// ... rest of the code remains the same ...` or `# ... rest of the code ...` when editing existing scripts. Always provide fully block-parsable scripts or clearly defined method overrides to prevent accidental code erasure.

### 🧱 2. Godot Node Composition Pattern (Game Logic)
- **Anti-Monolith Rule:** Core simulation actors (NPCs, Buildings, Logistics) must not operate as "God Objects." They must act as lightweight coordinators that delegate specialized work to dedicated child nodes.
- **Component Separation:** Isolate discrete logical frameworks into lightweight, single-responsibility child component scripts (e.g., `NPCNavigationComponent.gd`, `NPCEconomicBrain.gd`, `WarehouseLogistics.gd`).
- **Communication Flow:** Sub-components must handle internal states independently and pass critical information upward to parents via custom Godot signals. Parents may invoke methods downward directly.

### 3. Sub-View Separation (UI Windows & Systems)
- **Procedural UI Generation Ban:** You are strictly forbidden from imperatively constructing complex interface screens via code loops of `.new()` initializations (e.g., loops of `Button.new()`, `StyleBoxFlat.new()`, `PanelContainer.new()`). All custom components, inventory grids, and visual item cards must be mapped as dedicated, editable `.tscn` scene files.
- **Tab Component Isolation:** Master UI canvas layers (such as multi-tab panels) must perform strictly as top-level view switchers. They must simply toggle the visibility of self-contained sub-scene tab layouts (e.g., `main_data_view.tscn`, `ledger_view.tscn`, `upgrades_view.tscn`).
- **Context Injection:** Stream clean context references downward to these sub-tab components using initialization methods upon a view toggle, instead of forcing child tabs to poll global game singletons directly.

---

## 🗺️ Visual Map Blueprint & Division of Labor

With the transition to a fixed visual map (`world_map_blueprint.tscn`), there is a strict division of labor between map authoring (done by the USER in the Godot Editor) and scripting/parsing (done by the AGENT).

### 🛠️ User Responsibilities (Godot Editor Visual Authoring)
* **Node Placement & Arrangement**: Position, translate, scale, and rename nodes in the visual layout tree.
* **Overworld Features**: Draw highways and plaza roads (using `Line2D` and `ColorRect` placeholder shapes), resource node boundaries, and terrain obstacles.
* **Spawn Points**: Place and move spawn markers (`Player_Spawn_Anchor`, `Rival1_Spawn_Anchor`, and NPC spawn anchors) inside the settlement folders.
* **Building Lots & Grids**: Define empty building slots (`Slot` nodes with `Signpost` children) and municipal buildings (Chapel, Town Hall, Guild Halls) as layout markers.
* **Interior Boundaries**: Draw the physical wall boundaries of interior room layouts using a `Walls/Line2D` child.
* **Metadata Configuration**: Set metadata fields (e.g., `blueprint_interior_name` to link a building to its corresponding room) using the editor inspector.

### 🤖 Agent Responsibilities (GDScript & Automation Code)
* **Data Parsing**: Write and update GDScript parser loops (e.g., in `world_layout_spawner.gd`, `world_node_spawner.gd`, `world_npc_spawner.gd`) to dynamically traverse and load the blueprint scene tree.
* **Instantiation**: Automate the generation of active gameplay entities (spawning player, AI rivals, NPCs, resource nodes, public market stalls, fountains) exactly on top of the visual anchors parsed from the blueprint.
* **Collision Generation**: Programmatically parse the visual boundaries (like `Walls/Line2D`) and construct physical collision geometry (like a `StaticBody2D` with a closed `CollisionPolygon2D` wrapper) so characters are physically blocked by walls.
* **Logic Wiring**: Connect signals, initialize states, setup inventories, configure teleport triggers, and manage camera behaviors dynamically based on the parsed blueprint layout.
