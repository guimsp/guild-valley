# Guild Valley - Feature Backlog & Roadmap

This file tracks all planned, proposed, and future features for **Guild Valley**. Feel free to add new ideas, modify descriptions, or remove items to direct the game's development priorities.

---

## 🎯 Current Task
- None. Ready for next task selection.

---

## 📋 Planned Features & Ideas

### 🏛️ 1. Dynamic Lot Spawning & Licensing
- **Citizenship & Settlement Restrictions**: Characters default to a native City/Town. Building or settling in other cities requires purchasing a local license or paying a premium lot cost.
- **Luxury Spawners**: High-prosperity zones spawn luxury materials and premium goods in the overworld.

### 🤖 2. Dynamic Navigation Obstacle Avoidance
- **Dynamic Avoidance**: Enable obstacle avoidance (RVO pathfinding steering) so competitor NPCs, couriers, and wandering villagers naturally route around player-placed workstations and houses.

### 🧵 3. Tailor Career & Crafting Expansion
- **Tailor Clothing Recipes & Sewing Table**: Implement advanced Tailor career recipes, materials (like wool, fabric, clothes), and the custom workstation (Sewing Table).

### 💑 4. Dynastic Alliances & Career Partnerships
- **Dynastic Alliances**: Courting and marriage at a macro level with regional dynasties, granting access to new playable/hireable characters that can work at player businesses.
- **Career Partnerships**: Romancing or partnering with a townsperson of a different career unlocks joint building/crafting access, allowing players to build and run workstations belonging to their partner's profession.

### 🌍 5. Macro-Economy, Events & External Trade
- **Commerce-Driven Prosperity**: Selling items to public markets grants small, subtle trickles of prosperity to the local province/city (hidden from players in exact values but visible as incremental progress).
- **Dynamic Event Crises**: Random events requesting bulk goods from players (e.g., a city/province demanding weapons and armor for an upcoming war).
- **Quest System Overhaul**: Introduce distinct quest categories and rewards:
  - *Guild Quests & City Authority Quests* (from Councilors, Governors, etc.).
  - *Diverse Rewards*: Quests might yield Gold + Influence, Gold + Influence + Profession Exp (to boost specific careers), or Gold + Prosperity (to build up local cities).
- **River-Based External Trade**: Trading routes along rivers for exporting goods at higher prices, requiring high capital investments in security/escorts and trade licenses (High-Risk/High-Reward).
- **Bandit Encounters**: Random ambush and theft encounters during goods transportation, scaling in frequency and threat level depending on the province's security rating.

### 🌾 6. Profession Expansion & Raw Materials
- **Pervasive Profession Trees**: Expand unique buildings, recipes, and progression trees for WoodWorker, Rogue, Herbalist, and Entertainer professions.
- **Provincial Raw Material Nodes**: Specific nodes in each province dedicated to gathering basic raw materials, allowing players to source goods by investing money and managing time/logistics.

### ⚖️ 7. Health, Crime, & Underworld Systems
- **Black Market Trading Hub**: A dedicated black market trading system and custom illicit economy mechanics with unique trader NPCs for Rogue characters to exchange contraband and forged items.
- **Legal System & Jail Time**: Employees and characters face legal consequences. Misconduct or illegal actions can result in lawsuits, legal cases, and active jail sentences.
- **Injuries & Hospitalization**: Accidents in workplaces or physical altercations result in temporary injuries and recovery time in hospitals, disabling workers.

### 🏰 8. Province Travel & Guild Alliances
- **Walled City Entrance Tolls**: Entry tolls applied when entering walled cities via gated checkpoints guarded by city sentries. Bypassed by being affiliated with the local city/province guild.
- **Guild Trade Alliances**: Set up diplomatic treaties, trading agreements, and guild alliances at the macro level.

### ⛪ 9. Religion System
- **State Religion**: Interact with a centralized state religion. Players can donate gold/money to temples to accumulate political and social influence.

### 🏢 10. Building Interior Evolution & Workstation Spawning
- **Dynamic Building Interiors**: Support unique, themed interior templates matching the building type (e.g. bakeries, distilleries, inns, and event halls).
- **Workstation Improvement Spawning**: Dynamically spawn and position physical workbenches inside the interior scene when they are added via building improvements.
- **Service Navigation Target Points**: Guide worker NPCs to different specific coordinates and target nodes inside the building depending on the active recipe or service they are performing (e.g. baking oven vs. serving counter).

