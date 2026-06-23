// Guild Valley Interactive Canvas & JSON Builder Application Logic

// --- Application State ---
let state = {
  nodes: [],
  connections: [],
  activeNodeId: null,
  zoom: 1.0,
  panX: 100,
  panY: 50,
  isDraggingCanvas: false,
  draggedNodeId: null,
  dragOffset: { x: 0, y: 0 },
  connecting: null, // { nodeId, portType, startX, startY }
  tempLine: null,
  highlightFilter: null, // null, 'profession_chain', 'item_io', 'item_buildings'

  // --- Extended Selection & Movement State ---
  selectedNodeIds: [],
  isSelectingBox: false,
  selectionStart: { x: 0, y: 0 },
  dragStartPositions: {},
  dragMouseStart: { x: 0, y: 0 },

  // --- History Stack ---
  history: [],
  historyIndex: -1,

  // --- Views Filtering State ---
  customPositions: {}, // Holds custom coordinates when navigating views
  currentViewMode: 'canvas', // 'canvas', 'profession', 'item'
  professionFilter: 'all',
  itemCategoryFilter: 'all',
  itemTypeFilter: 'all',
  itemLevelFilter: 'all',
  drillLevel: 'all',

  // --- Preset Layouts ---
  presets: {},
  isSpacePressed: false,
  macroPositions: {}
};

// --- DOM Elements ---
const viewportEl = document.getElementById('viewport');
const canvasEl = document.getElementById('canvas');
const nodeContainerEl = document.getElementById('node-container');
const svgConnectionsEl = document.getElementById('svg-connections');
const zoomIndicatorEl = document.getElementById('zoom-indicator');
const nodeCountEl = document.getElementById('node-count-indicator');
const connCountEl = document.getElementById('conn-count-indicator');
const contextMenuEl = document.getElementById('context-menu');
const infoDrawerEl = document.getElementById('info-drawer');
const infoTitleEl = document.getElementById('info-drawer-title');
const infoContentEl = document.getElementById('info-drawer-content');
const propertiesFormEl = document.getElementById('properties-form');
const noSelectionEl = document.getElementById('no-selection-msg');
const jsonOutputEl = document.getElementById('json-output');
const selectionBoxEl = document.getElementById('selection-box');

// --- View Filters DOM ---
const viewModeSelect = document.getElementById('view-mode');
const drillLevelSelect = document.getElementById('drill-level');
const profViewSelect = document.getElementById('prof-view-select');
const itemFiltersBar = document.getElementById('item-filters-bar');
const filterCategory = document.getElementById('filter-category');
const filterType = document.getElementById('filter-type');
const filterLevel = document.getElementById('filter-level');

// --- Initialization ---
window.addEventListener('DOMContentLoaded', () => {
  loadSavedData();
  setupViewportEvents();
  setupGlobalControls();
  setupFormEvents();
  setupKeyboardEvents();
  loadPresets(); // Initialize Presets tab
  populateSpawnElementDropdown(); // Initialize element preset drop-down
  
  // Close context menu on left click
  document.addEventListener('click', (e) => {
    if (!contextMenuEl.contains(e.target)) {
      contextMenuEl.style.display = 'none';
    }
  });

  // Drawer close button
  document.getElementById('info-drawer-close').addEventListener('click', () => {
    infoDrawerEl.style.display = 'none';
  });

  // Confirm Modal Button Handlers
  const confirmModal = document.getElementById('custom-confirm-modal');
  document.getElementById('btn-confirm-cancel').addEventListener('click', (e) => {
    e.stopPropagation();
    confirmModal.style.display = 'none';
    confirmCallback = null;
  });

  document.getElementById('btn-confirm-ok').addEventListener('click', (e) => {
    e.stopPropagation();
    confirmModal.style.display = 'none';
    if (confirmCallback) {
      confirmCallback();
      confirmCallback = null;
    }
  });

  // Capture initial state in history
  pushHistoryState();
});

// --- State Loading & Saving ---
function loadSavedData() {
  const saved = localStorage.getItem('guild_valley_canvas_data');
  const savedMacro = localStorage.getItem('guild_valley_macro_data');
  
  if (savedMacro) {
    try {
      state.macroPositions = JSON.parse(savedMacro) || {};
    } catch (e) {
      console.error("Failed to parse saved macro positions.", e);
    }
  }

  if (saved) {
    try {
      const parsed = JSON.parse(saved);
      state.nodes = parsed.nodes || [];
      state.connections = parsed.connections || [];
      if (parsed.panX !== undefined) state.panX = parsed.panX;
      if (parsed.panY !== undefined) state.panY = parsed.panY;
      if (parsed.zoom !== undefined) state.zoom = parsed.zoom;
      
      // Cache custom positions cache
      state.nodes.forEach(n => {
        state.customPositions[n.id] = { x: n.x, y: n.y };
      });
    } catch (e) {
      console.error("Failed to parse saved graph data. Loading defaults.", e);
      loadDefaults();
    }
  } else {
    loadDefaults();
  }
  
  updateCanvasTransform();
  applyViewFilters();
  updateJsonOutput();
}

function saveCurrentState() {
  if (state.currentViewMode === 'canvas') {
    state.nodes.forEach(n => {
      state.customPositions[n.id] = { x: n.x, y: n.y };
    });
  }

  const dataToSave = {
    nodes: state.nodes.map(n => {
      const customPos = state.customPositions[n.id] || { x: n.x, y: n.y };
      return {
        ...n,
        x: customPos.x,
        y: customPos.y
      };
    }),
    connections: state.connections,
    panX: state.panX,
    panY: state.panY,
    zoom: state.zoom
  };
  localStorage.setItem('guild_valley_canvas_data', JSON.stringify(dataToSave));
  localStorage.setItem('guild_valley_macro_data', JSON.stringify(state.macroPositions));
  updateJsonOutput();
}

// Load default game dataset dynamically mapping nodes and connections
function loadDefaults() {
  state.nodes = [];
  state.connections = [];
  generateGraphFromStaticData();
  autoLayoutCanvas();
  saveCurrentState();
}

function generateGraphFromStaticData() {
  const data = window.INITIAL_GAME_DATA;
  if (!data) return;

  // 1. Add Profession Nodes
  data.professions.forEach(prof => {
    state.nodes.push({
      id: `prof_${prof.id}`,
      type: 'profession',
      refId: prof.id,
      name: prof.name,
      desc: prof.description,
      x: 0,
      y: 0
    });
  });

  // 2. Add Building Nodes (Grouped by Base Building ID)
  const buildingGroups = {};
  data.buildings.forEach(b => {
    const baseId = getBaseBuildingId(b.id);
    if (!buildingGroups[baseId]) {
      buildingGroups[baseId] = [];
    }
    buildingGroups[baseId].push(b);
  });

  Object.keys(buildingGroups).forEach(baseId => {
    const group = buildingGroups[baseId];
    // Sort levels in ascending order
    group.sort((x, y) => x.level - y.level);

    const firstLvl = group[0];
    state.nodes.push({
      id: `build_${baseId}`,
      type: 'building',
      refId: baseId,
      name: firstLvl.name.replace(/\s+L\d+$/, '').replace(/\s+T\d+$/, ''),
      profession: firstLvl.profession,
      levels: group.map(b => ({
        id: b.id,
        name: b.name,
        cost: b.cost,
        level: b.level,
        desc: b.desc,
        type: b.type,
        profession: b.profession
      })),
      activeLevelIdx: 0,
      x: 0,
      y: 0
    });

    // Connect profession to base building (only once per base building group!)
    if (firstLvl.profession && firstLvl.profession !== 'any') {
      state.connections.push({
        id: `conn_prof_build_${baseId}`,
        from: `prof_${firstLvl.profession}`,
        to: `build_${baseId}`,
        type: 'unlock'
      });
    }
  });

  // 3. Add Item Nodes
  data.items.forEach(item => {
    state.nodes.push({
      id: `item_${item.id}`,
      type: item.category, // raw_material, semi_elaborate, finished_good, equipment, skill_item
      refId: item.id,
      name: item.name,
      cost: item.base_value,
      weight: item.weight,
      desc: item.desc,
      min_price: item.min_price,
      max_price: item.max_price,
      rarity: item.rarity,
      x: 0,
      y: 0
    });
  });

  // 4. Add Connections based on Recipes Matrix
  data.recipes.forEach((r, idx) => {
    const outputItemId = `item_${r.output.id}`;
    const baseBuildingId = getBaseBuildingId(r.building);
    const buildingId = `build_${baseBuildingId}`;

    // Avoid duplicate output connections on the merged building node
    const outExists = state.connections.some(c => c.from === buildingId && c.to === outputItemId && c.label === r.name);
    if (!outExists) {
      state.connections.push({
        id: `conn_recipe_out_${idx}`,
        from: buildingId,
        to: outputItemId,
        type: 'output',
        label: r.name
      });
    }

    r.inputs.forEach((input, inIdx) => {
      const inputItemId = `item_${input.id}`;
      // Avoid duplicate input connections
      const inExists = state.connections.some(c => c.from === inputItemId && c.to === buildingId && c.label === `x${input.qty}`);
      if (!inExists) {
        state.connections.push({
          id: `conn_recipe_in_${idx}_${inIdx}`,
          from: inputItemId,
          to: buildingId,
          type: 'input',
          label: `x${input.qty}`
        });
      }
    });
  });

  // 5. Add Parent Law Council Node & Child Law Nodes
  state.nodes.push({
    id: "hub_council",
    type: "law",
    refId: "hub_council",
    name: "Provincial Council / Lawhouse",
    desc: "Main legislative assembly hall that processes seasonal taxes, handles delinquent backlogs, and assemblies custom bills sponsorship voting.",
    x: 2400,
    y: 100
  });

  data.laws.forEach((law, idx) => {
    const lawId = `law_${law.id}`;
    state.nodes.push({
      id: lawId,
      type: "law",
      refId: law.id,
      name: law.name,
      desc: law.desc,
      x: 2700,
      y: 100 + (idx * 130)
    });

    // Auto connect parent
    state.connections.push({
      id: `conn_law_hub_${law.id}`,
      from: "hub_council",
      to: lawId,
      type: "unlock"
    });
  });

  // 6. Add Parent Mechanics Core Node & Children Mechanics Nodes
  state.nodes.push({
    id: "hub_mechanics",
    type: "mechanic",
    refId: "hub_mechanics",
    name: "Game Core Systems Hub",
    desc: "Central simulation logic governing NPCs classes, AStar road navigation grids, marriages, and nightly conclave election cycles.",
    x: 2400,
    y: 2000
  });

  data.mechanics.forEach((mech, idx) => {
    const mechId = `mech_${mech.id}`;
    state.nodes.push({
      id: mechId,
      type: "mechanic",
      refId: mech.id,
      name: mech.name,
      desc: mech.desc,
      x: 2700,
      y: 1950 + (idx * 130)
    });

    // Auto connect parent
    state.connections.push({
      id: `conn_mech_hub_${mech.id}`,
      from: "hub_mechanics",
      to: mechId,
      type: "input"
    });
  });

  // Backup positions
  state.nodes.forEach(n => {
    state.customPositions[n.id] = { x: n.x, y: n.y };
  });
}

