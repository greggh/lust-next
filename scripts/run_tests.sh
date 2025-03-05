#!/bin/bash
# Simple script to run lust tests

# Ensure script is run from the project root
if [ ! -f "./lust.lua" ]; then
    echo "Error: This script must be run from the lust project root"
    echo "Usage: ./scripts/run_tests.sh"
    exit 1
fi

# Find all test files
test_files=$(find ./tests -name "*_test.lua" 2>/dev/null)

if [ -z "$test_files" ]; then
    echo "No test files found in ./tests/"
    exit 1
fi

# Run each test file
echo "Running lust tests..."
echo "-----------------------"
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