### 🖼️ 11. Housing Artifact Slots & Buff Stacking
- **Artifact Slots**: Each personal house has 1 slot (expanding to 2 slots at maximum house level) for displaying unique artifacts.
- **Buff Stacking Incentives**: Players can establish houses across different provinces to stack passive artifact bonuses (e.g., stats or production boosts) simultaneously.

---

## ✅ Completed Features

### 🎭 Showman (Entertainer) Profession Tier 1-4 Update
- Re-aligned Showman career progression loop from levels 1 to 10.
- Added 21 item resources: Raw (`clay_mud`, `raw_stone`, `marble_block`), semi-elaborate (`fine_pigments`, `artist_canvas`, `refined_clay`, `instrument_strings`), and finished/equipment goods (`clay_flute`, `festival_mask`, `plaster_bust`, `noble_statue`, `masterwork_lute`, `brass_horn`, `sheet_music`, `busking_ticket`, `concert_ticket`, `scenic_backdrop`, `royal_regalia`, `grand_stage_set`, `masterpiece_opera_partiture`, `monumental_acoustic_dome`).
- Configured 21 recipes covering workshop production, dynamic boost services, and spires.
- Created custom workshop scripts and scenes: Artisan Atelier, Busking Stages (L1-4), Instrument Workshop, Music Salons (L1-2), Scenic Design Lofts (L1-2), Grand Amphitheater, and Royal Opera House.
- Integrated placement rules for Royal Opera House (requiring Showman Level 10, gold, and consuming 1x Monumental Truss; spouse requirement explicitly removed per user instruction).
- Programmatically spawned overworld resource nodes for Clay Banks (`clay_mud`), Stone Quarries (`raw_stone`), and Marble Deposits (`marble_block`).
- Programmed dynamic service boosters in Music Salons, supporting cost scaling and ticket production.

### 👤 Rogue Profession Tier 1-4 Update
- Re-aligned Rogue progression loop from levels 1 to 10.
- Added 19 item resources: Raw (`scraped_metal`, `wild_animal_bones`, `deadwood_twigs`), refined (`utility_solder_bar`, `polished_bone_buttons`, `coarse_cordage`), finished (`street_cudgel`, `travelers_money_belt`, `transit_pass`, `concealed_liner_bag`, `performer_disguise_kit`, `flash_powder_bomb`, `poisoned_dagger`, `informant_report`, `private_security_voucher`, `squatters_writ`, `bandits_pass`, `skeleton_key`).
- Configured 14 recipes covering workbench fabrication, logistics, extortion, and safe conduct passes.
- Created custom workshop scripts and scenes: Smuggler's Hideout, Thieves' Den (L1-4), Informant Lookout, Cutpurse Apartments (L1-2), Crime Syndicate HQ (L1-2), Shadow Broker's Ring, and Palace Spire.
- Implemented map attributes ("W | S | H") drawing on map graphics and map click-to-dispatch, private security client-driven services, toll and tariff bypass for smuggler routes, Spire placement career/spouse rules, overworld scrap/bone/twig gathering mega-nodes spawning, and Squatter's Writ 48-hour audit shutdown confirmation logic on competitor workshops.

### 📑 Scholar Profession Tier 1-4 Update
- Re-aligned Scholar progression loop from levels 1 to 10.
- Added 20 item resources: Raw (`wild_flax`, `river_reeds`), refined (`inkwell`, `parchment_sheet`, `printing_plate`, `unsigned_bond`), finished (`land_deed`, `registry_ledger`, `blank_profession_book`/Apprenticeship Tome, `masterwork_folio`, `trade_passport`), and legal certificates/contracts (`signed_affidavit`, `tax_exemption_writ`, `imperial_trade_charter`, `active_debt_ledger`, `venture_certificate`, `defaulted_estate_contract`, `monopoly_defense_contract`, `central_banking_charter`, `fiat_currency_matrix`).
- Configured 22 recipes covering scriptorium paper making, legal drafting, usury lending, and masterpiece fiat currency matrix.
- Created custom workshop scripts and scenes: Paper Scriptorium (L1), Scholar Study (L1-4), Registrar Office (L1-2), Type-Setting Press (L1), Grand Courthouse (L1), Provincial Bank (L1-2), Sovereign Mint (L10 Spire), and Library Spire (L10).
- Handled spires checks (removed spouse/truss checks for Craftsman and Patreon spires), added Sovereign Mint Scholar Level 10 requirement, and added Provincial Bank advanced structural beam consumption.
- Enforced a 15 Gold border toll on NPCs transitioning between different provinces, bypassed if player has a `trade_passport` in inventory.
- Programmatically spawned Oakhaven Flax Field and Valley Reed Banks mega nodes.
- Fixed a pre-existing out-of-bounds inventory layout focus linking error.