// --- History Stack (Undo Logic) ---
function pushHistoryState() {
  const nodesCopy = JSON.parse(JSON.stringify(state.nodes));
  const connectionsCopy = JSON.parse(JSON.stringify(state.connections));

  if (state.historyIndex < state.history.length - 1) {
    state.history = state.history.slice(0, state.historyIndex + 1);
  }

  state.history.push({
    nodes: nodesCopy,
    connections: connectionsCopy
  });

  if (state.history.length > 50) {
    state.history.shift();
  }
  state.historyIndex = state.history.length - 1;
}

function undo() {
  if (state.historyIndex > 0) {
    state.historyIndex--;
    const prev = state.history[state.historyIndex];
    state.nodes = JSON.parse(JSON.stringify(prev.nodes));
    state.connections = JSON.parse(JSON.stringify(prev.connections));

    state.nodes.forEach(n => {
      state.customPositions[n.id] = { x: n.x, y: n.y };
    });

    applyViewFilters();
    updateJsonOutput();
  }
}

function setupKeyboardEvents() {
  window.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'z') {
      e.preventDefault();
      undo();
    }
    
    if (e.key === ' ' && !['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName)) {
      e.preventDefault();
      if (!state.isSpacePressed) {
        state.isSpacePressed = true;
        viewportEl.style.cursor = 'grab';
      }
    }
  });

  window.addEventListener('keyup', (e) => {
    if (e.key === ' ') {
      state.isSpacePressed = false;
      viewportEl.style.cursor = 'default';
    }
  });
}

// --- Dynamic Layouts & Views Sorting ---
function autoLayoutCanvas() {
  const columns = {
    profession: [],
    raw_material: [],
    building: [],
    semi_elaborate: [],
    finished_good: [],
    equipment: [],
    skill_item: [],
    law: [],
    mechanic: []
  };

  // Group nodes
  state.nodes.forEach(node => {
    if (columns[node.type]) {
      columns[node.type].push(node);
    } else {
      columns.finished_good.push(node);
    }
  });

  const xCoords = {
    profession: 100,
    raw_material: 420,
    building: 740,
    semi_elaborate: 1060,
    finished_good: 1380,
    equipment: 1700,
    skill_item: 2020,
    law: 2340,
    mechanic: 2660
  };

  Object.keys(columns).forEach(colType => {
    const colNodes = columns[colType];
    const x = xCoords[colType] || 100;
    const ySpacing = (colType === 'building' || colType === 'law' || colType === 'mechanic') ? 170 : 120;
    
    colNodes.forEach((node, idx) => {
      // Don't auto-arrange the parent hubs in flat columns, keep them grouped
      if (node.id === 'hub_council') {
        node.x = 2340;
        node.y = 100;
      } else if (node.id === 'hub_mechanics') {
        node.x = 2340;
        node.y = 1500;
      } else {
        node.x = x;
        node.y = 80 + (idx * ySpacing);
      }
      state.customPositions[node.id] = { x: node.x, y: node.y };
    });
  });

  state.zoom = 0.55;
  state.panX = 50;
  state.panY = 30;
  updateCanvasTransform();
  applyViewFilters();
}

// --- Dynamic Profession Flows Layout ---
function layoutProfessionFlow() {
  const activeProf = state.professionFilter;
  const data = window.INITIAL_GAME_DATA;

  const targetProfs = activeProf === 'all' 
    ? data.professions.map(p => p.id) 
    : [activeProf];

  let currentY = 100;

  targetProfs.forEach(profId => {
    const profNode = state.nodes.find(n => n.type === 'profession' && n.refId === profId);
    if (!profNode) return;

    profNode.x = 100;
    
    const buildings = state.nodes.filter(n => n.type === 'building' && n.profession === profId);
    let buildingY = currentY;
    
    buildings.forEach((bNode) => {
      bNode.x = 420;
      bNode.y = buildingY;

      const outputs = data.recipes.filter(r => getBaseBuildingId(r.building) === bNode.refId);
      let outputY = buildingY;

      outputs.forEach((recipe) => {
        const outNode = state.nodes.find(n => n.refId === recipe.output.id);
        if (outNode) {
          outNode.x = 740;
          outNode.y = outputY;

          const reqText = recipe.inputs.map(inp => `${inp.qty}x ${inp.id.replace('_', ' ')}`).join(', ');
          outNode.desc = `${window.INITIAL_GAME_DATA.items.find(i=>i.id===recipe.output.id)?.desc || ''} (Requires: ${reqText || 'None'})`;
          
          let inputY = outputY;
          recipe.inputs.forEach((input) => {
            const inpNode = state.nodes.find(n => n.refId === input.id);
            if (inpNode) {
              inpNode.x = 1060;
              inpNode.y = inputY;
              inputY += 130;
            }
          });

          outputY = Math.max(outputY + 140, inputY);
        }
      });

      if (bNode.refId.includes('inn') || bNode.refId.includes('tavern') || bNode.refId.includes('casino')) {
        const serviceTickets = state.nodes.filter(n => n.type === 'finished_good' && n.id.includes('ticket') && isTicketAssignedToBuilding(n.refId, bNode.refId));
        serviceTickets.forEach((srv) => {
          srv.x = 740;
          srv.y = outputY;
          outputY += 140;
        });
      }

      buildingY = Math.max(buildingY + 180, outputY);
    });

    profNode.y = currentY + (buildingY - currentY) / 2 - 50;
    currentY = buildingY + 100;
  });

  state.zoom = 0.55;
  state.panX = 80;
  state.panY = 40;
  updateCanvasTransform();
}

function isTicketAssignedToBuilding(ticketId, buildingId) {
  if (ticketId.includes('bathhouse') || ticketId.includes('kitchen')) return buildingId.includes('inn');
  if (ticketId.includes('entertainment')) return buildingId.includes('tavern');
  if (ticketId.includes('dining')) return buildingId.includes('inn');
  return false;
}

// --- Dynamic Item Supply Chains Layout ---
function layoutItemSupplyChain() {
  const columns = {
    raw_material: [],
    semi_elaborate: [],
    finished_good: [],
    equipment_and_skills: []
  };

  const visibleItems = state.nodes.filter(n => {
    if (n.type === 'profession' || n.type === 'building' || n.type === 'law' || n.type === 'mechanic') return false;
    
    if (state.itemCategoryFilter !== 'all' && state.itemCategoryFilter !== n.type) return false;

    if (state.itemTypeFilter !== 'all') {
      const type = getItemType(n.refId);
      if (type !== state.itemTypeFilter) return false;
    }

    if (state.itemLevelFilter !== 'all') {
      const level = getItemRecipeLevel(n.refId);
      if (level !== Number(state.itemLevelFilter)) return false;
    }

    return true;
  });

  visibleItems.forEach(item => {
    if (item.type === 'raw_material') columns.raw_material.push(item);
    else if (item.type === 'semi_elaborate') columns.semi_elaborate.push(item);
    else if (item.type === 'finished_good') columns.finished_good.push(item);
    else columns.equipment_and_skills.push(item);
  });

  const xCoords = {
    raw_material: 100,
    semi_elaborate: 450,
    finished_good: 800,
    equipment_and_skills: 1150
  };

  Object.keys(columns).forEach(col => {
    const colNodes = columns[col];
    const x = xCoords[col] || 100;
    colNodes.forEach((node, idx) => {
      node.x = x;
      node.y = 80 + (idx * 130);
    });
  });

  state.zoom = 0.65;
  state.panX = 80;
  state.panY = 40;
  updateCanvasTransform();
}

function layoutMixedProductions() {
  const mixedItemIds = new Set();
  const items = state.nodes.filter(n => ['raw_material', 'semi_elaborate', 'finished_good', 'equipment', 'skill_item'].includes(n.type));
  
  items.forEach(item => {
    const outConns = state.connections.filter(c => c.to === item.id && c.from.startsWith('build_'));
    const inConns = state.connections.filter(c => c.from === item.id && c.to.startsWith('build_'));

    if (outConns.length > 0 && inConns.length > 0) {
      const prodProfs = new Set();
      outConns.forEach(c => {
        const bNode = state.nodes.find(n => n.id === c.from);
        if (bNode && bNode.profession && bNode.profession !== 'any') {
          prodProfs.add(bNode.profession);
        }
      });

      const consProfs = new Set();
      inConns.forEach(c => {
        const bNode = state.nodes.find(n => n.id === c.to);
        if (bNode && bNode.profession && bNode.profession !== 'any') {
          consProfs.add(bNode.profession);
        }
      });

      let isMixed = false;
      for (let p1 of prodProfs) {
        for (let p2 of consProfs) {
          if (p1 !== p2) {
            isMixed = true;
            break;
          }
        }
        if (isMixed) break;
      }

      if (isMixed) {
        mixedItemIds.add(item.id);
      }
    }
  });

  const producers = new Set();
  const consumers = new Set();

  state.connections.forEach(c => {
    if (mixedItemIds.has(c.to) && c.from.startsWith('build_')) {
      producers.add(c.from);
    }
    if (mixedItemIds.has(c.from) && c.to.startsWith('build_')) {
      consumers.add(c.to);
    }
  });

  // Place nodes in three columns: Producer Buildings, Mixed Items, Consumer Buildings
  const leftCol = Array.from(producers);
  const midCol = Array.from(mixedItemIds);
  const rightCol = Array.from(consumers).filter(id => !leftCol.includes(id));

  leftCol.forEach((id, idx) => {
    const node = state.nodes.find(n => n.id === id);
    if (node) {
      node.x = 100;
      node.y = 100 + (idx * 160);
    }
  });

  midCol.forEach((id, idx) => {
    const node = state.nodes.find(n => n.id === id);
    if (node) {
      node.x = 450;
      node.y = 100 + (idx * 160);
    }
  });

  rightCol.forEach((id, idx) => {
    const node = state.nodes.find(n => n.id === id);
    if (node) {
      node.x = 800;
      node.y = 100 + (idx * 160);
    }
  });

  state.zoom = 0.75;
  state.panX = 100;
  state.panY = 50;
  updateCanvasTransform();
}

function getItemType(itemId) {
  const tools = ['bronze_pickaxe', 'heavy_steel_tools'];
  const armor = ['iron_chestplate', 'iron_helmet', 'leather_gloves'];
  const weapons = ['iron_sword'];
  const transportation = ['horse', 'cart'];
  const bags = ['leather_backpack'];
  const accessories = ['gold_ring', 'silver_necklace'];
  const consumables = [
    'bread', 'ale', 'baked_apples', 'savory_baked_eggs', 'apothecary_sweet_bun',
    'sweet_berry_cake', 'cured_pork', 'royal_venison_pasty', 'fine_aged_schnapps',
    'grapes', 'berries', 'apples', 'milk', 'water', 'sugar', 'honey', 'wheat'
  ];

  if (tools.includes(itemId)) return 'tool';
  if (armor.includes(itemId)) return 'armor';
  if (weapons.includes(itemId)) return 'weapon';
  if (transportation.includes(itemId)) return 'transportation';
  if (bags.includes(itemId)) return 'bag';
  if (accessories.includes(itemId)) return 'accessory';
  if (consumables.includes(itemId)) return 'consumable';
  return 'other';
}

