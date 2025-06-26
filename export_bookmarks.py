import json
import os

def flatten_bookmarks(node, path="", output=[]):
    if node["type"] == "folder":
        current_path = f"{path}/{node['name']}" if path else node["name"]
        output.append(f"folder: {current_path}, guid={node['guid']}, date_added={node['date_added']}, date_modified={node['date_modified']}")
        for child in node.get("children", []):
            flatten_bookmarks(child, current_path, output)
    elif node["type"] == "url":
        current_path = f"{path}/{node['name']}"
        output.append(f"url: {current_path}, name={node['name']}, url={node['url']}, guid={node['guid']}, date_added={node['date_added']}, date_modified={node['date_modified']}")

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
