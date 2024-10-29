#!/bin/bash

# Check if directory argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Directory containing the zip files
DIR="$1"

# Loop through all .zip files in the directory
for zip_file in "$DIR"/*.zip; do
    # Extract the student's name from the zip filename
    student_name=$(basename "$zip_file" | cut -d'_' -f2)
    
    echo "Processing student: $student_name"
    echo

    # Create a temporary directory to extract the zip file
    temp_dir=$(mktemp -d)

    # Unzip the file into the temporary directory
    unzip "$zip_file" -d "$temp_dir" > /dev/null

    # Try to find the 'src' directory or use the root directory if not found
    src_dir=$(find "$temp_dir" -type d -name "src" -print -quit)
    src_dir=${src_dir:-$temp_dir}
    
    for file in "$src_dir"/*.java; do
        echo -e "\e[1;33mSource Code: $(basename "$file")\e[0m"
        highlight -s vampire "$file"
        echo
    done
	
    # Compile all Java files together to resolve dependencies
    javac "$src_dir"/*.java 2> errors.log

    if [ $? -ne 0 ]; then
        echo -e "\e[1;31mCompilation failed for student: $student_name\e[0m"
        cat errors.log
        rm -rf "$temp_dir"
        read -p "Press Enter to continue to the next student..."
        echo
        echo -e "\e[1;31m---------------------------------------------------------\e[0m"
        echo
        continue
    fi

    echo -e "\e[1;32mCompilation succeeded for student: $student_name\e[0m"

    # Find the class with the main method to run it
    main_class=$(grep -l 'public static void main' "$src_dir"/*.java | head -n 1 | xargs -n 1 basename | sed 's/.java$//')

    if [ -z "$main_class" ]; then
        echo "No main method found in any class. Skipping execution."
    else
        echo -e "\e[1;34mRunning: $main_class\e[0m"
        (cd "$src_dir" && java "$main_class")
    fi

    # Clean up the temporary directory
    rm -rf "$temp_dir"

    # Wait for user input to proceed to the next student
    read -p "Press Enter to continue to the next student..."
    echo
    echo -e "\e[1;31m---------------------------------------------------------\e[0m"
    echo
done