function getItemRecipeLevel(itemId) {
  const data = window.INITIAL_GAME_DATA;
  const recipe = data.recipes.find(r => r.output.id === itemId);
  return recipe ? recipe.level : null;
}

function getBaseBuildingId(id) {
  return id.replace(/_(l|t)\d+$/, '');
}

function getBuildingTier(id) {
  const match = id.match(/_(l|t)(\d+)$/);
  return match ? Number(match[2]) : 1;
}

let confirmCallback = null;

function showCustomConfirm(title, message, onConfirm) {
  const modal = document.getElementById('custom-confirm-modal');
  const titleEl = document.getElementById('confirm-title');
  const msgEl = document.getElementById('confirm-message');

  titleEl.textContent = title;
  msgEl.textContent = message;
  confirmCallback = onConfirm;
  modal.style.display = 'flex';
  
  // Close context menu if open
  const contextMenu = document.getElementById('context-menu');
  if (contextMenu) contextMenu.style.display = 'none';
}

function showNotification(message, type = 'info') {
  const container = document.getElementById('toast-container');
  if (!container) return;
  
  const toast = document.createElement('div');
  toast.className = 'toast';
  
  let borderColor = '#3b82f6'; // info
  if (type === 'success') borderColor = '#10b981';
  else if (type === 'error') borderColor = '#ef4444';
  else if (type === 'warning') borderColor = '#f59e0b';
  
  toast.style.borderLeftColor = borderColor;
  toast.innerHTML = message;
  
  container.appendChild(toast);
  setTimeout(() => {
    toast.remove();
  }, 3000);
}

// --- Apply Visual Filter Rules ---
function applyViewFilters() {
  const viewMode = state.currentViewMode;
  
  const mixedItemIds = new Set();
  const mixedBuildingIds = new Set();

  if (viewMode === 'mixed') {
    const items = state.nodes.filter(n => ['raw_material', 'semi_elaborate', 'finished_good', 'equipment', 'skill_item'].includes(n.type));
    items.forEach(item => {
      const outConns = state.connections.filter(c => c.to === item.id && c.from.startsWith('build_'));
      const inConns = state.connections.filter(c => c.from === item.id && c.to.startsWith('build_'));

      if (outConns.length > 0 && inConns.length > 0) {
        const prodProfs = new Set();
        outConns.forEach(c => {
          const bNode = state.nodes.find(n => n.id === c.from);
          if (bNode && bNode.profession && bNode.profession !== 'any') {
            prodProfs.add(bNode.profession);
          }
        });

        const consProfs = new Set();
        inConns.forEach(c => {
          const bNode = state.nodes.find(n => n.id === c.to);
          if (bNode && bNode.profession && bNode.profession !== 'any') {
            consProfs.add(bNode.profession);
          }
        });

        let isMixed = false;
        for (let p1 of prodProfs) {
          for (let p2 of consProfs) {
            if (p1 !== p2) {
              isMixed = true;
              break;
            }
          }
          if (isMixed) break;
        }

        if (isMixed) {
          mixedItemIds.add(item.id);
          outConns.forEach(c => mixedBuildingIds.add(c.from));
          inConns.forEach(c => mixedBuildingIds.add(c.to));
        }
      }
    });
  }
  
  if (viewMode === 'profession') {
    layoutProfessionFlow();
  } else if (viewMode === 'item') {
    layoutItemSupplyChain();
  } else if (viewMode === 'mixed') {
    layoutMixedProductions();
  } else {
    state.nodes.forEach(n => {
      if (state.customPositions[n.id]) {
        n.x = state.customPositions[n.id].x;
        n.y = state.customPositions[n.id].y;
      }
    });
  }

  // 1. Render all nodes first so they exist in the DOM with updated coordinates
  renderNodes();

  // 2. Precompute highlighted related IDs if context filter is active
  const relatedIds = new Set();
  if (state.highlightFilter) {
    const activeNode = state.nodes.find(n => n.id === state.activeNodeId);
    if (activeNode) {
      relatedIds.add(activeNode.id);
      
      if (state.highlightFilter === 'profession_chain') {
        // Add all buildings connected to the profession on the canvas
        state.connections.forEach(c => {
          if (c.from === activeNode.id) relatedIds.add(c.to);
          if (c.to === activeNode.id) relatedIds.add(c.from);
        });
        // Add all items connected to those buildings on the canvas
        const firstLevel = Array.from(relatedIds);
        state.connections.forEach(c => {
          if (firstLevel.includes(c.from)) relatedIds.add(c.to);
          if (firstLevel.includes(c.to)) relatedIds.add(c.from);
        });
      } else if (state.highlightFilter === 'item_io') {
        // Add all buildings connected to this item on the canvas
        state.connections.forEach(c => {
          if (c.from === activeNode.id) relatedIds.add(c.to);
          if (c.to === activeNode.id) relatedIds.add(c.from);
        });
        // Add other items connected to those buildings
        const buildings = Array.from(relatedIds);
        state.connections.forEach(c => {
          if (buildings.includes(c.from) && c.to.startsWith('item_')) relatedIds.add(c.to);
          if (buildings.includes(c.to) && c.from.startsWith('item_')) relatedIds.add(c.from);
        });
      } else if (state.highlightFilter === 'item_buildings') {
        // Add only the buildings connected to this item on the canvas
        state.connections.forEach(c => {
          if (c.from === activeNode.id && c.to.startsWith('build_')) relatedIds.add(c.to);
          if (c.to === activeNode.id && c.from.startsWith('build_')) relatedIds.add(c.from);
        });
      }
    }
  }

  // 3. Adjust display visibility and grey-out states on the rendered DOM elements
  document.querySelectorAll('.node').forEach(nodeEl => {
    const isMacro = state.currentViewMode === 'macro';
    const node = isMacro 
      ? getMacroNodesList().find(n => n.id === nodeEl.id)
      : state.nodes.find(n => n.id === nodeEl.id);
    if (!node) return;

    // 1. Determine standard visibility
    let visible = true;
    
    if (viewMode === 'profession') {
      const data = window.INITIAL_GAME_DATA;
      const activeProf = state.professionFilter;
      const targetProfs = activeProf === 'all' ? data.professions.map(p => p.id) : [activeProf];
      
      if (node.type === 'profession') {
        visible = targetProfs.includes(node.refId);
      } else if (node.type === 'building') {
        visible = targetProfs.includes(node.profession);
      } else {
        visible = targetProfs.some(profId => isItemInCareerChain(node, profId)) || 
                  (node.type === 'finished_good' && node.id.includes('ticket') && targetProfs.includes('patreon'));
      }
    } else if (viewMode === 'item') {
      if (node.type === 'profession' || node.type === 'building' || node.type === 'law' || node.type === 'mechanic') {
        visible = false;
      } else {
        visible = true;
        if (state.itemCategoryFilter !== 'all' && state.itemCategoryFilter !== node.type) visible = false;
        if (state.itemTypeFilter !== 'all' && getItemType(node.refId) !== state.itemTypeFilter) visible = false;
        if (state.itemLevelFilter !== 'all' && getItemRecipeLevel(node.refId) !== Number(state.itemLevelFilter)) visible = false;
      }
    } else if (viewMode === 'mixed') {
      visible = mixedItemIds.has(node.id) || mixedBuildingIds.has(node.id);
    } else {
      const depth = state.drillLevel;
      if (depth === 'professions') {
        visible = node.type === 'profession';
      } else if (depth === 'buildings') {
        visible = (node.type === 'profession' || node.type === 'building' || node.type === 'home' || node.type === 'renting' || node.type === 'warehouse');
      } else {
        visible = true;
      }
    }

    nodeEl.style.display = visible ? 'block' : 'none';

    // 2. Handle context menu highlighting/fading for visible elements
    if (visible) {
      if (state.highlightFilter) {
        const isHighlighted = relatedIds.has(node.id);
        if (isHighlighted) {
          nodeEl.classList.remove('faded');
        } else {
          nodeEl.classList.add('faded');
        }
      } else {
        nodeEl.classList.remove('faded');
      }
    }
  });

  drawConnections();
}

