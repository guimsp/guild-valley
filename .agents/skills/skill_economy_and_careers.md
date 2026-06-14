# Skill: Economy, Careers, & Inventory Systems

This document contains rules and math formulas for managing items, player careers, recipes, inventories, and market pricing in Guild Valley.

---

## 🎒 Items & Recipes

1. **Item Definitions**:
   - Items are defined using `ItemData` (`res://common/items/item_data.gd`) custom resource instances (`.tres`).
   - Each item includes a `base_value`, `weight`, and `category`.
2. **Recipe Structures**:
   - Recipes are defined using `Recipe` (`res://common/items/recipe.gd`) custom resource instances (`.tres`).
   - A recipe maps input item keys to integer quantities, outputs a product item, requires a career level (e.g. Farmer Level 1), and rewards XP.

---

## 💹 Dynamic Supply & Demand Market Pricing

Market pricing is calculated dynamically based on available stock relative to the market's ideal target stock.

1. **The Formula**:
   The price multiplier scales based on stock deficit or surplus:
   $$Price = BaseValue \times \text{clamp}(1.0 + \frac{TargetStock - CurrentStock}{TargetStock} \times Sensitivity, 0.2, 3.0)$$
   - **Buy Spread**: Market sells items to players at $+10\%$ markup:
     `BuyPrice = int(Price * 1.1)`
   - **Sell Spread**: Market buys items from players at $-10\%$ markdown:
     `SellPrice = int(Price * 0.9)`
2. **Incremental Pricing Loops**:
   - When transacting in bulk (e.g., buying or selling 5 items at once), **do not calculate the price once and multiply by 5**.
   - Price must be calculated **incrementally** (in a loop of 1 unit at a time), updating the simulated stock count on each iteration. This ensures prices shift dynamically mid-transaction.
3. **Transaction Validation**:
   - Verify space limits (`max_slots`, `max_weight`) in the destination inventory before committing a trade.
   - Verify gold availability before buying.
