# Temporary File Management System Plan

## Overview

This document outlines a plan to implement a centralized temporary file management system for Firmo tests. The goal is to ensure that all temporary files and directories created during tests are automatically tracked and cleaned up, regardless of test success or failure.

## Problem Statement

The current system has several issues:

1. **Accumulated temporary files**: Tests leave behind many temporary files in `/tmp` (over 1000 observed)
2. **Inconsistent cleanup**: Tests are responsible for their own cleanup, which is often incomplete
3. **Manual tracking burden**: Each test must manually track and cleanup files
4. **No automatic cleanup on failure**: Failed tests often leave files behind
5. **No centralized management**: The `temp_file.lua` module provides helpers but doesn't track or ensure cleanup
6. **Dynamic file creation**: Tests create files at multiple points during execution, making tracking difficult

## Solution Goals

The proposed system will:

1. **Automatically track** all temporary files and directories created by tests
2. **Support dynamic file creation** throughout test execution
3. **Automatically clean up** after each test, regardless of success or failure
4. **Provide intuitive helpers** that minimize boilerplate code in tests
5. **Handle edge cases** like test failures and manually created files
6. **Integrate with the test runner** for seamless operation

## Implementation Components

### 1. Enhanced Temporary File Module

#### Extension to `lib/tools/temp_file.lua`:

```lua
-- Inside temp_file.lua

-- Global registry of temporary files by test context
local _temp_file_registry = setmetatable({}, {__mode = "k"}) -- Weak keys

-- Get current test context (from firmo runner)
local function get_current_test_context()
  -- Get from firmo.get_current_test() or similar
  return firmo._current_test_context or "_global_"
end

-- Register a file with the current test context
function M.register_file(file_path)
  local context = get_current_test_context()
  _temp_file_registry[context] = _temp_file_registry[context] or {}
  table.insert(_temp_file_registry[context], file_path)
  return file_path
end

-- Register a directory with the current test context
function M.register_directory(dir_path)
  local context = get_current_test_context()
  _temp_file_registry[context] = _temp_file_registry[context] or {}
  -- Adding a trailing slash to identify directories for cleanup order purposes
  table.insert(_temp_file_registry[context], dir_path .. "/")
  return dir_path
end

-- Enhanced create_with_content that registers the file
local original_create_with_content = M.create_with_content
function M.create_with_content(content, extension)
  local temp_path, err = original_create_with_content(content, extension)
  if temp_path then
    M.register_file(temp_path)
  end
  return temp_path, err
end

-- Create a temporary directory
function M.create_temp_directory()
  local temp_dir = os.tmpname() .. "_dir"
  local success, err = fs.create_directory(temp_dir)
  if not success then
    return nil, err
  end
  return M.register_directory(temp_dir)
end

-- Clean up all files for a test context
function M.cleanup_test_context(context)
  context = context or get_current_test_context()
  local files = _temp_file_registry[context] or {}
  local errors = {}
  
  -- Sort files so directories (ending with /) are removed after their contents
  table.sort(files, function(a, b)
    local a_is_dir = a:sub(-1) == "/"
    local b_is_dir = b:sub(-1) == "/"
    if a_is_dir == b_is_dir then
      return #a > #b  -- Longer paths first (deeper nested files)
    else
      return b_is_dir  -- Directories last
    end
  end)
  
  for i, path in ipairs(files) do
    local success, err = pcall(function()
      local is_dir = path:sub(-1) == "/"
      if is_dir then
        -- Remove trailing slash for actual operations
        fs.remove_directory(path:sub(1, -2))
      else
        fs.delete_file(path)
      end
    end)
    
    if not success then
      table.insert(errors, {path = path, error = err})
    end
  end
  
  -- Clear the registry for this context
  _temp_file_registry[context] = nil
  
  if #errors > 0 then
    local logger = logging.get_logger("temp_file")
    if logger then
      logger.warn("Failed to clean up some temporary files", {
        context = tostring(context),
        errors = errors
      })
    end
  end
  
  return #errors == 0, errors
end

-- Get statistics about temporary files
function M.get_stats()
  local stats = {
    contexts = 0,
    total_files = 0,
    files_by_context = {}
  }
  
  for context, files in pairs(_temp_file_registry) do
    stats.contexts = stats.contexts + 1
    stats.files_by_context[tostring(context)] = #files
    stats.total_files = stats.total_files + #files
  end
  
  return stats
end

-- Clean up all temporary files across all contexts
function M.cleanup_all()
  local stats = M.get_stats()
  local errors = {}
  
  for context, _ in pairs(_temp_file_registry) do
    local success, context_errors = M.cleanup_test_context(context)
    if not success and context_errors then
      for _, err in ipairs(context_errors) do
        table.insert(errors, err)
      end
    end
  end
  
  return #errors == 0, errors, stats
end
```

