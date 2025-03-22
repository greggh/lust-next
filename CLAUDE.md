# Project: firmo

## Overview

firmo is an enhanced Lua testing framework that provides comprehensive testing capabilities for Lua projects. It features BDD-style nested test blocks, assertions with detailed error messages, setup/teardown hooks, advanced mocking, tagging, asynchronous testing, code coverage analysis with multiline comment support, and test quality validation.

## Important Code Guidelines

### Diagnostic Comments

**NEVER remove diagnostic disable comments** from the codebase. These comments are intentionally placed to suppress specific warnings while we work on fixing the underlying issues. Examples include:

```lua
---@diagnostic disable-next-line: need-check-nil
---@diagnostic disable-next-line: redundant-parameter
---@diagnostic disable-next-line: unused-local
```

Only remove these comments when you are specifically fixing the issue they're suppressing.

#### Error Handling Diagnostic Patterns

The codebase uses several standardized error handling patterns that require diagnostic suppressions. These suppressions are necessary and intentional, not code smell:

1. **pcall Pattern**:
   ```lua
   ---@diagnostic disable-next-line: unused-local
   local ok, err = pcall(function()
     return some_operation()
   end)
   
   if not ok then
     -- Handle error in err
   end
   ```
   The `ok` variable appears unused because it's only used for control flow.

2. **error_handler.try Pattern**:
   ```lua
   ---@diagnostic disable-next-line: unused-local
   local success, result, err = error_handler.try(function()
     return some_operation()
   end)
   
   if not success then
     -- Handle error in result (which contains the error object)
   end
   ```
   The `success` variable appears unused for the same reason.

3. **Table Access Without nil Check**:
   ```lua
   ---@diagnostic disable-next-line: need-check-nil
   local value = table[key]
   ```
   Used when the code knows the key exists or handles nil values correctly afterward.

4. **Redundant Parameter Pattern**:
   ```lua
   ---@diagnostic disable-next-line: redundant-parameter
   await(50) -- Wait 50ms
   ```
   Used when calling functions that are imported from one module and re-exported through another (like `firmo.await` which comes from `lib/async/init.lua`). The Lua Language Server cannot correctly trace the parameter types through these re-exports, resulting in false "redundant parameter" warnings.

Always include these diagnostic suppressions when implementing these patterns. They are part of our standardized approach and removing them would cause unnecessary static analyzer warnings.

### JSDoc-Style Type Annotations

The codebase uses comprehensive JSDoc-style type annotations for improved type checking, documentation, and IDE support. All files MUST include these annotations following our standardized patterns. When implementing new functions or modifying existing ones, adhere to these requirements:

#### Required Type Annotations

1. **Module Interface Declarations** - All module files must begin with class/module definition:
   ```lua
   ---@class ModuleName
   ---@field function_name fun(param: type): return_type Description 
   ---@field another_function fun(param1: type, param2?: type): return_type|nil, error? Description
   ---@field _VERSION string Module version
   local M = {}
   ```

2. **Module Function Definitions**:
   ```lua
   --- Description of what the function does
   ---@param name type Description of the parameter
   ---@param optional_param? type Description of the optional parameter
   ---@return type Description of what the function returns
   function module.function_name(name, optional_param)
     -- Implementation
   end
   ```

3. **Function Re-exports**:
   When a function is defined in one module but exported through another:
   ```lua
   --- Description of what the function does
   ---@param name type Description of the parameter
   ---@param optional_param? type Description of the optional parameter
   ---@return type Description of what the function returns
   module.exported_function = original_module.function_name
   ```

4. **Local Function Annotations** - Helper functions should have annotations:
   ```lua
   ---@private
   ---@param value any The value to process
   ---@return string The processed value
   local function process_value(value)
   ```

5. **Variable Type Annotations** - For complex types:
   ```lua
   ---@type string[]
   local names = {}
   
   ---@type table<string, {id: number, name: string}>
   local cache = {}
   ```

#### Annotation Style Guidelines

