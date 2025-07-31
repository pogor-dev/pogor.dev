#!/bin/bash

# AstroPaper Migration Script
# This script upgrades AstroPaper to the latest version by selectively pulling files from upstream
# while preserving your custom content and configurations
#
# Features:
# - Handles unicode/emoji characters in filenames correctly
# - Creates backup branches for safety
# - Preserves custom configurations via ignore patterns
# - Supports targeting specific tags, branches, or commits

set -e  # Exit on any error

# Function to cleanup and restore git config on exit
cleanup_and_restore_config() {
    local exit_code=$?
    
    # Restore original core.quotepath setting if it was changed
    if [ -n "${ORIGINAL_QUOTEPATH+x}" ]; then
        if [ -n "$ORIGINAL_QUOTEPATH" ]; then
            git config core.quotepath "$ORIGINAL_QUOTEPATH" 2>/dev/null || true
        else
            git config --unset core.quotepath 2>/dev/null || true
        fi
    fi
    
    # Clean up temporary branch if it exists
    if git show-ref --verify --quiet "refs/heads/$TEMP_BRANCH" 2>/dev/null; then
        git checkout "$CURRENT_BRANCH" 2>/dev/null || true
        git branch -D "$TEMP_BRANCH" 2>/dev/null || true
    fi
    
    exit $exit_code
}

# Set trap to ensure cleanup happens on script exit
trap cleanup_and_restore_config EXIT INT TERM

# Configuration
UPSTREAM_REPO="https://github.com/satnaing/astro-paper.git"
UPSTREAM_REMOTE="astro-paper-upstream"
BACKUP_BRANCH="backup-before-upgrade-$(date +%Y%m%d-%H%M%S)"
CURRENT_BRANCH=$(git branch --show-current)
TEMP_BRANCH="temp-upstream-$(date +%Y%m%d-%H%M%S)"

# Default configuration
TARGET_BRANCH=""
TARGET_TAG=""
TARGET_COMMIT=""
IGNORE_FILE="${IGNORE_FILE:-$(dirname "$0")/.gitignore}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -b, --branch BRANCH     Use a specific branch (e.g., main, feature-xyz)"
    echo "  -t, --tag TAG           Use a specific tag (e.g., v5.5.0, v5.4.0)"
    echo "  -c, --commit COMMIT     Use a specific commit hash"
    echo "  -i, --ignore-file FILE  Use custom ignore file (default: same folder as script/.gitignore)"
    echo "  -h, --help              Show this help message"
    echo
    echo "If no options are provided, uses the latest tagged version."
    echo
    echo "Examples:"
    echo "  $0                          # Upgrade to latest version"
    echo "  $0 -t v5.4.0               # Upgrade to specific tag"
    echo "  $0 --tag v5.5.0            # Same as above"
    echo "  $0 -b main                 # Use main branch" 
    echo "  $0 --branch feature-xyz    # Use specific branch"
    echo "  $0 -c abc123def            # Use specific commit"
    echo "  $0 -t v5.5.0 -i custom.ignore  # Use custom ignore file"
}

# Function to check if pattern should be ignored
should_ignore() {
    local file="$1"
    
    # Read ignore patterns from ignore file
    if [ -f "$IGNORE_FILE" ]; then
        while IFS= read -r pattern; do
            # Skip empty lines and comments
            [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
            
            # Handle negation patterns (lines starting with !)
            if [[ "$pattern" =~ ^! ]]; then
                pattern="${pattern#!}"
                if [[ "$file" == $pattern || "$file" =~ $pattern ]]; then
                    return 1  # Don't ignore (explicitly include)
                fi
            else
                # Regular ignore pattern
                if [[ "$file" == $pattern || "$file" =~ $pattern ]]; then
                    return 0  # Should be ignored
                fi
            fi
        done < "$IGNORE_FILE"
    fi
    
    return 1  # Should not be ignored
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--branch)
                TARGET_BRANCH="$2"
                shift 2
                ;;
            -t|--tag)
                TARGET_TAG="$2"
                shift 2
                ;;
            -c|--commit)
                TARGET_COMMIT="$2"
                shift 2
                ;;
            -i|--ignore-file)
                IGNORE_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate that only one target type is specified
    local target_count=0
    [[ -n "$TARGET_BRANCH" ]] && target_count=$((target_count + 1))
    [[ -n "$TARGET_TAG" ]] && target_count=$((target_count + 1))
    [[ -n "$TARGET_COMMIT" ]] && target_count=$((target_count + 1))
    
    if [[ $target_count -gt 1 ]]; then
        log_error "Only one of --branch, --tag, or --commit can be specified"
        exit 1
    fi
}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not in a git repository!"
    exit 1
