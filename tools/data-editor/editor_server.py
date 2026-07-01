#!/usr/bin/env python3
import os
import sys
import json
import traceback
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, unquote

# Set up paths relative to this script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# Workspace root is two levels up from tools/data-editor/
WORKSPACE_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))

ITEMS_DIR = os.path.join(WORKSPACE_ROOT, 'common', 'items', 'instances')
LAWS_DIR = os.path.join(WORKSPACE_ROOT, 'common', 'politics', 'laws')

QUESTS_FILE = os.path.join(WORKSPACE_ROOT, 'common', 'quests', 'quests.json')
PROSPERITY_FILE = os.path.join(WORKSPACE_ROOT, 'common', 'singletons', 'prosperity_config.json')
BALANCE_FILE = os.path.join(WORKSPACE_ROOT, 'common', 'singletons', 'game_balance_config.json')
NPCS_FILE = os.path.join(WORKSPACE_ROOT, 'common', 'npc', 'npcs.json')
DIALOGUES_FILE = os.path.join(WORKSPACE_ROOT, 'common', 'narrative', 'dialogues.json')
TRAITS_FILE = os.path.join(WORKSPACE_ROOT, 'common', 'narrative', 'traits.json')

# Default properties from item_data.gd
DEFAULT_PROPERTIES = {
    "item_category_override": -1,
    "rarity_override": -1,
    "target_stock_override": -1,
    "price_elasticity_override": -1.0,
    "id": "",
    "item_level": 1,
    "name": "",
    "base_value": 10,
    "min_price": 1,
    "max_price": 999,
    "weight": 0.5,
    "category": "Resource",
    "market_category": "Raw Materials",
    "item_type": "Raw Material",
    "equipment_slot": "None",
    "armor_stat": 0,
    "attack_stat": 0,
    "speed_bonus": 0.0,
    "capacity_bonus": 0,
    "gathering_multiplier_bonus": 0.0,
    "durability": 100,
    "max_durability": 100,
    "is_tool": False,
    "is_tradable": True,
    "is_stackable": True,
    "max_stack": 20,
    "is_luxury_product": False,
    "is_raw_material": False,
    "description": ""
}

# Default properties from law_resource.gd
DEFAULT_LAW_PROPERTIES = {
    "id": "",
    "name": "",
    "description": "",
    "category": "Numerical",
    "influence_cost": 150,
    "value_type": "",
    "effect_value": 0.0
}

def val_to_py(val_str):
    val_str = val_str.strip()
    if val_str == 'true':
        return True
    if val_str == 'false':
        return False
    if val_str.startswith('"') and val_str.endswith('"'):
        # String: strip quotes and replace escapes
        inner = val_str[1:-1]
        return inner.replace('\\"', '"').replace('\\n', '\n')
    # Try int
    try:
        return int(val_str)
    except ValueError:
        pass
    # Try float
    try:
        return float(val_str)
    except ValueError:
        pass
    return val_str

def py_to_val(val):
    if isinstance(val, bool):
        return 'true' if val else 'false'
    if isinstance(val, int):
        return str(val)
    if isinstance(val, float):
        return str(val)
    if isinstance(val, str):
        if val.startswith('ExtResource(') or val.startswith('SubResource('):
            return val
        escaped = val.replace('"', '\\"').replace('\n', '\\n')
        return f'"{escaped}"'
    return str(val)

