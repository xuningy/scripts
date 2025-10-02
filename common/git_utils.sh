git-init() {
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "Usage: ${LTCYAN}git-init${NC}"
        return
    fi

    if [ -d ".git" ]; then
        echo -e "${CYAN}Git already initialized! Exiting.${NC}"
        return
    fi

    PACKAGE_NAME=$(basename "$PWD")
    echo -e "${CYAN}Initializing git for ${LTCYAN}$PACKAGE_NAME${NC}"

    # git init
    git init

    # Check if a .gitignore already exist. If not, create a .gitignore file.
    if [ ! -f ".gitignore" ]; then
        cp $BASH_SCRIPTS_DIR/common/gitignore_template.txt .gitignore

        echo -e "${CYAN}Added .gitignore${NC}"
    fi

    # Create a readme if the file doesn't already exist. If not, create a README.md file.
    if ! find . -iname "readme.md" -type f -print -quit | grep -q .; then

        echo "# $PACKAGE_NAME"  > README.md
        echo "Author: Xuning Yang" >> README.md

        echo -e "${CYAN}Added README.md${NC}"
    fi

    # Set config for the package
    git config user.email "xuningy@gmail.com"
    git config user.name "Xuning Yang"
    echo -e "${CYAN}Set user.name user.email to ${LTCYAN}Xuning Yang xuningy@gmail.com${NC}"

    git config -l

    return
}

git-unstage() {
    # Help text
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "Usage: ${LTCYAN}git-unstage [file]${NC}"
        echo "Unstages files from the staging area."
        echo "If a file is specified, unstages only that file."
        echo "If no file is specified, shows all staged files and prompts for confirmation."
        return
    fi

    # If a specific file is provided, unstage it directly
    if [[ -n "$1" ]]; then
        if git ls-files --cached --error-unmatch "$1" &>/dev/null; then
            git restore --staged "$1"
            echo -e "${CYAN}Unstaged file: ${LTCYAN}$1${NC}"
        else
            echo -e "${RED}Error: File '$1' is not staged or does not exist.${NC}"
            return 1
        fi
        return
    fi

    # Check if there are any staged files
    local staged_files=$(git diff --cached --name-only)
    if [[ -z "$staged_files" ]]; then
        echo -e "${CYAN}No files are currently staged.${NC}"
        return
    fi

    # Show the staged files that will be unstaged
    echo -e "${CYAN}The following staged files will be unstaged:${NC}"
    git diff --cached --name-status

    # Prompt for confirmation
    echo ""
    read -p "Proceed with unstaging all files? [y/N]: " choice

    case "$choice" in
        [yY])
            git restore --staged .
            echo -e "${CYAN}Successfully unstaged all files.${NC}"
            ;;
        *)
            echo "Aborted."
            return
            ;;
    esac
}

git-uncommit() {
    # Help text
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "Usage: ${LTCYAN}git-uncommit [number_of_commits]${NC}"
        echo "Uncommits the specified number of commits (default: 1) using git reset --soft."
        echo "Shows the commits that will be uncommitted and prompts for confirmation."
        return
    fi

    # Default to 1 commit if no argument provided
    local num_commits=${1:-1}

    # Validate that the argument is a positive integer
    if ! [[ "$num_commits" =~ ^[1-9][0-9]*$ ]]; then
        echo -e "${RED}Error: Number of commits must be a positive integer.${NC}"
        echo -e "Usage: ${LTCYAN}git-uncommit [number_of_commits]${NC}"
        return 1
    fi

    # Check if we have enough commits to go back
    local total_commits=$(git rev-list --count HEAD 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error: Not in a git repository or no commits found.${NC}"
        return 1
    fi

    if [[ $num_commits -gt $total_commits ]]; then
        echo -e "${RED}Error: Cannot go back $num_commits commits. Repository only has $total_commits commits.${NC}"
        return 1
    fi

    # Show the commits that will be uncommitted
    echo -e "${CYAN}The following $num_commits commit(s) will be uncommitted:${NC}"
    git log --oneline -n "$num_commits"

    # Prompt for confirmation
    echo ""
    read -p "Proceed with uncommitting these commits? [y/N]: " choice

    case "$choice" in
        [yY])
            git reset --soft "HEAD~$num_commits"
            echo -e "${CYAN}Successfully uncommitted $num_commits commit(s).${NC}"
            ;;
        *)
            echo "Aborted."
            return
            ;;
    esac
}

