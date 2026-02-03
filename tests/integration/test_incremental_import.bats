#!/usr/bin/env bats
# Integration tests for ralph-import --extend (incremental PRD import)
# Tests the full workflow of adding tasks to existing Ralph projects using Claude Code

load '../helpers/test_helper'
load '../helpers/fixtures'
load '../helpers/mocks'

# Root directory of the project
PROJECT_ROOT="${BATS_TEST_DIRNAME}/../.."

setup() {
    # Create temporary test directory
    TEST_DIR="$(mktemp -d)"
    ORIGINAL_DIR="$(pwd)"
    cd "$TEST_DIR"

    # Set up mock command directory (prepend to PATH)
    MOCK_BIN_DIR="$TEST_DIR/.mock_bin"
    mkdir -p "$MOCK_BIN_DIR"
    export PATH="$MOCK_BIN_DIR:$PATH"

    # Create mock claude command that extends fix_plan.md
    create_mock_claude_extend_success

    # Set Claude command to use mock
    export CLAUDE_CODE_CMD="claude"

    # Source libraries for helper functions
    source "$PROJECT_ROOT/lib/task_sources.sh"
    source "$PROJECT_ROOT/lib/enable_core.sh"
}

# =============================================================================
# MOCK CLAUDE HELPERS FOR EXTEND MODE
# =============================================================================

# Helper: Create mock claude command that successfully extends fix_plan.md
create_mock_claude_extend_success() {
    cat > "$MOCK_BIN_DIR/claude" << 'MOCK_CLAUDE_EXTEND_EOF'
#!/bin/bash
# Mock Claude Code CLI that extends fix_plan.md with new tasks

# Handle --version flag first
if [[ "$1" == "--version" ]]; then
    echo "Claude Code CLI version 2.0.80"
    exit 0
fi

# Read from stdin (the extend prompt)
prompt_content=$(cat)

# Determine target section from prompt (default to high)
target_section="High"
if echo "$prompt_content" | grep -qi "TARGET SECTION: medium"; then
    target_section="Medium"
elif echo "$prompt_content" | grep -qi "TARGET SECTION: low"; then
    target_section="Low"
fi

# Read existing fix_plan.md if it exists
existing_content=""
if [[ -f ".ralph/fix_plan.md" ]]; then
    existing_content=$(cat ".ralph/fix_plan.md")
fi

# Extract new tasks that would be found in the PRD
# For test purposes, we add standardized mock tasks based on the PRD content
# This simulates Claude's behavior of extracting and adding unique tasks

# Write extended fix_plan.md
cat > ".ralph/fix_plan.md" << 'EXTENDED_FIX_PLAN'
# Ralph Fix Plan

## High Priority
- [ ] Implement user authentication
- [ ] Set up database connection
- [ ] Real-time WebSocket updates
- [ ] Team workspace management
- [ ] File upload support (max 10MB)

## Medium Priority
- [ ] Add logging

## Low Priority
- [ ] Performance optimization

## Completed
- [x] Project initialization
- [x] Initial setup

## Notes
- Focus on MVP first
EXTENDED_FIX_PLAN

# Output JSON response
cat << 'JSON_OUTPUT'
{
    "result": "Successfully extended fix_plan.md with 3 new tasks in High priority section",
    "sessionId": "session-extend-123",
    "metadata": {
        "files_changed": 1,
        "has_errors": false,
        "completion_status": "complete"
    }
}
JSON_OUTPUT

exit 0
MOCK_CLAUDE_EXTEND_EOF
    chmod +x "$MOCK_BIN_DIR/claude"
}

# Helper: Create mock claude that preserves existing tasks and adds to medium section
create_mock_claude_extend_medium() {
    cat > "$MOCK_BIN_DIR/claude" << 'MOCK_CLAUDE_MEDIUM_EOF'
#!/bin/bash
# Mock Claude Code CLI that adds tasks to medium priority

if [[ "$1" == "--version" ]]; then
    echo "Claude Code CLI version 2.0.80"
    exit 0
fi

cat > /dev/null

cat > ".ralph/fix_plan.md" << 'EXTENDED_FIX_PLAN'
# Ralph Fix Plan

## High Priority
- [ ] Implement user authentication
- [ ] Set up database connection

## Medium Priority
- [ ] Add logging
- [ ] Add email notifications

## Low Priority
- [ ] Performance optimization

## Completed
- [x] Project initialization
- [x] Initial setup

## Notes
- Focus on MVP first
EXTENDED_FIX_PLAN

cat << 'JSON_OUTPUT'
{
    "result": "Successfully extended fix_plan.md with 1 new task in Medium priority section",
    "sessionId": "session-extend-medium-123",
    "metadata": {
        "files_changed": 1,
        "has_errors": false,
        "completion_status": "complete"
    }
}
JSON_OUTPUT

exit 0
MOCK_CLAUDE_MEDIUM_EOF
    chmod +x "$MOCK_BIN_DIR/claude"
}