def parse_tres(filepath):
    """
    Parses a Godot .tres resource file.
    Returns (header_string, properties_dict).
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find where the [resource] starts
    parts = content.split('[resource]\n')
    if len(parts) < 2:
        parts = content.split('[resource]\r\n')
    
    if len(parts) < 2:
        raise ValueError(f"No [resource] block found in {filepath}")
    
    header = parts[0] + '[resource]\n'
    body = parts[1]
    
    properties = {}
    lines = body.splitlines()
    i = 0
    in_string = False
    current_key = None
    current_val_lines = []
    
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped:
            i += 1
            continue
        
        if not in_string:
            if '=' in line:
                key, val = line.split('=', 1)
                key = key.strip()
                val = val.strip()
                
                # Check if this begins a multiline string
                if val.startswith('"') and (not val.endswith('"') or val == '"' or (val.endswith('"') and val.count('"') % 2 != 0)):
                    in_string = True
                    current_key = key
                    current_val_lines = [val]
                else:
                    properties[key] = val_to_py(val)
            else:
                pass
        else:
            current_val_lines.append(line)
            accumulated = '\n'.join(current_val_lines)
            
            # Count unescaped double quotes in accumulated
            quote_count = 0
            escaped = False
            for char in accumulated:
                if char == '\\':
                    escaped = not escaped
                elif char == '"':
                    if not escaped:
                        quote_count += 1
                    escaped = False
                else:
                    escaped = False
            
            if quote_count % 2 == 0:
                properties[current_key] = val_to_py(accumulated)
                in_string = False
                current_key = None
                current_val_lines = []
        i += 1
        
    return header, properties

def serialize_tres(filepath, updated_props):
    """
    Reads filepath, updates modified key-values, and returns the full string to write.
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    parts = content.split('[resource]\n')
    if len(parts) < 2:
        parts = content.split('[resource]\r\n')
    
    header = parts[0] + '[resource]\n'
    body = parts[1]
    
    body_lines = body.splitlines()
    key_ranges = {} # key -> (start_idx, end_idx)
    i = 0
    in_string = False
    current_key = None
    current_start = -1
    current_val_lines = []
    
    while i < len(body_lines):
        line = body_lines[i]
        stripped = line.strip()
        if not stripped:
            i += 1
            continue
        
        if not in_string:
            if '=' in line:
                key, val = line.split('=', 1)
                key = key.strip()
                val = val.strip()
                current_start = i
                if val.startswith('"') and (not val.endswith('"') or val == '"' or (val.endswith('"') and val.count('"') % 2 != 0)):
                    in_string = True
                    current_key = key
                    current_val_lines = [val]
                else:
                    key_ranges[key] = (i, i)
            else:
                pass
        else:
            current_val_lines.append(line)
            accumulated = '\n'.join(current_val_lines)
            quote_count = 0
            escaped = False
            for char in accumulated:
                if char == '\\':
                    escaped = not escaped
                elif char == '"':
                    if not escaped:
                        quote_count += 1
                    escaped = False
                else:
                    escaped = False
            
            if quote_count % 2 == 0:
                key_ranges[current_key] = (current_start, i)
                in_string = False
                current_key = None
                current_val_lines = []
        i += 1
        
    output_body_lines = []
    used_keys = set()
    i = 0
    while i < len(body_lines):
        found_key = None
        for key, (start, end) in key_ranges.items():
            if start == i:
                found_key = key
                break
        
        if found_key:
            start, end = key_ranges[found_key]
            i = end + 1
            used_keys.add(found_key)
            
            if found_key in updated_props:
                val_str = py_to_val(updated_props[found_key])
                output_body_lines.append(f"{found_key} = {val_str}")
            else:
                # Retain original lines
                for idx in range(start, end + 1):
                    output_body_lines.append(body_lines[idx])
        else:
            output_body_lines.append(body_lines[i])
            i += 1
            
    # Append keys that were not in the file originally
    for key, value in updated_props.items():
        if key not in used_keys:
            val_str = py_to_val(value)
            output_body_lines.append(f"{key} = {val_str}")
            
    return header + '\n'.join(output_body_lines) + '\n'