### 2. Test Helpers for Dynamic File Creation

#### Addition to `lib/tools/test_helper.lua`:

```lua
-- Inside test_helper.lua
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

-- Helper to create a temporary directory that tests can use throughout their execution
function helper.create_temp_test_directory()
  -- Create a temporary directory
  local dir_path, err = temp_file.create_temp_directory()
  if not dir_path then
    error("Failed to create temp test directory: " .. tostring(err))
  end
  
  -- Return a directory context with helper functions
  return {
    -- Full path to the temporary directory
    path = dir_path,
    
    -- Helper to create a file in this directory
    create_file = function(file_name, content)
      local file_path = dir_path .. "/" .. file_name
      
      -- Ensure parent directories exist
      local dir_name = file_path:match("(.+)/[^/]+$")
      if dir_name and dir_name ~= dir_path then
        local success, mkdir_err = fs.create_directory(dir_name)
        if not success then
          error("Failed to create parent directory: " .. dir_name .. ", error: " .. tostring(mkdir_err))
        end
        -- Register the created directory
        temp_file.register_directory(dir_name)
      end
      
      -- Write the file
      local success, write_err = fs.write_file(file_path, content)
      if not success then
        error("Failed to create test file: " .. file_path .. ", error: " .. tostring(write_err))
      end
      
      -- Register the file with temp_file tracking system
      temp_file.register_file(file_path)
      
      return file_path
    end,
    
    -- Helper to create a subdirectory
    create_subdirectory = function(subdir_name)
      local subdir_path = dir_path .. "/" .. subdir_name
      local success, err = fs.create_directory(subdir_path)
      if not success then
        error("Failed to create test subdirectory: " .. subdir_path .. ", error: " .. tostring(err))
      end
      
      -- Register the directory with temp_file tracking system
      temp_file.register_directory(subdir_path)
      
      return subdir_path
    end,
    
    -- Helper to check if a file exists in this directory
    file_exists = function(file_name)
      return fs.file_exists(dir_path .. "/" .. file_name)
    end,
    
    -- Helper to read a file from this directory
    read_file = function(file_name)
      return fs.read_file(dir_path .. "/" .. file_name)
    end,
    
    -- Helper to generate a unique filename in the test directory
    unique_filename = function(prefix, extension)
      prefix = prefix or "temp"
      extension = extension or "tmp"
      
      local timestamp = os.time()
      local random = math.random(10000, 99999)
      return prefix .. "_" .. timestamp .. "_" .. random .. "." .. extension
    end,
    
    -- Helper to create a series of numbered files
    create_numbered_files = function(basename, content_pattern, count)
      local files = {}
      for i = 1, count do
        local filename = string.format("%s_%03d.txt", basename, i)
        local content = string.format(content_pattern, i)
        local path = self.create_file(filename, content)
        table.insert(files, path)
      end
      return files
    end
  }
end

-- Helper for creating a temporary test directory with predefined content
function helper.with_temp_test_directory(files_map, callback)
  -- Create a temporary directory
  local test_dir = helper.create_temp_test_directory()
  
  -- Create all the specified files
  local created_files = {}
  for file_name, content in pairs(files_map) do
    local file_path = test_dir.create_file(file_name, content)
    table.insert(created_files, file_path)
  end
  
  -- Call the callback with the directory path and context
  local results = {pcall(callback, test_dir.path, created_files, test_dir)}
  local success = table.remove(results, 1)
  
  -- Note: cleanup happens automatically via temp_file.cleanup_test_context
  -- which is called by the runner
  
  if not success then
    error(results[1])  -- Re-throw the error
  end
  
  return unpack(results)
end

-- Helper to manually register existing files for cleanup
function helper.register_temp_file(file_path)
  return temp_file.register_file(file_path)
end

-- Helper to manually register existing directories for cleanup
function helper.register_temp_directory(dir_path)
  return temp_file.register_directory(dir_path)
end
```

### 3. Integration with Test Runner

#### Modification to `runner.lua`:

```lua
-- Inside runner.lua

local temp_file = require("lib.tools.temp_file")

-- Store the current test context during execution
local function set_current_test_context(context)
  firmo._current_test_context = context
end

-- Clear the current test context
local function clear_current_test_context()
  firmo._current_test_context = nil
end

-- Before each test execution
local original_execute_test = execute_test
function execute_test(test, ...)
  -- Set the current test context
  set_current_test_context(test)
  
  -- Execute the test
  local success, result = original_execute_test(test, ...)
  
  -- Clean up temporary files for this test
  local cleanup_success, cleanup_errors = temp_file.cleanup_test_context(test)
  
  if not cleanup_success and cleanup_errors and #cleanup_errors > 0 then
    -- Log cleanup issues but don't fail the test
    log.warn("Failed to clean up some temporary files", {
      test = test.name,
      errors = cleanup_errors
    })
  end
  
  -- Clear the test context
  clear_current_test_context()
  
  return success, result
end

-- After all tests, clean up any remaining files
local original_run_tests = run_tests
function run_tests(...)
  local success, result = original_run_tests(...)
  
  -- Final cleanup of any remaining temporary files
  local stats = temp_file.get_stats()
  if stats.total_files > 0 then
    log.warn("Found uncleaned temporary files after all tests", {
      total_files = stats.total_files,
      files_by_context = stats.files_by_context
    })
    
    -- Force cleanup of all remaining files
    temp_file.cleanup_all()
  end
  
  return success, result
end
```

### 4. Firmo Core Integration

#### Addition to `firmo.lua`:

```lua
-- Inside firmo.lua

-- Expose the current test context for internal use
firmo._current_test_context = nil

-- Get the current test context (for use by modules)
function firmo.get_current_test_context()
  return firmo._current_test_context
end
```

## Usage Examples

### 1. Basic Usage with Automatic Tracking

```lua
it("should test file operations", function()
  -- Create a temporary file that will be automatically cleaned up
  local file_path, err = temp_file.create_with_content("test content", "txt")
  expect(err).to_not.exist()
  
  -- Use the file in tests
  local content = fs.read_file(file_path)
  expect(content).to.equal("test content")
  
  -- No need for manual cleanup
end)
```

### 2. Dynamic File Creation Throughout Test Execution

```lua
it("should handle dynamic file creation", function()
  -- Create a test directory context
  local test_dir = test_helper.create_temp_test_directory()
  
  -- Create initial files
  test_dir.create_file("config.lua", "return { mode = 'test' }")
  
  -- Perform some test operations
  local config = dofile(test_dir.path .. "/config.lua")
  expect(config.mode).to.equal("test")
  
  -- Create more files based on test results
  test_dir.create_file("results/output.txt", "Test passed for mode: " .. config.mode)
  
  -- Check the created files
  expect(test_dir.file_exists("results/output.txt")).to.be_truthy()
  
  -- No need for manual cleanup
end)
```

### 3. Creating a Directory Structure Upfront

```lua
it("should test with a predefined directory structure", function()
  test_helper.with_temp_test_directory({
    ["config.json"] = '{"setting": "value"}',
    ["data.txt"] = "test data",
    ["scripts/helper.lua"] = "return function() return true end"
  }, function(dir_path, files, test_dir)
    -- Test code using the directory
    expect(fs.file_exists(dir_path .. "/config.json")).to.be_truthy()
    
    -- Can also create more files dynamically
    test_dir.create_file("additional.txt", "more data")
  end)
end)
```

### 4. Working with Existing Files

```lua
it("should work with manually created files", function()
  -- For files created through other means
  local file_path = "/tmp/manually_created_file.txt"
  fs.write_file(file_path, "content")
  
  -- Register for automatic cleanup
  test_helper.register_temp_file(file_path)
  
  -- Continue with test
  expect(fs.file_exists(file_path)).to.be_truthy()
  
  -- No need for manual cleanup
end)
```

## Migration Plan

### Phase 1: Core Implementation (Week 1)

1. Implement the enhanced `temp_file.lua` module
2. Create the test helper additions
3. Modify the runner.lua integration
4. Add firmo.lua integration
5. Create the cleanup script
6. Update documentation in CLAUDE.md

### Phase 2: Example and Validation (Week 1-2)

1. Create example file showing usage
2. Update a few high-priority tests as proof of concept
3. Verify automatic cleanup works as expected
4. Get feedback and adjust implementation

### Phase 3: Gradual Test Updates (Weeks 2-4)

1. Identify tests with the most temporary file usage
2. Update these high-impact tests first
3. Create helper scripts to detect tests leaving files behind
4. Gradually update remaining tests

### Phase 4: Full Deployment (Week 4+)

