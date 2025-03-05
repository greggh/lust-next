#!/bin/bash
# Wrapper script for running lust tests

# Ensure script is run from the project root
if [ ! -f "./lust.lua" ]; then
    echo "Error: This script must be run from the lust project root"
    echo "Usage: ./scripts/run_tests.sh [options]"
    echo ""
    echo "Options:"
    echo "  --dir DIR       Specify test directory (default: ./tests)"
    echo "  --pattern PAT   Specify test file pattern (default: *_test.lua)"
    echo "  --individual    Run each test file individually (legacy mode)"
    exit 1
fi

# Process arguments as before, then pass them to the Lua runner script
TEST_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            TEST_ARGS+=("--dir" "$2")
            shift 2
            ;;
        --pattern)
            TEST_ARGS+=("--pattern" "$2")
            shift 2
            ;;
        --individual)
            # Legacy mode: Run each test file individually
            # Find all test files
            TEST_DIR="${TEST_ARGS[1]:-./tests}"
            PATTERN="${TEST_ARGS[3]:-*_test.lua}"
            
            echo "Running tests individually (legacy mode)..."
            echo "-----------------------"
            
            test_files=$(find "$TEST_DIR" -name "$PATTERN" 2>/dev/null)
            
            if [ -z "$test_files" ]; then
                echo "No test files found in $TEST_DIR matching $PATTERN"
                exit 1
            fi
            
            # Run each test file
            for test_file in $test_files; do
                echo "Running $test_file"
                lua "$test_file"
                if [ $? -ne 0 ]; then
                    echo "Test failed: $test_file"
                    exit 1
                fi
                echo ""
            done
            
            echo "All tests passed!"
            exit 0
            ;;
        *)
            # Unknown option, pass it to the Lua script
            TEST_ARGS+=("$1")
            shift
            ;;
    esac
done

# Run the Lua test runner
lua "./scripts/run_tests.lua" "${TEST_ARGS[@]}"