// --- Viewport Events (Box Selection, Panning, Sockets) ---
function setupViewportEvents() {
  viewportEl.addEventListener('pointerdown', (e) => {
    const isBackground = (e.target === viewportEl || e.target === canvasEl || e.target === svgConnectionsEl || e.target === nodeContainerEl);
    if (!isBackground) return;

    const isPanAction = state.isSpacePressed || e.button === 1;

    if (isPanAction) {
      e.preventDefault();
      state.isDraggingCanvas = true;
      state.dragOffset = { x: e.clientX - state.panX, y: e.clientY - state.panY };
      viewportEl.style.cursor = 'grabbing';
      viewportEl.setPointerCapture(e.pointerId);
      e.stopPropagation();
    } else if (e.button === 0) {
      state.isSelectingBox = true;
      
      const rect = viewportEl.getBoundingClientRect();
      const startX = (e.clientX - rect.left - state.panX) / state.zoom;
      const startY = (e.clientY - rect.top - state.panY) / state.zoom;
      
      state.selectionStart = { x: startX, y: startY };
      
      selectionBoxEl.style.left = `${startX}px`;
      selectionBoxEl.style.top = `${startY}px`;
      selectionBoxEl.style.width = '0px';
      selectionBoxEl.style.height = '0px';
      selectionBoxEl.style.display = 'block';

      if (!e.shiftKey) {
        state.selectedNodeIds = [];
        document.querySelectorAll('.node').forEach(el => el.classList.remove('selected'));
      }
      
      if (state.highlightFilter) {
        state.highlightFilter = null;
        applyViewFilters();
      }

      viewportEl.setPointerCapture(e.pointerId);
      e.stopPropagation();
    }
  });

  viewportEl.addEventListener('pointermove', (e) => {
    if (state.isSelectingBox) {
      const rect = viewportEl.getBoundingClientRect();
      const currentX = (e.clientX - rect.left - state.panX) / state.zoom;
      const currentY = (e.clientY - rect.top - state.panY) / state.zoom;

      const x = Math.min(state.selectionStart.x, currentX);
      const y = Math.min(state.selectionStart.y, currentY);
      const width = Math.abs(state.selectionStart.x - currentX);
      const height = Math.abs(state.selectionStart.y - currentY);

      selectionBoxEl.style.left = `${x}px`;
      selectionBoxEl.style.top = `${y}px`;
      selectionBoxEl.style.width = `${width}px`;
      selectionBoxEl.style.height = `${height}px`;
    } else if (state.isDraggingCanvas) {
      state.panX = e.clientX - state.dragOffset.x;
      state.panY = e.clientY - state.dragOffset.y;
      updateCanvasTransform();
    } else if (state.connecting) {
      updateTempLine(e.clientX, e.clientY);
    }
  });

  viewportEl.addEventListener('pointerup', (e) => {
    if (state.isSelectingBox) {
      selectionBoxEl.style.display = 'none';
      state.isSelectingBox = false;
      viewportEl.releasePointerCapture(e.pointerId);

      const x1 = parseFloat(selectionBoxEl.style.left);
      const y1 = parseFloat(selectionBoxEl.style.top);
      const w = parseFloat(selectionBoxEl.style.width);
      const h = parseFloat(selectionBoxEl.style.height);
      const x2 = x1 + w;
      const y2 = y1 + h;

      const isMacro = state.currentViewMode === 'macro';
      const nodesToCheck = isMacro ? getMacroNodesList() : state.nodes;

      state.selectedNodeIds = [];
      nodesToCheck.forEach(node => {
        const nodeEl = document.getElementById(node.id);
        if (!nodeEl || nodeEl.style.display === 'none') return;

        const nw = nodeEl.offsetWidth || 270;
        const nh = nodeEl.offsetHeight || 40;

        const overlapX = Math.max(x1, node.x) < Math.min(x2, node.x + nw);
        const overlapY = Math.max(y1, node.y) < Math.min(y2, node.y + nh);

        if (overlapX && overlapY) {
          state.selectedNodeIds.push(node.id);
          nodeEl.classList.add('selected');
        } else {
          nodeEl.classList.remove('selected');
        }
      });
      
    } else if (state.isDraggingCanvas) {
      state.isDraggingCanvas = false;
      viewportEl.releasePointerCapture(e.pointerId);
      viewportEl.style.cursor = state.isSpacePressed ? 'grab' : 'default';
      saveCurrentState();
    } else if (state.connecting) {
      if (state.tempLine) {
        state.tempLine.remove();
        state.tempLine = null;
      }
      state.connecting = null;
    }
  });

  viewportEl.addEventListener('wheel', (e) => {
    e.preventDefault();
    
    if (e.ctrlKey) {
      const zoomIntensity = 0.08;
      const mouseX = e.clientX - viewportEl.getBoundingClientRect().left;
      const mouseY = e.clientY - viewportEl.getBoundingClientRect().top;
      
      const canvasMouseX = (mouseX - state.panX) / state.zoom;
      const canvasMouseY = (mouseY - state.panY) / state.zoom;
      
      if (e.deltaY < 0) {
        state.zoom += state.zoom * zoomIntensity;
      } else {
        state.zoom -= state.zoom * zoomIntensity;
      }
      
      state.zoom = Math.max(0.1, Math.min(state.zoom, 3.0));
      
      state.panX = mouseX - canvasMouseX * state.zoom;
      state.panY = mouseY - canvasMouseY * state.zoom;
    } else {
      state.panX -= e.deltaX;
      state.panY -= e.deltaY;
    }
    
    updateCanvasTransform();
    saveCurrentState();
  }, { passive: false });
}

function updateCanvasTransform() {
  canvasEl.style.transform = `translate(${state.panX}px, ${state.panY}px) scale(${state.zoom})`;
  zoomIndicatorEl.textContent = `${Math.round(state.zoom * 100)}%`;
}

// --- Node Cards Rendering & Interactions ---
function getMacroNodesList() {
  const data = window.INITIAL_GAME_DATA;
  if (!data || !data.macroNodes) return [];

  // Default positions for Systems Flow Diagram (3 columns)
  const defaultPos = {
    macro_guilds: { x: 100, y: 100 },
    macro_professions: { x: 100, y: 350 },
    macro_relationships: { x: 100, y: 600 },
    macro_buildings: { x: 500, y: 200 },
    macro_economy: { x: 500, y: 500 },
    macro_influence: { x: 500, y: 800 },
    macro_prosperity: { x: 900, y: 200 },
    macro_laws: { x: 900, y: 600 }
  };

  return data.macroNodes.map(node => {
    const saved = state.macroPositions[node.id] || defaultPos[node.id] || { x: 100, y: 100 };
    return {
      id: node.id,
      type: 'macro',
      name: node.name,
      desc: node.desc,
      x: saved.x,
      y: saved.y
    };
  });
}

function renderNodes() {
  nodeContainerEl.innerHTML = '';
  
  const isMacro = state.currentViewMode === 'macro';
  const nodesToRender = isMacro ? getMacroNodesList() : state.nodes;
  
  nodesToRender.forEach(node => {
    const nodeEl = document.createElement('div');
    nodeEl.id = node.id;
    nodeEl.className = `node ${node.type}`;
    nodeEl.style.left = `${node.x}px`;
    nodeEl.style.top = `${node.y}px`;
    
    if (state.activeNodeId === node.id) {
      nodeEl.classList.add('active-node');
    }
    if (state.selectedNodeIds.includes(node.id)) {
      nodeEl.classList.add('selected');
    }

    const titleText = (node.type === 'building' && node.levels && node.levels[node.activeLevelIdx || 0]) 
      ? node.levels[node.activeLevelIdx || 0].name 
      : (node.name || 'Untitled');
    const subText = node.type.replace('_', ' ').toUpperCase();
    const costText = node.cost !== undefined ? `${node.cost} G` : '';
    const weightText = node.weight !== undefined ? `${node.weight} W` : '';
    
    const isItem = ['raw_material', 'semi_elaborate', 'finished_good', 'equipment', 'skill_item'].includes(node.type);
    
    let detailsHTML = '';
    if (isMacro) {
      detailsHTML = `<div style="font-size: 0.75rem; color: var(--text-muted); line-height: 1.4; pointer-events: none;">${node.desc}</div>`;
    } else if (isItem) {
      const itemLevel = getItemRecipeLevel(node.refId);
      const minP = node.min_price !== undefined ? `${node.min_price}` : '?';
      const maxP = node.max_price !== undefined ? `${node.max_price}` : '?';
      const rarityLabel = node.rarity || 'Common';
      
      const data = window.INITIAL_GAME_DATA;
      const recipe = data ? data.recipes.find(r => r.output.id === node.refId) : null;
      let recipeDetails = '';
      if (recipe) {
        const bData = data.buildings.find(b => b.id === recipe.building);
        const bName = bData ? bData.name.replace(/\s+L\d+$/, '').replace(/\s+T\d+$/, '') : recipe.building.replace(/_(l|t)\d+$/, '');
        
        let inputsLine = '';
        if (recipe.inputs && recipe.inputs.length > 0) {
          const inpList = recipe.inputs.map(inp => {
            const itemData = data.items.find(i => i.id === inp.id);
            return `${inp.qty}x ${itemData ? itemData.name : inp.id}`;
          }).join(', ');
          inputsLine = `<div style="margin-top: 2px; line-height: 1.25;">Inputs: <span style="color:#ffffff;">${inpList}</span></div>`;
        }
        
        recipeDetails = `
          <div style="margin-top: 4px; border-top: 1px dashed rgba(255,255,255,0.08); padding-top: 4px;">
            <div>Produced: <strong style="color:#ffffff;">${bName}</strong></div>
            ${inputsLine}
          </div>
        `;
      }

      detailsHTML = `
        <div style="margin-bottom: 2px;">Rarity: <strong style="color:#ffffff;">${rarityLabel}</strong> ${itemLevel ? `| Lvl: ${itemLevel}` : ''}</div>
        <div>Price: ${minP}-${maxP} G (Base: ${node.cost || 0} G)</div>
        <div>Weight: ${weightText}</div>
        ${recipeDetails}
      `;
    } else if (node.type === 'building') {
      const activeIdx = node.activeLevelIdx || 0;
      const levels = node.levels || [];
      const activeLvl = levels[activeIdx] || node;
      
      let lvlButtonsHTML = '';
      if (levels.length > 1) {
        lvlButtonsHTML = `
          <div class="lvl-btn-group">
            ${levels.map((lvl, idx) => {
              const tier = getBuildingTier(lvl.id);
              return `<button type="button" class="lvl-btn ${idx === activeIdx ? 'active' : ''}" data-idx="${idx}">T${tier}</button>`;
            }).join('')}
          </div>
        `;
      }

      const tier = getBuildingTier(activeLvl.id || node.id);

      detailsHTML = `
        ${lvlButtonsHTML}
        <div class="lvl-details" style="font-size: 0.7rem; color: var(--text-muted); line-height: 1.35;">
          <div>Tier: <strong style="color: #ffffff;">Tier ${tier}</strong></div>
          <div>Cost: ${activeLvl.cost || 0} G</div>
          <div>Level Req: ${activeLvl.level || 1}</div>
          <div>Profession: ${activeLvl.profession || 'any'}</div>
        </div>
      `;
    } else {
      detailsHTML = `
        ${costText ? `<div>Cost: ${costText}</div>` : ''}
        ${weightText ? `<div>Weight: ${weightText}</div>` : ''}
        ${node.level ? `<div>Level: ${node.level}</div>` : ''}
      `;
    }

    const isCollapsed = node.collapsed !== false;
    
    // Short category label for badge
    let subTextShort = 'OTHER';
    if (node.type === 'profession') subTextShort = 'PROF';
    else if (node.type === 'building') subTextShort = 'BUILD';
    else if (node.type === 'raw_material') subTextShort = 'RAW';
    else if (node.type === 'semi_elaborate') subTextShort = 'SEMI';
    else if (node.type === 'finished_good') subTextShort = 'FIN';
    else if (node.type === 'equipment') subTextShort = 'EQUIP';
    else if (node.type === 'skill_item') subTextShort = 'SKILL';
    else if (node.type === 'law') subTextShort = 'LAW';
    else if (node.type === 'mechanic') subTextShort = 'MECH';
    else if (node.type === 'macro') subTextShort = 'MACRO';

    nodeEl.innerHTML = `
      ${isMacro ? '' : '<div class="port input-port" data-node="' + node.id + '" data-type="input"></div>'}
      <div class="node-header-row">
        <div class="node-badge ${node.type}">${subTextShort}</div>
        <button type="button" class="node-toggle-btn ${isCollapsed ? 'collapsed' : ''}" data-node="${node.id}">
          <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="6 9 12 15 18 9"></polyline>
          </svg>
        </button>
      </div>
      <div class="node-title-row">
        <div class="node-title-group">
          <span class="node-title" title="${titleText}">${titleText}</span>
          <span class="node-subtitle" title="${node.refId || node.id}">(${node.refId || node.id})</span>
        </div>
      </div>
      
      <div class="node-details ${isCollapsed ? 'collapsed' : ''}">
        ${detailsHTML}
      </div>
      ${isMacro ? '' : '<div class="port output-port" data-node="' + node.id + '" data-type="output"></div>'}
    `;

    // Toggle collapse handlers
    nodeEl.querySelector('.node-toggle-btn').addEventListener('click', (e) => {
      e.stopPropagation();
      node.collapsed = !isCollapsed;
      saveCurrentState();
      applyViewFilters();
      drawConnections();
    });

    nodeEl.addEventListener('dblclick', (e) => {
      e.stopPropagation();
      node.collapsed = !isCollapsed;
      saveCurrentState();
      applyViewFilters();
      drawConnections();
    });

    // --- Node Dragging ---
    nodeEl.addEventListener('pointerdown', (e) => {
      if (e.target.classList.contains('port')) return;

      state.activeNodeId = node.id;
      
      if (!state.selectedNodeIds.includes(node.id)) {
        state.selectedNodeIds = [node.id];
        document.querySelectorAll('.node').forEach(el => el.classList.remove('selected'));
        nodeEl.classList.add('selected');
      }

      state.draggedNodeId = node.id;
      
      state.dragStartPositions = {};
      state.selectedNodeIds.forEach(id => {
        const targetNode = isMacro ? getMacroNodesList().find(n => n.id === id) : state.nodes.find(n => n.id === id);
        if (targetNode) {
          state.dragStartPositions[id] = { x: targetNode.x, y: targetNode.y };
        }
      });

      state.dragMouseStart = {
        x: e.clientX / state.zoom,
        y: e.clientY / state.zoom
      };

      nodeEl.setPointerCapture(e.pointerId);
      e.stopPropagation();
      
      populatePropertiesPanel(node);
      pushHistoryState();
    });

    nodeEl.addEventListener('pointermove', (e) => {
      if (state.draggedNodeId === node.id) {
        const dx = (e.clientX / state.zoom) - state.dragMouseStart.x;
        const dy = (e.clientY / state.zoom) - state.dragMouseStart.y;
        
        state.selectedNodeIds.forEach(id => {
          const targetNode = isMacro ? getMacroNodesList().find(n => n.id === id) : state.nodes.find(n => n.id === id);
          const startPos = state.dragStartPositions[id];
          if (targetNode && startPos) {
            targetNode.x = startPos.x + dx;
            targetNode.y = startPos.y + dy;
            
            const cardEl = document.getElementById(targetNode.id);
            if (cardEl) {
              cardEl.style.left = `${targetNode.x}px`;
              cardEl.style.top = `${targetNode.y}px`;
            }

            if (isMacro) {
              state.macroPositions[targetNode.id] = { x: targetNode.x, y: targetNode.y };
            } else {
              state.customPositions[targetNode.id] = { x: targetNode.x, y: targetNode.y };
            }
          }
        });
        
        drawConnections();
      }
    });

    nodeEl.addEventListener('pointerup', (e) => {
      if (state.draggedNodeId === node.id) {
        state.draggedNodeId = null;
        nodeEl.releasePointerCapture(e.pointerId);
        saveCurrentState();
      }
    });

    nodeEl.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      e.stopPropagation();
      
      state.activeNodeId = node.id;
      populatePropertiesPanel(node);

      contextMenuEl.style.left = `${e.clientX}px`;
      contextMenuEl.style.top = `${e.clientY}px`;
      contextMenuEl.style.display = 'block';

      const profActions = document.getElementById('prof-only-actions');
      const itemActions = document.getElementById('item-only-actions');
      
      if (node.type === 'profession') {
        profActions.style.display = 'block';
        itemActions.style.display = 'none';
      } else if (isItem) {
        profActions.style.display = 'none';
        itemActions.style.display = 'block';
      } else {
        profActions.style.display = 'none';
        itemActions.style.display = 'none';
      }
    });

    // --- Sockets ---
    if (!isMacro) {
      nodeEl.querySelectorAll('.port').forEach(port => {
        port.addEventListener('pointerdown', (e) => {
          e.stopPropagation();
          
          const rect = port.getBoundingClientRect();
          const startX = (rect.left + rect.width/2 - state.panX) / state.zoom;
          const startY = (rect.top + rect.height/2 - state.panY) / state.zoom;
          
          state.connecting = {
            nodeId: node.id,
            portType: port.dataset.type,
            startX,
            startY
          };
          
          port.setPointerCapture(e.pointerId);
          pushHistoryState();
        });

        port.addEventListener('pointerup', (e) => {
          e.stopPropagation();
          port.releasePointerCapture(e.pointerId);

          if (state.connecting && state.connecting.nodeId !== node.id) {
            if (state.connecting.portType !== port.dataset.type) {
              const fromId = state.connecting.portType === 'output' ? state.connecting.nodeId : node.id;
              const toId = state.connecting.portType === 'input' ? state.connecting.nodeId : node.id;
              
              const exists = state.connections.some(c => c.from === fromId && c.to === toId);
              if (!exists) {
                state.connections.push({
                  id: `conn_${Date.now()}_${Math.floor(Math.random()*1000)}`,
                  from: fromId,
                  to: toId,
                  type: 'custom'
                });
                saveCurrentState();
                drawConnections();
              }
            }
          }
          
          if (state.tempLine) {
            state.tempLine.remove();
            state.tempLine = null;
          }
          state.connecting = null;
        });
      });
    }

    nodeContainerEl.appendChild(nodeEl);

    // Attach level button listeners for buildings
    if (node.type === 'building' && node.levels) {
      nodeEl.querySelectorAll('.lvl-btn').forEach(btn => {
        btn.addEventListener('pointerdown', (e) => {
          e.stopPropagation();
        });
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const idx = Number(btn.dataset.idx);
          node.activeLevelIdx = idx;
          saveCurrentState();
          applyViewFilters();
          if (state.activeNodeId === node.id) {
            populatePropertiesPanel(node);
          }
        });
      });
    }
  });

  nodeCountEl.textContent = nodesToRender.length;
  connCountEl.textContent = state.connections.filter(c => document.getElementById(c.from)?.style.display !== 'none' && document.getElementById(c.to)?.style.display !== 'none').length;
}

