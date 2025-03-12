# Project-Wide Error Handling Implementation Plan

## Overview

This document outlines a comprehensive plan for implementing consistent error handling patterns across the entire lust-next project. The goal is to ensure that all modules follow standardized error handling practices, leading to a more robust, maintainable, and user-friendly codebase.

## Guiding Principles

1. **Consistency**: Apply the same error handling patterns across all modules
2. **Structured Errors**: Use structured error objects with categorization and contextual information
3. **Proper Propagation**: Ensure errors are properly propagated up the call stack
4. **Meaningful Messages**: Provide clear, actionable error messages to users
5. **Recovery Mechanisms**: Where appropriate, include graceful recovery options
6. **Comprehensive Logging**: Log all errors with appropriate severity and context

## Standard Error Handling Patterns

The following patterns should be consistently applied across all modules:

### 1. Input Validation

```lua
function module.function_name(required_param, optional_param)
  -- Validate required parameters
  if not required_param then
    local err = error_handler.validation_error(
      "Missing required parameter",
      {
        parameter_name = "required_param",
        operation = "module.function_name"
      }
    )
    logger.warn(err.message, err.context)
    return nil, err
  end
  
  -- Validate parameter types
  if optional_param ~= nil and type(optional_param) ~= "table" then
    local err = error_handler.validation_error(
      "Optional parameter must be a table or nil",
      {
        parameter_name = "optional_param",
        provided_type = type(optional_param),
        operation = "module.function_name"
      }
    )
    logger.warn(err.message, err.context)
    return nil, err
  end
  
  -- Continue with function implementation...
end
```

### 2. I/O Operations

```lua
-- Reading files
local content, err = error_handler.safe_io_operation(
  function() return fs.read_file(file_path) end,
  file_path,
  {operation = "read_file"}
)

if not content then
  logger.error("Failed to read file", {
    file_path = file_path,
    error = err.message
  })
  return nil, err
end

-- Writing files
local success, err = error_handler.safe_io_operation(
  function() return fs.write_file(file_path, content) end,
  file_path,
  {operation = "write_file"}
)

if not success then
  logger.error("Failed to write file", {
    file_path = file_path,
    error = err.message
  })
  return nil, err
end
```

### 3. Error Propagation

```lua
-- Call another function and propagate errors
local result, err = another_function()
if not result then
  -- Add context and propagate
  logger.error("Operation failed", {
    operation = "current_function",
    error = err.message
  })
  return nil, err
end

-- Use the result
return process_result(result)
```

### 4. Function Try/Catch Pattern

The standard pattern for using error_handler.try (UPDATED 2025-03-12):

```lua
local success, result, err = error_handler.try(function()
  -- Potentially risky code here
  return some_operation()
end)

if success then
  -- Important: return the actual result, not the success flag
  return result
else
  -- Log the error if needed
  logger.error("Operation failed", {
    operation = "function_name",
    error = error_handler.format_error(result), -- Note: result contains the error object on failure
    category = result.category
  })
  
  -- Return nil and the error object
  return nil, result -- Note: on failure, result contains the error object
end
```

IMPORTANT: Never directly return the result of error_handler.try as it returns a boolean success flag, not the actual operation result:

```lua
-- INCORRECT: This returns the boolean success flag, not the actual result
return error_handler.try(function()
  return some_operation()
end)

-- CORRECT: Process the return values properly
local success, result, err = error_handler.try(function()
  return some_operation()
end)

if success then
  return result
else
  return nil, result -- error object is in result when success is false
end
```

## Implementation Phases

### Phase 1: Core Modules (Current Focus)

1. **Error Handler Implementation**
   - ✅ Ensure error_handler module is complete and robust
   - ✅ Add proper categorization and severity levels
   - ✅ Implement try/catch pattern
   - ✅ Add safe I/O operations

2. **Coverage Module**
   - ✅ Implement error handling in coverage/init.lua
   - ✅ Implement error handling in debug_hook.lua (Completed 2025-03-11)
     - ✅ Added missing track_line function
     - ✅ Added track_function implementation with error handling
     - ✅ Added track_block implementation with error handling
     - ✅ Enhanced all operations with proper error handling
   - ✅ Implement error handling in file_manager.lua
   - ✅ Implement error handling in static_analyzer.lua
   - ✅ Implement error handling in patchup.lua (Enhanced 2025-03-11)
     - ✅ Fixed "attempt to index a boolean value" error
     - ✅ Enhanced type checking for line_info handling
     - ✅ Added better error handling and logging
   - ✅ Implement error handling in instrumentation.lua
   - ✅ Fix the syntax error in coverage/init.lua (CRITICAL)
   - ✅ Fix report generation to handle different line_data formats (Completed 2025-03-11)