### 🧪 Herbalist Profession Tier 1-4 Update
- Re-aligned Herbalist career progression loop from levels 1 to 10.
- Added raw resources (`raw_wild_herbs`, `overworld_root`, `underground_fungi`) and semi-elaborates/finished goods (`flora_oil`, `dried_shives`, `raw_pigment_powder`, `stamina_draught`, `nitre_powder`, `healing_salve`, `chemical_solvent`, `pure_sulfur`, `antitoxin_serum`, `restoration_flask`, `lethal_poison_base`, `void_catalyst`, `crop_blight_contract`, `archduke_treatment_contract`, `draught_of_infinity`, `philosophers_stone`).
- Configured 22 new recipes covering botany, medicine, dyes, contracts (Crop Blight, Archduke Treatment), and spires.
- Created custom workshop scripts and scenes: Biomass Drying Shed (L1), Apothecary Shop (L1-4), Acid Crucible & Still (L1), Infusion Infirmary (L1-2), Conservatory Lab (L1-2), Imperial Sanitarium, and Alchemical Greenhouse Spire.
- Implemented level 10 validation (no spouse, no truss requirement) on Alchemical Spire placement.
- Programmatically spawned overworld gatherable nodes for wild herbs, root, and fungi at coordinate Vector2s.
- Integrated the Infirmaries with Dynamic Boosters (Anti-Toxin Serum, Restoration Flask) yielding a 1.5x price multiplier.

### 🪵 Woodworker Profession Tier 1-4 Update
- Re-aligned Woodworker career progression loop from levels 1 to 10.
- Added raw resources (`raw_log`, `raw_hardwood_log`, `firewood`) and semi-elaborates/finished goods (`wooden_pegs`, `basic_crate`, `loom_frame`, `shipping_crate`, `refined_hardwood`, `reinforced_wheel`, `handcart`, `freight_wagon`, `ornate_fittings`, `modular_wing`, `heavy_scaffolding`, `masterwork_vault_door`).
- Configured 23 new recipes covering wood processing, cartwrighting, architecture, event contracts (Bridge Reconstruction, Palace Remodeling), and masterwork vault doors.
- Created custom workshop scripts and scenes: Timber Mill (L1), Carpentry Workshop (L1-4), Hardwood Kiln, Wheelwright Shop (L1-2), Architecture Atelier (L1-2), Civil Engineering Guildhall, and Citadel Spire.
- Implemented spouse career and Woodworker Level 10 validation on Citadel Spire placement.
- Programmatically spawned overworld gatherable nodes for Hardwood Logs at Valley Hardwood Grove and Mineville Hardwood Forest.
- Configured GreatForest and OakhavenForest to harvest `raw_log` instead of standard timber.
- Integrated the Hauling and Transit Services with Dynamic Boosters (Handcart, Freight Wagon) yielding a 1.5x price multiplier.

### 🛠️ Craftsman Profession Tier 1-4 Update
- Re-aligned Craftsman career progression loop from levels 1 to 10.
- Programmatically spawned raw overworld gathering nodes: Coal Nuggets, Copper Ore, and Zinc Ore.
- Created 31 new item resources representing raw resources, intermediates, finished contracts, and martial weapons/armor.
- Configured 24 new recipes covering metallurgy, toolmaking, defensive fortification spikes, and military armory commissions.
- Added custom workshop scripts and scenes: Bloomery Smelter (L1), Blacksmith Forge (L1-2), Alloy Blast Furnace (L4), The Armory (L1-3), Imperial Siege Arsenal (L7), Imperial Ordnance Foundry (L8), and Imperial Ironworks Spire (L10).
- Implemented spouse career and Craftsman Level 10 validation on Ironworks Spire placement.
- Integrated the Garrison Outfitting Service dynamic booster and client transaction logs inside Armories.

### 🥖 Patreon Profession Tier 1-4 Update
- Re-aligned Patreon progression loop from levels 1 to 10.
- Added new items (Wild animal hides, tanned leather strips, cargo keg, stage costume, spice grubs, tickets/vouchers, sovereign banquet, sovereign nectar, and royal tapestry/painting decor items).
- Revamped Tavern and Inn to separate production and services, including DYNAMIC_BOOST mechanics.
- Implemented Tier 4 Imperial Gastronomy Spire with Monumental Truss construction cost.

