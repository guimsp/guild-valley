# Guild Valley - Feature Backlog & Roadmap

This file tracks all planned, proposed, and future features for **Guild Valley**. Feel free to add new ideas, modify descriptions, or remove items to direct the game's development priorities.

---

## 🎯 Current Task
- **Completed Build Menu Focus Polish**: Fixed the focus selector beating/respawning bug on clock ticks by caching and restoring the last focused card on viewport focus changes.

---

## 📋 Planned Features & Ideas

### 🤖 1. NPC & Opponent Economy AI (Buyers, Prices & Attractiveness)
- **Generic Buyer NPCs**: Roaming townspeople representing local customers who have infinite funds but buy products/services selectively based on key decision variables.
- **Economic Purchase Variables**:
  - **Attractiveness**: Storefront decoration, level/prestige, and walking distance.
  - **Prices**: Current item prices set by the shop owner relative to market/average values.
  - **Randomness**: Random choice factors and daily individual needs.
- **Opponent Logic (Rivals)**: Competitors dynamically expand by building/claiming lots, crafting items, upgrading workstations, and hiring employees to compete.

### 🏛️ 2. Prosperity, Lot Scaling & Visual Evolutions
- **Prosperity Rating**: Cities maintain higher prosperity than Towns, driving higher populations and Lot density.
- **Luxury Spawners**: High-prosperity zones spawn luxury materials and premium goods.
- **City Visual Evolution**: Cities upgrade walls and visually expand on sleep transitions when prosperity milestones are reached (selecting randomly from 3 predefined visual evolution paths).

### 📜 3. Settlement Licenses & Trade Freedom
- **Citizenship & Settlement**: Characters default to a native City/Town. Building or settling in other cities requires purchasing a local license or paying a premium lot cost.
- **Trade Freedom**: Players and NPCs are free to trade merchandise globally across all markets, regardless of settlement status (settlement restricts building only).

### 🏛️ 4. Character Titles, Taxes & Provincial Politics
- **Social Class Titles (Character Level)**: A separate 10-tier character progression system representing social class climbing (Commoner, Noble, etc.) unlocked via experience and gold, yielding generic rewards not tied to specific careers.
- **Taxes**: Implements provincial tax systems for residential houses (real estate) and production buildings.
- **Provincial Politics**: Spend influence and gold to vote on or pass laws/norms affecting taxes, regional security, and career productivity across the province.
- **Interconnected Paths**: Ability to leverage politics for illicit benefit (e.g., lobbying to defund security in a region to facilitate burglaries and rogue actions).

### 🤖 5. Built-in Navigation Upgrades
- **Built-in Navigation**: Replace the custom waypoint-raycast pathfinding with Godot's native `NavigationRegion2D` and `NavigationAgent2D`.
- **Dynamic Avoidance**: Enable obstacle avoidance so competitor NPCs and wandering villagers naturally route around player-placed workstations and houses.

### 🧵 6. Player Career & Crafting Expansion
- **Tailor Recipes**: Implement the Tailor career recipes, materials (like wool, fabric, clothes), and custom workstation (Sewing Table).

### 👤 7. Character Creation & Starting Profession
- **Starting Career Selection**: Provide a screen at the beginning of the game where players select their native starting career (e.g. Patreon, Craftsman, Tailor, Scholar).
- **Starting Inventory & Lore**: Adapt starting items, gold, and local lore based on the selected career choice.

### 💑 8. Dynasties, Courting & NPC Relationships
- **NPC Affinity**: Add dialogue options, gifting, and favor tasks to increase relationship points with specific townspeople.
- **Dynastic Marriage & Partnerships**: Courting and marriage at a macro level with regional dynasties, granting access to new playable/hireable characters that can work at player businesses.
- **Career Partnerships**: Romancing or partnering with a townsperson of a different career unlocks joint building/crafting access, allowing players to build and run workstations belonging to their partner's profession.

### 🌍 9. Macro-Economy, Events & External Trade
- **Province & Global Events**: Dynamic events affecting industries, sales, or stocks (e.g. foreign war outbreak generating massive order requests for weapons, armor, and health items).
- **Service/Production Events**: Unusual events within specific business types (e.g., a bank client failing to pay back their debt and interests).
- **River-Based External Trade**: Trading routes along rivers for exporting goods at higher prices, requiring high capital investments in security/escorts and trade licenses (High-Risk/High-Reward).
- **Bandit Encounters**: Random ambush and theft encounters during goods transportation, scaling in frequency and threat level depending on the province's security rating.

