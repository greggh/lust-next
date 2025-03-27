# Test Discovery Examples

This document provides practical examples of using the Test Discovery module in Firmo. These examples demonstrate common use cases and patterns for finding and working with test files.

## Basic Discovery

### Finding All Tests in the Default Directory

```lua
-- discover_basic.lua
local discover = require("lib.tools.discover")

-- Find all test files in the default "tests" directory
local result, err = discover.discover()

if err then
  print("Error discovering tests: " .. err.message)
  os.exit(1)
end

print("Found " .. result.matched .. " test files:")
for i, file in ipairs(result.files) do
  print(i .. ". " .. file)
end
```

### Finding Tests in a Specific Directory

```lua
-- discover_directory.lua
local discover = require("lib.tools.discover")

-- Specify a different directory
local result, err = discover.discover("tests/unit")

if err then
  print("Error discovering tests: " .. err.message)
  os.exit(1)
end

print("Found " .. result.matched .. " tests in unit directory:")
for i, file in ipairs(result.files) do
  print(i .. ". " .. file)
end
```

### Finding Tests Matching a Pattern

```lua
-- discover_pattern.lua
local discover = require("lib.tools.discover")

-- Find tests matching "user" in their path
local result, err = discover.discover("tests", "user")

if err then
  print("Error discovering tests: " .. err.message)
  os.exit(1)
end

print("Found " .. result.matched .. " user-related tests:")
for i, file in ipairs(result.files) do
  print(i .. ". " .. file)
end
```

## Configuring Discovery

### Custom Test Patterns

```lua
-- discover_custom_patterns.lua
local discover = require("lib.tools.discover")

-- Configure with custom patterns
discover.configure({
  include = {"*_test.lua", "test_*.lua", "check_*.lua"},
  exclude = {"*_fixture.lua", "*_helper.lua"}
})

local result, err = discover.discover("tests")

if err then
  print("Error discovering tests: " .. err.message)
  os.exit(1)
end

print("Found " .. result.matched .. " tests with custom patterns:")
for i, file in ipairs(result.files) do
  print(i .. ". " .. file)
end
```

### Method Chaining Configuration

```lua
-- discover_chaining.lua
local discover = require("lib.tools.discover")

-- Use method chaining to configure
discover.configure({recursive = true})
        .add_include_pattern("integration_*.lua")
        .add_exclude_pattern("*_wip.lua")

local result, err = discover.discover("tests")

if err then
  print("Error discovering tests: " .. err.message)
  os.exit(1)
end

print("Found " .. result.matched .. " tests with chained configuration:")
for i, file in ipairs(result.files) do
  print(i .. ". " .. file)
end
```

## Checking Individual Files

```lua
-- discover_check_files.lua
local discover = require("lib.tools.discover")

-- Sample files to check
local files = {
  "src/utils.lua",
  "tests/user_test.lua",
  "tests/helpers/test_helper.lua",
  "tests/integration_auth.lua",
  "tests/test_login.lua"
}

-- Configure with custom patterns
discover.configure({
  include = {"*_test.lua", "test_*.lua", "integration_*.lua"},
  exclude = {"*_helper.lua"}
})

print("Checking files against test patterns:")
for _, file in ipairs(files) do
  if discover.is_test_file(file) then
    print("✓ " .. file .. " IS a test file")
  else
    print("✗ " .. file .. " is NOT a test file")
  end
end
```

## Advanced Usage

### Building a Test Summary Report

```lua
-- discover_test_summary.lua
local discover = require("lib.tools.discover")
local fs = require("lib.tools.filesystem")

-- Configure discovery
discover.configure({
  include = {"*_test.lua", "test_*.lua"},
  recursive = true
})

-- Discover all test files
local result, err = discover.discover("tests")

if err then
  print("Error discovering tests: " .. err.message)
  os.exit(1)
end

-- Group tests by directory
local tests_by_directory = {}
for _, file in ipairs(result.files) do
  -- Get directory path (everything before the last slash)
  local dir = file:match("(.+)/[^/]+$") or ""
  
  if not tests_by_directory[dir] then
    tests_by_directory[dir] = {}
  end
  table.insert(tests_by_directory[dir], file)
end

-- Print summary
print("TEST SUITE SUMMARY")
print("==================")
print("Total test files: " .. result.matched)

-- Get directories in sorted order
local directories = {}
for dir in pairs(tests_by_directory) do
  table.insert(directories, dir)
end
table.sort(directories)

-- Print tests by directory
for _, dir in ipairs(directories) do
  local tests = tests_by_directory[dir]
  print("\n" .. dir .. " (" .. #tests .. " tests):")
  
  for _, test_file in ipairs(tests) do
    -- Get just the filename
    local filename = test_file:match("([^/]+)$")
    
    -- Get file size
    local size = fs.get_file_size(test_file)
    local size_str = size and string.format("%.1f KB", size / 1024) or "unknown"
    
    print("  - " .. filename .. " (" .. size_str .. ")")
  end
end
```