fi

# Parse command line arguments
parse_arguments "$@"

# Validate ignore file exists if specified
if [[ -n "$IGNORE_FILE" && ! -f "$IGNORE_FILE" ]]; then
    log_error "Ignore file not found: $IGNORE_FILE"
    exit 1
fi

log_info "Using ignore file: $IGNORE_FILE"

# Show usage if help is requested (handled in parse_arguments)

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    log_error "You have uncommitted changes. Please commit or stash them before running this script."
    git status --porcelain
    exit 1
fi

log_info "Starting AstroPaper upgrade process..."

# Check if upstream remote exists
if git remote get-url "$UPSTREAM_REMOTE" > /dev/null 2>&1; then
    log_info "Upstream remote '$UPSTREAM_REMOTE' already exists"
    EXISTING_URL=$(git remote get-url "$UPSTREAM_REMOTE")
    if [ "$EXISTING_URL" != "$UPSTREAM_REPO" ]; then
        log_warning "Upstream remote URL differs. Updating to $UPSTREAM_REPO"
        git remote set-url "$UPSTREAM_REMOTE" "$UPSTREAM_REPO"
    fi
else
    log_info "Adding upstream remote '$UPSTREAM_REMOTE'"
    git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_REPO"
fi

# Fetch from upstream
log_info "Fetching from upstream..."
git fetch "$UPSTREAM_REMOTE"

# Determine the target version to use
if [[ -n "$TARGET_TAG" ]]; then
    TARGET_REF="$TARGET_TAG"
    log_info "Using AstroPaper tag: $TARGET_TAG"
    
    # Verify the tag exists
    if ! git show "$TARGET_REF" > /dev/null 2>&1; then
        log_error "Tag '$TARGET_REF' not found in upstream repository"
        log_info "Available tags:"
        git ls-remote --tags "$UPSTREAM_REMOTE" | grep -E 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/.*refs\/tags\///' | sort -V | tail -10
        exit 1
    fi
elif [[ -n "$TARGET_BRANCH" ]]; then
    TARGET_REF="$TARGET_BRANCH"
    log_info "Using AstroPaper branch: $TARGET_BRANCH"
    
    # Verify the branch exists
    if ! git show "$UPSTREAM_REMOTE/$TARGET_REF" > /dev/null 2>&1; then
        log_error "Branch '$TARGET_REF' not found in upstream repository"
        log_info "Available branches:"
        git ls-remote --heads "$UPSTREAM_REMOTE" | sed 's/.*refs\/heads\///' | head -10
        exit 1
    fi
elif [[ -n "$TARGET_COMMIT" ]]; then
    TARGET_REF="$TARGET_COMMIT"
    log_info "Using AstroPaper commit: $TARGET_COMMIT"
    
    # Verify the commit exists
    if ! git cat-file -e "$TARGET_COMMIT" 2>/dev/null; then
        log_error "Commit '$TARGET_COMMIT' not found"
        exit 1
    fi
else
    # Get the latest tag from upstream (default behavior)
    LATEST_TAG=$(git ls-remote --tags "$UPSTREAM_REMOTE" | grep -E 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 | sed 's/.*refs\/tags\///')
    if [ -z "$LATEST_TAG" ]; then
        log_error "Could not find any version tags in upstream repository"
        exit 1
    fi
    TARGET_REF="$LATEST_TAG"
    log_info "No target specified, using latest AstroPaper version: $LATEST_TAG"
fi

# Create backup branch
log_info "Creating backup branch: $BACKUP_BRANCH"
git checkout -b "$BACKUP_BRANCH"
git checkout "$CURRENT_BRANCH"

# Create a temporary branch for the upstream version  
log_info "Creating temporary branch to merge upstream changes..."

# For tags and commits, we need to use the upstream remote reference
if [[ -n "$TARGET_TAG" || -n "$TARGET_COMMIT" ]]; then
    git checkout -b "$TEMP_BRANCH" "$TARGET_REF"
else
    git checkout -b "$TEMP_BRANCH" "$UPSTREAM_REMOTE/$TARGET_REF"
fi

# Get all files from upstream
log_info "Getting list of files from upstream..."
# Temporarily set core.quotepath=false to handle unicode filenames properly
# This prevents git from using octal escape sequences for unicode characters
ORIGINAL_QUOTEPATH=$(git config --get core.quotepath 2>/dev/null || echo "")
git config core.quotepath false