### 🌾 10. Profession Expansion & Raw Materials
- **Pervasive Profession Trees**: Expand unique buildings, recipes, and progression trees for Craftsman, WoodWorker, Scholar, Patreon, Tailor, Rogue, Herbalist, and Entertainer professions.
- **Basic Item Gathering**: Refine world gathering mechanics for basic raw materials (wheat, eggs, apples, fresh water, etc.) to support foundational economy loops.
- **Provincial Raw Material Nodes**: Specific nodes in each province dedicated to gathering basic raw materials, allowing players to source goods by investing money and managing time/logistics.

### ⚖️ 11. Health, Crime & Legal Systems
- **Legal System & Jail Time**: Employees and characters face legal consequences. Misconduct or illegal actions can result in lawsuits, legal cases, and active jail sentences.
- **Injuries & Hospitalization**: Accidents in workplaces or physical altercations result in temporary injuries and recovery time in hospitals, disabling workers.

### 🏰 12. Province Travel & Guild Alliances
- **Province Border Restrictions**: Border tolls and entry requirements (gold fees or title thresholds) needed to travel to, buy properties in, or build in new provinces.
- **Guild Trade Alliances**: Set up diplomatic treaties, trading agreements, and guild alliances at the macro level.

### ⛪ 13. Religion System
- **State Religion**: Interact with a centralized state religion. Players can donate gold/money to temples to accumulate political and social influence.

---

## ✅ Completed Features

### 📈 Simulated Economy, Shop Selection Refinement & Market Balancing
- Refactored NPC shop selection utility weights and transaction limits.
- Implemented consolidated midnight balancing loops (caravans and background consumption).
- Created Warehouse building and minimum stock logistics gating.
- Spawned 4 Provincial Guild footprint stubs and custom interior layouts.

### 🛡️ Player & Employee Equipment System
- Developed a complete equipment slot system supporting Head Armor, Main Armor (Body), Gloves, Hand Weapon, Tool, Bag, Necklace, Ring, and Transportation (horse and cart).
- Equipped items grant corresponding attribute boosts (Armor, Attack, Speed multipliers, Inventory Capacity, and Gathering Yields).
- Implemented tool durability tracking: gathering at Mega-Nodes decrements durability, breaking the tool at 0. Breakages alert the player and pause NPC gathering shifts.
- Designed a statically configured, gamepad-friendly UI in the editor (`game_hud.tscn`) showing active stats alongside inventory.
- Created an Employee Equipment popup modal inside the building manager to equip items from the player's inventory.
- Added inventory capacity checks to block unequipping/swapping bags if the active inventory exceeds the new capacity.
- Integrated all equipment states with JSON save/load serialization.

### 📋 Hired Worker Assignment Redesign & NPC Filtering
- Redesigned building work assignment to replace legacy OptionButton dropdown menus with a clean button-triggered pop-up selector.
- Supports specifying production quantities (1, 5, 10, 25) or Continuous (indefinite loop) crafting targets.
- Displays recipe selections using final product names (e.g. "Flour") rather than actions ("Grind Wheat").
- Implemented NPC role filtering in the hireable pool: quest-givers (e.g., Cornelius) and interior-only characters cannot be hired as employees.
- Fixed traveling pathing for workers outside the workshop, guiding them to the doors first to teleport inside prior to pathfinding to the crafting bench.

### 🏰 Cities, Towns, Plazas & Allowed Settlement Limits
- Implemented **City and Town** entities on the overworld map.
- Added **Allowed Settlement restrictions** (`allowed_settlement`) to `BuildingData`. Configured raw-gathering (Mines, Fields) to towns only, and Bank to city only, throwing dynamic `"Cant build here"` messages.
- Created walkable community **Plazas** covering the market areas.

### 🛣️ NPC Road Navigation & Physics Lot Avoidance
- Created a grid-snapped **AStar2D Road Navigation Network** in `GameState` that automatically maps and connects all roads and plazas.
- Hooked up **AIRival** to utilize the AStar road pathfinding for state machine movements.
- Created the **NPC entity (soft blue mod)** and spawned 2-3 active wandering NPCs per city and town roaming along roads and plazas.
- Designed dynamic **NPC Lot Barriers** (Static bodies on Layer 3) that block AI entities from stepping on vacant/occupied lots while allowing the player to walk freely.
- Excluded currently highlighted lots from AI house buyouts.
- Adjusted query shape sweeps to prevent contact boundary false-positives with adjacent lots.
- Set up dynamic character-to-character collision exception rules (Player, Rivals, NPCs) to let entities slide and walk through each other.

