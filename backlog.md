# Guild Valley - Feature Backlog & Roadmap

This file tracks all planned, proposed, and future features for **Guild Valley**. Feel free to add new ideas, modify descriptions, or remove items to direct the game's development priorities.

---

## 🎯 Current Task
- **Workstation & House Ownership and Access Control**
  - Implement workstation ownership (Public, Player, Rented, NPC).
  - Multi-day renting system with max limits for fields and mines.
  - Locked NPC house doors allowing player buyout at a 3x premium price.
  - Save/load serialization of ownership states and static door locks.
  - NPC target filtering to exclude player-owned or rented stations.

---

## 📋 Planned Features & Ideas

### 🏘️ 1. Cities, Towns & Influence Dominion
- **City & Town Entities**: Fixed Cities and Towns placed in the world map.
- **Radius of Influence**: Cities possess a radius of influence mapping which Towns belong to their dominion. Towns close to a City always belong to that City.
- **Dynamic Town Ownership**: Towns can change faction or city ownership over time.
- **Special Resource Towns**: Specialized gathering nodes (Mines, Forests) that have fixed ownership and cannot change.

### 🛣️ 2. Road Network, Lot-Based Building & Transport
- **Road Network**: Inter-connected street network linking all Cities and Towns.
- **Lot-Based Building**: Construction is restricted to defined lots connected to the road system. Free building placement is removed.
- **Prosperity Lot Pricing**: Lot purchase prices depend on the location and the prosperity rating of the closest City or Town.
- **10% Transport Boost**: Characters traveling on road nodes receive a 10% speed multiplier.
- **Inter-City Pathfinding**: NPC routing and pathfinding along the road network between Towns and Cities (enabling automated trade routes).

### 🏛️ 3. Prosperity, Lot Scaling & Visual Evolutions
- **Prosperity Rating**: Cities maintain higher prosperity than Towns, driving higher populations and Lot density.
- **Luxury Spawners**: High-prosperity zones spawn luxury materials and premium goods.
- **City Visual Evolution**: Cities upgrade walls and visually expand on sleep transitions when prosperity milestones are reached (selecting randomly from 3 predefined visual evolution paths).

### 📜 4. Settlement Licenses & Trade Freedom
- **Citizenship & Settlement**: Characters default to a native City/Town. Building or settling in other cities requires purchasing a local license or paying a premium lot cost.
- **Trade Freedom**: Players and NPCs are free to trade merchandise globally across all markets, regardless of settlement status (settlement restricts building only).

### 🔑 5. Influence, Titles & Provincial Politics
- **Influence Currency**: Influence points earned through economic/political actions.
- **Provincial Titles**: Accumulated influence with a province determines titles (e.g., Citizen, Guildmaster, Patrician). Accumulated influence is never consumed or lost.
- **Provincial Politics**: Spend influence and gold to vote on or pass policies affecting taxes, career productivity, and pricing rules (restricted by titles).

### 🤖 6. AI Navigation & Pathfinding
- **Built-in Navigation**: Replace the custom waypoint-raycast pathfinding with Godot's native `NavigationRegion2D` and `NavigationAgent2D`.
- **Dynamic Avoidance**: Enable obstacle avoidance so competitor NPCs and wandering villagers naturally route around player-placed workstations and houses.

### 🧵 7. Player Career & Crafting Expansion
- **Tailor Recipes**: Implement the Tailor career recipes, materials (like wool, fabric, clothes), and custom workstation (Sewing Table).
- **Tools System**: Add upgradeable tools (Axes, Pickaxes, Scythes) that affect gathering speed and career efficiency.

### 🏢 8. Building Classification & Real Estate (Home / Production / Renting)
- **Classification**: Divide buildings by:
  - **Home**: Private houses where characters live. The player/opponent can build/buy houses for themselves in towns or cities (can own multiple).
  - **Production**: Workstations (Crafting Benches, Smelters, Looms, Mills, etc.) and future public utilities (Bank, Inn).
  - **Renting**: Homes bought to create a rental business.
- **Renting Mechanics**: Every home in the game (except for player and opponent's starting/personal houses) can be bought by the player or opponent to make a renting business out of it.
- **Tenant Simulation**: Rental properties will not always have residents; occupancy depends on property location (e.g. proximity to market/center), city prosperity, and population.
- **Population Classes**: Possible future differentiation of low/mid/high class population, impacting rents and demand.


