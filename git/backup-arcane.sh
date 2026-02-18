#!/bin/bash

# ==============================================================================
# .ENV DISTRIBUTABLE GENERATOR & BACKUP TOOL
# ==============================================================================

# --- Defaults ---
TARGET_DIR="."
DEFAULT_KEYS="password|pw|passwd|client_?id|secret|key|token|auth|credential|private|cert|signature|salt|claim"
GIT_AUTHOR_NAME="Arcane Backup"
GIT_AUTHOR_EMAIL="backup@arcane.local"
PUSH_CHANGES=false
NO_COLOR=false

# --- Help Function ---
show_help() {
    echo "Usage: sudo $0 [options]"
    echo ""
    echo "Scans a directory for .env files, creates sanitized .dist copies,"
    echo "and commits them to a git repository."
    echo ""
    echo "Options:"
    echo "  -p, --path <dir>      Target directory to scan (Default: current dir)"
    echo "  -k, --keys <regex>    Regex pattern for secrets to wipe (Default: standard secrets)"
    echo "  -u, --user <name>     Git commit author name (Default: Arcane Backup)"
    echo "  -e, --email <email>   Git commit author email (Default: backup@arcane.local)"
    echo "  -P, --push            Push changes to remote origin after committing"
    echo "  -n, --no-color        Disable colored output (useful for logs)"
    echo "  -h, --help            Show this help message and exit"
    echo ""
    echo "Example:"
    echo "  sudo $0 --path /data/projects --push"
}

# --- Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--path) TARGET_DIR="$2"; shift ;;
        -k|--keys) DEFAULT_KEYS="$2"; shift ;;
        -u|--user) GIT_AUTHOR_NAME="$2"; shift ;;
        -e|--email) GIT_AUTHOR_EMAIL="$2"; shift ;;
        -P|--push) PUSH_CHANGES=true ;;
        -n|--no-color) NO_COLOR=true ;; 
        -h|--help) 
            show_help
            exit 0 
            ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

# --- Root Check ---
# We check this AFTER parsing args so --help works without sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[0;33mPermission Denied: Please run this script with sudo.\033[0m"
    echo "Example: sudo $0 -p $TARGET_DIR"
    exit 1
fi

# --- Color Handling ---
if [ "$NO_COLOR" = true ] || [ ! -t 1 ]; then
    BOLD=""
    GREEN=""
    YELLOW=""
    GRAY=""
    NC=""
else
    BOLD='\033[1m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    GRAY='\033[0;90m'
    NC='\033[0m'
fi

# --- Validation & User Detection ---
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}Error: Directory '$TARGET_DIR' does not exist.${NC}"
    exit 1
fi

# Auto-detect the REAL system user (the one who owns the git repo)
# We need this user to run git commands so SSH keys work.
if [ -d "$TARGET_DIR/.git" ]; then
    SYSTEM_USER=$(stat -c '%U' "$TARGET_DIR/.git")
else
    SYSTEM_USER=$(stat -c '%U' "$TARGET_DIR")
fi

# Fallback: if root owns the dir, try to use the sudo user
if [ "$SYSTEM_USER" == "root" ] && [ -n "$SUDO_USER" ]; then
    SYSTEM_USER="$SUDO_USER"
fi

cd "$TARGET_DIR" || exit 1
TARGET_DIR=$(pwd)

echo -e "${BOLD}${GREEN}=== .ENV Backup Tool ===${NC}"
echo -e "${GRAY}Target:      $TARGET_DIR${NC}"
echo -e "${GRAY}System User: $SYSTEM_USER (Will run git commands)${NC}"
echo -e "${GRAY}Git Author:  $GIT_AUTHOR_NAME <$GIT_AUTHOR_EMAIL>${NC}"

if [ "$PUSH_CHANGES" = true ]; then
    echo -e "${GRAY}Mode:        Commit & Push${NC}\n"
else
    echo -e "${GRAY}Mode:        Commit Only${NC}\n"
fi


# --- Step 1: Sanitize ---
files_processed=0
files_updated=0

# Loop through files
while read -r file; do
    ((files_processed++))
    dist_file="${file}.dist"
    
    # Create temp file in /tmp to avoid permission issues during creation
    temp_file=$(mktemp)
    
    # Process with sed
    sed -E "s/^([^#]*($DEFAULT_KEYS)[^=]*)=.*/\1=/I" "$file" > "$temp_file"

    if [ ! -f "$dist_file" ] || ! cmp -s "$temp_file" "$dist_file"; then
        # Move the temp file to destination (as root)
        mv "$temp_file" "$dist_file"
        
        # CRITICAL: Change ownership to the system user so git can read it
        chown "$SYSTEM_USER" "$dist_file"
        
        echo -e "   ${YELLOW}➜ Updated:${NC} $dist_file"
        ((files_updated++))
    else
        rm "$temp_file"
    fi

done < <(find . -type f \( -name ".env" -o -name ".env.global" \) -not -path "*/.git/*" -not -path "*/node_modules/*")

# --- Step 2: Git (Run as System User) ---
if [ -d ".git" ]; then
    
    # We wrap git commands in 'sudo -u $SYSTEM_USER' so they run as 'eric' (or whoever owns the repo)
    
    # Configure local git user/email for this repo
    sudo -u "$SYSTEM_USER" git config user.name "$GIT_AUTHOR_NAME"
    sudo -u "$SYSTEM_USER" git config user.email "$GIT_AUTHOR_EMAIL"
    
    # Add all files (respecting .gitignore)
    sudo -u "$SYSTEM_USER" git add .

    if ! sudo -u "$SYSTEM_USER" git diff --cached --quiet; then
        echo -e "\n${BOLD}Git: Changes detected.${NC}"
        timestamp=$(date +'%Y-%m-%d %H:%M')
        
        sudo -u "$SYSTEM_USER" git commit -m "docs: auto-save [$timestamp]"
        echo -e "${GREEN}✔ Backup committed successfully.${NC}"

        if [ "$PUSH_CHANGES" = true ]; then
             echo -e "${GRAY}Pushing to remote...${NC}"
             if sudo -u "$SYSTEM_USER" git push; then
                 echo -e "${GREEN}✔ Pushed to remote.${NC}"
            else
                 echo -e "${YELLOW}✖ Push failed (Check SSH keys for user $SYSTEM_USER).${NC}"
            fi
        fi
    else
        echo -e "\n${GRAY}Git: No changes to commit.${NC}"
    fi
else
    echo -e "\n${YELLOW}Skipping Git: Not a repository.${NC}"
fi

echo -e "\n${BOLD}Done. ($files_updated updated / $files_processed scanned)${NC}"