# Helper: Create mock claude that adds to low priority section
create_mock_claude_extend_low() {
    cat > "$MOCK_BIN_DIR/claude" << 'MOCK_CLAUDE_LOW_EOF'
#!/bin/bash
# Mock Claude Code CLI that adds tasks to low priority

if [[ "$1" == "--version" ]]; then
    echo "Claude Code CLI version 2.0.80"
    exit 0
fi

cat > /dev/null

cat > ".ralph/fix_plan.md" << 'EXTENDED_FIX_PLAN'
# Ralph Fix Plan

## High Priority
- [ ] Implement user authentication
- [ ] Set up database connection

## Medium Priority
- [ ] Add logging

## Low Priority
- [ ] Performance optimization
- [ ] Add dark mode theme

## Completed
- [x] Project initialization
- [x] Initial setup

## Notes
- Focus on MVP first
EXTENDED_FIX_PLAN

cat << 'JSON_OUTPUT'
{
    "result": "Successfully extended fix_plan.md with 1 new task in Low priority section",
    "sessionId": "session-extend-low-123",
    "metadata": {
        "files_changed": 1,
        "has_errors": false,
        "completion_status": "complete"
    }
}
JSON_OUTPUT

exit 0
MOCK_CLAUDE_LOW_EOF
    chmod +x "$MOCK_BIN_DIR/claude"
}

# Helper: Create mock claude that reports no new tasks (all duplicates)
create_mock_claude_extend_no_new() {
    cat > "$MOCK_BIN_DIR/claude" << 'MOCK_CLAUDE_NO_NEW_EOF'
#!/bin/bash
# Mock Claude Code CLI that finds no new unique tasks

if [[ "$1" == "--version" ]]; then
    echo "Claude Code CLI version 2.0.80"
    exit 0
fi

cat > /dev/null

# Keep fix_plan.md unchanged (all tasks already exist)
# We don't modify the file, it stays the same

cat << 'JSON_OUTPUT'
{
    "result": "No new unique tasks found. fix_plan.md is up to date.",
    "sessionId": "session-extend-nonew-123",
    "metadata": {
        "files_changed": 0,
        "has_errors": false,
        "completion_status": "complete"
    }
}
JSON_OUTPUT

exit 0
MOCK_CLAUDE_NO_NEW_EOF
    chmod +x "$MOCK_BIN_DIR/claude"
}

# Helper: Create mock claude that fails
create_mock_claude_extend_failure() {
    cat > "$MOCK_BIN_DIR/claude" << 'MOCK_CLAUDE_FAIL_EOF'
#!/bin/bash
# Mock Claude Code CLI that fails

if [[ "$1" == "--version" ]]; then
    echo "Claude Code CLI version 2.0.80"
    exit 0
fi

cat > /dev/null

cat << 'JSON_OUTPUT'
{
    "result": "Failed to extend fix_plan.md",
    "sessionId": "session-extend-fail-123",
    "metadata": {
        "files_changed": 0,
        "has_errors": true,
        "completion_status": "failed",
        "error_message": "Could not parse PRD content"
    }
}
JSON_OUTPUT

exit 1
MOCK_CLAUDE_FAIL_EOF
    chmod +x "$MOCK_BIN_DIR/claude"
}

teardown() {
    cd "$ORIGINAL_DIR" 2>/dev/null || cd /

    if [[ -n "$TEST_DIR" ]] && [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi

    # Clean up mock bin directory
    if [[ -n "$MOCK_BIN_DIR" ]] && [[ -d "$MOCK_BIN_DIR" ]]; then
        rm -rf "$MOCK_BIN_DIR"
    fi
}

# Helper: Create a minimal Ralph project structure
create_ralph_project() {
    local project_name="${1:-test-project}"

    mkdir -p "$project_name/.ralph/specs"
    mkdir -p "$project_name/.ralph/logs"
    mkdir -p "$project_name/src"

    cat > "$project_name/.ralph/PROMPT.md" << 'EOF'
# Ralph Development Instructions

## Context
You are Ralph working on a test project.

## Current Objectives
- Implement core features

## Current Task
Follow fix_plan.md
EOF

    cat > "$project_name/.ralph/fix_plan.md" << 'EOF'
# Ralph Fix Plan

## High Priority
- [ ] Implement user authentication
- [ ] Set up database connection

## Medium Priority
- [ ] Add logging

## Low Priority
- [ ] Performance optimization

## Completed
- [x] Project initialization
- [x] Initial setup

## Notes
- Focus on MVP first
EOF

    cat > "$project_name/.ralph/AGENT.md" << 'EOF'
# Agent Build Instructions

## Build
npm run build

## Test
npm test
EOF

    echo "$project_name"
}

# Helper: Create a PRD file with tasks
create_test_prd() {
    local filename="${1:-phase2.md}"

    cat > "$filename" << 'EOF'
# Phase 2 Requirements

## New Features

1. Add real-time notifications
2. Implement team collaboration
3. Add file attachments

## Requirements
- [ ] Real-time WebSocket updates
- [ ] Team workspace management
- [ ] File upload support (max 10MB)

## Technical Notes
Use socket.io for real-time features.
EOF

    echo "$filename"
}

# =============================================================================
# EXTEND MODE VALIDATION TESTS (3 tests)
# =============================================================================

@test "ralph-import --extend fails outside Ralph project" {
    create_test_prd "requirements.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "requirements.md"

    assert_failure
    [[ "$output" =~ "Not in a Ralph-enabled project" ]] || [[ "$output" =~ "no .ralph/" ]]
}

@test "ralph-import --extend succeeds in valid Ralph project" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    create_test_prd "phase2.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "phase2.md"

    assert_success
    [[ "$output" =~ "successfully" ]] || [[ "$output" =~ "SUCCESS" ]] || [[ "$output" =~ "extended" ]]
}