1. **Error Handling Pattern** - For functions that may fail, use this pattern:
   ```lua
   ---@return ValueType|nil value The result or nil if operation failed
   ---@return table|nil error Error information if operation failed
   ```

2. **Optional Parameters** - Mark with question mark suffix:
   ```lua
   ---@param options? table Optional configuration
   ```

3. **Nullable Types** - Use pipe with nil:
   ```lua
   ---@return string|nil The result or nil if not found
   ```

4. **Union Types** - Use pipe for multiple possible types:
   ```lua
   ---@param id string|number The identifier (string or number)
   ```

5. **Complex Return Patterns** - Document each possible return value:
   ```lua
   ---@return boolean|nil success Whether operation succeeded or nil if error
   ---@return table|nil result Result data if success, nil if error
   ---@return table|nil error Error data if failure, nil if success
   ```

6. **Tables with Specific Fields** - Document the structure:
   ```lua
   ---@param options {timeout?: number, retry?: boolean, max_attempts?: number} Configuration options
   ```

7. **Callback Signatures** - Document the callback function signature:
   ```lua
   ---@param callback fun(result: string, success: boolean): boolean Function called with result
   ```

#### When Annotations Are Required

1. **ALL new files** must include comprehensive type annotations
2. **ALL existing files** being modified must have annotations added if missing
3. **WHENEVER modifying functions**, ensure annotations are updated to match the changes
4. **WHENEVER adding new functionality**, include complete annotations

The standard annotation structure follows sumneko Lua Language Server format for optimal IDE integration. This is a mandatory part of our code quality standards.

#### Common Type Annotation Examples

- `---@param name string` - String parameter
- `---@param count number` - Number parameter
- `---@param callback function` - Function parameter
- `---@param options? table` - Optional table parameter (note the `?`)
- `---@param items table<string, number>` - Table with string keys and number values
- `---@param handler fun(item: string): boolean` - Function that takes string and returns boolean
- `---@return boolean` - Boolean return value
- `---@return nil` - No return value
- `---@return string|nil, string?` - String or nil, with optional second string
- `---@return boolean|nil success, table|nil error` - Success flag or error pattern

Until all functions have proper type annotations throughout the export chain, continue using the diagnostic suppressions as needed. The goal is to gradually add type annotations to all major modules in this priority order:

1. Core modules (async, error_handler, logging)
2. Tools modules (filesystem, benchmark, codefix)  
3. Public API functions in firmo.lua
4. Test helper functions and utilities

### Markdown Formatting

When working with Markdown files:

1. **Code Block Format**: Use simple triple backticks without language specifiers when the language is obvious:
   
   ```
   -- Lua code goes here
   ```
   
   NOT:
   
   ```text
   -- Lua code goes here
   ```

2. **Consistency**: Never use ````text` in our markdown files. These have been removed from all documentation.

3. **Balanced Backticks**: Always ensure that backticks are balanced (equal number of opening and closing backticks).

### Lua Compatibility

For cross-version Lua compatibility:

1. **Table Unpacking**: Always use the compatibility function for unpacking:
   
   ```lua
   local unpack_table = table.unpack or unpack
   ```

2. **Table Length**: Use the `#` operator instead of `table.getn`:
   
   ```lua
   local length = #my_table  -- Correct
   local length = table.getn(my_table)  -- Incorrect, deprecated
   ```

## Essential Commands

### Testing Commands

- Run All Tests: `env -C /home/gregg/Projects/lua-library/firmo lua test.lua tests/`
- Run Specific Test: `env -C /home/gregg/Projects/lua-library/firmo lua test.lua tests/reporting_test.lua`
- Run Tests by Pattern: `env -C /home/gregg/Projects/lua-library/firmo lua test.lua --pattern=coverage tests/`
- Run Tests with Coverage: `env -C /home/gregg/Projects/lua-library/firmo lua test.lua --coverage tests/`
- Run Tests with Watch Mode: `env -C /home/gregg/Projects/lua-library/firmo lua test.lua --watch tests/`
- Run Tests with Quality Validation: `env -C /home/gregg/Projects/lua-library/firmo lua test.lua --quality tests/`
- Run Example: `env -C /home/gregg/Projects/lua-library/firmo lua examples/report_example.lua`