// --- Connection Paths Vector Drawing ---
function drawConnections() {
  while (svgConnectionsEl.firstChild) {
    svgConnectionsEl.removeChild(svgConnectionsEl.firstChild);
  }

  const viewMode = state.currentViewMode;

  const isNodeFaded = (nodeId) => {
    const el = document.getElementById(nodeId);
    return el && el.classList.contains('faded');
  };

  // 0. Draw macro connections if viewMode is macro
  if (viewMode === 'macro') {
    const data = window.INITIAL_GAME_DATA;
    if (data && data.macroConnections) {
      data.macroConnections.forEach((conn, idx) => {
        const fromNode = getMacroNodesList().find(n => n.id === conn.from);
        const toNode = getMacroNodesList().find(n => n.id === conn.to);
        
        if (!fromNode || !toNode) return;

        const isFaded = isNodeFaded(conn.from) || isNodeFaded(conn.to);
        drawBezierPath(fromNode, toNode, 'unlock', conn.label, `macro_conn_${idx}`, isFaded);
      });
    }
    return;
  }

  // 1. Draw special item-to-item lines if item_io filter is active
  if (state.highlightFilter === 'item_io') {
    const activeNode = state.nodes.find(n => n.id === state.activeNodeId);
    if (activeNode) {
      const activeItemId = activeNode.refId;
      const data = window.INITIAL_GAME_DATA;
      
      data.recipes.forEach(r => {
        const outId = `item_${r.output.id}`;
        const outNode = state.nodes.find(n => n.id === outId);
        
        r.inputs.forEach(input => {
          const inpId = `item_${input.id}`;
          const inpNode = state.nodes.find(n => n.id === inpId);
          
          if (inpNode && outNode && (r.output.id === activeItemId || input.id === activeItemId)) {
            const inpEl = document.getElementById(inpId);
            const outEl = document.getElementById(outId);
            if (inpEl && outEl && inpEl.style.display !== 'none' && outEl.style.display !== 'none') {
              const isFaded = isNodeFaded(inpId) || isNodeFaded(outId);
              drawBezierPath(inpNode, outNode, 'input', `x${input.qty}`, null, isFaded);
            }
          }
        });
      });
    }
  }

  // 2. Draw standard connections for the active view mode
  if (viewMode === 'item') {
    const data = window.INITIAL_GAME_DATA;
    data.recipes.forEach(r => {
      const outputItemId = `item_${r.output.id}`;
      const outNode = state.nodes.find(n => n.id === outputItemId);
      const outCardEl = document.getElementById(outputItemId);
      if (!outNode || !outCardEl || outCardEl.style.display === 'none') return;

      r.inputs.forEach(input => {
        const inputItemId = `item_${input.id}`;
        const inpNode = state.nodes.find(n => n.id === inputItemId);
        const inpCardEl = document.getElementById(inputItemId);
        if (!inpNode || !inpCardEl || inpCardEl.style.display === 'none') return;

        const isFaded = isNodeFaded(inputItemId) || isNodeFaded(outputItemId);
        drawBezierPath(inpNode, outNode, 'input', `x${input.qty}`, null, isFaded);
      });
    });
  } else {
    state.connections.forEach(conn => {
      const fromNode = state.nodes.find(n => n.id === conn.from);
      const toNode = state.nodes.find(n => n.id === conn.to);
      
      if (!fromNode || !toNode) return;

      const fromEl = document.getElementById(fromNode.id);
      const toEl = document.getElementById(toNode.id);
      if (!fromEl || !toEl || fromEl.style.display === 'none' || toEl.style.display === 'none') return;

      const isFaded = isNodeFaded(conn.from) || isNodeFaded(conn.to);
      drawBezierPath(fromNode, toNode, conn.type, conn.label, conn.id, isFaded);
    });
  }
}

function drawBezierPath(fromNode, toNode, type, label, connId, isFaded = false) {
  const fromEl = document.getElementById(fromNode.id);
  const toEl = document.getElementById(toNode.id);

  const fromWidth = 270; 
  const toWidth = 270;
  const fromHeight = fromEl ? fromEl.offsetHeight : 40; 
  const toHeight = toEl ? toEl.offsetHeight : 40; 

  const x1 = fromNode.x + fromWidth;
  const y1 = fromNode.y + (fromHeight / 2);
  const x2 = toNode.x;
  const y2 = toNode.y + (toHeight / 2);

  const dx = Math.abs(x2 - x1) * 0.45;
  const pathD = `M ${x1} ${y1} C ${x1 + dx} ${y1}, ${x2 - dx} ${y2}, ${x2} ${y2}`;

  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  path.setAttribute('d', pathD);
  path.setAttribute('class', isFaded ? 'connection-line faded' : 'connection-line');
  
  let strokeColor = 'rgba(156, 163, 175, 0.4)';
  if (type === 'unlock') strokeColor = 'rgba(245, 158, 11, 0.65)';
  else if (type === 'input') strokeColor = 'rgba(14, 165, 233, 0.65)';
  else if (type === 'output') strokeColor = 'rgba(168, 85, 247, 0.65)';

  path.setAttribute('stroke', strokeColor);

  if (type === 'input' || type === 'output') {
    const animPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    animPath.setAttribute('d', pathD);
    animPath.setAttribute('class', isFaded ? 'connection-line connection-flow faded' : 'connection-line connection-flow');
    animPath.setAttribute('stroke', strokeColor.replace('0.65', '0.25'));
    svgConnectionsEl.appendChild(animPath);
  }

  if (label) {
    const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    text.setAttribute('x', `${x1 + (x2 - x1)/2}`);
    text.setAttribute('y', `${y1 + (y2 - y1)/2 - 8}`);
    text.setAttribute('fill', isFaded ? 'rgba(255,255,255,0.2)' : 'rgba(255,255,255,0.7)');
    text.setAttribute('font-size', '10px');
    text.setAttribute('font-family', 'sans-serif');
    text.setAttribute('text-anchor', 'middle');
    text.textContent = label;
    svgConnectionsEl.appendChild(text);
  }

  path.addEventListener('click', (e) => {
    e.stopPropagation();
    if (connId) {
      showCustomConfirm(
        "Remove Connection",
        `Remove connection between ${fromNode.name} and ${toNode.name}?`,
        () => {
          pushHistoryState();
          state.connections = state.connections.filter(c => c.id !== connId);
          saveCurrentState();
          drawConnections();
        }
      );
    }
  });

  svgConnectionsEl.appendChild(path);
}

