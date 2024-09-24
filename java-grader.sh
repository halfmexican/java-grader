#!/bin/bash

# Check if directory argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Directory containing the .java files
DIR="$1"

# Loop through all .java files in the directory
for file in "$DIR"/*.java; do
    # Extract the student's name from the filename
    student_name=$(echo "$(basename "$file")" | cut -d'_' -f2)

    echo "Processing student: $student_name"
    echo

    # Extract the class name from the Java file
    class_name=$(grep -oP 'public\s+class\s+\K\w+' "$file")

    # Check if the class name is found
    if [ -z "$class_name" ]; then
        echo "Class name not found in the file for student: $student_name"
        echo "Please check the file and make sure it contains a valid public class declaration."
        echo
        
        # Display the program with syntax highlighting
        echo "Program:"
        highlight -s vampire "$sanitized_file" 
        echo
        
        # Wait for user input to proceed to the next student
        read -p "Press Enter to continue to the next student..."
        echo
        echo -e "\e[1;31m---------------------------------------------------------\e[0m"
        echo
        continue
    fi

    # Create a temporary filename with the correct class name
    sanitized_file="${DIR}/${class_name}.java"
    
    # Copy the original file to the sanitized filename
    cp "$file" "$sanitized_file"

    # Try to compile the sanitized .java file
    if javac "$sanitized_file"; then
        echo -e "\e[1;32mCompilation succeeded for student: $student_name\e[0m"
        echo

        # Before displaying the program, remove excessive whitespace
        sed -i 's/^[[:space:]]*$//' "$sanitized_file"
        # Display the program with syntax highlighting
        echo "Program:"
        highlight -s vampire "$sanitized_file" 
        echo
            
        # Run the program and display the output
        echo -e "\e[1;34mOutput:\e[0m"
        java -cp "$DIR" "$class_name"
        echo
    else
        echo -e "\e[1;31mCompilation failed for student: $student_name\e[0m"
        # Before displaying the program, remove excessive whitespace
        sed -i 's/^[[:space:]]*$//' "$sanitized_file"

        # Display the program with syntax highlighting
        echo "Program:"
        highlight -s vampire "$sanitized_file" 
        echo
    fi

    # Clean up the temporary file
    rm "$sanitized_file"

    # Wait for user input to proceed to the next student
    read -p "Press Enter to continue to the next student..."
    echo
    echo -e "\e[1;31m---------------------------------------------------------\e[0m"
    echo
done