### Custom Test Runner with Discovery

```lua
-- discover_test_runner.lua
local discover = require("lib.tools.discover")

local function run_test_file(file_path)
  print("\nRunning " .. file_path)
  
  -- Record the current environment
  local old_env = {}
  for k, v in pairs(_G) do
    old_env[k] = v
  end
  
  -- Create a clean test environment
  local test_env = setmetatable({}, {__index = _G})
  
  -- Track test results
  test_env.tests_run = 0
  test_env.tests_passed = 0
  test_env.tests_failed = 0
  
  -- Simple test function
  test_env.test = function(name, fn)
    test_env.tests_run = test_env.tests_run + 1
    local success, err = pcall(fn)
    
    if success then
      print("  ✓ " .. name)
      test_env.tests_passed = test_env.tests_passed + 1
    else
      print("  ✗ " .. name .. " - " .. tostring(err))
      test_env.tests_failed = test_env.tests_failed + 1
    end
  end
  
  -- Run the test in the custom environment
  local fn, err = loadfile(file_path)
  if not fn then
    print("Error loading test file: " .. tostring(err))
    return {run = 0, passed = 0, failed = 0, error = err}
  end
  
  setfenv(fn, test_env)
  
  local success, err = pcall(fn)
  if not success then
    print("Error executing test file: " .. tostring(err))
    return {run = 0, passed = 0, failed = 1, error = err}
  end
  
  return {
    run = test_env.tests_run,
    passed = test_env.tests_passed,
    failed = test_env.tests_failed
  }
end

local function run_tests(directory, pattern)
  -- Discover test files
  local result, err = discover.discover(directory, pattern)
  if err then
    print("Error discovering tests: " .. err.message)
    return false
  end
  
  if result.matched == 0 then
    print("No matching test files found")
    return true
  end
  
  print("\n=========================")
  print("Running " .. result.matched .. " test files...")
  print("=========================")
  
  -- Run each test file
  local total_run = 0
  local total_passed = 0
  local total_failed = 0
  local failed_files = {}
  
  for _, file in ipairs(result.files) do
    local results = run_test_file(file)
    
    total_run = total_run + results.run
    total_passed = total_passed + results.passed
    total_failed = total_failed + results.failed
    
    if results.failed > 0 or results.error then
      table.insert(failed_files, file)
    end
  end
  
  -- Print summary
  print("\n=========================")
  print("SUMMARY")
  print("=========================")
  print("Files: " .. result.matched .. " total, " .. 
        (result.matched - #failed_files) .. " passed, " .. 
        #failed_files .. " failed")
  print("Tests: " .. total_run .. " total, " .. 
        total_passed .. " passed, " .. 
        total_failed .. " failed")
  
  if #failed_files > 0 then
    print("\nFailed files:")
    for _, file in ipairs(failed_files) do
      print("  - " .. file)
    end
  end
  
  return total_failed == 0
end

-- Run all tests in a directory
local success = run_tests("tests", nil)
if not success then
  os.exit(1)
end
```

### Integration with File Watcher

```lua
-- discover_watch.lua
local discover = require("lib.tools.discover")
local watcher = require("lib.tools.watcher")

-- Configure discovery
discover.configure({
  include = {"*_test.lua", "test_*.lua"},
  recursive = true
})

-- Find all test files
local result, err = discover.discover("tests")
if err then
  print("Error discovering tests: " .. err.message)
  os.exit(1)
end

print("Watching for changes in source files...")
print("Found " .. result.matched .. " test files")

-- Map source files to test files (simplified approach)
local source_to_tests = {}

-- Helper to run a test file
local function run_test(file)
  print("\nRunning test: " .. file)
  os.execute("lua " .. file)
end

-- Find corresponding test for a source file (simplified)
local function find_tests_for_source(source_file)
  -- Extract the base name without extension
  local base_name = source_file:match("([^/]+)%.lua$")
  if not base_name then
    return {}
  end
  
  -- Look for test files that might be related
  local matching_tests = {}
  for _, test_file in ipairs(result.files) do
    if test_file:match(base_name) then
      table.insert(matching_tests, test_file)
    end
  end
  
  return matching_tests
end

-- Create a watcher for source files
watcher.create()
       :add_pattern("src/**.lua")
       :on_change(function(file)
         print("\nSource file changed: " .. file)
         local tests = find_tests_for_source(file)
         
         if #tests == 0 then
           print("No matching tests found for " .. file)
         else
           print("Running " .. #tests .. " matching tests:")
           for _, test in ipairs(tests) do
             run_test(test)
           end
         end
       end)
       :start()

-- This script would run until interrupted
print("Watching for changes. Press Ctrl+C to stop.")
while true do
  os.execute("sleep 1")
end
```

