#!/usr/bin/env bats
# Unit tests for lib/task_sources.sh
# Tests beads integration, GitHub integration, PRD extraction, and task normalization

load '../helpers/test_helper'
load '../helpers/fixtures'

# Path to task_sources.sh
TASK_SOURCES="${BATS_TEST_DIRNAME}/../../lib/task_sources.sh"

setup() {
    # Create temporary test directory
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Source the library
    source "$TASK_SOURCES"
}

teardown() {
    if [[ -n "$TEST_DIR" ]] && [[ -d "$TEST_DIR" ]]; then
        cd /
        rm -rf "$TEST_DIR"
    fi
}

# =============================================================================
# BEADS DETECTION (3 tests)
# =============================================================================

@test "check_beads_available returns false when no .beads directory" {
    run check_beads_available
    assert_failure
}

@test "check_beads_available returns false when bd command not found" {
    mkdir -p .beads
    # bd command likely won't exist in test environment
    if command -v bd &>/dev/null; then
        skip "bd command is available"
    fi
    run check_beads_available
    assert_failure
}

@test "get_beads_count returns 0 when beads unavailable" {
    run get_beads_count
    assert_output "0"
}

# =============================================================================
# GITHUB DETECTION (3 tests)
# =============================================================================

@test "check_github_available returns false when no gh command" {
    # gh command may not exist in test environment
    if ! command -v gh &>/dev/null; then
        run check_github_available
        assert_failure
    else
        skip "gh command is available"
    fi
}

@test "check_github_available returns false when not in git repo" {
    run check_github_available
    assert_failure
}

@test "get_github_issue_count returns 0 when GitHub unavailable" {
    run get_github_issue_count
    assert_output "0"
}

# =============================================================================
# PRD EXTRACTION (6 tests)
# =============================================================================

@test "extract_prd_tasks extracts checkbox items" {
    cat > prd.md << 'EOF'
# Requirements

- [ ] Implement user authentication
- [x] Set up database
- [ ] Add API endpoints
EOF

    run extract_prd_tasks "prd.md"

    assert_success
    [[ "$output" =~ "Implement user authentication" ]]
    [[ "$output" =~ "Add API endpoints" ]]
}

@test "extract_prd_tasks extracts numbered list items" {
    cat > prd.md << 'EOF'
# Requirements

1. Implement user authentication
2. Set up database
3. Add API endpoints
EOF

    run extract_prd_tasks "prd.md"

    assert_success
    [[ "$output" =~ "Implement user authentication" ]]
}

@test "extract_prd_tasks returns empty for file without tasks" {
    cat > prd.md << 'EOF'
# Empty Document

This document has no tasks.
EOF

    run extract_prd_tasks "prd.md"

    assert_success
}

@test "extract_prd_tasks returns error for missing file" {
    run extract_prd_tasks "nonexistent.md"
    assert_failure
}

@test "extract_prd_tasks normalizes checked items to unchecked" {
    cat > prd.md << 'EOF'
- [x] Completed task
- [X] Another completed
EOF

    run extract_prd_tasks "prd.md"

    assert_success
    [[ "$output" =~ "[ ]" ]]
    [[ ! "$output" =~ "[x]" ]]
    [[ ! "$output" =~ "[X]" ]]
}

@test "extract_prd_tasks limits output to 30 tasks" {
    # Create PRD with 40 tasks
    {
        echo "# Tasks"
        for i in {1..40}; do
            echo "- [ ] Task $i"
        done
    } > prd.md

    run extract_prd_tasks "prd.md"

    # Count the number of task lines
    task_count=$(echo "$output" | grep -c '^\- \[' || echo "0")
    [[ "$task_count" -le 30 ]]
}

# =============================================================================
# TASK NORMALIZATION (5 tests)
# =============================================================================

@test "normalize_tasks converts bullet points to checkboxes" {
    input="- First task
* Second task"

    run normalize_tasks "$input"

    assert_success
    [[ "$output" =~ "- [ ] First task" ]]
    [[ "$output" =~ "- [ ] Second task" ]]
}

@test "normalize_tasks converts numbered items to checkboxes" {
    input="1. First task
2. Second task"

    run normalize_tasks "$input"

    assert_success
    [[ "$output" =~ "- [ ]" ]]
}

