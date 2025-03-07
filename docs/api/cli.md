
# Command Line Interface

This document describes the command-line interface (CLI) provided by Lust-Next.

## Overview

Lust-Next can be run directly from the command line to discover and run tests. This provides a convenient way to run tests without writing test runner scripts.

## Basic Usage

```bash

# Run all tests in the default directory (./tests)
lua lust-next.lua

# Run tests in a specific directory
lua lust-next.lua --dir path/to/tests

# Run a specific test file
lua lust-next.lua path/to/test_file.lua

```text

## Command Line Options

### --dir DIRECTORY

Specifies the directory to search for test files.

**Default:** `./tests`

**Example:**

```bash
lua lust-next.lua --dir ./src/tests

```text

### --tags TAG1,TAG2,...

Filters tests to only run those with the specified tags. Multiple tags can be specified as a comma-separated list.

**Example:**

```bash

# Run only tests tagged with "unit"
lua lust-next.lua --tags unit

# Run tests tagged with either "fast" or "critical"
lua lust-next.lua --tags fast,critical

```text

### --filter PATTERN

Filters tests to only run those with names matching the specified pattern.

**Example:**

```bash

# Run only tests with "validation" in their name
lua lust-next.lua --filter validation

```text

### --help, -h

Shows the help message with available options.

**Example:**

```bash
lua lust-next.lua --help

```text

## Running a Specific Test File

You can run a specific test file by providing its path as an argument.

**Example:**

```bash
lua lust-next.lua ./tests/user_test.lua

```text

## Combining Options

You can combine multiple options to customize the test run.

**Example:**

```bash

# Run unit tests with "validation" in their name from a specific directory
lua lust-next.lua --dir ./src/tests --tags unit --filter validation

```text

## Exit Codes

Lust-Next sets the process exit code based on the test results:

- **0**: All tests passed
- **1**: One or more tests failed, or an error occurred during test execution

This is useful for integration with CI systems.

## Environment Variables

Lust-Next doesn't use environment variables directly, but you can create wrapper scripts that use environment variables to configure test runs.

**Example:**

```bash
#!/bin/bash

# run_tests.sh

# Get test type from environment variable, default to "unit"
TEST_TYPE=${TEST_TYPE:-unit}

# Run tests with appropriate tags
lua lust-next.lua --tags $TEST_TYPE

```text

Then you can run specific test types with:

```bash
TEST_TYPE=integration ./run_tests.sh

```text

## Examples

### Running All Tests

```bash
lua lust-next.lua

```text

### Running Only Unit Tests

```bash
lua lust-next.lua --tags unit

```text

### Running Tests in a Specific Module

```bash
lua lust-next.lua --filter user

```text

### Combining Tag and Pattern Filters

```bash
lua lust-next.lua --tags unit --filter validation

```text

### Running a Specific Test File

```bash
lua lust-next.lua ./tests/user_test.lua

```text

### Running Tests with Custom Directory

```bash
lua lust-next.lua --dir ./integration_tests

```text

## Integration with Make

You can integrate Lust-Next with Make for more complex test workflows:

```makefile
.PHONY: test test-unit test-integration

test:
 lua lust-next.lua

test-unit:
 lua lust-next.lua --tags unit

test-integration:
 lua lust-next.lua --tags integration

test-coverage:
 luacov && lua lust-next.lua && luacov-console

```text

## Integration with CI Systems

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:

    - uses: actions/checkout@v2

    - name: Set up Lua
      uses: leafo/gh-actions-lua@v8
      with:
        luaVersion: "5.3"

    - name: Install dependencies
      run: |
        luarocks install luafilesystem

    - name: Run unit tests
      run: lua lust-next.lua --tags unit

    - name: Run integration tests
      run: lua lust-next.lua --tags integration

```text

## Creating Custom Test Runners

You can create custom test runners that use Lust-Next's API:

```lua
-- runner.lua
local lust = require("lust-next")

-- Parse command line arguments
local tags, filter, dir = nil, nil, "./tests"

for i = 1, #arg do
  if arg[i] == "--tags" and arg[i+1] then
    tags = {}
    for tag in arg[i+1]:gmatch("[^,]+") do
      table.insert(tags, tag)
    end
    i = i + 1
  elseif arg[i] == "--filter" and arg[i+1] then
    filter = arg[i+1]
    i = i + 1
  elseif arg[i] == "--dir" and arg[i+1] then
    dir = arg[i+1]
    i = i + 1
  end
end

-- Apply filters
if tags then
  lust.only_tags(unpack(tags))
end

if filter then
  lust.filter(filter)
end

-- Run tests
local results = lust.run_discovered(dir)

-- Print custom summary
print("\n========== TEST SUMMARY ==========")
print("Files:  " .. results.passed_files .. "/" .. results.total_files .. " passed")
print("Tests:  " .. results.passed_tests .. "/" .. results.total_tests .. " passed")
if results.skipped_tests > 0 then
  print("Skipped: " .. results.skipped_tests)
end
print("===================================")

-- Exit with appropriate code
os.exit(results.failed_tests == 0 and 0 or 1)

```text

You can then run this custom runner:

```bash
lua runner.lua --tags unit --filter validation

```text

## Best Practices

1. **Use Tags Consistently**: Establish a convention for tag names (e.g., "unit", "integration", "slow") and use them consistently.

1. **Group Related Options**: When running tests, group related command-line options together for clarity.

1. **CI Integration**: Set up your CI system to run different test subsets using tags.

1. **Exit Codes**: Use exit codes in scripts to indicate test success or failure.

1. **Custom Runners**: For complex requirements, create custom test runners using the Lust-Next API.

