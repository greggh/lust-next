# Phase 2: Test Content Organization Plan

## Overview

This document outlines the plan for Phase 2 of the test system reorganization, which focuses on properly organizing test content. Phase 1 has successfully enhanced the generic runner (`scripts/runner.lua`) and created a central CLI (`test.lua`). Phase 2 will now focus on moving special test logic into standard test files and organizing the test content in a more logical structure.

## Goals

1. Move special test logic into standard test files
2. Organize tests into logical directories
3. Ensure all test files use the standard describe/it pattern
4. Move configuration into test files using `before` hooks
5. Create comprehensive test suite file(s)

## Implementation Plan

### Step 1: Identify Special-Purpose Test Files

Current special-purpose test files that need restructuring:

1. `/home/gregg/Projects/lua-library/lust-next/run-instrumentation-tests.lua`
2. `/home/gregg/Projects/lua-library/lust-next/run-single-test.lua`

### Step 2: Create Logical Directory Structure

Create the following directory structure for better organization:

```
tests/
├── core/            # Core framework tests 
├── coverage/        # Coverage-related tests
│   ├── instrumentation/  # Instrumentation-specific tests
│   └── hooks/           # Debug hook tests
├── quality/         # Quality validation tests
├── reporting/       # Report generation tests
│   └── formatters/      # Formatter-specific tests
├── tools/           # Utility module tests
│   ├── filesystem/      # Filesystem module tests
│   ├── logging/         # Logging module tests
│   └── watcher/         # File watcher tests
└── integration/     # Cross-component integration tests
```

### Step 3: Move Special Test Logic

1. **Instrumentation Tests**:
   - Create `tests/coverage/instrumentation/instrumentation_test.lua`
   - Move test logic from `run-instrumentation-tests.lua` to the new file
   - Ensure the new test file uses standard describe/it pattern
   - Move configuration into `before` hooks

2. **Single Test Logic**:
   - Create `tests/coverage/instrumentation/single_test.lua`
   - Move test logic from `run-single-test.lua` to the new file
   - Ensure the new test file uses standard describe/it pattern
   - Move configuration into `before` hooks

### Step 4: Add Configuration via Hooks

Ensure all tests use proper configuration via hooks:

```lua
-- Example of moving configuration into before hooks
describe("Instrumentation module tests", function()
  -- Set up configuration before each test suite
  before(function()
    -- Configure coverage
    coverage.init({
      enabled = true,
      use_instrumentation = true,
      instrument_on_load = true,
      use_static_analysis = true,
      track_blocks = true,
      cache_instrumented_files = false
    })
    
    -- Start coverage tracking
    coverage.start()
  end)
  
  -- Clean up after each test suite
  after(function()
    -- Stop coverage tracking
    coverage.stop()
  end)
  
  -- Test cases go here...
end)
```

### Step 5: Create Comprehensive Test Suite File

Create a file that runs all test files:

```lua
-- tests/all_tests.lua
local lust = require("lust-next")

-- Core tests
describe("Core functionality tests", function()
  require("tests.core.assertions_test")
  require("tests.core.expect_test")
  require("tests.core.hooks_test")
  -- ...
end)

-- Coverage tests
describe("Coverage tests", function()
  require("tests.coverage.coverage_test")
  require("tests.coverage.instrumentation.instrumentation_test")
  require("tests.coverage.hooks.debug_hook_test")
  -- ...
end)

-- And so on for other test categories...
```

## Verification

After implementing these changes, verify that:

1. All tests can be run through the new `test.lua` script
2. Tests continue to pass with proper hooks execution
3. Test organization is logical and maintainable
4. Special-purpose test logic is properly integrated into standard test files

## Timeline

1. **Directory Structure Creation**: 1 hour
2. **Instrumentation Test Migration**: 2-3 hours
3. **Single Test Migration**: 1-2 hours
4. **Hook Configuration**: 1-2 hours
5. **All Tests Suite Creation**: 1 hour

Total estimated time: 6-9 hours