### 👤 Character Core Stats, Trait Pipeline & Serialization (Phase 1)
- **CharacterResource Container**: Standardized base stats (LP, AP, damage, walking/gathering speed, productivity) and progress/ID metadata.
- **Prosperity-Weighted Trait Generation**: RNG loops inside NPCManager weighing provincial prosperity levels to roll 0-2 traits on spawning.
- **Tool Level Restraints**: Restricts overworld harvesting: level 1 tool for tier 1 resource, level 2 tool for tiers 1-3, and level 3 tool for tiers 1-6. Breaks scheduling and raises alerts on violation.
- **Midnight Wage Scaling**: Midnight loop evaluating `Daily_Wage = (Profession_Level * 15) + (Sum_Of_All_Base_Stats * 2) + (Active_Mods_Value_Weight)`.
- **Skill Book Overwriting UI**: Selection list view and confirmation replacement panel when capping at 2 active traits.
- **Deep Serialization**: Flat dictionary exports and safe reconstructive loads for player, rival, and employee resources.

### 🧠 Trait Modifiers & Probabilities (Phase 2)
- **Trait Registration & Scaled Modifiers**: Registered traits `"Fleet-Footed"`, `"Diligent Master"`, `"Scythe-Wielder"`, `"Miracle Artisan"`, and `"Scavenger's Eye"` in `npc_manager.gd` with scaled modifiers across Levels 1-3.
- **Passive Attribute Modifiers**: Refactored speed and productivity getters in player (`player.gd`) and competitor rivals (`ai_rival.gd`), employee productivity (`npc_ai_controller.gd`), and NPC speed multipliers (`npc_navigation_component.gd`) to apply passive multipliers.
- **Scythe-Wielder Gathering Speed**: Scaled tick yields in `logistics_manager.gd` during resource harvesting by Scythe-Wielder level (+5% / +10% / +15%).
- **Miracle Artisan Yield Duplication**: Hooked up 3%/7%/15% probability-based duplication for manual player crafting (`base_production_building.gd`) and employee crafting (`BuildingStaffComponent.gd`), spawning visual confirmation floating text.
- **Miracle Artisan Free Service Inputs**: Allowed service providers to skip ingredient/booster consumption and serve off-duty consumer NPCs for free on Miracle Artisan trigger.
- **Scavenger's Eye Resource Harvest**: Added level 1 raw material drop checks (3%/6%/10% chance) when harvesting high-level nodes, depositing items directly to Player inventory or building storage.

### 🌐 Macro Scale Modifier Managers (Phase 3)
- **Settlement Scope Modifiers**: Embedded export modifiers dictionaries into `city.gd` and `town.gd` matching local boundary circles to scale internal benches.
- **Province Scope Modifiers**: Created the `ProvinceMasterData` Autoload singleton tracking regional modifier lists (laws, weather events) propagating sector territory parameters.
- **Map Scope Modifiers**: Created the `GlobalProfile` Autoload singleton containing global empire profile layer arrays that apply unchanging blanket changes globally.
- **Decoupled Evaluation Pipeline**: Integrated `GameState.apply_macro_modifier()` which resolves Settlement, Province, and Map modifiers to compute speed, productivity, manual player/employee crafting times, and tavern/inn service durations at runtime.

### 📊 F1 Status Screen Expansion: Global Modifiers & Employees Status (F1 Status)
- **Programmatic Tab Integration**: Instantiated and registered two new tabs ("Global Modifiers" and "Employees Status") dynamically in `UI/game_hud.gd` to extend the Character F1 HUD.
- **Global Modifiers Section**: Renders Map-wide, Province-wide, and Local Settlement scope modifiers at runtime, displaying their source description and active values (e.g. +10% movement speed, -15% crafting time).
- Employees Status Section: Lists player-hired employees across all active workshops, including their assigned task, trait modifiers breakdown, daily wage, and current equipment.