3. **Core Module Groups (Priority)**
   - ✅ Implement error handling in central_config.lua (Completed 2025-03-11)
   - ✅ Implement error handling in module_reset.lua (Completed 2025-03-11)
     - ✅ Replaced temporary validation functions with error_handler patterns
     - ✅ Enhanced logging functionality with robust error handling
     - ✅ Improved error context in all error reports
     - ✅ Added detailed error propagation throughout the module
     - ✅ Replaced direct error() calls with structured error_handler.throw
     - ✅ Added safe try/catch patterns for print operations
   - 🔄 Implement error handling in filesystem.lua (In Progress 2025-03-12)
     - ✅ Added direct error_handler require to ensure it's always available
     - ✅ Enhanced safe_io_action function with proper try/catch patterns
     - ✅ Implemented validation pattern for read_file, write_file, append_file, copy_file, and move_file functions
     - ✅ Used structured error objects with categorization
     - ✅ Replaced pcall with error_handler.try for better error handling
     - ✅ Added detailed context for error reporting
     - ✅ Implemented proper error chaining with original error as cause
     - ✅ Implemented proper error handling for delete_file function
     - ✅ Enhanced create_directory with comprehensive error handling
     - ✅ Added proper error handling to ensure_directory_exists function
     - ✅ Implemented robust error handling for delete_directory function
     - ✅ Implemented comprehensive error handling for get_directory_contents function
     - ✅ Enhanced normalize_path with proper error handling and validation
     - 🔄 Identified issue with join_paths returning boolean instead of path string (2025-03-12)
     - ✅ Enhanced get_directory_name with comprehensive error handling
     - 🔄 Identified issue with get_file_name returning boolean instead of filename (2025-03-12)
     - 🔄 Identified issue with get_extension returning boolean instead of extension (2025-03-12)
     - 🔄 Identified issue with get_absolute_path returning boolean instead of absolute path (2025-03-12)
     - ✅ Added comprehensive error handling to get_relative_path function
     - ✅ Enhanced file discovery functions with comprehensive error handling (2025-03-11)
       - ✅ Implemented error handling for glob_to_pattern with validation and error chaining
       - 🔄 Identified issue with matches_pattern returning boolean instead of match result (2025-03-12)
       - 🔄 Identified issue with discover_files returning boolean instead of file list (2025-03-12)
       - ✅ Implemented robust error handling for scan_directory with error aggregation
       - ✅ Enhanced find_matches with proper validation and context-rich errors
     - ✅ Enhanced information functions with proper error handling (2025-03-11)
       - ✅ Implemented error handling for file_exists with safe I/O operations
       - ✅ Enhanced directory_exists with platform-specific error handling
       - ✅ Added comprehensive error handling to get_file_size with detailed context
       - ✅ Implemented error handling for file time functions (get_modified_time, get_creation_time)
       - ✅ Enhanced type checking functions (is_file, is_directory) with proper validation
     - ✅ Documented proper pattern for handling error_handler.try results (2025-03-12):
       ```lua
       local success, result, err = error_handler.try(function()
         -- Function body
         return result
       end)
       
       if success then
         return result
       else
         return nil, result -- On failure, result contains the error object
       end
       ```
   - ✅ Implement error handling in version.lua (Completed 2025-03-11)
     - ✅ Added error handling to version parsing with validation
     - ✅ Enhanced version comparison with robust error handling
     - ✅ Implemented error handling for version requirement checking
     - ✅ Added fallback mechanisms for error handler loading
     - ✅ Enhanced with structured logging and parameter validation
   - ✅ Implement error handling in main lust-next.lua
     - ✅ Added direct error_handler require to ensure it's always available
     - ✅ Replaced try_require fallbacks with error_handler.try
     - ✅ Enhanced test discovery, execution, and core test functions
     - ✅ Improved error propagation throughout the test framework
     - ✅ Added detailed context for all error objects
     - ✅ Enhanced logging integration with structured error reporting

### Phase 2: Tool Modules

1. **Reporting System**
   - [ ] Implement error handling in reporting/init.lua
   - [ ] Add error handling to all formatters
   - [ ] Create tests verifying error handling

2. **Utility Tools**
   - [ ] Implement error handling in tools/benchmark.lua
   - [ ] Add error handling to tools/codefix.lua
   - [ ] Enhance tools/interactive.lua
   - [ ] Update tools/markdown.lua
   - [ ] Improve tools/parser modules
   - [ ] Update tools/watcher.lua

