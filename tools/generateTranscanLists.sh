#!/bin/bash
# Script to generate list files from Transcan directory
# Format: Filename=URL *Size=0 MB

SOURCE_DIR="./Transcan"
DEST_DIR=".."

#rm -f "$DEST_DIR/*_transcan*.txt"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Directory $SOURCE_DIR does not exist."
    exit 1
fi

sanitize_name() {
    echo "$1" | tr -cd '[:alnum:]'
}

encodeUrl(){
    echo "$1" | sed 's/ /%20/g' | sed 's/(/%28/g' | sed 's/)/%29/g' | sed "s/'/%27/g" | sed "s/,/%2C/g"
}

find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d | sort | while read -r system_path; do
    system_name=$(basename "$system_path")
    root_output_file="$DEST_DIR/${system_name}_transcan.txt"
    # We will append to root file, so ensure it starts empty if we are going to use it
    # But strictly we should only create it if we have content? 
    # Let's truncate it first, we can check size later or just leave it.
    : > "$root_output_file"
    root_has_content=false
    
    # 1. Process files directly in the system folder
    find "$system_path" -maxdepth 1 -type f | sort | while read -r filepath; do
        filename=$(basename "$filepath")
        read -r url < "$filepath"
        if [ -n "$url" ]; then
            url=$(encodeUrl "${url}")
            echo "${filename}=${url} *Size=0 MB" >> "$root_output_file"
            root_has_content=true
        fi
    done
    
    # 2. Iterate over subdirectories
    find "$system_path" -mindepth 1 -maxdepth 1 -type d | sort | while read -r sub_path; do
        sub_name=$(basename "$sub_path")
        
        # SKIP if ends with .m3u
        if [[ "$sub_name" == *.m3u ]]; then
             continue
        fi
        
        # Check if it starts with hyphen "-"
        if [[ "$sub_name" == -* ]]; then
            # It IS a subfolder -> distinct file
            clean_sub_name=$(sanitize_name "$sub_name")
            sub_output_file="$DEST_DIR/${system_name}_transcan_${clean_sub_name}.txt"
            
            # echo "Processing subfolder (distinct) $system_name/$sub_name -> $(basename "$sub_output_file")"
            : > "$sub_output_file"
            
            count_sub=$(find "$sub_path" -maxdepth 1 -type f | wc -l)
            if [ "$count_sub" -gt 0 ]; then
                find "$sub_path" -maxdepth 1 -type f | sort | while read -r filepath; do
                    filename=$(basename "$filepath")
                    read -r url < "$filepath"
                    if [ -n "$url" ]; then
                        url=$(encodeUrl "${url}")
                        echo "${filename}=${url} *Size=0 MB" >> "$sub_output_file"
                    fi
                done
            else
                rm "$sub_output_file"
            fi
            
        else
            # It is NOT a subfolder (no dash) -> Merge into main platform file
            # echo "Processing subfolder (merge) $system_name/$sub_name -> $(basename "$root_output_file")"
            
            find "$sub_path" -maxdepth 1 -type f | sort | while read -r filepath; do
                filename=$(basename "$filepath")
                read -r url < "$filepath"
                if [ -n "$url" ]; then
                     url=$(encodeUrl "${url}")
                     echo "${filename}=${url} *Size=0 MB" >> "$root_output_file"
                     root_has_content=true
                fi
            done
        fi
    done
    
    if [ ! -s "$root_output_file" ]; then
        rm "$root_output_file"
    else
        echo "Generated: $(basename "$root_output_file")"
    fi
done

echo "Done. Files generated in $DEST_DIR"
