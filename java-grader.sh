#!/bin/bash

# Check if directory argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Directory to search
DIR="$1"

# Ensure we have Bash version 4 or higher for associative arrays
if (( ${BASH_VERSION%%.*} < 4 )); then
    echo "This script requires Bash version 4 or higher."
    exit 1
fi

# Function to process student files and compile/run them
process_student_files() {
    local student_name="$1"
    shift
    local all_files=("$@")
    local java_files=()
    local txt_files=()
    local renamed_files=()

    # Separate .java and .txt files
    for file in "${all_files[@]}"; do
        if [[ "$file" == *.java ]]; then
            java_files+=("$file")
        elif [[ "$file" == *.txt ]]; then
            txt_files+=("$file")
        fi
    done

    if [ ${#java_files[@]} -eq 0 ]; then
        echo "No valid Java files found to process for student: $student_name."
        return 1
    fi

    echo -e "\e[1;31mProcessing student: $student_name\e[0m"
    echo

    for file in "${java_files[@]}"; do
        if [ -f "$file" ]; then
            # Extract the public class name from the Java file
            class_name=$(grep -E 'public class [A-Za-z_][A-Za-z0-9_]*' "$file" | head -n 1 | awk '{print $3}' | tr -d '{')
            if [ -n "$class_name" ]; then
                # Rename the file to match the public class name
                new_filename="$(dirname "$file")/$class_name.java"
                if [ "$file" != "$new_filename" ]; then
                    mv "$file" "$new_filename"
                    file="$new_filename"
                fi
                # Update the list of files to compile
                renamed_files+=("$file")
            else
                # If no public class is found, keep the original filename
                renamed_files+=("$file")
            fi

            echo -e "\e[1;33mSource Code: $(basename "$file")\e[0m"

            # Format the code with Astyle
            astyle --style=java "$file" > /dev/null

            # Display the formatted code
            highlight -s vampire "$file" || echo "Highlight failed for $file"

            echo
        else
            echo "Skipping non-file entry: $file"
        fi
    done

    # Copy .txt files to the directory where the Java program will run
    for txt_file in "${txt_files[@]}"; do
        if [ -f "$txt_file" ]; then
            cp "$txt_file" "$(dirname "${renamed_files[0]}")"
        fi
    done

    # Compile the Java files
    javac "${renamed_files[@]}" 2> errors.log

    if [ $? -ne 0 ]; then
        echo -e "\e[1;31mCompilation failed for student: $student_name.\e[0m"
        cat errors.log

        prompt_for_next
        return 1
    fi

    echo -e "\e[1;32mCompilation succeeded for student: $student_name!\e[0m"

    # Find the class with the main method to run it
    main_class_file=$(grep -l 'public static void main' "${renamed_files[@]}" | head -n 1)
    if [ -z "$main_class_file" ]; then
        echo "No main method found in any class for student: $student_name. Skipping execution."
    else
        main_class_name=$(basename "$main_class_file" .java)
        run_main_method "$main_class_name" "$(dirname "$main_class_file")" "$student_name"
    fi

    prompt_for_next
}

# Function to run the main method and allow re-runs
run_main_method() {
    local main_class="$1"
    local class_dir="$2"
    local student_name="$3"

    while true; do
        echo -e "\e[1;34mRunning: $main_class for student: $student_name\e[0m"
        (cd "$class_dir" && java "$main_class")

        read -p "Press 'r' to rerun, Enter to continue to the next student: " choice
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

# Main processing
process_submissions() {
    # Check for zip files and process them
    zip_files=("$DIR"/*.zip)

    if [ -e "${zip_files[0]}" ]; then
        for zip_file in "${zip_files[@]}"; do
            if [ -f "$zip_file" ]; then
                student_name=$(basename "$zip_file" | awk -F'_' '{print $2}')
                temp_dir=$(mktemp -d)

                unzip "$zip_file" -d "$temp_dir" > /dev/null

                # Use find to collect .java and .txt files, preserving paths with spaces
                mapfile -d $'\0' student_files < <(find "$temp_dir" -type f \( -name "*.java" -o -name "*.txt" \) -print0)

                if [ ${#student_files[@]} -gt 0 ]; then
                    process_student_files "$student_name" "${student_files[@]}"
                else
                    echo "No Java or text files found in $zip_file for student: $student_name."
                    prompt_for_next
                fi

                rm -rf "$temp_dir"
            fi
        done
    else
        # Process Java and text files directly from the directory
        declare -A student_files_map

        # Collect all Java and text files and group them by student username
        for file in "$DIR"/*.{java,txt}; do
            if [ -f "$file" ]; then
                # Extract the student's username from the filename
                # Assuming the pattern: Lab 6_<username>_attempt_<timestamp>_<filename>.java or .txt
                student_name=$(basename "$file" | awk -F'_' '{print $2}')

                # Handle the case where the filename doesn't match the expected pattern
                if [ -z "$student_name" ]; then
                    echo "Could not extract student username from filename: $(basename "$file")"
                    continue
                fi

                # Append the file to the array for that student
                student_files_map["$student_name"]+="$file"$'\n'
            fi
        done

        if [ ${#student_files_map[@]} -gt 0 ]; then
            echo "No zip files found. Processing Java and text files directly from $DIR..."
            echo

            # Process each student's files
            for student_name in "${!student_files_map[@]}"; do
                # Read the list of files for this student into an array
                IFS=$'\n' read -d '' -r -a student_files <<< "${student_files_map[$student_name]}"

                process_student_files "$student_name" "${student_files[@]}"
            done
        else
            echo "No zip, Java, or text files found in the directory."
            exit 1
        fi
    fi
}

# Start processing submissions
process_submissions