function updateTempLine(clientX, clientY) {
  if (!state.connecting) return;
  if (state.tempLine) state.tempLine.remove();

  const rect = viewportEl.getBoundingClientRect();
  const mouseX = (clientX - rect.left - state.panX) / state.zoom;
  const mouseY = (clientY - rect.top - state.panY) / state.zoom;

  const x1 = state.connecting.startX;
  const y1 = state.connecting.startY;
  const x2 = mouseX;
  const y2 = mouseY;

  const dx = Math.abs(x2 - x1) * 0.5;
  const pathD = `M ${x1} ${y1} C ${x1 + dx} ${y1}, ${x2 - dx} ${y2}, ${x2} ${y2}`;

  state.tempLine = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  state.tempLine.setAttribute('d', pathD);
  state.tempLine.setAttribute('stroke', '#3b82f6');
  state.tempLine.setAttribute('stroke-width', '3px');
  state.tempLine.setAttribute('fill', 'none');
  state.tempLine.setAttribute('stroke-dasharray', '5 5');

  svgConnectionsEl.appendChild(state.tempLine);
}

// --- Context View Filters ---
function triggerContextFilter(filterType, e) {
  if (e) e.stopPropagation();
  state.highlightFilter = filterType;
  contextMenuEl.style.display = 'none';
  applyViewFilters();
}

viewportEl.addEventListener('click', (e) => {
  if (e.target === viewportEl || e.target === canvasEl) {
    if (state.highlightFilter) {
      state.highlightFilter = null;
      applyViewFilters();
    }
  }
});

function isItemInCareerChain(node, careerId) {
  if (node.type === 'building' && node.profession === careerId) return true;
  
  const data = window.INITIAL_GAME_DATA;
  return data.recipes.some(r => {
    if (r.profession !== careerId) return false;
    const isInput = r.inputs.some(inp => inp.id === node.refId);
    const isOutput = r.output.id === node.refId;
    return isInput || isOutput;
  });
}

// --- Detail Drawer Toggle ---
function showNodeInfo(e) {
  if (e) e.stopPropagation();
  contextMenuEl.style.display = 'none';
  const node = state.nodes.find(n => n.id === state.activeNodeId);
  if (!node) return;

  const isItem = ['raw_material', 'semi_elaborate', 'finished_good', 'equipment', 'skill_item'].includes(node.type);
  let contentText = '';
  
  if (node.type === 'building' && node.levels) {
    const activeLvl = node.levels[node.activeLevelIdx || 0];
    infoTitleEl.textContent = activeLvl.name;
    const tier = getBuildingTier(activeLvl.id);
    contentText = `
      <strong>Category:</strong> BUILDING<br>
      <strong>ID Key:</strong> ${activeLvl.id}<br>
      <strong>Tier:</strong> Tier ${tier}<br>
      <strong>Cost / Value:</strong> ${activeLvl.cost} G<br>
      <strong>Unlock Level:</strong> ${activeLvl.level}<br>
      <strong>Profession:</strong> ${activeLvl.profession || 'any'}<br>
      ${activeLvl.desc ? `<p style="margin-top:8px; font-style:italic;">${activeLvl.desc}</p>` : ''}
    `;
  } else {
    infoTitleEl.textContent = node.name;
    if (isItem) {
      const itemLevel = getItemRecipeLevel(node.refId);
      contentText = `
        <strong>Category:</strong> ${node.type.toUpperCase()}<br>
        <strong>ID Key:</strong> ${node.refId || node.id}<br>
        <strong>Rarity:</strong> ${node.rarity || 'Common'}<br>
        ${itemLevel ? `<strong>Recipe Level Required:</strong> ${itemLevel}<br>` : ''}
        <strong>Base Gold Price:</strong> ${node.cost || 0} G<br>
        <strong>Minimum Clamp Price:</strong> ${node.min_price || 0} G<br>
        <strong>Maximum Clamp Price:</strong> ${node.max_price || 0} G<br>
        <strong>Weight:</strong> ${node.weight || 0} W<br>
        ${node.desc ? `<p style="margin-top:8px; font-style:italic;">${node.desc}</p>` : ''}
      `;
    } else {
      contentText = `
        <strong>Category:</strong> ${node.type.toUpperCase()}<br>
        <strong>ID Key:</strong> ${node.refId || node.id}<br>
        ${node.cost !== undefined ? `<strong>Cost / Value:</strong> ${node.cost} G<br>` : ''}
        ${node.level !== undefined ? `<strong>Unlock Level:</strong> ${node.level}<br>` : ''}
        ${node.desc ? `<p style="margin-top:8px; font-style:italic;">${node.desc}</p>` : ''}
      `;
    }
  }

  infoContentEl.innerHTML = contentText;
  infoDrawerEl.style.display = 'block';
}

// --- Sidebar Properties Form Binding ---
function populatePropertiesPanel(node) {
  noSelectionEl.style.display = 'none';
  propertiesFormEl.style.display = 'block';

  const isMacro = node.type === 'macro';
  
  // Set read-only status for macro nodes
  document.getElementById('prop-name').readOnly = isMacro;
  document.getElementById('prop-desc').readOnly = isMacro;

  // Show or hide the delete node button
  const deleteBtn = document.getElementById('btn-delete-node');
  if (deleteBtn) {
    deleteBtn.style.display = isMacro ? 'none' : 'block';
  }

  const activeLvl = (node.type === 'building' && node.levels && node.levels.length > 0)
    ? node.levels[node.activeLevelIdx || 0]
    : null;

  document.getElementById('prop-type').value = node.type.toUpperCase();
  document.getElementById('prop-id').value = activeLvl ? activeLvl.id : (node.refId || node.id);
  document.getElementById('prop-name').value = activeLvl ? activeLvl.name : node.name;
  document.getElementById('prop-desc').value = (activeLvl ? activeLvl.desc : node.desc) || '';

  const statsGroup = document.getElementById('group-stats');
  const levelGroup = document.getElementById('group-level');
  const weightGroup = document.getElementById('group-weight');
  const profGroup = document.getElementById('group-profession');

  if (node.type === 'building') {
    statsGroup.style.display = 'flex';
    weightGroup.style.display = 'none';
    levelGroup.style.display = 'block';
    profGroup.style.display = 'block';

    document.getElementById('prop-cost').value = activeLvl ? (activeLvl.cost || 0) : (node.cost || 0);
    document.getElementById('prop-level').value = activeLvl ? (activeLvl.level || 1) : (node.level || 1);
    document.getElementById('prop-profession').value = activeLvl ? (activeLvl.profession || 'any') : (node.profession || 'any');
  } else if (node.type === 'profession' || node.type === 'law' || node.type === 'mechanic' || node.type === 'macro') {
    statsGroup.style.display = 'none';
    levelGroup.style.display = 'none';
    profGroup.style.display = 'none';
  } else {
    statsGroup.style.display = 'flex';
    weightGroup.style.display = 'block';
    levelGroup.style.display = 'none';
    profGroup.style.display = 'none';

    document.getElementById('prop-cost').value = node.cost || 0;
    document.getElementById('prop-weight').value = node.weight || 0;
  }
}

function setupFormEvents() {
  const form = document.getElementById('properties-form');
  
  form.addEventListener('input', (e) => {
    const node = state.nodes.find(n => n.id === state.activeNodeId);
    if (!node || node.type === 'macro') return;

    const activeLvl = (node.type === 'building' && node.levels && node.levels.length > 0)
      ? node.levels[node.activeLevelIdx || 0]
      : null;

    if (e.target.id === 'prop-name') {
      if (activeLvl) activeLvl.name = e.target.value;
      node.name = e.target.value;
      const cardTitleEl = document.querySelector(`#${node.id} .node-title`);
      if (cardTitleEl) cardTitleEl.textContent = node.name;
    } else if (e.target.id === 'prop-desc') {
      if (activeLvl) activeLvl.desc = e.target.value;
      node.desc = e.target.value;
    } else if (e.target.id === 'prop-cost') {
      const val = Number(e.target.value);
      if (activeLvl) activeLvl.cost = val;
      node.cost = val;
    } else if (e.target.id === 'prop-weight') {
      node.weight = Number(e.target.value);
    } else if (e.target.id === 'prop-level') {
      const val = Number(e.target.value);
      if (activeLvl) activeLvl.level = val;
      node.level = val;
    } else if (e.target.id === 'prop-profession') {
      if (activeLvl) activeLvl.profession = e.target.value;
      node.profession = e.target.value;
    }

    saveCurrentState();
    drawConnections();
  });

  document.getElementById('btn-delete-node').addEventListener('click', deleteSelectedNode);
}

function deleteSelectedNode(e) {
  if (e) e.stopPropagation();
  if (!state.activeNodeId) return;
  if (state.activeNodeId.startsWith('macro_')) return;
  
  showCustomConfirm(
    "Delete Node",
    "Are you sure you want to delete this node? All associated connections will be removed.",
    () => {
      pushHistoryState();
      const targetId = state.activeNodeId;
      
      state.connections = state.connections.filter(c => c.from !== targetId && c.to !== targetId);
      state.nodes = state.nodes.filter(n => n.id !== targetId);
      
      state.activeNodeId = null;
      propertiesFormEl.style.display = 'none';
      noSelectionEl.style.display = 'block';
      contextMenuEl.style.display = 'none';

      saveCurrentState();
      applyViewFilters();
    }
  );
}