1. Ensure all tests use the new system
2. Monitor temporary file count
3. Fix any remaining issues
4. Document best practices and patterns

## Documentation Updates

### 1. Update to CLAUDE.md

```markdown
### Temporary File Management

Firmo tests should use the provided temporary file management system that automatically tracks and cleans up files:

#### Creating Temporary Files

```lua
-- Create a temporary file
local file_path, err = temp_file.create_with_content("file content", "lua")
expect(err).to_not.exist("Failed to create temporary file")

-- Create a temporary directory
local dir_path = temp_file.create_temp_directory()

-- No manual cleanup needed - the system will automatically clean up
-- when the test completes
```

#### Working with Temporary Test Directories

For tests that need to work with multiple files, use the test directory helpers:

```lua
-- Create a test directory context
local test_dir = test_helper.create_temp_test_directory()

-- Create files in the directory
test_dir.create_file("config.json", '{"setting": "value"}')
test_dir.create_file("subdir/data.txt", "nested file content")

-- Use the directory in tests
local config_path = test_dir.path .. "/config.json"
expect(fs.file_exists(config_path)).to.be_truthy()
```

#### Creating Test Directories with Predefined Content

For tests that need a directory with a predefined structure:

```lua
test_helper.with_temp_test_directory({
  ["config.json"] = '{"setting": "value"}',
  ["data.txt"] = "test data",
  ["scripts/helper.lua"] = "return function() return true end"
}, function(dir_path, files, test_dir)
  -- Test code here...
  expect(fs.file_exists(dir_path .. "/config.json")).to.be_truthy()
end)
```

#### Registering Existing Files

If you create files through other means, register them for cleanup:

```lua
-- For files created outside the temp_file system
local file_path = "/tmp/my_test_file.txt"
fs.write_file(file_path, "content")

-- Register for automatic cleanup
test_helper.register_temp_file(file_path)
```
```

### 2. Example File

Create a comprehensive example at `examples/temp_file_management_example.lua`.

## Technical Considerations

1. **File system operations can fail**: All cleanup operations need proper error handling
2. **Order matters for directories**: Clean up files before their parent directories 
3. **Cross-platform issues**: Ensure system works on Windows, Linux, and macOS
4. **Weak references**: Use weak tables for test references to avoid memory leaks
5. **Proper error propagation**: Don't let cleanup errors affect test results
6. **Recursive directory removal**: Ensure directory cleanup handles nested content

## Success Criteria

1. **Zero leftover files**: No temporary files remaining after test runs
2. **Minimal code changes**: Tests require minimal modification to adopt the system
3. **Support for dynamic creation**: Files can be created at any point during test execution
4. **Error resilience**: Files are cleaned up even when tests fail
5. **Reporting capability**: System provides clear insights on temporary file usage

## Implementation Status

### Phase 1: Core Implementation ✅

1. ✅ Implemented the enhanced `temp_file.lua` module
   - Added tracking system with test context awareness
   - Implemented file and directory registration
   - Added cleanup functionality with error handling
   - Added stats collection for monitoring
   - Implemented simplified context tracking with string identifiers
   - Added debug logging for troubleshooting

2. ✅ Created the test helper additions
   - Added `create_temp_test_directory()` function with comprehensive helpers
   - Added `with_temp_test_directory()` for predefined content
   - Added manual registration helpers
   - Integrated with structured error handling
   - Added utilities for common test operations

3. ✅ Created the integration module for test runners
   - Added `temp_file_integration.lua` for runner integration
   - Implemented context tracking for tests
   - Added automatic cleanup after test execution
   - Provided patches for firmo test runners
   - Added initialization function for setup

4. ✅ Created the cleanup script
   - Implemented `cleanup_temp_files.lua` for orphaned files
   - Added age-based cleaning option
   - Added dry-run functionality
   - Added detailed logging
   - Implemented safeguards against accidental deletion

5. ✅ Updated documentation in CLAUDE.md
   - Added usage examples for all functions
   - Added commands for cleanup script
   - Documented best practices
   - Added troubleshooting section

6. ✅ Created example files
   - Created comprehensive example in `temp_file_management_example.lua`
   - Created simple test in `temp_file_test.lua`
   - Added verification steps to confirm operation

### Phase 2: Testing and Validation ⚠️

1. ⚠️ Timeout issue investigation (In Progress)
   - Identified potential issues with context tracking
   - Added debug logging to trace operation
   - Simplified context management to use string identifiers
   - Need to complete testing with proper test runner
   - Need to verify performance with larger test suites