@test "normalize_tasks preserves existing checkboxes" {
    input="- [ ] Already a task"

    run normalize_tasks "$input"

    assert_success
    [[ "$output" =~ "- [ ] Already a task" ]]
}

@test "normalize_tasks handles plain text lines" {
    input="Plain text task"

    run normalize_tasks "$input"

    assert_success
    [[ "$output" =~ "- [ ] Plain text task" ]]
}

@test "normalize_tasks handles empty input" {
    run normalize_tasks ""
    assert_success
}

# =============================================================================
# TASK PRIORITIZATION (3 tests)
# =============================================================================

@test "prioritize_tasks puts critical tasks in High Priority" {
    input="- [ ] Critical bug fix
- [ ] Normal task"

    output=$(prioritize_tasks "$input" || true)

    [[ "$output" =~ "## High Priority" ]]
    # Critical should be before Medium
    high_section="${output%%## Medium*}"
    [[ "$high_section" =~ "Critical bug fix" ]]
}

@test "prioritize_tasks puts optional tasks in Low Priority" {
    input="- [ ] Nice to have feature
- [ ] Normal task"

    run prioritize_tasks "$input"

    assert_success
    [[ "$output" =~ "## Low Priority" ]]
    low_section="${output##*## Low Priority}"
    [[ "$low_section" =~ "Nice to have" ]]
}

@test "prioritize_tasks puts regular tasks in Medium Priority" {
    input="- [ ] Regular task"

    output=$(prioritize_tasks "$input" || true)

    [[ "$output" =~ "## Medium Priority" ]]
}

# =============================================================================
# COMBINED IMPORT (3 tests)
# =============================================================================

@test "import_tasks_from_sources handles prd source" {
    mkdir -p docs
    cat > docs/prd.md << 'EOF'
# Requirements
- [ ] Test task
EOF

    run import_tasks_from_sources "prd" "docs/prd.md" ""

    assert_success
    [[ "$output" =~ "Test task" ]]
}

@test "import_tasks_from_sources handles empty sources" {
    run import_tasks_from_sources "" "" ""

    assert_failure
}

@test "import_tasks_from_sources handles none source" {
    run import_tasks_from_sources "none" "" ""

    # 'none' doesn't import anything, so fails
    assert_failure
}

# =============================================================================
# FIX_PLAN.MD PARSING (4 tests)
# =============================================================================

@test "parse_fix_plan_sections parses high priority tasks" {
    cat > fix_plan.md << 'EOF'
# Ralph Fix Plan

## High Priority
- [ ] High task 1
- [ ] High task 2

## Medium Priority
- [ ] Medium task

## Completed
- [x] Done task
EOF

    # Don't use run - we need to preserve global arrays
    parse_fix_plan_sections "fix_plan.md"
    local result=$?

    [[ $result -eq 0 ]]
    # Check that PARSED_HIGH_PRIORITY array was populated
    [[ "${#PARSED_HIGH_PRIORITY[@]}" -eq 2 ]]
}

@test "parse_fix_plan_sections parses completed tasks" {
    cat > fix_plan.md << 'EOF'
# Ralph Fix Plan

## High Priority
- [ ] Task 1

## Completed
- [x] Done task 1
- [x] Done task 2
- [x] Done task 3
EOF

    # Don't use run - we need to preserve global arrays
    parse_fix_plan_sections "fix_plan.md"
    local result=$?

    [[ $result -eq 0 ]]
    # Check completed array has 3 items
    [[ "${#PARSED_COMPLETED[@]}" -eq 3 ]]
}

@test "parse_fix_plan_sections handles missing file" {
    run parse_fix_plan_sections "nonexistent.md"
    assert_failure
}

@test "parse_fix_plan_sections handles notes section" {
    cat > fix_plan.md << 'EOF'
# Ralph Fix Plan

## High Priority
- [ ] Task 1

## Notes
- Important note 1
- Important note 2
EOF

    # Don't use run - we need to preserve global arrays
    parse_fix_plan_sections "fix_plan.md"
    local result=$?

    [[ $result -eq 0 ]]
    # Check notes array
    [[ "${#PARSED_NOTES[@]}" -ge 1 ]]
}

# =============================================================================
# TASK DEDUPLICATION (4 tests)
# =============================================================================