// --- Dynamic Blueprint Spawning Selection Forms ---
function populateSpawnElementDropdown() {
  const category = document.getElementById('spawn-category').value;
  const elementSelect = document.getElementById('spawn-element');
  const customNameGroup = document.getElementById('group-spawn-custom-name');
  
  elementSelect.innerHTML = '';
  
  const customOpt = document.createElement('option');
  customOpt.value = 'custom';
  customOpt.textContent = '<Create Custom Node>';
  elementSelect.appendChild(customOpt);

  const data = window.INITIAL_GAME_DATA;
  let itemsToPopulate = [];

  if (category === 'profession') itemsToPopulate = data.professions;
  else if (category === 'building') itemsToPopulate = data.buildings;
  else if (category === 'law') itemsToPopulate = data.laws;
  else if (category === 'mechanic') itemsToPopulate = data.mechanics;
  else itemsToPopulate = data.items.filter(item => item.category === category);

  itemsToPopulate.forEach(item => {
    const opt = document.createElement('option');
    opt.value = item.id;
    opt.textContent = item.name;
    elementSelect.appendChild(opt);
  });

  handleSpawnElementChange();
}

function handleSpawnElementChange() {
  const elementSelect = document.getElementById('spawn-element');
  const customNameGroup = document.getElementById('group-spawn-custom-name');
  if (elementSelect.value === 'custom') {
    customNameGroup.style.display = 'block';
  } else {
    customNameGroup.style.display = 'none';
  }
}

function spawnSelectedNode() {
  if (state.currentViewMode === 'macro') {
    showNotification("Adding custom nodes is disabled in Macro Systems Map view.", "warning");
    return;
  }

  const category = document.getElementById('spawn-category').value;
  const selectionId = document.getElementById('spawn-element').value;
  const customNameInput = document.getElementById('spawn-custom-name');

  const viewportRect = viewportEl.getBoundingClientRect();
  const x = (-state.panX + viewportRect.width/2 - 100) / state.zoom;
  const y = (-state.panY + viewportRect.height/2 - 50) / state.zoom;

  pushHistoryState();

  if (selectionId === 'custom') {
    const name = customNameInput.value.trim() || `New ${category.replace('_', ' ')}`;
    const uniqueId = `custom_${category}_${Date.now()}`;
    
    const node = {
      id: uniqueId,
      type: category,
      name: name,
      desc: 'Custom mocked element.',
      x: x,
      y: y
    };

    if (category === 'building') {
      node.cost = 100;
      node.level = 1;
      node.profession = 'any';
    } else if (category !== 'profession' && category !== 'law' && category !== 'mechanic') {
      node.cost = 10;
      node.weight = 0.5;
      node.rarity = 'Common';
    }

    state.nodes.push(node);
    state.activeNodeId = uniqueId;
    state.customPositions[uniqueId] = { x: node.x, y: node.y };
    customNameInput.value = '';
  } else {
    // Check if preset already exists on canvas
    const exists = state.nodes.find(n => n.refId === selectionId);
    if (exists) {
      showNotification(`"${exists.name}" is already present on the canvas! Focusing card.`, "info");
      state.activeNodeId = exists.id;
      
      // Center view around existing node
      const nodeEl = document.getElementById(exists.id);
      const nw = nodeEl ? nodeEl.offsetWidth : 270;
      const nh = nodeEl ? nodeEl.offsetHeight : 40;
      state.panX = (viewportRect.width / 2) - (exists.x * state.zoom) - (nw / 2) * state.zoom;
      state.panY = (viewportRect.height / 2) - (exists.y * state.zoom) - (nh / 2) * state.zoom;
      updateCanvasTransform();
      applyViewFilters();
      populatePropertiesPanel(exists);
      return;
    }

    // Lookup preset data
    const data = window.INITIAL_GAME_DATA;
    let preset = null;

    if (category === 'profession') preset = data.professions.find(p => p.id === selectionId);
    else if (category === 'building') preset = data.buildings.find(b => b.id === selectionId);
    else if (category === 'law') preset = data.laws.find(l => l.id === selectionId);
    else if (category === 'mechanic') preset = data.mechanics.find(m => m.id === selectionId);
    else preset = data.items.find(i => i.id === selectionId);

    if (!preset) return;

    const uniqueId = `${category}_${preset.id}`;
    const node = {
      id: uniqueId,
      type: category,
      refId: preset.id,
      name: preset.name,
      desc: preset.desc || preset.description || '',
      x: x,
      y: y
    };

    if (category === 'building') {
      node.cost = preset.cost;
      node.level = preset.level;
      node.profession = preset.profession;
    } else if (category === 'law' || category === 'mechanic') {
      // no costs
    } else {
      node.cost = preset.base_value;
      node.weight = preset.weight;
      node.min_price = preset.min_price;
      node.max_price = preset.max_price;
      node.rarity = preset.rarity;
    }

    state.nodes.push(node);
    state.activeNodeId = uniqueId;
    state.customPositions[uniqueId] = { x: node.x, y: node.y };

    // Auto connect Law or Mechanic parent nodes if present on canvas
    if (category === 'law') {
      const parent = state.nodes.find(n => n.id === 'hub_council');
      if (parent) {
        state.connections.push({
          id: `conn_law_hub_${preset.id}`,
          from: 'hub_council',
          to: uniqueId,
          type: 'unlock'
        });
      }
    } else if (category === 'mechanic') {
      const parent = state.nodes.find(n => n.id === 'hub_mechanics');
      if (parent) {
        state.connections.push({
          id: `conn_mech_hub_${preset.id}`,
          from: 'hub_mechanics',
          to: uniqueId,
          type: 'input'
        });
      }
    }
  }

  saveCurrentState();
  applyViewFilters();
  switchTab('properties');
}

function spawnCareerNetwork() {
  if (state.currentViewMode === 'macro') {
    showNotification("Spawning career networks is disabled in Macro Systems Map view.", "warning");
    return;
  }

  const professionId = document.getElementById('spawn-career-select').value;
  const data = window.INITIAL_GAME_DATA;
  if (!data) return;

  pushHistoryState();

  const relatedNodeIds = new Set();
  relatedNodeIds.add(`prof_${professionId}`);
  
  data.buildings.forEach(b => {
    if (b.profession === professionId) {
      relatedNodeIds.add(`build_${getBaseBuildingId(b.id)}`);
    }
  });

  data.recipes.forEach(r => {
    if (r.profession === professionId) {
      relatedNodeIds.add(`build_${getBaseBuildingId(r.building)}`);
      relatedNodeIds.add(`item_${r.output.id}`);
      r.inputs.forEach(inp => {
        relatedNodeIds.add(`item_${inp.id}`);
      });
    }
  });

  if (professionId === 'patreon') {
    data.items.forEach(item => {
      if (item.category === 'finished_good' && item.id.includes('ticket')) {
        relatedNodeIds.add(`item_${item.id}`);
      }
    });
  }

  const typeColumns = {
    profession: 100,
    raw_material: 420,
    building: 740,
    semi_elaborate: 1060,
    finished_good: 1380,
    equipment: 1700,
    skill_item: 2020
  };

  let addedCount = 0;
  let levelsArray = null;

  relatedNodeIds.forEach(nodeId => {
    const exists = state.nodes.find(n => n.id === nodeId);
    if (exists) return;

    let type = '';
    let refId = '';
    let name = '';
    let desc = '';
    let cost, weight, level, profession, min_price, max_price, rarity;
    levelsArray = null;

    if (nodeId.startsWith('prof_')) {
      refId = nodeId.replace('prof_', '');
      const p = data.professions.find(p => p.id === refId);
      if (!p) return;
      type = 'profession';
      name = p.name;
      desc = p.description;
    } else if (nodeId.startsWith('build_')) {
      refId = nodeId.replace('build_', '');
      const levels = data.buildings.filter(b => getBaseBuildingId(b.id) === refId);
      if (levels.length === 0) return;
      levels.sort((x, y) => x.level - y.level);

      const firstLvl = levels[0];
      type = 'building';
      name = firstLvl.name.replace(/\s+L\d+$/, '').replace(/\s+T\d+$/, '');
      desc = firstLvl.desc;
      cost = firstLvl.cost;
      level = firstLvl.level;
      profession = firstLvl.profession;
      levelsArray = levels.map(b => ({
        id: b.id,
        name: b.name,
        cost: b.cost,
        level: b.level,
        desc: b.desc,
        type: b.type,
        profession: b.profession
      }));
    } else if (nodeId.startsWith('item_')) {
      refId = nodeId.replace('item_', '');
      const item = data.items.find(i => i.id === refId);
      if (!item) return;
      type = item.category;
      name = item.name;
      desc = item.desc;
      cost = item.base_value;
      weight = item.weight;
      min_price = item.min_price;
      max_price = item.max_price;
      rarity = item.rarity;
    } else {
      return;
    }

    const x = typeColumns[type] || 420;
    const sameTypeNodes = state.nodes.filter(n => n.type === type);
    const maxY = sameTypeNodes.reduce((max, n) => Math.max(max, n.y), 0);
    const y = sameTypeNodes.length > 0 ? maxY + 140 : 100;

    const node = {
      id: nodeId,
      type,
      refId,
      name,
      desc,
      x,
      y
    };

    if (cost !== undefined) node.cost = cost;
    if (weight !== undefined) node.weight = weight;
    if (level !== undefined) node.level = level;
    if (profession !== undefined) node.profession = profession;
    if (min_price !== undefined) node.min_price = min_price;
    if (max_price !== undefined) node.max_price = max_price;
    if (rarity !== undefined) node.rarity = rarity;
    if (levelsArray) {
      node.levels = levelsArray;
      node.activeLevelIdx = 0;
    }

    state.nodes.push(node);
    state.customPositions[nodeId] = { x, y };
    addedCount++;
  });

  const defaultConns = [];
  data.buildings.forEach(b => {
    if (b.profession && b.profession !== 'any') {
      const baseBuildingId = getBaseBuildingId(b.id);
      defaultConns.push({
        id: `conn_prof_build_${baseBuildingId}`,
        from: `prof_${b.profession}`,
        to: `build_${baseBuildingId}`,
        type: 'unlock'
      });
    }
  });

  data.recipes.forEach((r, idx) => {
    const outputItemId = `item_${r.output.id}`;
    const baseBuildingId = getBaseBuildingId(r.building);
    const buildingId = `build_${baseBuildingId}`;

    defaultConns.push({
      id: `conn_recipe_out_${idx}`,
      from: buildingId,
      to: outputItemId,
      type: 'output',
      label: r.name
    });

    r.inputs.forEach((input, inIdx) => {
      const inputItemId = `item_${input.id}`;
      defaultConns.push({
        id: `conn_recipe_in_${idx}_${inIdx}`,
        from: inputItemId,
        to: buildingId,
        type: 'input',
        label: `x${input.qty}`
      });
    });
  });

  if (professionId === 'patreon') {
    data.items.forEach(item => {
      if (item.category === 'finished_good' && item.id.includes('ticket')) {
        let bId = '';
        if (item.id.includes('bathhouse') || item.id.includes('kitchen')) bId = 'patreon_inn';
        else if (item.id.includes('entertainment')) bId = 'patreon_tavern';
        else if (item.id.includes('dining')) bId = 'patreon_inn';
        
        if (bId) {
          defaultConns.push({
            id: `conn_patreon_ticket_${item.id}`,
            from: `build_${bId}`,
            to: `item_${item.id}`,
            type: 'output',
            label: 'Service'
          });
        }
      }
    });
  }

  defaultConns.forEach(conn => {
    const fromExists = state.nodes.some(n => n.id === conn.from);
    const toExists = state.nodes.some(n => n.id === conn.to);
    const connExists = state.connections.some(c => c.from === conn.from && c.to === conn.to && c.label === conn.label);

    if (fromExists && toExists && !connExists) {
      state.connections.push(conn);
    }
  });

  saveCurrentState();
  applyViewFilters();
  showNotification(`Added ${addedCount} missing nodes and their connections for the "${professionId.toUpperCase()}" career network!`, "success");
}