git-delete() {
    # Help text
    if [[ $1 = "-h" || $1 = "--help" ]]; then
        echo -e "Usage: ${LTCYAN}git-delete [remotename](OPTIONAL) <branchname>${NC}"
        echo "Deletes the specified local and remote Git branch."
        echo "If no remotename is given, only the local branch is deleted."
        return
    fi

    # Argument parsing
    if [[ $# -eq 1 ]]; then
        remotename="origin"
        branchname="$1"
    elif [[ $# -eq 2 ]]; then
        remotename="$1"
        branchname="$2"
    else
        echo "Error: Invalid number of arguments"
        echo -e "Usage: ${LTCYAN}git-delete [remotename] <branchname>${NC}"
        return 1
    fi

    # Check existence
    local_exists=false
    remote_exists=false

    if git show-ref --verify --quiet "refs/heads/$branchname"; then
        local_exists=true
    fi

    if [[ -n $remotename ]]; then
        if git ls-remote --exit-code --heads "$remotename" "$branchname" &>/dev/null; then
            remote_exists=true
        fi
    fi

    if [[ $local_exists == false && $remote_exists == false ]]; then
        echo "Error: Branch '$branchname' not found locally or remotely."
        return 1
    fi

    echo "You are about to delete the following:"
    $local_exists && echo "- Local branch: $branchname"
    $remote_exists && echo "- Remote branch: $remotename/$branchname"

    echo "Proceed? [l = local only, r = remote only, y = both, N = cancel]"
    read -p "[l/r/y/N]: " choice

    case "$choice" in
        [lL])
            if [[ $local_exists == true ]]; then
                git branch -d "$branchname" 2>/dev/null || git branch -D "$branchname"
                echo "Local branch '$branchname' deleted."
            else
                echo "Local branch '$branchname' does not exist."
            fi
            ;;
        [rR])
            if [[ $remote_exists == true ]]; then
                git push "$remotename" --delete "$branchname"
                echo "Remote branch '$remotename/$branchname' deleted."
            else
                echo "Remote branch '$remotename/$branchname' does not exist."
            fi
            ;;
        [yY])
            if [[ $local_exists == true ]]; then
                git branch -d "$branchname" 2>/dev/null || git branch -D "$branchname"
                echo "Local branch '$branchname' deleted."
            fi
            if [[ $remote_exists == true ]]; then
                git push "$remotename" --delete "$branchname"
                echo "Remote branch '$remotename/$branchname' deleted."
            fi
            ;;
        *)
            echo "Aborted."
            return
            ;;
    esac

    echo "Branch deletion complete."
}

git-diff-common() {
    # Help text
    if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]; then
        echo -e "Usage: ${LTCYAN}git-diff-common <dir1> <dir2>${NC}"
        echo "Compares Python files that exist in both directories and shows their differences."
        echo "Both arguments must be valid directories."
        return
    fi

    local dir1="$1"
    local dir2="$2"

    if [[ ! -d "$dir1" || ! -d "$dir2" ]]; then
        echo -e "${RED}Error: Both arguments must be directories.${NC}"
        echo -e "Usage: ${LTCYAN}git-diff-common <dir1> <dir2>${NC}"
        return 1
    fi

    echo -e "${CYAN}Comparing Python files between ${LTCYAN}$dir1${CYAN} and ${LTCYAN}$dir2${NC}"

    comm -12 \
    <(find "$dir1" -type f -name '*.py' -exec basename {} \; | sort) \
    <(find "$dir2" -type f -name '*.py' -exec basename {} \; | sort) \
    | while read file; do
        echo -e "\n${LTCYAN}=== Diffing $file ===${NC}"
        # Find the full paths of the files
        file1=$(find "$dir1" -name "$file" -type f)
        file2=$(find "$dir2" -name "$file" -type f)
        git diff --no-index --color "$file1" "$file2"
    done
}
