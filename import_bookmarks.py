import json
import os

def build_tree(lines):
    tree = {"roots": {"bookmark_bar": {"children": [], "type": "folder", "name": "bookmark_bar"},
                      "other": {"children": [], "type": "folder", "name": "other"},
                      "synced": {"children": [], "type": "folder", "name": "synced"}}}
    folders = {}

    for line in lines:
        parts = line.strip().split(", ")
        type_path = parts[0].split(": ")
        type_ = type_path[0]
        path = type_path[1]
        attributes = {kv.split("=")[0]: kv.split("=")[1] for kv in parts[1:]}
        
        if type_ == "folder":
            folders[path] = {"type": "folder", "name": path.split("/")[-1], "children": [], **attributes}
        elif type_ == "url":
            bookmark = {"type": "url", "name": attributes["name"], "url": attributes["url"], **{k: v for k, v in attributes.items() if k not in ["name", "url"]}}
            parent_path = "/".join(path.split("/")[:-1])
            if parent_path in folders:
                folders[parent_path]["children"].append(bookmark)
            else:
                root = path.split("/")[0]
                if root in tree["roots"]:
                    tree["roots"][root]["children"].append(bookmark)
    
    # Build the tree structure
    for path in sorted(folders.keys(), key=lambda p: len(p.split("/"))):
        parts = path.split("/")
        if len(parts) == 1:
            tree["roots"][parts[0]] = folders[path]
        else:
            parent_path = "/".join(parts[:-1])
            if parent_path in folders:
                folders[parent_path]["children"].append(folders[path])
    
    return tree

def import_bookmarks(txt_file, jsonmeantime(json_file):
    with open(txt_file, "r") as f:
        lines = f.readlines()
    
    tree = build_tree(lines)
    
    with open(json_file, "w") as f:
        json.dump(tree, f, indent=2)

# Usage
import_bookmarks("bookmarks.txt", os.path.expanduser("~/.chromium/Profile 5/Bookmarks"))