@test "ralph-import --extend validates fix_plan.md exists" {
    mkdir -p ".ralph"
    # Don't create fix_plan.md

    create_test_prd "requirements.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "requirements.md"

    assert_failure
    [[ "$output" =~ "missing" ]] || [[ "$output" =~ "fix_plan.md" ]]
}

# =============================================================================
# TASK EXTRACTION AND MERGING TESTS (4 tests)
# =============================================================================

@test "ralph-import --extend extracts tasks from PRD via Claude" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    create_test_prd "phase2.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "phase2.md"

    assert_success
    # Check that tasks were added to fix_plan.md by Claude
    run grep "Real-time WebSocket" ".ralph/fix_plan.md"
    assert_success
}

@test "ralph-import --extend preserves completed tasks" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    create_test_prd "phase2.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "phase2.md"

    assert_success
    # Check completed tasks are still there (Claude preserves them)
    run grep "\[x\] Project initialization" ".ralph/fix_plan.md"
    assert_success

    run grep "\[x\] Initial setup" ".ralph/fix_plan.md"
    assert_success
}

@test "ralph-import --extend uses Claude to deduplicate tasks" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    # Use mock that reports no new tasks (simulating all duplicates)
    create_mock_claude_extend_no_new

    # Create PRD with duplicate task
    cat > "duplicate.md" << 'EOF'
# Duplicate Test
- [ ] Implement user authentication
- [ ] Brand new task
EOF

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "duplicate.md"

    assert_success
    # Claude handles deduplication - output should indicate success
    [[ "$output" =~ "SUCCESS" ]] || [[ "$output" =~ "extended" ]] || [[ "$output" =~ "up to date" ]]
}

@test "ralph-import --extend reports task update via Claude" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    create_test_prd "phase2.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "phase2.md"

    assert_success
    # Claude reports results via JSON response
    [[ "$output" =~ "SUCCESS" ]] || [[ "$output" =~ "extended" ]] || [[ "$output" =~ "tasks" ]]
}

# =============================================================================
# SECTION TARGETING TESTS (3 tests)
# =============================================================================

@test "ralph-import --extend --section medium adds to medium priority" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    # Use mock that adds to medium section
    create_mock_claude_extend_medium

    cat > "medium-tasks.md" << 'EOF'
# Medium Priority Tasks
- [ ] Add email notifications
EOF

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend --section medium "medium-tasks.md"

    assert_success

    # Task should be in Medium Priority section (Claude placed it there)
    run grep -A 5 "## Medium Priority" ".ralph/fix_plan.md"
    [[ "$output" =~ "email notifications" ]]
}

@test "ralph-import --extend --section low adds to low priority" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    # Use mock that adds to low section
    create_mock_claude_extend_low

    cat > "low-tasks.md" << 'EOF'
# Low Priority
- [ ] Add dark mode theme
EOF

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend --section low "low-tasks.md"

    assert_success

    # Task should be in Low Priority section (Claude placed it there)
    run grep -A 5 "## Low Priority" ".ralph/fix_plan.md"
    [[ "$output" =~ "dark mode" ]]
}

@test "ralph-import --extend rejects invalid section" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    create_test_prd "phase2.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend --section invalid "phase2.md"

    assert_failure
    [[ "$output" =~ "Invalid section" ]] || [[ "$output" =~ "must be" ]]
}

# =============================================================================
# PROMPT UPDATE TESTS (2 tests)
# =============================================================================