2. ⚠️ Test Automatic Cleanup (In Progress)
   - Need to verify automatic cleanup works with the test runner
   - Initial implementation completed but needs verification
   - Need to test with more complex test scenarios
   - Need to verify cleanup behavior with failed tests

3. ⚠️ Debug and Adjust Implementation (In Progress)
   - Implemented simplified context tracking
   - Added explicit error handling with recovery paths
   - Need to complete performance optimization
   - Need to test with large file operations
   - Need to verify compatibility with different Lua implementations

### Phase 3: Gradual Test Updates

1. ❌ Identify High-Priority Tests
   - Need to identify tests with the most temporary file usage
   - Focus on tests that create many files without cleanup
   - Use runner integration to detect temporary file usage

2. ❌ Update Initial Tests
   - Need to update high-impact tests as proof of concept
   - Need to verify performance in real tests
   - Need to document conversion patterns for existing tests

3. ⚠️ Create Detection Tools (In Progress)
   - Created `cleanup_temp_files.lua` with scanning capabilities
   - Tool can identify orphaned temporary files
   - Need to enhance to associate files with specific tests
   - Need to implement monitoring during test runs

4. ❌ Plan for Gradual Updates
   - Need to determine strategy for updating remaining tests
   - Need to identify key test patterns for conversion
   - Need to create guidelines for test authors

### Phase 4: Full Deployment

1. ❌ System-Wide Implementation
   - Need to update all tests to use the new system
   - Need to ensure all files are properly cleaned up
   - Need to verify integration with all test types

2. ❌ Monitoring and Metrics
   - Need to implement monitoring for temporary file count
   - Need to track cleanup success rates
   - Need to add reporting to test summaries

3. ❌ Final Documentation
   - Need to complete documentation of patterns and practices
   - Need to create training materials for developers
   - Need to document advanced usage scenarios

## Current Challenges

1. **Timeout Issues**:
   - Complex context tracking may lead to performance issues
   - Lack of proper testing with the test runner
   - Need to verify integration with actual test workloads
   - File system operations can be slow with many resources

2. **Context Management Complexity**:
   - Initial implementation used table objects with weak references
   - Current implementation simplifies to string identifiers
   - Need to verify this approach works with nested test contexts
   - Need to ensure proper cleanup with complex test hierarchies

3. **Integration Complexity**:
   - Patching test runner functions introduces complexity
   - Need to ensure proper context tracking during test execution
   - Integration needs thorough testing with actual test workloads
   - Different test patterns may require different integration approaches

## Updated Next Steps

1. **Complete Timeout Issue Investigation**:
   - Test the implementation with proper test runner
   - Run comprehensive tests with the full testing framework
   - Monitor execution time with different context strategies
   - Verify performance with large numbers of files
   - Document findings and recommended configuration

2. **Revise Context Management Strategy**:
   - Continue with simplified string identifier approach
   - Test with complex nested test scenarios
   - Add support for hierarchical contexts if needed
   - Enhance error recovery for context management
   - Document best practices for context management

3. **Optimize Cleanup Operations**:
   - Profile cleanup operations to identify bottlenecks
   - Implement more efficient resource tracking
   - Add improvements for cleanup ordering
   - Implement targeted optimizations for identified hot spots
   - Document performance considerations for cleanup

4. **Improve Test Runner Integration**:
   - Test integration with actual test workloads
   - Verify automatic cleanup behavior
   - Test with failed tests to ensure proper cleanup
   - Add recovery mechanisms for integration failures
   - Document integration patterns and troubleshooting

5. **Validation and Testing Plan**:
   - Create a comprehensive test suite for the temporary file system
   - Test with various test patterns and scenarios
   - Verify compatibility with different Lua implementations
   - Document validation approach and test coverage
   - Create benchmarks for performance measurement

6. **Documentation and Training**:
   - Create comprehensive troubleshooting guide
   - Document common failure patterns and solutions
   - Add performance tuning recommendations
   - Create migration guide for existing tests
   - Document advanced usage patterns and edge cases

## Conclusion

This plan provides a comprehensive approach to temporary file management in Firmo tests. By implementing a centralized tracking and cleanup system that integrates with the test runner, we can eliminate the problem of accumulated temporary files while making tests more maintainable and reliable.

The system is designed to be flexible, supporting both upfront and dynamic file creation, while providing intuitive helpers that reduce boilerplate code in tests. With proper implementation and migration, this solution will significantly improve the test infrastructure.