### 🧹 HUD Architecture & Modularization Refactor
- **Code Size Reduction**: Refactored the massive `UI/game_hud.gd` script, reducing its size from 2,188 lines to 740 lines by delegating distinct UI layout and populating tasks to RefCounted helper scripts.
- **Strict Static Typing**: Declared `class_name GameHUD` on the main HUD node for typed type-hinting, implementing strict compile-time types across all variables, arguments, and return types.
- **Extracted UI Helpers**:
  - [game_hud_character_tabs.gd](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/UI/game_hud_character_tabs.gd): Renders career tabs, wealth ledgers, location-specific global modifier lists, and employee overview cards.
  - [game_hud_inventory_manager.gd](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/UI/game_hud_inventory_manager.gd): Builds the grid slots, updates player equipment stats, connects equipment slots, and routes keyboard focus mapping.
  - [game_hud_rental_window.gd](file:///Users/guidospiritoso/Desktop/Antigravity/guild-valley/UI/game_hud_rental_window.gd): Configures size, styles, buttons, and animations for the house rental dialog overlay.

### 🤖 NPC & Opponent Economy AI (Buyers, Prices & Attractiveness)
- **Generic Buyer NPCs**: Roaming townspeople representing local customers who buy products selectively based on attractiveness (decoration, level, distance), prices set by the shop owner, randomness, and daily needs.
- **Opponent Logic (Rivals)**: Competitors dynamically compete, gather resources, refine inputs, construct production buildings, hire employees, and sell finished products at their private market stalls.

### 👤 Character Creation & Starting Profession
- **Starting Career Selection**: Fully functional character creation menu to choose name and starting career path (Patreon, Craftsman, Tailor, Scholar).
- **Starting Equipment**: Populates player's inventory with matching career-starting items.

### 🏛️ Character Titles, Taxes & Provincial Politics
- **Title Upgrade Progression**: 5-tier titles (Apprentice, Journeyman, Guildmaster, Patrician, Guild Baron) unlocked via Gold and Influence, yielding building tier unlocks and passive boosts.
- **Taxes & Delinquency System**: Periodic real estate and production taxes with backlogs, delinquency status effects, and legal audit summing.
- **Provincial Politics**: Influence-weighted Conclave voting system to pass or reject 14 active provincial laws.

### 💑 Dynasties, Courting & NPC Relationships
- **NPC Affinity**: Relationship value tracking with chatting, flirting, and custom quest/favor tasks.
- **Gifting**: Interface to gift any inventory item, adjusting relationship points dynamically depending on liked/disliked items.
- **Marriage Proposal**: Proposal at 80+ Affinity using a Ring, moving the spouse to the player's cozy house and enabling them as a hireable employee.

### 🤖 Built-in Native Navigation
- **AStar & NavigationRegion2D**: Standard pathfinding utilizing Godot's native `NavigationRegion2D` and `NavigationAgent2D`.
- **Lot Avoidance**: Physics collision boxes block NPCs/Rivals from walking across vacant or highlighted building lots.

### 🧵 Tailor Career Core Loop
- **Weaving Workstations**: Loom and spinning jenny workstations.
- **Tailor Core Recipes**: Weaving cotton to cloth, spools of thread, and dyes.

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

### 🏛️ Province-Wide Prosperity, Lot Scaling, Infrastructure & Ledger
- **Province-Wide Prosperity & Level Scaling**:
  - Implemented a unified prosperity evaluation mapping with new thresholds: 100 (base/Level 1), 250 (Level 2), 500 (Level 3), 750 (Level 4), and 1000 (Level 5).
  - Synced settlement `.prosperity`, `.prosperity_level`, and `.security_rating` attributes.
- **Dynamic Lot Expansion & Visual Evolutions**:
  - Implemented directional city-lot expansions on sleep transitions, adding buildable lots and progressing city wall tiers (Palisade -> Finished Wood -> Massive Stone Walls).
  - Synced paved road network upgrades across the province once Level 3 is reached.
- **Paved Speed Boosts**:
  - Road segments support an upgraded `is_paved` status applying a flat +3% travel speed boost on top of default road boosts.
- **Security Attribute**:
  - Integrated settlement-wide `security_rating` starting at a baseline of 100 and buffing by +20 per level above Level 1.
- **Global Wealth Transaction Ledger**:
  - Developed a persistent, comprehensive gold update attribution system tracking all sources of income/loss.
  - Implemented a dedicated Ledger view tab under the F1 Character Screen.
- **Inventory Context Interaction Menu**:
  - Replaced double-click/default action with a context options popup (Equip/Consume, More Data, Delete with confirmation dialog).

---

## 🏛️ Endgame Grand Events System Design

### 📋 Overview
The Grand Events system represents the pinnacle of the **Guild Valley** endgame. Players utilize their Event Halls and high-tier materials to host massive regional events that dictate provincial prestige, shift market demand, and trigger macro-economic booms or busts.

---

### 📅 Cooldowns & Scheduling
- **Seasonal Cooldown**: Hostable once per season (4 game days/years).
- **Audit Penalty**: A catastrophic mishap triggers a mandatory 2-day Guild audit on the hosting Event Hall, locking all production and storefront transactions.
- **Opponent Interference**: Competitors (Rivals) can attempt to sabotage active event preparations, adding +15% mishap risk unless the building has the `iron_reinforcements` improvement.

---

### 🗳️ Pool of 6-7 Grand Events (with Player Choices)
Each Grand Event presents the player with critical logistics choices, matching the inputs and required careers to dictate outcomes:

1. **Grand Cathedral Inauguration**
   - *Career Focus*: Scholar / Patreon
   - *Inputs*: Finished luxury goods, common wine, sweet berry cakes.
   - *Choices*: 
     - *Solemn Mass*: Lower payout, 0% mishap chance, +30 Holy Faction affinity.
     - *Pompous Pageantry*: High payout, 30% mishap chance, +50 Influence.

2. **Royal Tournament Banquet**
   - *Career Focus*: Craftsman / Patreon
   - *Inputs*: Savory baked eggs, ale, standard timber, fine weapons.
   - *Choices*:
     - *Bountiful Feast*: Focus on food. Safe and stable reputation boost.
     - *Warrior's Gala*: Focus on heavy combat goods and premium wine. Higher payout, higher risk.

3. **Imperial Fleet Outfitting**
   - *Career Focus*: Craftsman / Scholar
   - *Inputs*: Standard timber, sails/cloth, iron bars, cured pork.
   - *Choices*:
     - *Naval Commission*: High base payout, scales with quality, requires strict deadlines.
     - *Privateer Contracting*: High profit margins but high risk of merchant audit if goods fail inspection.

4. **Guild Baron's Gala**
   - *Career Focus*: Patreon / Tailor
   - *Inputs*: Gilded cream cakes, common wine, luxury clothes.
   - *Choices*:
     - *Aristocratic Display*: Huge prestige/influence reward, high cost.
     - *Guild Alliance Dinner*: Medium payout, boosts relationship with opponent rivals.

5. **Provincial Harvest Summit**
   - *Career Focus*: Patreon / Craftsman
   - *Inputs*: Flour, savory baked eggs, baked apples, ale.
   - *Choices*:
     - *Peasant Feast*: High popularity/attractiveness bonus (+20 to all businesses), low gold return.
     - *Mercantile Trade Fair*: High gold payout, scales with items' levels.

6. **Alchemist's Grand Exhibition**
   - *Career Focus*: Scholar / Patreon
   - *Inputs*: Smugglers' moonshine, basic ingredients, apothecary buns.
   - *Choices*:
     - *Controlled Demos*: Low risk, modest payouts.
     - *Volatile Spectacle*: 40% mishap risk, massive payout & breakthrough chance.

7. **Winter Solstice Jubilee**
   - *Career Focus*: Tailor / Patreon
   - *Inputs*: Common wine, baked apples, cured pork, blankets/cloth.
   - *Choices*:
     - *Charity Drive*: Boosts tax exemptions for the next year.
     - *Imperial Revelry*: Large immediate gold payout from visiting nobles.

---

### 🏆 The 5 Event Outcomes
The final rating of the hosted event is determined by the input quality (average item level), staff career levels, and mishap rolls:

1. **Pristine / Masterwork Success**
   - *Conditions*: Triggered if all inputs are high quality (avg level >= 6). Mishap chance clamped to 0%.
   - *Rewards*: 150% gold payout, +50 Influence, +15 Attractiveness for 2 days, and immediate Career XP.
2. **Standard Success**
   - *Conditions*: Event successfully hosted with no mishaps.
   - *Rewards*: 100% gold payout, standard Career XP, and +10 Influence.
3. **Mishap / Partial Success**
   - *Conditions*: A mishap occurs but the event is saved by quick action.
   - *Rewards*: Payout reduced by 50-70%, no Influence reward, and temporary Attractiveness penalty (-10).
4. **Catastrophic Mishap**
   - *Conditions*: Critical mishap failure (e.g. food poisoning, fire).
   - *Rewards*: 0% gold payout, -30 Influence, and 12-hour building lock.
5. **Grand Boycott / Audit Strike**
   - *Conditions*: Event fails while player is under tax delinquency or active political audit.
   - *Rewards*: Demolition penalty, heavy Conclave fine, and -100 Influence.