## Complete Example: Test Organization Tool

```lua
-- discover_organize.lua
local discover = require("lib.tools.discover")
local fs = require("lib.tools.filesystem")

-- Configuration
local source_dir = "src"
local test_dir = "tests"
local create_missing = true

-- Configure discovery
discover.configure({
  include = {"*_test.lua", "test_*.lua"},
  recursive = true
})

-- Step 1: Discover all source files
local source_files = fs.list_files_recursive(source_dir, "%.lua$")
print("Found " .. #source_files .. " source files")

-- Step 2: Discover all test files
local result, err = discover.discover(test_dir)
if err then
  print("Error discovering tests: " .. err.message)
  os.exit(1)
end
print("Found " .. result.matched .. " test files")

-- Step 3: Map source files to expected test files
local source_to_expected_test = {}
local missing_tests = {}

for _, source_file in ipairs(source_files) do
  -- Skip non-lua files and special files
  if source_file:match("%.lua$") and not source_file:match("init%.lua$") then
    -- Extract module name and path
    local rel_path = source_file:sub(#source_dir + 2) -- Remove source_dir prefix
    local expected_test = test_dir .. "/" .. rel_path:gsub("%.lua$", "_test.lua")
    
    source_to_expected_test[source_file] = expected_test
    
    -- Check if test exists
    local test_exists = false
    for _, test_file in ipairs(result.files) do
      if test_file == expected_test then
        test_exists = true
        break
      end
    end
    
    if not test_exists then
      table.insert(missing_tests, {
        source = source_file,
        expected_test = expected_test
      })
    end
  end
end

-- Step 4: Report missing tests
print("\nMissing tests: " .. #missing_tests)
for i, info in ipairs(missing_tests) do
  print(i .. ". Missing: " .. info.expected_test .. " (for " .. info.source .. ")")
  
  -- Create test file stub if requested
  if create_missing then
    -- Create directory if needed
    local dir = info.expected_test:match("(.+)/[^/]+$")
    if not fs.is_directory(dir) then
      fs.create_directory(dir)
    end
    
    -- Create basic test file
    local module_path = info.source:sub(#source_dir + 2):gsub("%.lua$", ""):gsub("/", ".")
    local test_content = string.format([[
-- Auto-generated test file for %s
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import the module under test
local module = require("%s")

describe("%s", function()
  it("should be properly initialized", function()
    expect(module).to.exist()
    -- Add more tests here
  end)
  
  -- Add more test blocks here
end)
]], info.source, module_path, module_path)

    local file = io.open(info.expected_test, "w")
    if file then
      file:write(test_content)
      file:close()
      print("  Created test stub: " .. info.expected_test)
    else
      print("  Failed to create test stub: " .. info.expected_test)
    end
  end
end

-- Step 5: Find orphaned tests (tests without corresponding source)
local orphaned_tests = {}

for _, test_file in ipairs(result.files) do
  -- Try to derive the source file path
  local source_path = test_file:gsub("^" .. test_dir, source_dir)
  source_path = source_path:gsub("_test%.lua$", ".lua")
  
  local source_exists = false
  for _, source_file in ipairs(source_files) do
    if source_file == source_path then
      source_exists = true
      break
    end
  end
  
  if not source_exists then
    table.insert(orphaned_tests, {
      test = test_file,
      expected_source = source_path
    })
  end
end

-- Report orphaned tests
print("\nOrphaned tests: " .. #orphaned_tests)
for i, info in ipairs(orphaned_tests) do
  print(i .. ". Orphaned: " .. info.test .. " (missing source: " .. info.expected_source .. ")")
end

print("\nSummary:")
print("- Source files: " .. #source_files)
print("- Test files: " .. result.matched)
print("- Missing tests: " .. #missing_tests)
print("- Orphaned tests: " .. #orphaned_tests)
print("- Test coverage: " .. string.format("%.1f%%", 
  (#source_files - #missing_tests) / #source_files * 100))
```

## Conclusion

These examples demonstrate the many ways you can use the Test Discovery module in Firmo. From simple test finding to complex test management tools, the discovery module provides a flexible foundation for working with test files programmatically.