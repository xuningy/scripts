
open() {
    nautilus --browser $@
}

restart-nomachine() {
    sudo /etc/NX/nxserver --status
    sudo /etc/NX/nxserver --restart
}
# Escape a string for sed (delimiters and special chars)
escape_sed() {
  local string="$1"
  local delimiter="$2"
  printf '%s\n' "$string" | sed -e "s/[$delimiter&\\/]/\\\\&/g"
}

replace_string() {

# Help function to display usage instructions
  show_help() {
    cat << EOF
Usage: replace_string <old_string> <new_string>

This script performs a search-and-replace operation in files and previews the changes before applying them.

Options:
<old_string>    The string to search for in files.
<new_string>    The string to replace the old string with.

--help          Show this help message and exit.

Example:
replace_string "oldText" "newText"
EOF
  }

  # Show help if requested
  if [[ "$1" == "--help" ]]; then
    show_help
    return
  fi

  # Validate that both old and new strings are provided
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Error: Both old string and new string are required."
    show_help
    return 1
  fi

  local old="$1"
  local new="$2"

  local delimiters='@#|~^%'
  local delimiter
  for d in $(echo "$delimiters" | grep -o .); do
    if [[ "$old$new" != *"$d"* ]]; then
      delimiter="$d"
      break
    fi
  done

  if [[ -z "$delimiter" ]]; then
    echo "Could not find a safe delimiter."
    return 1
  fi

  local safe_old
  local safe_new
  safe_old=$(escape_sed "$old" "$delimiter")
  safe_new=$(escape_sed "$new" "$delimiter")

  echo "Search string: $old"
  echo "Replace with:  $new"
  echo

  local files
  IFS=$'\n' read -d '' -r -a files < <(grep -rl -- "$old" . && printf '\0')

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No files found containing the string: $old"
    return
  fi

  echo "Preview of changes:"
  for file in "${files[@]}"; do
    while IFS= read -r line; do
      if [[ "$line" == *"$old"* ]]; then
        local replaced="${line//$old/$new}"
        local colored_old_line
        local colored_new_line
        local colored_file="\x1b[35m$file\x1b[0m"  # Purple file path

        # Red for old string, green for new string
        colored_old_line=$(echo "$line" | sed "s/$safe_old/\x1b[31m&\x1b[0m/g")
        colored_new_line=$(echo "$replaced" | sed "s/$safe_new/\x1b[32m&\x1b[0m/g")

        # Use echo -e to print colored file path, old line, and new line
        echo -e "${colored_file}:"
        echo -e "     ${colored_old_line}"
        echo -e "     ${colored_new_line}"
      fi
    done < "$file"
  done

  read -rp "Proceed with replacements? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    for file in "${files[@]}"; do
      sed -i "s${delimiter}${safe_old}${delimiter}${safe_new}${delimiter}g" "$file"
      echo -e "\x1b[35mUpdated:\x1b[0m $file"
    done
  else
    echo "Operation canceled."
  fi
}