@test "deduplicate_tasks removes exact duplicates" {
    local existing="- [ ] Task one
- [ ] Task two"

    local new="- [ ] Task one
- [ ] Task three"

    run deduplicate_tasks "$existing" "$new"

    assert_success
    # Should only output "Task three"
    [[ "$output" =~ "Task three" ]]
    [[ ! "$output" =~ "Task one" ]]
}

@test "deduplicate_tasks is case insensitive" {
    local existing="- [ ] Implement Authentication"

    local new="- [ ] implement authentication
- [ ] New task"

    run deduplicate_tasks "$existing" "$new"

    assert_success
    # Should only output "New task" (authentication is duplicate)
    [[ "$output" =~ "New task" ]]
    [[ ! "$output" =~ "authentication" ]]
}

@test "deduplicate_tasks ignores checkbox state" {
    local existing="- [x] Completed task"

    local new="- [ ] Completed task
- [ ] New task"

    run deduplicate_tasks "$existing" "$new"

    assert_success
    # "Completed task" should be deduplicated even though checkbox differs
    [[ "$output" =~ "New task" ]]
    [[ ! "$output" =~ "Completed task" ]]
}

@test "deduplicate_tasks handles empty existing" {
    local new="- [ ] Task one
- [ ] Task two"

    run deduplicate_tasks "" "$new"

    assert_success
    # All tasks should be output
    [[ "$output" =~ "Task one" ]]
    [[ "$output" =~ "Task two" ]]
}

# =============================================================================
# FIX_PLAN MERGING (4 tests)
# =============================================================================

@test "merge_fix_plan preserves completed tasks" {
    cat > fix_plan.md << 'EOF'
# Ralph Fix Plan

## High Priority
- [ ] Existing high task

## Medium Priority
- [ ] Existing medium task

## Low Priority

## Completed
- [x] Finished task 1
- [x] Finished task 2
EOF

    local new_tasks="- [ ] New task 1
- [ ] New task 2"

    run merge_fix_plan "fix_plan.md" "$new_tasks" "high"

    assert_success
    # Check completed tasks are preserved
    [[ "$output" =~ "Finished task 1" ]]
    [[ "$output" =~ "Finished task 2" ]]
    # Check new tasks added
    [[ "$output" =~ "New task 1" ]]
    [[ "$output" =~ "New task 2" ]]
}

@test "merge_fix_plan adds tasks to specified section" {
    cat > fix_plan.md << 'EOF'
# Ralph Fix Plan

## High Priority
- [ ] High task

## Medium Priority

## Low Priority

## Completed
EOF

    local new_tasks="- [ ] New medium task"

    run merge_fix_plan "fix_plan.md" "$new_tasks" "medium"

    assert_success
    # New task should appear in output
    [[ "$output" =~ "New medium task" ]]
}

@test "merge_fix_plan handles empty new tasks" {
    cat > fix_plan.md << 'EOF'
# Ralph Fix Plan

## High Priority
- [ ] Existing task

## Completed
- [x] Done task
EOF

    run merge_fix_plan "fix_plan.md" "" "high"

    assert_success
    # Existing content should be preserved
    [[ "$output" =~ "Existing task" ]]
    [[ "$output" =~ "Done task" ]]
}

@test "merge_fix_plan returns error for missing file" {
    run merge_fix_plan "nonexistent.md" "- [ ] Task" "high"
    assert_failure
}

# =============================================================================
# UNIQUE TASK COUNT (2 tests)
# =============================================================================

@test "get_unique_task_count counts unique tasks correctly" {
    cat > fix_plan.md << 'EOF'
# Ralph Fix Plan

## High Priority
- [ ] Existing task

## Completed
EOF

    local new_tasks="- [ ] Existing task
- [ ] New task 1
- [ ] New task 2"

    run get_unique_task_count "fix_plan.md" "$new_tasks"

    assert_success
    # Should output 2 (only new tasks, not existing)
    assert_output "2"
}

@test "get_unique_task_count returns 0 for all duplicates" {
    cat > fix_plan.md << 'EOF'
# Ralph Fix Plan

## High Priority
- [ ] Task A
- [ ] Task B

## Completed
EOF

    local new_tasks="- [ ] Task A
- [ ] Task B"

    run get_unique_task_count "fix_plan.md" "$new_tasks"

    assert_success
    assert_output "0"
}