// --- Global Toolbar Event Handlers ---
function setupGlobalControls() {
  document.getElementById('btn-auto-layout').addEventListener('click', () => {
    pushHistoryState();
    autoLayoutCanvas();
  });
  
  document.getElementById('btn-reset-view').addEventListener('click', (e) => {
    e.stopPropagation();
    state.zoom = 0.75;
    state.panX = 100;
    state.panY = 50;
    updateCanvasTransform();
    saveCurrentState();
  });

  document.getElementById('btn-clear-canvas').addEventListener('click', (e) => {
    e.stopPropagation();
    showCustomConfirm(
      "Clear Canvas",
      "CRITICAL WARNING: This will permanently delete all nodes and connections from the screen. Proceed?",
      () => {
        pushHistoryState();
        state.nodes = [];
        state.connections = [];
        state.activeNodeId = null;
        state.selectedNodeIds = [];
        propertiesFormEl.style.display = 'none';
        noSelectionEl.style.display = 'block';
        applyViewFilters();
        saveCurrentState();
      }
    );
  });

  document.getElementById('btn-reset-defaults').addEventListener('click', (e) => {
    e.stopPropagation();
    showCustomConfirm(
      "Load Defaults",
      "Reset canvas to default game data? This will overwrite your current layout.",
      () => {
        pushHistoryState();
        loadDefaults();
      }
    );
  });

  // --- Views Navigation Engine ---
  viewModeSelect.addEventListener('change', (e) => {
    state.currentViewMode = e.target.value;
    
    drillLevelSelect.style.display = state.currentViewMode === 'canvas' ? 'block' : 'none';
    profViewSelect.style.display = state.currentViewMode === 'profession' ? 'block' : 'none';
    itemFiltersBar.style.display = state.currentViewMode === 'item' ? 'flex' : 'none';

    applyViewFilters();
  });

  drillLevelSelect.addEventListener('change', (e) => {
    state.drillLevel = e.target.value;
    applyViewFilters();
  });

  profViewSelect.addEventListener('change', (e) => {
    state.professionFilter = e.target.value;
    applyViewFilters();
  });

  filterCategory.addEventListener('change', (e) => {
    state.itemCategoryFilter = e.target.value;
    applyViewFilters();
  });
  filterType.addEventListener('change', (e) => {
    state.itemTypeFilter = e.target.value;
    applyViewFilters();
  });
  filterLevel.addEventListener('change', (e) => {
    state.itemLevelFilter = e.target.value;
    applyViewFilters();
  });

  // JSON Panel Controls
  document.getElementById('btn-copy-json').addEventListener('click', (e) => {
    e.stopPropagation();
    jsonOutputEl.select();
    navigator.clipboard.writeText(jsonOutputEl.value);
    showNotification('JSON copied to clipboard!', 'success');
  });

  document.getElementById('btn-load-json').addEventListener('click', (e) => {
    e.stopPropagation();
    try {
      pushHistoryState();
      const parsed = JSON.parse(jsonOutputEl.value);
      state.nodes = parsed.nodes || [];
      state.connections = parsed.connections || [];
      
      state.nodes.forEach(n => {
        state.customPositions[n.id] = { x: n.x, y: n.y };
      });

      applyViewFilters();
      saveCurrentState();
      showNotification('Graph layout loaded successfully!', 'success');
    } catch (err) {
      showNotification(`Invalid JSON format: ${err.message}`, 'error');
    }
  });

  document.getElementById('btn-download-json').addEventListener('click', () => {
    const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(jsonOutputEl.value);
    const downloadAnchor = document.createElement('a');
    downloadAnchor.setAttribute("href", dataStr);
    downloadAnchor.setAttribute("download", "guild_valley_relationships.json");
    document.body.appendChild(downloadAnchor);
    downloadAnchor.click();
    downloadAnchor.remove();
  });

  // Presets State saving
  document.getElementById('btn-save-preset').addEventListener('click', (e) => {
    e.stopPropagation();
    saveCurrentPreset();
  });

  // Spawning Element Presets selectors binding
  document.getElementById('spawn-category').addEventListener('change', (e) => {
    e.stopPropagation();
    populateSpawnElementDropdown();
  });
  document.getElementById('spawn-element').addEventListener('change', (e) => {
    e.stopPropagation();
    handleSpawnElementChange();
  });
  document.getElementById('btn-spawn-node').addEventListener('click', (e) => {
    e.stopPropagation();
    spawnSelectedNode();
  });
  document.getElementById('btn-spawn-career-network').addEventListener('click', (e) => {
    e.stopPropagation();
    spawnCareerNetwork();
  });
}

// --- Presets Layouts Manager Logic ---
function loadPresets() {
  const savedPresets = localStorage.getItem('guild_valley_custom_presets');
  state.presets = {};
  
  if (savedPresets) {
    try {
      state.presets = JSON.parse(savedPresets);
    } catch (e) {
      console.error("Failed to parse saved presets.", e);
    }
  }
  
  renderPresetsList();
}

function renderPresetsList() {
  const listEl = document.getElementById('presets-list');
  if (!listEl) return;
  listEl.innerHTML = '';

  // 1. Built-in default preset
  const defaultCard = document.createElement('div');
  defaultCard.className = 'catalog-card';
  defaultCard.style.padding = '8px 12px';
  defaultCard.innerHTML = `
    <div class="catalog-info">
      <h4 style="font-size:0.8rem; font-weight:600; margin:0;">Default Game Layout</h4>
      <p style="font-size:0.65rem; margin:2px 0 0 0; color:var(--text-muted);">Preloaded dataset of all systems</p>
    </div>
    <button class="btn btn-primary" id="btn-load-default-preset" style="padding:4px 8px; font-size:0.75rem;">Load</button>
  `;
  defaultCard.querySelector('#btn-load-default-preset').addEventListener('click', (e) => {
    e.stopPropagation();
    showCustomConfirm(
      "Load Default Layout",
      "Load default game layout? This will overwrite your current active canvas screen.",
      () => {
        loadDefaults();
      }
    );
  });
  listEl.appendChild(defaultCard);

  // 2. Custom Presets
  Object.keys(state.presets).forEach(name => {
    const card = document.createElement('div');
    card.className = 'catalog-card';
    card.style.padding = '8px 12px';
    card.innerHTML = `
      <div class="catalog-info" style="max-width: 65%;">
        <h4 style="font-size:0.8rem; font-weight:600; margin:0; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;" title="${name}">${name}</h4>
        <p style="font-size:0.65rem; margin:2px 0 0 0; color:var(--text-muted);">Nodes: ${state.presets[name].nodes.length}</p>
      </div>
      <div style="display:flex; gap: 4px;">
        <button class="btn btn-primary btn-load-custom" style="padding:4px 8px; font-size:0.75rem;">Load</button>
        <button class="btn btn-delete-custom" style="padding:4px 8px; font-size:0.75rem; color:#ef4444; border-color:rgba(239,68,68,0.2);">Delete</button>
      </div>
    `;

    card.querySelector('.btn-load-custom').addEventListener('click', (e) => {
      e.stopPropagation();
      showCustomConfirm(
        "Load Preset",
        `Load custom layout "${name}"? Current active canvas screen will be overwritten.`,
        () => {
          loadPresetByName(name);
        }
      );
    });

    card.querySelector('.btn-delete-custom').addEventListener('click', (e) => {
      e.stopPropagation();
      showCustomConfirm(
        "Delete Preset",
        `Permanently delete custom preset "${name}"?`,
        () => {
          deletePresetByName(name);
        }
      );
    });

    listEl.appendChild(card);
  });
}

function loadPresetByName(name) {
  const preset = state.presets[name];
  if (!preset) return;

  pushHistoryState();
  state.nodes = JSON.parse(JSON.stringify(preset.nodes));
  state.connections = JSON.parse(JSON.stringify(preset.connections));

  state.customPositions = {};
  state.nodes.forEach(n => {
    state.customPositions[n.id] = { x: n.x, y: n.y };
  });

  state.activeNodeId = null;
  state.selectedNodeIds = [];

  applyViewFilters();
  saveCurrentState();
  
  state.zoom = 0.75;
  state.panX = 100;
  state.panY = 50;
  updateCanvasTransform();
}

function deletePresetByName(name) {
  delete state.presets[name];
  localStorage.setItem('guild_valley_custom_presets', JSON.stringify(state.presets));
  renderPresetsList();
}

function saveCurrentPreset() {
  const inputEl = document.getElementById('preset-name-input');
  const name = inputEl.value.trim();
  
  if (!name) {
    showNotification("Please enter a name for the layout preset.", "warning");
    return;
  }

  const doSave = () => {
    const nodesCopy = JSON.parse(JSON.stringify(state.nodes));
    const connectionsCopy = JSON.parse(JSON.stringify(state.connections));

    state.presets[name] = {
      nodes: nodesCopy,
      connections: connectionsCopy
    };

    localStorage.setItem('guild_valley_custom_presets', JSON.stringify(state.presets));
    inputEl.value = '';
    renderPresetsList();
    showNotification(`Layout "${name}" saved successfully!`, "success");
  };

  if (state.presets[name]) {
    showCustomConfirm(
      "Preset Exists",
      `A preset named "${name}" already exists. Overwrite?`,
      doSave
    );
  } else {
    doSave();
  }
}

// --- live JSON viewer synchronization ---
function updateJsonOutput() {
  const jsonToDisplay = {
    nodes: state.nodes.map(n => {
      const customPos = state.customPositions[n.id] || { x: n.x, y: n.y };
      return {
        id: n.id,
        type: n.type,
        refId: n.refId,
        name: n.name,
        x: Math.round(customPos.x),
        y: Math.round(customPos.y),
        profession: n.profession,
        cost: n.cost,
        weight: n.weight,
        level: n.level,
        desc: n.desc,
        min_price: n.min_price,
        max_price: n.max_price,
        rarity: n.rarity
      };
    }),
    connections: state.connections.map(c => ({
      from: c.from,
      to: c.to,
      type: c.type,
      label: c.label
    }))
  };
  jsonOutputEl.value = JSON.stringify(jsonToDisplay, null, 2);
}
