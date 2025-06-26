import json
import os

def flatten_bookmarks(node, path, output):
    current_path = f"{path}/{node['name']}" if path else node["name"]
    if node["type"] == "folder":
        # For folders, include all attributes except 'type', 'children', and 'name'
        attrs = [f"{key}={value}" for key, value in node.items() if key not in ["type", "children", "name"]]
        output.append(f"folder: {current_path}, " + ", ".join(attrs))
        for child in node.get("children", []):
            flatten_bookmarks(child, current_path, output)
    elif node["type"] == "url":
        # For URLs, include all attributes except 'type'
        attrs = [f"{key}={value}" for key, value in node.items() if key not in ["type"]]
        output.append(f"url: {current_path}, " + ", ".join(attrs))

def export_bookmarks(json_file, txt_file):
    with open(json_file, "r") as f:
        data = json.load(f)
    
    output = []
    for root in ["bookmark_bar", "other", "synced"]:
        if root in data["roots"]:
            flatten_bookmarks(data["roots"][root], "", output)
    
    # Sort the output for consistency
    output.sort()
    
    with open(txt_file, "w") as f:
        for line in output:
            f.write(line + "\n")

# Usage
export_bookmarks(os.path.expanduser("~/.config/chromium/Profile 1/Bookmarks"), "bookmarks.txt")