### 🏢 Building Classification & Real Estate Rules
- Mapped private houses, rental houses, production buildings, and public landmarks.
- Developed dynamic Bank and Inn visual scenes, 3x buyout pricing, and interior templates.

### 🕹️ Focus Navigation & Unified Input Overhaul (WASD/F/QE)
- Unified interaction/select confirmations to `F` (or `Enter` / `ui_accept`), and tab cycling to `Q`/`E`.
- Designed compact grid card layouts and step-by-step transaction popups in Market UI.
- Programmed continuous crafting on focused recipe cards and vertical focus bridges.
- Implemented 2D grid neighbor linking for Inventory bags and Building UI Worker Ledgers.
- Resolved tab focus retention issues on build menu reopen cycles.

### 🚚 Advanced Inter-Workshop Logistics, Trade Routes & Employee Mobility
- **Sequential Waypoint Planning & Stop Resource**: Implemented stop schemas (`TradeRouteStop` resource) defining building stop, action type (LOAD/UNLOAD), item ID, and target quantity. Old legacy single-item cargo definitions were removed.
- **Improved Visual Route Planning Map**: Built an interactive 2D map visualizer (painted green grass background, stone roads, and brick plazas/markets) centered dynamically on the valley coordinate bounds. Enabled WASD/arrow key focus navigation to cycle and select waypoints on the map.
- **Ingredient Filtering**: Implemented strict destination recipe validation on UNLOAD stops. Displays warning if building does not consume item and disables route start.
- **Worker Modal Confirmation**: Added Enter/ui_accept route confirmation, displaying a scrollable hired employee list popup showing worker name, home workshop, and active status (Idle, Crafting, Gathering, On Route) to select the courier.
- **Logistics Courier AI**: Enhanced courier state machine to loop stops, perform sequential transactions with a 0.5s unit delay at market stalls, handle cargo inventories (max 4 slots), and deposit gold/profit into their home workshop strongbox.
- **Employee Mobility & Transfers**: Decoupled hired workers from static buildings, introducing global `transfer_to_building()` to re-home workers. Added "Transfer" button in the building worker management UI allowing inline workshop switching.
- **Personal Houses Integration**: Placed interactive `CommercialRoutesConsole` items in all personal player houses (excluding rentals). Benches were removed from player houses and towns. Added HUD open/close integration and Esc key closing.
- **Mega-Node Harvesting & Clean Up**: Migrated resource gathering to Mega-Nodes, enabling `F` interaction monitoring overlays and directional-independent access. Deleted legacy regular gathering node templates.

### 📈 Simulated Economy, Shop Selection Refinement & Market Balancing
- **NPC Shop Selection Refinement**: Implemented social class weights for Peasants, Citizens, and Nobles. NPCs buying from private player stalls have transaction caps limiting finished products to 1-2 units.
- **24-Hour Consolidated Market Sync**: Designed nightly balancing loop executing Phase A (Simulated Background Guild Consumption) and Phase B (Merchant Caravan shortage/glut/disruption safety-valves) strictly at midnight.
- **Player Warehouses**: Created a 48-slot player-purchasable Warehouse storage depot (placed next to houses under the General construction tab) with custom UI panels enabling minimum retained stock threshold locks that logistics couriers respect.
- **Provincial Guild Hall Stubs**: Spawned Craftsman, Scholar, Tailor, and Patreon Guild footprints in overworld cities with a custom `900x600` baked navigation interior stub.

### 🏛️ Three-Tier Guild Loops, Breakthrough Quests & Conclave Elections
- **Professional Rank Hierarchy & Level Locks**: Added Novice (L1-3), Journeyman (L4-6), Expert (L7-9), and Master (L10) career naming tiers with automatic experience hardlocks at levels 3, 6, and 9.
- **Breakthrough Rank Quests**: Introduced profession-specific Guild Master NPCs (e.g. *Craftsman Guild Master*, *Scholar Guild Master*, *Tailor Guild Master*, *Patreon Guild Master*) inside each guild house, exclusively dedicated to level up breakthrough choices (Novice -> Journeyman -> Expert -> Master).
- **Seasonal Guild Conclave (Election Loop)**: Added a 4-day loop with blind-bidding, midnight Day 2 voting resolution with Title/Prestige multipliers, term limits, and default neutral Guild Elder fallback.
- **Guild Office NPCs & Modifiers**: Spawned visual, interactive NPCs inside the guild hall offices representing the Grand Chairman, Donations Overseer (display name; office name: Logistics Overseer), and Materials Steward. Interacting with them opens their designated single-purpose conclave windows (tab buttons hidden, cycling disabled): Elections/Audits for the Chairman, Donations for the Donations Overseer, and Wholesalers/Bundles for the Materials Steward.
- **Province Prosperity, Donations & Wholesale Store**: Enabled donations of gold or raw materials to advance Province Prosperity (now displayed next to the province name under the minimap radar in brackets). Wholesale store bundles are timed (refreshing every 10 real-world minutes) and locked individually upon purchase.
- **Bureaucratic Audits**: Implemented competitor audit summons spawning an inspector NPC who applies `is_under_audit = true` for 12 game hours (halting production and clearing storefront inventory), governed by a global 2-day cooldown.

