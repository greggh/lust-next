# Interactive CLI Examples

This document provides practical examples of using the Firmo interactive CLI for various testing scenarios and workflows. These examples demonstrate how to use the CLI effectively for test development, debugging, and maintenance.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Test Running Examples](#test-running-examples)
- [Test Filtering Examples](#test-filtering-examples)
- [Watch Mode Examples](#watch-mode-examples)
- [Codefix Integration Examples](#codefix-integration-examples)
- [Custom Configuration Examples](#custom-configuration-examples)
- [Programmatic Usage Examples](#programmatic-usage-examples)
- [Complete Workflow Examples](#complete-workflow-examples)

## Basic Usage

### Example 1: Starting the Interactive CLI

```lua
local firmo = require("firmo")
local interactive = require("lib.tools.interactive")

-- Start the interactive CLI with default configuration
interactive.start(firmo)
```

### Example 2: Basic Command Sequence

Once the CLI is running, you can enter commands at the prompt:

```
-- View available commands
> help

-- See current configuration
> status

-- List available test files
> list

-- Run all tests
> run

-- Exit the CLI
> exit
```

## Test Running Examples

### Example 3: Running Specific Tests

```
-- Run a specific test file by path
> run tests/utils/string_utils_test.lua

-- Run a test file by index from the list
> list
Available test files:
  1. tests/core/config_test.lua
  2. tests/core/lifecycle_test.lua
  3. tests/utils/string_utils_test.lua
  
> run 3  -- Runs string_utils_test.lua
```

### Example 4: Configuring Test Location

```
-- Change the test directory
> dir tests/unit

-- List tests in the new directory
> list

-- Change the test file pattern
> pattern *_spec.lua

-- List tests with the new pattern
> list
```

### Example 5: Running Test Suites

```
-- Run all core tests
> dir tests/core
> run

-- Run all utility tests
> dir tests/utils
> run

-- Return to running all tests
> dir tests
> run
```

## Test Filtering Examples

### Example 6: Filtering by Test Name

```
-- Filter tests containing "validation"
> filter validation

-- Run the filtered tests
> run

-- Clear the filter
> filter
```

### Example 7: Focusing on Specific Tests

```
-- Focus on tests containing "should handle errors"
> focus "should handle errors"

-- Run the focused tests
> run

-- Clear the focus
> focus
```

### Example 8: Using Tag Filters

```
-- Run tests with "unit" tag
> tags unit

-- Run tests with both "unit" and "fast" tags
> tags unit,fast

-- Clear tag filters
> tags
```

### Example 9: Combined Filtering

You can combine multiple filter types:

```
-- Focus on error handling in unit tests
> focus "error"
> tags unit

-- Run the filtered tests
> run

-- Clear all filters
> focus
> tags
```

## Watch Mode Examples

### Example 10: Basic Watch Mode

```
-- Enable watch mode
> watch on

-- Wait for file changes
-- (Tests will automatically run when files change)

-- Press Enter to return to the prompt
> watch off
```

### Example 11: Configuring Watch Directories

```
-- Add source directory to watch list
> watch-dir src

-- Add tests directory to watch list
> watch-dir tests

-- Exclude certain directories
> watch-exclude node_modules
> watch-exclude %.git

-- Enable watch mode with these settings
> watch on
```

### Example 12: Focused Watching

```
-- Focus on specific tests
> focus "string utils"

-- Set tag filter
> tags unit

-- Enable watch mode with filters active
> watch on

-- Only the focused and tagged tests will run when files change
```

## Codefix Integration Examples

### Example 13: Checking Code Quality

```
-- Check code quality in source directory
> codefix check src

-- Check a specific file
> codefix check src/utils/string_utils.lua
```

### Example 14: Fixing Code Quality Issues

```
-- Fix code quality issues in source directory
> codefix fix src

-- Fix a specific file
> codefix fix src/utils/string_utils.lua
```

### Example 15: Combining Codefix with Testing

```
-- Fix code issues
> codefix fix src

-- Run tests to verify fixes didn't break anything
> run

-- Enable watch mode to monitor for regressions
> watch on
```

## Custom Configuration Examples

### Example 16: Simple Custom Configuration

```lua
local firmo = require("firmo")
local interactive = require("lib.tools.interactive")

-- Configure with custom settings
interactive.configure({
  test_dir = "tests/unit",
  test_pattern = "*_test.lua",
  watch_mode = true,
  colorized_output = true
})

-- Start with custom configuration
interactive.start(firmo)
```

### Example 17: Comprehensive Configuration

```lua
local firmo = require("firmo")
local interactive = require("lib.tools.interactive")

-- Configure with detailed settings
interactive.configure({
  -- Test configuration
  test_dir = "tests",
  test_pattern = "*_test.lua",
  
  -- Watch configuration
  watch_mode = true,
  watch_dirs = { "src", "tests", "lib" },
  watch_interval = 0.5,
  exclude_patterns = { 
    "node_modules", 
    "%.git", 
    "%.vscode", 
    "%.idea", 
    "build",
    "dist"
  },
  
  -- UI configuration
  colorized_output = true,
  prompt_symbol = "$",
  max_history = 200,
  
  -- Debug configuration
  debug = false,
  verbose = true
})

-- Start with detailed configuration
interactive.start(firmo)
```

### Example 18: Using Central Configuration

```lua
local firmo = require("firmo")
local interactive = require("lib.tools.interactive")
local central_config = require("lib.core.central_config")

-- Set configuration in central_config
central_config.set("interactive", {
  test_dir = "tests",
  watch_mode = true,
  watch_dirs = { "src", "tests" },
  exclude_patterns = { "node_modules", "%.git" },
  colorized_output = true
})

-- Interactive will automatically use central_config settings
interactive.start(firmo)
```

## Programmatic Usage Examples

### Example 19: Running Tests Programmatically

```lua
local firmo = require("firmo")
local interactive = require("lib.tools.interactive")

-- Configure interactive module
interactive.configure({
  test_dir = "tests",
  test_pattern = "*_test.lua"
})

-- Programmatically execute commands
local function run_interactive_commands()
  local commands = {
    "dir tests/unit",
    "list",
    "filter validation",
    "run",
    "filter",  -- Clear filter
    "run"
  }
  
  for _, cmd in ipairs(commands) do
    print("Executing: " .. cmd)
    interactive.process_command(cmd)
  end
end

run_interactive_commands()
```

### Example 20: Custom Test Runner Script

```lua
-- test_runner.lua
local firmo = require("firmo")
local interactive = require("lib.tools.interactive")

-- Get command line arguments
local args = {...}
local test_dir = args[1] or "tests"
local pattern = args[2] or "*_test.lua"
local tag_filter = args[3]

-- Configure interactive module
interactive.configure({
  test_dir = test_dir,
  test_pattern = pattern,
  colorized_output = true
})

-- Set tag filter if provided
if tag_filter then
  firmo.filter_tags({tag_filter})
end

-- Discover and run tests
local test_files = firmo.discover_tests(test_dir, pattern)
print("Found " .. #test_files .. " test files")

local success = firmo.run_all(test_files)
if not success then
  os.exit(1)
end
```

Usage:
```
lua test_runner.lua tests/unit "*_test.lua" unit
```

### Example 21: CI Integration Script

```lua
-- ci.lua
local firmo = require("firmo")
local interactive = require("lib.tools.interactive")

-- Configure interactive module for CI environment
interactive.configure({
  test_dir = "tests",
  test_pattern = "*_test.lua",
  colorized_output = false,  -- Better for CI logs
  verbose = true             -- More detailed output
})

-- Run test sequence
local function run_test_sequence()
  print("Running unit tests...")
  interactive.process_command("dir tests/unit")
  local unit_success = interactive.process_command("run")
  
  print("Running integration tests...")
  interactive.process_command("dir tests/integration")
  local integration_success = interactive.process_command("run")
  
  return unit_success and integration_success
end

-- Run tests and exit with appropriate code
local success = run_test_sequence()
os.exit(success and 0 or 1)
```

## Complete Workflow Examples

### Example 22: Test-Driven Development Workflow

```lua
local firmo = require("firmo")
local interactive = require("lib.tools.interactive")

-- Configure for TDD workflow
interactive.configure({
  test_dir = "tests",
  test_pattern = "*_test.lua",
  watch_mode = true,
  watch_dirs = { "src", "tests" },
  watch_interval = 0.5
})

-- Start TDD session
firmo.focus("user authentication")  -- Focus on feature being developed
interactive.start(firmo)

-- TDD Session Commands:
-- > run
-- (Write tests that fail)
-- (Implement code to make tests pass)
-- (Tests automatically rerun when code changes)
-- > codefix fix src
-- (Refactor code while tests verify functionality)
```

### Example 23: Debugging Workflow

```lua
local firmo = require("firmo")
local interactive = require("lib.tools.interactive")

-- Configure for debugging workflow
interactive.configure({
  test_dir = "tests",
  test_pattern = "*_test.lua",
  colorized_output = true,
  verbose = true,
  debug = true  -- Enable detailed debug information
})

-- Start debugging session
interactive.start(firmo)

-- Debugging Session Commands:
-- > focus "failing test"
-- > run
-- (Examine test output for failures)
-- > watch on
-- (Modify code to fix issues)
-- (Tests automatically rerun on changes)
-- > focus  -- Clear focus when fixed
-- > run    -- Verify all tests pass after fix
```

### Example 24: Code Quality Maintenance Workflow

```lua
local firmo = require("firmo")
local interactive = require("lib.tools.interactive")

-- Configure for code quality workflow
interactive.configure({
  test_dir = "tests",
  test_pattern = "*_test.lua"
})

-- Start code quality session
interactive.start(firmo)

-- Code Quality Session Commands:
-- > run
-- (Verify all tests pass)
-- > codefix check src
-- (Identify code quality issues)
-- > codefix fix src
-- (Fix code quality issues)
-- > run
-- (Verify tests still pass after fixes)
-- > watch on
-- (Watch for regressions during further development)
```

These examples demonstrate the flexibility and power of the interactive CLI for various testing scenarios and workflows. By combining different features and commands, you can create an efficient testing environment tailored to your specific needs.