3. **Mocking System**
   - [ ] Add error handling to mocking/init.lua
   - [ ] Implement error handling in mock.lua
   - [ ] Update spy.lua
   - [ ] Enhance stub.lua

### Phase 3: Extension Modules

1. **Async Module**
   - [ ] Implement error handling in async/init.lua
   - [ ] Enhance error handling in parallel execution

2. **Quality Module**
   - [ ] Add error handling to quality/init.lua
   - [ ] Update quality validation components

### Phase 4: Documentation and Testing

1. **Comprehensive Documentation**
   - [ ] Create detailed error handling guide
   - [ ] Document error categories and severity levels
   - [ ] Provide examples for each pattern

2. **Testing Framework**
   - [ ] Create dedicated error handling tests for each module
   - [ ] Verify error propagation across module boundaries
   - [ ] Test recovery mechanisms

## Implementation Approach

For each module, follow these steps:

1. **Analyze Current Error Handling**
   - Identify existing error handling patterns
   - Locate error-prone operations
   - Map error propagation paths

2. **Create Backup**
   - Always backup files before modification
   - Keep original versions for reference

3. **Implement Standard Patterns**
   - Apply input validation
   - Enhance I/O operations
   - Add proper try/catch patterns
   - Fix error propagation

4. **Test Implementation**
   - Create dedicated tests
   - Verify error objects are properly structured
   - Ensure errors are properly propagated
   - Test recovery mechanisms

5. **Document Implementation**
   - Update implementation status in this plan
   - Document any module-specific approaches

## Tracking Progress

We will use the following indicators in this document:

- ✅ Completed
- ⚠️ In Progress (Critical)
- 🔄 In Progress (Standard)
- ❌ Failed (Needs Attention)
- ⏱️ Scheduled
- [ ] Not Started

## Current Priorities

0. **✅ COMPLETED (2025-03-12)**: Fix Logger Conditionals in lust-next.lua
   - ✅ Updated logger initialization to treat it as a required dependency
   - ✅ Fixed core functions (discover, run_file, format, describe, and variants)
   - ✅ Updated tag handling functions (tags, only_tags, filter, reset_filters)
   - ✅ Fixed test execution functions (it, fit, xit) with direct logger usage
   - ✅ Enhanced should_run_test function with consistent logging patterns 
   - ✅ Removed conditionals in before/after hooks handling
   - ✅ Fixed CLI mode and watch mode functionalities with direct logger calls
   - ✅ Enhanced error propagation with consistent logging patterns
   - ✅ Created comprehensive session summaries documenting implementation progress
   - ✅ Fixed syntax errors in the file caused by the modifications
   - ✅ Verified the fixes with proper syntax validation

1. **⚠️ CRITICAL (2025-03-12)**: Fix Filesystem Module Return Value Processing
   - ✅ Identified critical issues with error_handler.try results not being properly processed
   - ✅ Fixed an issue in central_config.lua to handle non-structured errors
   - ✅ Created a workaround in LPegLabel module to avoid using problematic fs.join_paths
   - ⚠️ Need to properly fix fs.join_paths to return the path string, not the boolean success value
   - ⚠️ Need to properly fix fs.discover_files to return the file list, not the boolean success value
   - ⚠️ Need to remove the temporary workaround in run_all_tests.lua

1. **HIGHEST**: Reporting System Integration
   - Implement error handling in reporting/init.lua
   - Add error handling to all formatters
   - Create tests verifying error handling

2. **HIGH**: Core Module Completion
   - Complete rewrite of coverage/init.lua with proper error handling
   - Extract assertion functions to a dedicated module
   - Create comprehensive error handling test suite

3. **MEDIUM**: Tool Modules
   - Implement error handling in tools/benchmark.lua
   - Add error handling to tools/codefix.lua
   - Update tools/watcher.lua with error handling

4. **MEDIUM**: Documentation and Testing
   - Create detailed error handling guide
   - Document error categories and severity levels
   - Create dedicated error handling tests for each module

## Expected Benefits

1. **Improved Reliability**: Better error handling leads to fewer crashes and unexpected behaviors
2. **Enhanced Debugging**: Structured errors make problem identification easier
3. **Better User Experience**: Clear error messages help users resolve issues
4. **Easier Maintenance**: Consistent patterns make code more maintainable
5. **Reduced Support Burden**: Better error handling decreases the need for support

## Conclusion

This comprehensive error handling implementation will significantly improve the lust-next project's reliability, maintainability, and user experience. By applying consistent error handling patterns across all modules, we establish a robust foundation for future development and ensure a better experience for users of the framework.

---

This document will be continuously updated as we make progress on implementing consistent error handling throughout the project.

Last Updated: 2025-03-11