### 🧱 Monolithic Code Decoupling & Component Composition (Milestones 1-4)
- **Node Composition Pattern for Production**: Extracted monolithic 1680-line `base_production_building.gd` into modular, isolated child component nodes: [BuildingUpgradeComponent](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/components/production/BuildingUpgradeComponent.gd) and [BuildingStaffComponent](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/components/production/BuildingStaffComponent.gd), utilizing GDScript getter/setter proxy redirectors for backward compatibility.
- **F1-F10 UI Sub-Windows Decoupling**: Decoupled monolithic 2980-line `game_hud.gd` into 6 standalone sub-window scripts ([TitleUpgradeWindow](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/UI/title_upgrade_window.gd), [InfluenceBrokerWindow](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/UI/influence_broker_window.gd), [AlertUiManager](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/UI/alert_ui_manager.gd), [BusinessListWindow](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/UI/business_list_window.gd), [OpponentsListWindow](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/UI/opponents_list_window.gd), [BuildMenuWindow](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/UI/build_menu_window.gd)) cached via master HUD references instead of parent hierarchy pointers.
- **Main Data Ledger Refactoring**: Modularized 1580-line `main_data_view.gd` into [WorkshopViewController](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/common/ui/workshop_view.gd), [WarehouseViewController](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/common/ui/warehouse_view.gd), and [MainDataViewModalManager](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/common/ui/modal_manager.gd) attached to single common parent nodes.
- **Player HUD Decoupling**: Decoupled 1580-line `player_hud.gd` into [PlayerInventoryWindow](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/common/ui/player_inventory_window.gd) and [PlayerInteractPrompt](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/common/ui/player_interact_prompt.gd), and deleted duplicate build menu nodes.

### 🕹️ UI Responsiveness, Key Hold & Focus Overhaul
- **Reactive Player Gold Updating**: Added a new `gold_changed` signal and setter in [GameState](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/common/singletons/game_state.gd), updating HUD gold displays immediately upon transactions.
- **Build Menu Focus Retention**: Added focus-preservation during build menu card refreshes on time clock ticks, automatically saving and restoring the user's active focused card.
- **Focus Trapping & Escape Prevention**: Locked focus navigation inside all active popup dialogs (Market UI, Price Adjuster, Transaction Prompt, and Build Menu) via viewport `gui_focus_changed` traps and explicit focus neighbors.
- **Continuous Slider Adjustment**: Removed echo key restrictions to support holding down `A`/`D`/Left/Right keys for fast slider adjustments.
- **Build Menu Selector Beat Fix**: Resolved focus selector flickering ("beating" or respawning) on clock ticks by caching `_last_focused_card` and restoring focus to it rather than resetting to the first card when viewport focus briefly escapes or resets.
- **Milestone 5 - Employee Scheduling & Modal Focus Wrap**:
  - Automatically route active recipe employees to the workbench if they are idling or outside when their shift starts.
  - Teleport off-shift employees from the building interior to the doorstep when their shift ends to prevent them from getting stuck.
  - Enforce off-shift crafting/gathering pause in the building staff component so workers do not work while off-duty.
  - Reorder the quantity buttons in the job selection modal so "Continuous (Indefinite)" is the first option.
  - Setup explicit vertical focus wrapping for these quantity selection buttons and trap focus inside the modal overlays to prevent escape to the background view.
  - Restrict infinite virtual stock checks to public MarketStalls only; private stalls and production buildings require real stock to be sold.
  - Automatically transfer finished goods from building storage to the storefront stall for Rival/NPC-run production buildings so they can sell crafted goods.
  - Multiplied NPC necessity demand cooldowns and initial timers by 4x to decrease overall consumption frequency.