### Test Command Format

The standard test command format follows this pattern:

```
lua test.lua [options] [path]
```

Where:

- `[options]` are command-line flags like `--coverage`, `--watch`, `--pattern=coverage`
- `[path]` is a file or directory path (the system automatically detects which)

Common options include:

- `--coverage`: Enable coverage tracking
- `--quality`: Enable quality validation
- `--pattern=<pattern>`: Filter test files by pattern
- `--watch`: Enable watch mode for continuous testing
- `--verbose`: Show more detailed output
- `--help`: Show all available options

> **Note:** We have completed the transition to a standardized test system where all tests run through the `test.lua` utility in the project root. All special-purpose runners have been removed in favor of this unified approach.

## Important Testing Notes

### Test Implementation Guidelines

- NEVER use `firmo.run()` - this function DOES NOT EXIST
- NEVER use `firmo()` to run tests - this is not a correct method
- Do not include any calls to `firmo()` or `firmo.run()` in test files
- Use proper lifecycle hooks: `before`/`after` (NOT `before_all`/`after_all`, which don't exist)
- Import test functions correctly: `local describe, it, expect = firmo.describe, firmo.it, firmo.expect`
- For test lifecycle, use: `local before, after = firmo.before, firmo.after`

### Assertion Style Guide

firmo uses expect-style assertions rather than assert-style assertions:

```lua
-- CORRECT: firmo expect-style assertions
expect(value).to.exist()
expect(actual).to.equal(expected)
expect(value).to.be.a("string")
expect(value).to.be_truthy()
expect(value).to.match("pattern")
expect(fn).to.fail()

-- INCORRECT: busted-style assert assertions (don't use these)
assert.is_not_nil(value)         -- wrong
assert.equals(expected, actual)  -- wrong
assert.type_of(value, "string")  -- wrong
assert.is_true(value)            -- wrong
```

### Testing Error Conditions

When writing tests that verify error behavior, use the standardized error testing pattern with `expect_error` flag and `test_helper.with_error_capture()`:

```lua
-- Import the test helper module
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- CORRECT: standardized pattern for testing error conditions
it("should handle invalid input", { expect_error = true }, function()
  -- Use with_error_capture to safely call functions that may throw errors
  local result, err = test_helper.with_error_capture(function()
    return function_that_should_error()
  end)()
  
  -- Make assertions about the error
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.category).to.exist() -- Avoid overly specific category expectations
  expect(err.message).to.match("expected pattern") -- Check message pattern
end)

-- For functions that might return false instead of nil+error:
it("tests both error patterns", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return function_that_might_return_false_or_nil_error()
  end)()
  
  if result == nil then
    expect(err).to.exist()
    expect(err.message).to.match("expected pattern")
  else
    expect(result).to.equal(false)
  end
end)

-- For simple error message verification:
it("should verify error messages", function()
  -- Automatically verifies the function throws an error
  -- with the expected message pattern
  local err = test_helper.expect_error(fails_with_message, "expected error")
  
  -- Additional assertions on the error object
  expect(err.category).to.exist()
end)
```

### Error Testing Best Practices

1. **Always use the `expect_error` flag**: This marks the test as one that expects errors:
   ```lua
   it("test description", { expect_error = true }, function()
     -- Test code that should produce errors
   end)
   ```

2. **Always use `test_helper.with_error_capture()`**: This safely captures errors without crashing tests:
   ```lua
   local result, err = test_helper.with_error_capture(function()
     return function_that_throws()
   end)()
   ```

3. **Be flexible with error categories**: Avoid hard-coding specific categories to make tests more resilient:
   ```lua
   -- Recommended:
   expect(err.category).to.exist()
   
   -- More specific but still flexible:
   expect(err.category).to.match("^[A-Z_]+$")
   
   -- Avoid unless necessary:
   expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
   ```

4. **Use pattern matching for error messages**: Use `match()` instead of `equal()` for error messages:
   ```lua
   expect(err.message).to.match("invalid file")  -- Good
   expect(err.message).to.equal("Invalid file format")  -- Too specific
   ```

5. **Test for existence first**: Always check that the value exists before making assertions about it:
   ```lua
   expect(err).to.exist()
   if err then
     expect(err.message).to.match("pattern")
   end
   ```

6. **Handle both error patterns**: Some functions return `nil, error` while others return `false`:
   ```lua
   if result == nil then
     expect(err).to.exist()
   else
     expect(result).to.equal(false)
   end
   ```

7. **Clean up resources properly**: If your test creates files or resources, ensure they're cleaned up:
   ```lua
   -- Track resources for cleanup
   local test_files = {}
   
   -- Create with error handling
   local file_path, create_err = temp_file.create_with_content(content, "lua")
   expect(create_err).to_not.exist("Failed to create test file: " .. tostring(create_err))
   table.insert(test_files, file_path)
   
   -- Cleanup in after() hook with error handling
   after(function()
     for _, path in ipairs(test_files) do
       local success, err = pcall(function() temp_file.remove(path) end)
       if not success and logger then
         logger.warn("Failed to remove test file: " .. tostring(err))
       end
     end
     test_files = {}
   end)
   ```

8. **Document expected error behavior**: Add comments that explain what errors are expected:
   ```lua
   it("should reject invalid input", { expect_error = true }, function()
     -- Passing a number should cause a validation error
     local result, err = test_helper.with_error_capture(function()
       return module.process_string(123)
     end)()
     
     expect(result).to_not.exist()
     expect(err).to.exist()
     expect(err.message).to.match("string expected")
   end)
   ```

For comprehensive guidance on standardized error handling patterns, see the following resources:

- [Standardized Error Handling Patterns](docs/coverage_repair/error_handling_patterns.md): Complete guide to all error handling patterns
- [Coverage Error Testing Guide](docs/coverage_repair/coverage_error_testing_guide.md): Specialized patterns for coverage module testing
- [Test Timeout Optimization Guide](docs/coverage_repair/test_timeout_optimization_guide.md): Solutions for tests with timeout issues

Note that the parameter order for equality assertions is the opposite of busted:

- In busted: `assert.equals(expected, actual)`
- In firmo: `expect(actual).to.equal(expected)`

For negating assertions, use `to_not` rather than separate functions:

```lua
expect(value).to_not.equal(other_value)
expect(value).to_not.be_truthy()
expect(value).to_not.be.a("number")
```

### Common Assertion Mistakes to Avoid

1. **Incorrect negation syntax**:

   ```lua
   -- WRONG:
   expect(value).not_to.equal(other_value)  -- "not_to" is not valid

   -- CORRECT:
   expect(value).to_not.equal(other_value)  -- use "to_not" instead
   ```

2. **Incorrect member access syntax**:

   ```lua
   -- WRONG:
   expect(value).to_be(true)  -- "to_be" is not a valid method
   expect(number).to_be_greater_than(5)  -- underscore methods need dot access

   -- CORRECT:
   expect(value).to.be(true)  -- use "to.be" not "to_be"
   expect(number).to.be_greater_than(5)  -- this is correct because it's a method
   ```

3. **Inconsistent operator order**:

   ```lua
   -- WRONG:
   expect(expected).to.equal(actual)  -- parameters reversed

   -- CORRECT:
   expect(actual).to.equal(expected)  -- what you have, what you expect
   ```

### Complete Assertion Pattern Mapping

If you're coming from a busted-style background, use this mapping to convert assertions:

| busted-style                      | firmo style                         | Notes                              |
| --------------------------------- | ----------------------------------- | ---------------------------------- |
| `assert.is_not_nil(value)`        | `expect(value).to.exist()`          | Checks if a value is not nil       |
| `assert.is_nil(value)`            | `expect(value).to_not.exist()`      | Checks if a value is nil           |
| `assert.equals(expected, actual)` | `expect(actual).to.equal(expected)` | Note the reversed parameter order! |
| `assert.is_true(value)`           | `expect(value).to.be_truthy()`      | Checks if a value is truthy        |
| `assert.is_false(value)`          | `expect(value).to_not.be_truthy()`  | Checks if a value is falsey        |
| `assert.type_of(value, "string")` | `expect(value).to.be.a("string")`   | Checks the type of a value         |
| `assert.is_string(value)`         | `expect(value).to.be.a("string")`   | Type check                         |
| `assert.is_number(value)`         | `expect(value).to.be.a("number")`   | Type check                         |
| `assert.is_table(value)`          | `expect(value).to.be.a("table")`    | Type check                         |
| `assert.same(expected, actual)`   | `expect(actual).to.equal(expected)` | Deep equality check                |
| `assert.matches(pattern, value)`  | `expect(value).to.match(pattern)`   | String pattern matching            |
| `assert.has_error(fn)`            | `expect(fn).to.fail()`              | Checks if a function throws error  |

### Extended Assertions

Firmo includes a comprehensive set of advanced assertions for more precise and convenient testing:

#### Collection Assertions
```lua
-- Check length of strings or tables
expect("hello").to.have_length(5)
expect({1, 2, 3}).to.have_length(3)
expect("hello").to.have_size(5)  -- alias for have_length

-- Check if collection is empty
expect("").to.be.empty()
expect({}).to.be.empty()
```

#### Numeric Assertions
```lua
-- Numeric assertions
expect(5).to.be.positive()
expect(-5).to.be.negative()
expect(10).to.be.integer()
expect(5.5).to_not.be.integer()
```

#### String Assertions
```lua
-- String assertions
expect("HELLO").to.be.uppercase()
expect("hello").to.be.lowercase()
```

#### Object Structure Assertions
```lua
-- Object property assertions
expect({name = "John"}).to.have_property("name")
expect({name = "John"}).to.have_property("name", "John")

-- Schema validation
expect({name = "John", age = 30}).to.match_schema({
  name = "string",
  age = "number"
})
```

#### Function Behavior Assertions
```lua
-- Function behavior assertions
local obj = {count = 0}
expect(function() obj.count = obj.count + 1 end).to.change(function() return obj.count end)
expect(function() obj.count = obj.count + 1 end).to.increase(function() return obj.count end)
expect(function() obj.count = obj.count - 1 end).to.decrease(function() return obj.count end)
```

#### Deep Equality
```lua
-- Deep equality (alias)
expect({a = 1, b = {c = 2}}).to.deep_equal({a = 1, b = {c = 2}})
```

For more comprehensive assertions and detailed examples, see `docs/coverage_repair/assertion_pattern_mapping.md` and `tests/assertions/extended_assertions_test.lua`.

### Temporary File Management

Firmo tests should use the provided temporary file management system that automatically tracks and cleans up files. The system has been fully integrated into the test framework to ensure all temporary resources are properly cleaned up.

#### Creating Temporary Files

```lua
-- Create a temporary file
local file_path, err = temp_file.create_with_content("file content", "lua")
expect(err).to_not.exist("Failed to create temporary file")

-- Create a temporary directory
local dir_path, err = temp_file.create_temp_directory()
expect(err).to_not.exist("Failed to create temporary directory")

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
local file_path = os.tmpname()
local f = io.open(file_path, "w")
f:write("content")
f:close()

-- Register for automatic cleanup
test_helper.register_temp_file(file_path)
```

#### Best Practices for Temporary Files

1. **ALWAYS** use `temp_file.create_with_content()` instead of `os.tmpname()`
2. **ALWAYS** check error returns with `expect(err).to_not.exist()`
3. **NEVER** manually remove temporary files (no need for `os.remove()` or `temp_file.remove()`)
4. **ALWAYS** use `test_helper.create_temp_test_directory()` for complex tests
5. For more advanced usage, see the full documentation in `docs/coverage_repair/temp_file_integration_summary.md`

#### Troubleshooting Orphaned Files

If temporary files are not being cleaned up:

```lua
-- Clean up orphaned temporary files (dry run mode)
lua scripts/cleanup_temp_files.lua --dry-run

-- Clean up orphaned temporary files (actual cleanup)
lua scripts/cleanup_temp_files.lua
```

### Test Directory Structure

Tests are organized in a logical directory structure by component:

```
tests/
├── core/            # Core framework tests
├── coverage/        # Coverage-related tests
│   ├── instrumentation/  # Instrumentation-specific tests
│   └── hooks/           # Debug hook tests
├── quality/         # Quality validation tests
├── reporting/       # Reporting framework tests
│   └── formatters/      # Formatter-specific tests
├── tools/           # Utility module tests
│   ├── filesystem/      # Filesystem module tests
│   ├── logging/         # Logging system tests
│   └── watcher/         # File watcher tests
├── error_handling/  # Error handling tests
│   ├── core/            # Core error handling tests
│   ├── coverage/        # Coverage error handling tests
│   ├── reporting/       # Reporting error handling tests
│   ├── tools/           # Tools error handling tests
│   └── mocking/         # Mocking error handling tests
└── ...
```

### Test Execution

- Tests are run using the standardized command: `lua test.lua [path]`
- For a single test file: `lua test.lua tests/reporting_test.lua`
- For a directory of tests: `lua test.lua tests/coverage/`
- For all tests: `lua test.lua tests/`

### Other Useful Commands

- Fix Markdown Files: `env -C /home/gregg/Projects/lua-library/firmo lua scripts/fix_markdown.lua docs`
- Fix Specific Markdown Files: `env -C /home/gregg/Projects/lua-library/firmo lua scripts/fix_markdown.lua README.md CHANGELOG.md`
- Debug Report Generation: `env -C /home/gregg/Projects/lua-library/firmo lua test.lua --coverage --format=html tests/reporting_test.lua`
- Test Quality Validation: `env -C /home/gregg/Projects/lua-library/firmo lua test.lua --quality --quality-level=2 tests/quality_test.lua`
- Clean Orphaned Temp Files: `env -C /home/gregg/Projects/lua-library/firmo lua scripts/cleanup_temp_files.lua`
- Clean Orphaned Temp Files (Dry Run): `env -C /home/gregg/Projects/lua-library/firmo lua scripts/cleanup_temp_files.lua --dry-run`
- Check Lua Syntax: `env -C /home/gregg/Projects/lua-library/firmo lua scripts/check_syntax.lua <file_path>` 
- Find Print Statements: `env -C /home/gregg/Projects/lua-library/firmo lua scripts/find_print_statements.lua lib/`

## Project Structure

- `/lib`: Modular codebase with logical subdirectories
  - `/lib/assertion.lua`: Standalone assertion module
  - `/lib/core`: Core utilities (type checking, fix_expect, version)
  - `/lib/async`: Asynchronous testing functionality
  - `/lib/coverage`: Code coverage tracking
  - `/lib/quality`: Quality validation
  - `/lib/reporting`: Test reporting system
    - `/lib/reporting/formatters`: Individual formatter implementations
  - `/lib/tools`: Utilities (codefix, watcher, interactive CLI, markdown)
    - `/lib/tools/logging`: Structured logging system
    - `/lib/tools/parser`: Lua code parsing utilities
    - `/lib/tools/vendor`: Third-party dependencies
  - `/lib/mocking`: Mocking system (spy, stub, mock)
- `/tests`: Test files for framework functionality
  - `/tests/core`: Core module tests
  - `/tests/coverage`: Coverage system tests
  - `/tests/quality`: Quality validation tests
  - `/tests/reporting`: Reporting system tests
  - `/tests/tools`: Utility module tests
  - `/tests/error_handling`: Error handling tests
- `/examples`: Example scripts demonstrating usage
- `/scripts`: Development and maintenance utility scripts
- `/docs`: Documentation files
- `firmo.lua`: Main framework file
- `test.lua`: Unified test runner

## Coverage Module Architecture

### Components

1. **Coverage Module (init.lua)**:

   - Provides public API for coverage tracking
   - Initializes and configures subsystems
   - Manages coverage lifecycle (start, stop, reset)
   - Processes coverage data before reporting

2. **Debug Hook (debug_hook.lua)**:

   - Sets up and manages Lua debug hooks
   - Tracks line executions and function calls
   - Stores execution data
   - Provides accessor functions for coverage data

3. **Static Analyzer (static_analyzer.lua)**:

   - Parses Lua code into AST
   - Identifies executable and non-executable lines
   - Tracks code structure (functions, blocks)
   - Provides information about line executability

4. **File Manager (file_manager.lua)**:

   - Discovers files for coverage analysis
   - Applies include/exclude patterns
   - Processes discovered files

5. **Patchup (patchup.lua)**:

   - Fixes coverage data for non-executable lines
   - Identifies comments and structural code
   - Patches files based on static analysis

6. **Instrumentation (instrumentation.lua)**:
   - Transforms Lua code with coverage tracking
   - Hooks into Lua's loading functions
   - Generates sourcemaps for error reporting

### Error Handling Guidelines

When working with the coverage module and implementing error handling:

1. **Use Structured Error Objects**: Always use error_handler.create() or specialized functions

   ```lua
   local err = error_handler.validation_error(
     "Missing required parameter",
     {parameter_name = "file_path", operation = "track_file"}
   )
   ```

2. **Proper Error Propagation**: Return nil and error object

   ```lua
   if not file_content then
     return nil, error_handler.io_error(
       "Failed to read file",
       {file_path = file_path, operation = "track_file"}
     )
   end
   ```

3. **Try/Catch Pattern**: Use error_handler.try for operations that might throw errors

   ```lua
   local success, result, err = error_handler.try(function()
     return analyze_file(file_path)
   end)

   if not success then
     logger.error("Failed to analyze file", {
       file_path = file_path,
       error = error_handler.format_error(result)
     })
     return nil, result
   end
   ```

4. **Safe I/O Operations**: Use error_handler.safe_io_operation for file access

   ```lua
   local content, err = error_handler.safe_io_operation(
     function() return fs.read_file(file_path) end,
     file_path,
     {operation = "read_coverage_file"}
   )
   ```

5. **Validation Functions**: Always validate input parameters
   ```lua
   error_handler.assert(type(file_path) == "string",
     "file_path must be a string",
     error_handler.CATEGORY.VALIDATION,
     {provided_type = type(file_path)}
   )
   ```

## Error Handling Implementation Across Modules

All modules in firmo follow these consistent error handling patterns:

1. **Input Validation**: Validate all function parameters at the start
2. **Error Propagation**: Return nil/false and error objects for failures
3. **Error Types**: Use specialized error types (validation, io, runtime, etc.)
4. **Error Context**: Include detailed contextual information in error objects
5. **Try/Catch**: Wrap potentially risky operations in error_handler.try()
6. **Logging**: Log errors with appropriate severity levels and context
7. **Safe I/O**: Use safe I/O operations with proper error handling
8. **Recovery**: Implement recovery mechanisms and fallbacks where appropriate

Complete error handling has been implemented across:

- All formatters in the reporting system
- All tools modules (benchmark, codefix, interactive, markdown, watcher)
- Mocking system (init, spy, mock)
- Core framework modules (config, coverage components)

## Current Focus and Work Order

Our current priorities in order:

1. **✓ Assertion Module Extraction** *(Completed)*
   - ✓ Created a dedicated assertion module to resolve circular dependencies
   - ✓ Refactored all assertion patterns for consistent error handling
   - ✓ Updated expect chain with better error propagation  
   - ✓ Implemented existing assertion patterns
   - ✓ Fixed cycle detection in deep equality and stringification functions
   - [ ] Review and add missing assertion types identified in code review

2. **✓ Coverage/init.lua Error Handling Rewrite** *(Completed)*
   - ✓ Implemented comprehensive error handling throughout
   - ✓ Improved data validation with structured error objects
   - ✓ Enhanced file tracking with better error boundaries
   - ✓ Fixed issues in report generation

3. **✓ Error Handling Test Suite** *(Completed)*
   - ✓ Created tests for error scenarios in coverage subsystems
   - ✓ Verified error propagation across module boundaries
   - ✓ Tested recovery mechanisms and fallbacks
   - ✓ Fixed mock system errors during test execution

4. **Static Analyzer and Debug Hook Enhancements** *(In Progress)*
   - [ ] Review and fix line classification system implementation
   - [ ] Fix function detection accuracy issues
   - [ ] Correct block boundary identification problems
   - [ ] Debug condition expression tracking failures
   - [✓] Fixed error handling and validation issues
   - [ ] Fix data collection and representation issues
   - [ ] Resolve inconsistencies between execution and coverage
   - [ ] Fix performance monitoring issues
   - [✓] Fixed instrumentation errors

5. **✓ JSDoc Type Annotation Maintenance** *(Completed)*
   - ✓ Added comprehensive JSDoc-style type annotations across all files
   - ✓ Updated annotations for modified functions
   - ✓ Added annotations to new functionality and files
   - ✓ Ensured consistent annotation style following our guidelines
   - ✓ Used annotations to improve type checking and IDE integration

6. **✓ HTML Coverage Report Enhancements** *(Completed)*
   - ✓ Added enhanced navigation features to HTML coverage reports
   - ✓ Implemented code folding functionality for better code organization
   - ✓ Added line bookmarking capability for important code sections
   - ✓ Added visited lines tracking for code review progress
   - ✓ Implemented execution frequency heatmap visualization
   - ✓ Updated examples to use new reporting.save_coverage_report() method
   - ✓ Created source navigation plan document for future enhancements

7. **Code Quality and Repository Organization** *(Largely Completed)*
   - ✓ Relocated check_syntax.lua from tools/ to scripts/ directory with proper annotations 
   - ✓ Removed redundant tools/ directory from root
   - ✓ Fixed code modernization issues (table.getn, unpacking)
   - ✓ Added comprehensive temporary file management system
   - ✓ Reviewed all diagnostic disable comments
     - Confirmed they follow documented patterns in CLAUDE.md
     - Verified necessity for all instances (pcall, try/catch, table access)
   - ✓ Audited fallback mechanisms
     - Reviewed all fallbacks in core modules
     - Confirmed all serve important recovery functions
   - ✓ Audited examples directory for relevance and accuracy
     - Updated all examples to use modern reporting.save_coverage_report() method
     - Ensured consistent practices across all example files
   - [ ] Standardize markdown formatting

## Future Enhancements

Once the core coverage system is fully repaired, we plan to:

1. **Further Enhance Reporting and Visualization**

   - ✓ Add hover tooltips for execution count *(Completed)*
   - ✓ Implement visualization for block execution frequency *(Completed)*
   - ✓ Add code folding, bookmarking, and tracking features *(Completed)*
   - [ ] Add function complexity metrics to reports
   - [ ] Implement responsive design for all screen sizes
   - [ ] Modernize HTML reports with Tailwind CSS and Alpine.js

2. **Improve Instrumentation Approach**

   - Refactor for clarity and stability
   - Fix sourcemap handling
   - Enhance module require instrumentation

3. **Integration and Documentation**
   - Create pre-commit hooks for coverage checks
   - Add continuous integration examples
   - Update comprehensive documentation

## Documentation Links

- Tasks: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/tasks/firmo-tasks.md`
- Architecture: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/plans/firmo-architecture.md`
- Project Status: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/project-status.md`

