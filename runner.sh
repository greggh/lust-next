#!/bin/bash

# Generic test runner for lust-next
# Usage: runner.sh [test_file] [additional_arguments]
# Example: runner.sh tests/coverage_error_handling_test.lua --verbose

# Set working directory to project root
cd "$(dirname "$0")"

# Default to running all tests if no file specified
TEST_PATH=${1:-"tests/"}

# If the first argument is a test file, shift it off and pass remaining args
if [ -n "$1" ]; then
  shift
fi

# Run the test with all remaining arguments
lua test.lua "$TEST_PATH" "$@"

# Display completion message
echo ""
echo "Test execution complete."