class DataEditorRequestHandler(BaseHTTPRequestHandler):
    def end_headers(self):
        # Enable CORS just in case
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        parsed_url = urlparse(self.path)
        path = parsed_url.path

        if path == '/api/items':
            self.handle_get_items()
        elif path == '/api/laws':
            self.handle_get_laws()
        elif path == '/api/quests':
            self.handle_get_json_file(QUESTS_FILE)
        elif path == '/api/prosperity':
            self.handle_get_json_file(PROSPERITY_FILE)
        elif path == '/api/balance':
            self.handle_get_json_file(BALANCE_FILE)
        elif path == '/api/npcs':
            self.handle_get_json_file(NPCS_FILE)
        elif path == '/api/dialogues':
            self.handle_get_json_file(DIALOGUES_FILE)
        elif path == '/api/traits':
            self.handle_get_json_file(TRAITS_FILE)
        elif path == '/' or path == '/index.html':
            self.serve_static_file('index.html', 'text/html')
        else:
            # Check if serving from tools/data-editor/
            relative_file = path.lstrip('/')
            file_path = os.path.join(SCRIPT_DIR, relative_file)
            if os.path.exists(file_path) and os.path.isfile(file_path) and file_path.startswith(SCRIPT_DIR):
                ext = os.path.splitext(file_path)[1]
                mime = 'text/plain'
                if ext == '.html': mime = 'text/html'
                elif ext == '.css': mime = 'text/css'
                elif ext == '.js': mime = 'application/javascript'
                elif ext == '.png': mime = 'image/png'
                elif ext == '.jpg' or ext == '.jpeg': mime = 'image/jpeg'
                elif ext == '.svg': mime = 'image/svg+xml'
                self.serve_static_file(relative_file, mime)
            else:
                self.send_error(404, "File not found")

    def do_POST(self):
        parsed_url = urlparse(self.path)
        path = parsed_url.path

        if path == '/api/items/save':
            self.handle_save_items()
        elif path == '/api/laws/save':
            self.handle_save_laws()
        elif path == '/api/quests/save':
            self.handle_save_json_file(QUESTS_FILE)
        elif path == '/api/prosperity/save':
            self.handle_save_json_file(PROSPERITY_FILE)
        elif path == '/api/balance/save':
            self.handle_save_json_file(BALANCE_FILE)
        elif path == '/api/npcs/save':
            self.handle_save_json_file(NPCS_FILE)
        elif path == '/api/dialogues/save':
            self.handle_save_json_file(DIALOGUES_FILE)
        elif path == '/api/traits/save':
            self.handle_save_json_file(TRAITS_FILE)
        else:
            self.send_error(404, "Endpoint not found")

    def serve_static_file(self, rel_path, content_type):
        try:
            full_path = os.path.join(SCRIPT_DIR, rel_path)
            with open(full_path, 'rb') as f:
                content = f.read()
            self.send_response(200)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', len(content))
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self.send_error(500, f"Error reading file: {str(e)}")

    def handle_get_json_file(self, filepath):
        try:
            if not os.path.exists(filepath):
                if filepath.endswith('dialogues.json') or filepath.endswith('traits.json'):
                    os.makedirs(os.path.dirname(filepath), exist_ok=True)
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write('{}')
                else:
                    self.send_error(404, f"File not found: {filepath}")
                    return
            with open(filepath, 'rb') as f:
                content = f.read()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(content))
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            traceback.print_exc()
            self.send_error(500, f"Error reading config: {str(e)}")

    def handle_save_json_file(self, filepath):
        try:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            # Validate JSON
            parsed = json.loads(post_data.decode('utf-8'))
            
            # Write JSON back formatted neatly
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(parsed, f, indent=2)
                
            response_data = json.dumps({"success": True}).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response_data))
            self.end_headers()
            self.wfile.write(response_data)
        except Exception as e:
            traceback.print_exc()
            self.send_error(500, f"Error saving config: {str(e)}")

    def handle_get_items(self):
        try:
            items = []
            if not os.path.exists(ITEMS_DIR):
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps([]).encode('utf-8'))
                return

            for root, dirs, files in os.walk(ITEMS_DIR):
                for file in files:
                    if file.endswith('.tres'):
                        full_path = os.path.join(root, file)
                        rel_path = os.path.relpath(full_path, WORKSPACE_ROOT)
                        try:
                            _, raw_props = parse_tres(full_path)
                            
                            # Merge parsed properties with DEFAULT_PROPERTIES to represent full object
                            merged_props = {}
                            for k, v in DEFAULT_PROPERTIES.items():
                                merged_props[k] = raw_props.get(k, v)
                            
                            # Keep any extra fields in raw_props (e.g. equipment specific stats)
                            for k, v in raw_props.items():
                                if k not in merged_props:
                                    merged_props[k] = v
                                    
                            # Inject path metadata
                            merged_props['_filepath'] = rel_path
                            items.append(merged_props)
                        except Exception as parse_err:
                            print(f"Error parsing {full_path}: {parse_err}")

            # Sort by name
            items.sort(key=lambda x: x.get('name', '').lower() or x.get('id', '').lower())
            
            response_data = json.dumps(items).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response_data))
            self.end_headers()
            self.wfile.write(response_data)
        except Exception as e:
            traceback.print_exc()
            self.send_error(500, f"Internal Server Error: {str(e)}")

    def handle_save_items(self):
        try:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            payload = json.loads(post_data.decode('utf-8'))
            
            results = []
            for item_update in payload:
                rel_path = item_update.get('_filepath')
                updates = item_update.get('updates', {})
                
                if not rel_path:
                    continue
                
                # Security checks
                target_path = os.path.abspath(os.path.join(WORKSPACE_ROOT, rel_path))
                if not target_path.startswith(ITEMS_DIR):
                    self.send_error(403, f"Access denied: {rel_path} is outside items directory.")
                    return
                if not target_path.endswith('.tres'):
                    self.send_error(400, f"Invalid file format: {rel_path}")
                    return
                if not os.path.exists(target_path):
                    self.send_error(404, f"File not found: {rel_path}")
                    return
                
                _, current_props = parse_tres(target_path)
                
                # Merge updates
                updated_props = dict(current_props)
                for k, v in updates.items():
                    if k in DEFAULT_PROPERTIES:
                        expected_type = type(DEFAULT_PROPERTIES[k])
                        if expected_type == bool:
                            updated_props[k] = bool(v)
                        elif expected_type == int:
                            updated_props[k] = int(v)
                        elif expected_type == float:
                            updated_props[k] = float(v)
                        else:
                            updated_props[k] = str(v)
                    else:
                        updated_props[k] = v
                
                new_tres_content = serialize_tres(target_path, updated_props)
                
                # Save to disk
                with open(target_path, 'w', encoding='utf-8') as f:
                    f.write(new_tres_content)
                
                results.append({"_filepath": rel_path, "status": "saved"})
                
            response_data = json.dumps({"success": True, "results": results}).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response_data))
            self.end_headers()
            self.wfile.write(response_data)
            
        except Exception as e:
            traceback.print_exc()
            self.send_error(500, f"Internal Server Error: {str(e)}")

    def handle_get_laws(self):
        try:
            laws = []
            if not os.path.exists(LAWS_DIR):
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps([]).encode('utf-8'))
                return

            for root, dirs, files in os.walk(LAWS_DIR):
                for file in files:
                    if file.endswith('.tres'):
                        full_path = os.path.join(root, file)
                        rel_path = os.path.relpath(full_path, WORKSPACE_ROOT)
                        try:
                            _, raw_props = parse_tres(full_path)
                            
                            merged_props = {}
                            for k, v in DEFAULT_LAW_PROPERTIES.items():
                                merged_props[k] = raw_props.get(k, v)
                            
                            for k, v in raw_props.items():
                                if k not in merged_props:
                                    merged_props[k] = v
                                    
                            merged_props['_filepath'] = rel_path
                            laws.append(merged_props)
                        except Exception as parse_err:
                            print(f"Error parsing law {full_path}: {parse_err}")

            # Sort by name
            laws.sort(key=lambda x: x.get('name', '').lower() or x.get('id', '').lower())
            
            response_data = json.dumps(laws).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response_data))
            self.end_headers()
            self.wfile.write(response_data)
        except Exception as e:
            traceback.print_exc()
            self.send_error(500, f"Internal Server Error: {str(e)}")

    def handle_save_laws(self):
        try:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            payload = json.loads(post_data.decode('utf-8'))
            
            results = []
            for law_update in payload:
                rel_path = law_update.get('_filepath')
                updates = law_update.get('updates', {})
                
                if not rel_path:
                    continue
                
                # Security checks
                target_path = os.path.abspath(os.path.join(WORKSPACE_ROOT, rel_path))
                if not target_path.startswith(LAWS_DIR):
                    self.send_error(403, f"Access denied: {rel_path} is outside laws directory.")
                    return
                if not target_path.endswith('.tres'):
                    self.send_error(400, f"Invalid file format: {rel_path}")
                    return
                if not os.path.exists(target_path):
                    self.send_error(404, f"File not found: {rel_path}")
                    return
                
                _, current_props = parse_tres(target_path)
                
                # Merge updates
                updated_props = dict(current_props)
                for k, v in updates.items():
                    if k in DEFAULT_LAW_PROPERTIES:
                        expected_type = type(DEFAULT_LAW_PROPERTIES[k])
                        if expected_type == bool:
                            updated_props[k] = bool(v)
                        elif expected_type == int:
                            updated_props[k] = int(v)
                        elif expected_type == float:
                            updated_props[k] = float(v)
                        else:
                            updated_props[k] = str(v)
                    else:
                        updated_props[k] = v
                
                new_tres_content = serialize_tres(target_path, updated_props)
                
                # Save to disk
                with open(target_path, 'w', encoding='utf-8') as f:
                    f.write(new_tres_content)
                
                results.append({"_filepath": rel_path, "status": "saved"})
                
            response_data = json.dumps({"success": True, "results": results}).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response_data))
            self.end_headers()
            self.wfile.write(response_data)
            
        except Exception as e:
            traceback.print_exc()
            self.send_error(500, f"Internal Server Error: {str(e)}")

def run(port=8000):
    server_address = ('', port)
    httpd = HTTPServer(server_address, DataEditorRequestHandler)
    print(f"Game Data Editor Server running on port {port}...")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()

if __name__ == '__main__':
    port = 8000
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass
    run(port)