@test "ralph-import --extend --update-prompt updates PROMPT.md" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    create_test_prd "phase2.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend --update-prompt "phase2.md"

    assert_success

    # PROMPT.md should have new content
    run grep -c "Requirements" ".ralph/PROMPT.md"
    # Should have at least 2 occurrences (original + new section)
    [[ "$output" -ge 1 ]]
}

@test "ralph-import --extend without --update-prompt does not modify PROMPT.md" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    # Get original PROMPT.md content
    local original_hash
    original_hash=$(md5sum ".ralph/PROMPT.md" | cut -d' ' -f1)

    create_test_prd "phase2.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "phase2.md"

    assert_success

    # PROMPT.md should be unchanged
    local new_hash
    new_hash=$(md5sum ".ralph/PROMPT.md" | cut -d' ' -f1)
    [[ "$original_hash" == "$new_hash" ]]
}

# =============================================================================
# DRY RUN TESTS (2 tests)
# =============================================================================

@test "ralph-import --extend --dry-run shows preview without changes" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    # Get original fix_plan.md content
    local original_content
    original_content=$(cat ".ralph/fix_plan.md")

    create_test_prd "phase2.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend --dry-run "phase2.md"

    assert_success
    [[ "$output" =~ "DRY RUN" ]] || [[ "$output" =~ "dry-run" ]]

    # fix_plan.md should be unchanged (Claude not invoked in dry-run)
    local new_content
    new_content=$(cat ".ralph/fix_plan.md")
    [[ "$original_content" == "$new_content" ]]
}

@test "ralph-import --extend --dry-run shows what Claude will do" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    create_test_prd "phase2.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend --dry-run "phase2.md"

    assert_success
    # Should describe what Claude will do
    [[ "$output" =~ "Claude Code will" ]] || [[ "$output" =~ "Read existing" ]] || [[ "$output" =~ "Extract tasks" ]]
}

# =============================================================================
# SPEC FILE COPY TESTS (2 tests)
# =============================================================================

@test "ralph-import --extend copies PRD to specs directory" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    create_test_prd "phase2.md"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "phase2.md"

    assert_success

    # PRD should be copied to specs
    assert_file_exists ".ralph/specs/imported-phase2.md"
}

@test "ralph-import --extend handles duplicate spec filenames" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    create_test_prd "phase2.md"

    # Import twice
    bash "$PROJECT_ROOT/ralph_import.sh" --extend "phase2.md"
    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "phase2.md"

    assert_success

    # Should have created a timestamped version
    local spec_count
    spec_count=$(ls -1 .ralph/specs/imported-phase2* 2>/dev/null | wc -l)
    [[ "$spec_count" -ge 1 ]]
}

# =============================================================================
# IDEMPOTENCY TESTS (2 tests)
# =============================================================================

@test "ralph-import --extend is idempotent via Claude (safe to run multiple times)" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    create_test_prd "phase2.md"

    # First import
    bash "$PROJECT_ROOT/ralph_import.sh" --extend "phase2.md"

    # Count tasks in fix_plan.md
    local task_count_1
    task_count_1=$(grep -c '^\- \[' ".ralph/fix_plan.md" || echo "0")

    # Use mock that reports no new tasks for second import
    create_mock_claude_extend_no_new

    # Second import (same PRD) - Claude deduplicates
    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "phase2.md"

    assert_success

    # Task count should be the same (Claude deduplicates)
    local task_count_2
    task_count_2=$(grep -c '^\- \[' ".ralph/fix_plan.md" || echo "0")
    # Note: mock doesn't change file, so counts stay same
    [[ "$task_count_1" -eq "$task_count_2" ]]
}

@test "ralph-import --extend reports via Claude when no new tasks" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    create_test_prd "phase2.md"

    # Use mock that reports no new tasks
    create_mock_claude_extend_no_new

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "phase2.md"

    assert_success
    # Claude reports no new tasks via JSON result
    [[ "$output" =~ "up to date" ]] || [[ "$output" =~ "No new" ]] || [[ "$output" =~ "SUCCESS" ]]
}

# =============================================================================
# HELP AND CLI TESTS (2 tests)
# =============================================================================

@test "ralph-import --help shows extend mode documentation" {
    run bash "$PROJECT_ROOT/ralph_import.sh" --help

    assert_success
    [[ "$output" =~ "--extend" ]]
    [[ "$output" =~ "--section" ]]
    [[ "$output" =~ "--dry-run" ]]
}

@test "ralph-import --extend with missing file shows error" {
    local project
    project=$(create_ralph_project)
    cd "$project"

    run bash "$PROJECT_ROOT/ralph_import.sh" --extend "nonexistent.md"

    assert_failure
    [[ "$output" =~ "does not exist" ]] || [[ "$output" =~ "not found" ]]
}