# Use null-terminated output (-z flag) and proper array handling for unicode filenames
# This is more robust than using command substitution with spaces/newlines
ALL_UPSTREAM_FILES=()
while IFS= read -r -d '' file; do
    ALL_UPSTREAM_FILES+=("$file")
done < <(git ls-tree -r --name-only -z "$TEMP_BRANCH")

# Filter files that should be updated (not ignored)
FILES_TO_UPDATE=()
for file in "${ALL_UPSTREAM_FILES[@]}"; do
    if ! should_ignore "$file"; then
        FILES_TO_UPDATE+=("$file")
    fi
done

log_info "Found ${#FILES_TO_UPDATE[@]} files to update (${#ALL_UPSTREAM_FILES[@]} total upstream files)"

# Switch back and backup files that will be preserved
git checkout "$CURRENT_BRANCH"

log_info "Backing up files that will be preserved..."
mkdir -p .astro-paper-backup
for file in "${ALL_UPSTREAM_FILES[@]}"; do
    if should_ignore "$file" && [ -e "$file" ]; then
        backup_dir=$(dirname ".astro-paper-backup/$file")
        mkdir -p "$backup_dir"
        cp "$file" ".astro-paper-backup/$file" 2>/dev/null || true
    fi
done

# Update files from upstream
log_info "Updating files from upstream..."
for file in "${FILES_TO_UPDATE[@]}"; do
    log_info "Updating $file"
    # Create directory if it doesn't exist
    file_dir=$(dirname "$file")
    if [ "$file_dir" != "." ]; then
        mkdir -p "$file_dir"
    fi
    
    # Copy the file from the temporary branch
    # Use git show with proper quoting to handle unicode filenames
    if ! git show "$TEMP_BRANCH:$file" > "$file" 2>/dev/null; then
        log_warning "Could not update $file"
    fi
done

# Restore preserved files
log_info "Restoring preserved custom files..."
if [ -d ".astro-paper-backup" ]; then
    # Use find with -print0 and while read to handle unicode filenames properly
    find .astro-paper-backup -type f -print0 | while IFS= read -r -d '' backup_file; do
        original_file="${backup_file#.astro-paper-backup/}"
        if [ -f "$backup_file" ]; then
            cp "$backup_file" "$original_file"
            log_info "  ↳ Restored $original_file"
        fi
    done
fi

# Clean up
rm -rf .astro-paper-backup
# Note: Temp branch and git config cleanup is handled by the EXIT trap

# Update package.json version if we're using a tag
if [[ -n "$TARGET_TAG" && "$TARGET_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_info "Updating package.json version to match AstroPaper $TARGET_TAG..."
    if command -v jq > /dev/null 2>&1; then
        # Use jq if available for proper JSON manipulation
        jq --arg version "${TARGET_TAG#v}" '.version = $version' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback to sed (less reliable but works)
        sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"${TARGET_TAG#v}\"/" package.json
    fi
else
    log_info "Not updating package.json version (not using a semver tag)"
fi

# Update dependencies to match upstream
log_info "Checking for dependency updates..."
if git show "$UPSTREAM_REMOTE/$TARGET_REF:package.json" > /dev/null 2>&1; then
    git show "$UPSTREAM_REMOTE/$TARGET_REF:package.json" > upstream-package.json
    
    log_info "Manual dependency review required:"
    echo "  - Compare upstream-package.json with your package.json"
    echo "  - Update dependencies as needed"
    echo "  - Run 'pnpm install' to update lock file"
    
    # Clean up
    # rm upstream-package.json  # Keep for manual review
fi

# Stage changes
log_info "Staging updated files..."
git add .

# Show what changed
log_info "Summary of changes:"
git diff --cached --stat

log_success "AstroPaper upgrade completed!"
echo
log_info "Next steps:"
echo "  1. Review the changes: git diff --cached"
echo "  2. Test your site: pnpm dev"
echo "  3. Update dependencies manually if needed"
echo "  4. Commit the changes: git commit -m 'feat: upgrade to AstroPaper $TARGET_REF'"
echo "  5. If something goes wrong, restore from backup: git checkout $BACKUP_BRANCH"
echo
log_warning "Remember to:"
echo "  - Test all functionality after upgrade"
echo "  - Update your custom configurations if needed"
echo "  - Check upstream-package.json for new dependencies"
echo "  - Run 'pnpm install' to update dependencies"
echo "  - Review $IGNORE_FILE file to customize which files to preserve"

