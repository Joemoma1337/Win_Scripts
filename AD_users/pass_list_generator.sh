#!/bin/bash

# Usage: ./pick_random_lines.sh input.txt output.txt
# Example: ./random.sh rockyou.txt 100_rockyou.txt

input_file="$1"
output_file="$2"
lines_to_pick=100

# Check if input file exists
if [[ ! -f "$input_file" ]]; then
    echo "Error: Input file '$input_file' not found."
    exit 1
fi

# Pick 100 random lines
shuf -n "$lines_to_pick" "$input_file" > "$output_file"

# Done
echo "Selected $lines_to_pick random lines from '$input_file' into '$output_file'"
