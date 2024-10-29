#!/bin/bash

# Check if directory argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Directory to search
DIR="$1"

# Function to process Java files and compile/run them
process_java_files() {
    local java_files=("$@")

    for file in "${java_files[@]}"; do
        echo -e "\e[1;33mSource Code: $(basename "$file")\e[0m"
        
        # Format the code with Astyle
        astyle --style=java "$file" > /dev/null
        
        # Display the formatted code
        highlight -s vampire "$file"
        echo
    done

    # Compile all Java files together to resolve dependencies
    javac "${java_files[@]}" 2> errors.log

    if [ $? -ne 0 ]; then
        echo -e "\e[1;31mCompilation failed.\e[0m"
        cat errors.log
        prompt_for_next
        return 1
    fi

    echo -e "\e[1;32mCompilation succeeded!\e[0m"

    # Find the class with the main method to run it
    main_class=$(grep -l 'public static void main' "${java_files[@]}" | head -n 1 | xargs -n 1 basename | sed 's/.java$//')

    if [ -z "$main_class" ]; then
        echo "No main method found in any class. Skipping execution."
    else
        run_main_method "$main_class" "$(dirname "${java_files[0]}")"
    fi
}

# Function to run the main method and allow re-runs
run_main_method() {
    local main_class="$1"
    local class_dir="$2"

    while true; do
        echo -e "\e[1;34mRunning: $main_class\e[0m"
        (cd "$class_dir" && java "$main_class")

        read -p "Press 'r' to rerun or Enter to continue to the next student: " choice
        if [ "$choice" != "r" ]; then
            break
        fi
    done
}

# Function to prompt for continuation
prompt_for_next() {
    read -p "Press Enter to continue to the next student..."
    echo
    echo -e "\e[1;31m---------------------------------------------------------\e[0m"
    echo
}

# Check for zip files and process them
zip_files=("$DIR"/*.zip)
if [ -e "${zip_files[0]}" ]; then
    for zip_file in "${zip_files[@]}"; do
        student_name=$(basename "$zip_file" | cut -d'_' -f2)
        echo "Processing student: $student_name"
        echo

        temp_dir=$(mktemp -d)
        unzip "$zip_file" -d "$temp_dir" > /dev/null

        src_dir=$(find "$temp_dir" -type d -name "src" -print -quit)
        src_dir=${src_dir:-$temp_dir}

        java_files=("$src_dir"/*.java)
        if [ -e "${java_files[0]}" ]; then
            process_java_files "${java_files[@]}"
        else
            echo "No Java files found in $zip_file."
        fi

        rm -rf "$temp_dir"
        prompt_for_next
    done
else
    # If no zip files are found, search for Java files directly
    java_files=("$DIR"/*.java)
    if [ -e "${java_files[0]}" ]; then
        echo "No zip files found. Processing Java files directly from $DIR..."
        process_java_files "${java_files[@]}"
    else
        echo "No zip or Java files found in the directory."
        exit 1
    fi
fi
