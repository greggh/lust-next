# Parallel Testing Examples

This document provides examples of how to use Firmo's parallel testing features.

## Basic Parallel Execution

This example demonstrates the basic setup for parallel test execution:

```lua
-- File: basic_parallel_example.lua
local firmo = require("firmo")
local parallel = require("lib.tools.parallel")

-- Register parallel with Firmo
parallel.register_with_firmo(firmo)

-- Discover test files
local test_files = firmo.discover("./tests", "*_test.lua")

-- Configure parallel execution
parallel.configure({
  workers = 4,
  timeout = 30,
  show_worker_output = true
})

-- Run tests in parallel
local results = parallel.run_tests(test_files)

-- Print summary
print("Test Summary:")
print("  Total tests: " .. results.total)
print("  Passed: " .. results.passed)
print("  Failed: " .. results.failed)
print("  Skipped: " .. results.skipped)
print("  Total time: " .. string.format("%.2f", results.elapsed) .. " seconds")
```

## Performance Comparison

This example compares the performance of sequential vs. parallel test execution:

```lua
-- File: performance_comparison_example.lua
local firmo = require("firmo")
local parallel = require("lib.tools.parallel")
local fs = require("lib.tools.filesystem")

-- Register parallel with Firmo
parallel.register_with_firmo(firmo)

-- Discover test files
local test_files = firmo.discover("./tests", "*_test.lua")

-- Run tests sequentially first
print("Running tests sequentially...")
local sequential_start = os.clock()
for _, file in ipairs(test_files) do
  firmo.reset()
  dofile(file)
end
local sequential_time = os.clock() - sequential_start
print("Sequential execution time: " .. string.format("%.3f", sequential_time) .. " seconds")

-- Now run tests in parallel
print("\nRunning tests in parallel...")
local parallel_start = os.clock()
local results = parallel.run_tests(test_files, {
  workers = 4,
  show_worker_output = false
})
local parallel_time = os.clock() - parallel_start
print("Parallel execution time: " .. string.format("%.3f", parallel_time) .. " seconds")

-- Calculate and show speedup
local speedup = sequential_time / parallel_time
print("\nParallel execution was " .. string.format("%.2fx", speedup) .. " faster")
```

## Custom Test File Creation

This example demonstrates creating test files dynamically and running them in parallel:

```lua
-- File: dynamic_test_files_example.lua
local firmo = require("firmo")
local parallel = require("lib.tools.parallel")
local fs = require("lib.tools.filesystem")

-- Register parallel with Firmo
parallel.register_with_firmo(firmo)

-- Function to create test files
local function create_test_files(dir, count)
  -- Ensure directory exists
  fs.ensure_directory_exists(dir)
  
  -- Create test files
  local files = {}
  for i = 1, count do
    local file_path = fs.join_paths(dir, "test_" .. i .. ".lua")
    
    -- Generate test content
    local content = [[
local firmo = require('firmo')
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe('Test File ]] .. i .. [[', function()
  it('test case 1', function()
    expect(1 + 1).to.equal(2)
  end)
  
  it('test case 2', function()
    expect('hello').to.be.a('string')
  end)
  
  it('test case 3', function()
    expect(true).to.be_truthy()
  end)
end)
]]
    
    -- Write the file
    local success = fs.write_file(file_path, content)
    if success then
      table.insert(files, file_path)
    end
  end
  
  return files
end

-- Create test files
local temp_dir = "/tmp/firmo_parallel_example"
local test_files = create_test_files(temp_dir, 10)
print("Created " .. #test_files .. " test files in " .. temp_dir)

-- Run tests in parallel
local results = parallel.run_tests(test_files, {
  workers = 4,
  show_worker_output = false
})

-- Print summary
print("\nTest Summary:")
print("  Total tests: " .. results.total)
print("  Passed: " .. results.passed)
print("  Failed: " .. results.failed)
print("  Skipped: " .. results.skipped)
print("  Total time: " .. string.format("%.2f", results.elapsed) .. " seconds")

-- Clean up
for _, file in ipairs(test_files) do
  fs.delete_file(file)
end
fs.delete_directory(temp_dir)
```

## Parallel Testing with Coverage

This example shows how to run tests in parallel with coverage enabled:

```lua
-- File: parallel_coverage_example.lua
local firmo = require("firmo")
local parallel = require("lib.tools.parallel")

-- Register parallel with Firmo
parallel.register_with_firmo(firmo)

-- Discover test files
local test_files = firmo.discover("./tests", "*_test.lua")

-- Run tests in parallel with coverage
local results = parallel.run_tests(test_files, {
  workers = 4,
  aggregate_coverage = true,
  coverage = true,  -- Enable coverage tracking
  show_worker_output = false
})

-- Print coverage summary
if results.coverage then
  local total_lines = 0
  local covered_lines = 0
  
  for file_path, file_data in pairs(results.coverage) do
    local file_covered = 0
    local file_total = 0
    
    if file_data.lines then
      for line, count in pairs(file_data.lines) do
        file_total = file_total + 1
        if count > 0 then
          file_covered = file_covered + 1
        end
      end
    end
    
    total_lines = total_lines + file_total
    covered_lines = covered_lines + file_covered
    
    print(file_path .. ": " .. 
      string.format("%.1f%%", (file_covered / math.max(1, file_total)) * 100) .. 
      " (" .. file_covered .. "/" .. file_total .. " lines)")
  end
  
  -- Print overall coverage
  print("\nOverall coverage: " .. 
    string.format("%.1f%%", (covered_lines / math.max(1, total_lines)) * 100) .. 
    " (" .. covered_lines .. "/" .. total_lines .. " lines)")
end
```

## Parallel Testing with Custom Options

This example demonstrates configuring parallel testing with custom options:

```lua
-- File: custom_options_example.lua
local firmo = require("firmo")
local parallel = require("lib.tools.parallel")

-- Register parallel with Firmo
parallel.register_with_firmo(firmo)

-- Configure parallel with custom options
parallel.configure({
  workers = 6,                -- Use 6 worker processes
  timeout = 45,               -- 45 second timeout per file
  output_buffer_size = 20480, -- Larger output buffer
  verbose = true,             -- Enable verbose logging
  show_worker_output = false, -- Hide worker output
  fail_fast = true,           -- Stop on first failure
  aggregate_coverage = true,  -- Combine coverage data
  debug = true                -- Enable debug mode
})

-- Print current configuration
local config = parallel.debug_config()
print("Parallel Configuration:")
for key, value in pairs(config.local_config) do
  if type(value) ~= "table" and type(value) ~= "function" then
    print("  " .. key .. ": " .. tostring(value))
  end
end

-- Discover and run test files
local test_files = firmo.discover("./tests", "*_test.lua")
if #test_files > 0 then
  local results = parallel.run_tests(test_files)
  
  -- Print summary
  print("\nTest Summary:")
  print("  Total tests: " .. results.total)
  print("  Passed: " .. results.passed)
  print("  Failed: " .. results.failed)
  print("  Skipped: " .. results.skipped)
else
  print("No test files found")
end
```

## Using Parallel with Central Configuration

This example shows integration with the central configuration system:

```lua
-- File: central_config_example.lua
local firmo = require("firmo")
local parallel = require("lib.tools.parallel")
local central_config = require("lib.core.central_config")

-- Register parallel with Firmo
parallel.register_with_firmo(firmo)

-- Configure parallel via central configuration
central_config.set("parallel", {
  workers = 8,
  timeout = 30,
  verbose = true,
  show_worker_output = false,
  fail_fast = true
})

-- Verify configuration
local config = parallel.debug_config()
print("Using central configuration: " .. tostring(config.using_central_config))
print("Workers: " .. config.local_config.workers)
print("Timeout: " .. config.local_config.timeout)

-- Discover and run test files
local test_files = firmo.discover("./tests", "*_test.lua")
local results = parallel.run_tests(test_files)

-- Print summary
print("\nTest Summary:")
print("  Total tests: " .. results.total)
print("  Passed: " .. results.passed)
print("  Failed: " .. results.failed)
print("  Skipped: " .. results.skipped)
```

## CLI Example

To run tests in parallel using the command line:

```bash
# Basic parallel execution
lua test.lua --parallel tests/

# Specify number of workers
lua test.lua --parallel --workers 8 tests/

# Set timeout for test files
lua test.lua --parallel --timeout 45 tests/

# Enable verbose output
lua test.lua --parallel --verbose-parallel tests/

# Hide worker output
lua test.lua --parallel --no-worker-output tests/

# Stop on first failure
lua test.lua --parallel --fail-fast tests/

# Run with coverage but don't aggregate results
lua test.lua --parallel --coverage --no-aggregate-coverage tests/
```

## Output Example

When running tests in parallel, the output will look like:

```
$ lua test.lua --parallel --workers 4 tests/

Running 20 test files in parallel with 4 workers...

--- Output from tests/module1_test.lua ---
Test File: tests/module1_test.lua
✓ PASS  should calculate sum
✓ PASS  should handle negative numbers
3 tests complete (0.032s)
--- End output from tests/module1_test.lua ---

--- Output from tests/module2_test.lua ---
Test File: tests/module2_test.lua
✓ PASS  should validate input
✗ FAIL  should reject invalid data
  Expected true to equal false
1 of 2 tests failed (0.028s)
--- End output from tests/module2_test.lua ---

[...more test outputs...]

Parallel Test Summary:
  Files tested: 20
  Total tests: 43
  Passed: 40
  Failed: 2
  Skipped: 1
  Total time: 0.89 seconds

Errors:
  1. In file: tests/module2_test.lua
     Expected true to equal false
  2. In file: tests/module15_test.lua
     Expected nil but got table
```