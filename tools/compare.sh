#!/bin/bash
# Get the directory of this script to ensure we use relative paths correctly
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd "$SCRIPT_DIR" || exit 1
rm Transcan/*/systeminfo.txt
# Using embedded Python for robust string/URL handling
python3 - <<EOF
import os
import urllib.parse
import sys
import re

# Define directories relative to the script location
TRANS_DIR = "Transcan"
ROMLISTS_DIR = ".."

def normalize_url(url):
    """
    Decodes URL encoding (e.g., %20 -> space), strips whitespace,
    removes http:// or https:// protocol, and converts to lowercase.
    """
    if not url:
        return ""
    # Decode first
    u = urllib.parse.unquote(url).strip()
    # Remove protocol (http:// or https://)
    u = re.sub(r'^https?://', '', u, flags=re.IGNORECASE)
    # Lowercase to handle case differences
    return u.lower()

def normalize_filename(fname):
    """
    Normalizes filename for comparison (lowercase).
    """
    return fname.strip().lower()

def get_matching_romlists(system_name, all_romfiles):
    """
    Returns a list of romlist filenames that belong to the system.
    Matches:
      - {system_name}.txt
      - {system_name}_*.txt
    Does NOT match:
      - {system_name}cd.txt (e.g. pcengine vs pcenginecd)
    """
    matches = []
    prefix_underscore = f"{system_name}_"
    exact_match = f"{system_name}.txt"
    
    for fname in all_romfiles:
        if fname == exact_match:
            matches.append(fname)
        elif fname.startswith(prefix_underscore) and fname.endswith(".txt"):
            matches.append(fname)
    return matches

def main():
    if not os.path.exists(TRANS_DIR):
        print(f"Directory {TRANS_DIR} not found in {os.getcwd()}")
        return
        
    if not os.path.exists(ROMLISTS_DIR):
        print(f"Directory {ROMLISTS_DIR} not found in {os.getcwd()}")
        return

    # Cache all romlist filenames to avoid repeated listdir calls
    all_romfiles = [f for f in os.listdir(ROMLISTS_DIR) if f.endswith(".txt")]

    # Iterate over each system folder in Transcan
    for system_name in sorted(os.listdir(TRANS_DIR)): 
        system_path = os.path.join(TRANS_DIR, system_name)
        
        if not os.path.isdir(system_path):
            continue

        # Find all corresponding romlist files
        matching_files = get_matching_romlists(system_name, all_romfiles)
        
        if not matching_files:
            print(f"Processing system: {system_name} - No matching romlists found. Skipping.")
            continue
            
        print(f"Processing system: {system_name}")
        
        # Load URLs AND Filenames from ALL matching romlists
        romlist_urls = set()
        romlist_filenames = set()
        
        for r_file in matching_files:
            romlist_path = os.path.join(ROMLISTS_DIR, r_file)
            try:
                with open(romlist_path, 'r', encoding='utf-8') as rf:
                    for line in rf:
                        line = line.strip()
                        if not line or '=' not in line:
                            continue
                        
                        parts = line.split('=', 1)
                        if len(parts) < 2:
                            continue
                            
                        # Format: Filename=URL *Size=...
                        fname_part = parts[0]
                        url_part = parts[1]
                        
                        # Store normalized filename
                        romlist_filenames.add(normalize_filename(fname_part))
                        
                        # Strip *Size=... suffix if present
                        if " *Size=" in url_part:
                            url_part = url_part.split(" *Size=")[0]
                        
                        norm_url = normalize_url(url_part)
                        if norm_url:
                            romlist_urls.add(norm_url)
            except Exception as e:
                print(f"  Error reading {r_file}: {e}")

        # Now check every file in the Transcan system folder recursively
        deleted_count = 0
        checked_count = 0
        
        # Use os.walk for recursion
        for root, dirs, files in os.walk(system_path):
            for fname in files:
                fpath = os.path.join(root, fname)
                
                checked_count += 1
                
                is_duplicate = False
                
                # Check 1: Filename Match
                # We compare the file's name on disk with the filenames in romlist
                if normalize_filename(fname) in romlist_filenames:
                    is_duplicate = True
                
                # Check 2: URL Match (only if not already matched)
                if not is_duplicate:
                    try:
                        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                            content = f.read()
                        
                        file_url = normalize_url(content)
                        if file_url in romlist_urls:
                            is_duplicate = True
                    except Exception as e:
                        print(f"  Error processing content of {fname}: {e}")
                
                if is_duplicate:
                    try:
                        os.remove(fpath)
                        deleted_count += 1
                        # print(f"  Deleted duplicate: {fname}")
                    except OSError as e:
                        print(f"  Failed to delete {fname}: {e}")

        print(f"  Checked {checked_count} file(s). Deleted {deleted_count} duplicates.")

if __name__ == "__main__":
    main()
EOF
