# Project: lust-next

## Overview
lust-next is an enhanced Lua testing framework that provides comprehensive testing capabilities for Lua projects. It features BDD-style nested test blocks, assertions with detailed error messages, setup/teardown hooks, advanced mocking, tagging, asynchronous testing, code coverage analysis with multiline comment support, and test quality validation.

## Essential Commands

### Testing Commands

- Run All Tests: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua tests/`
- Run Specific Test: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua tests/reporting_test.lua`
- Run Tests by Pattern: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --pattern=coverage tests/`
- Run Tests with Coverage: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --coverage tests/`
- Run Tests with Watch Mode: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --watch tests/`
- Run Tests with Quality Validation: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --quality tests/`
- Run Example: `env -C /home/gregg/Projects/lua-library/lust-next lua examples/report_example.lua`

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

- NEVER use `lust.run()` - this function DOES NOT EXIST
- NEVER use `lust()` to run tests - this is not a correct method
- Do not include any calls to `lust()` or `lust.run()` in test files
- Use proper lifecycle hooks: `before`/`after` (NOT `before_all`/`after_all`, which don't exist)
- Import test functions correctly: `local describe, it, expect = lust.describe, lust.it, lust.expect`
- For test lifecycle, use: `local before, after = lust.before, lust.after`

### Assertion Style Guide

lust-next uses expect-style assertions rather than assert-style assertions:

```lua
-- CORRECT: lust-next expect-style assertions
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

Note that the parameter order for equality assertions is the opposite of busted:
- In busted: `assert.equals(expected, actual)`
- In lust-next: `expect(actual).to.equal(expected)`

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

| busted-style                       | lust-next style                     | Notes                             |
|------------------------------------|-------------------------------------|-----------------------------------|
| `assert.is_not_nil(value)`         | `expect(value).to.exist()`          | Checks if a value is not nil      |
| `assert.is_nil(value)`             | `expect(value).to_not.exist()`      | Checks if a value is nil          |
| `assert.equals(expected, actual)`  | `expect(actual).to.equal(expected)` | Note the reversed parameter order! |
| `assert.is_true(value)`            | `expect(value).to.be_truthy()`      | Checks if a value is truthy       |
| `assert.is_false(value)`           | `expect(value).to_not.be_truthy()`  | Checks if a value is falsey       |
| `assert.type_of(value, "string")`  | `expect(value).to.be.a("string")`   | Checks the type of a value        |
| `assert.is_string(value)`          | `expect(value).to.be.a("string")`   | Type check                        |
| `assert.is_number(value)`          | `expect(value).to.be.a("number")`   | Type check                        |
| `assert.is_table(value)`           | `expect(value).to.be.a("table")`    | Type check                        |
| `assert.same(expected, actual)`    | `expect(actual).to.equal(expected)` | Deep equality check               |
| `assert.matches(pattern, value)`   | `expect(value).to.match(pattern)`   | String pattern matching           |
| `assert.has_error(fn)`             | `expect(fn).to.fail()`              | Checks if a function throws error |

For more comprehensive assertions and detailed examples, see `docs/coverage_repair/assertion_pattern_mapping.md`.

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

- Fix Markdown Files: `env -C /home/gregg/Projects/lua-library/lust-next lua scripts/fix_markdown.lua docs`
- Fix Specific Markdown Files: `env -C /home/gregg/Projects/lua-library/lust-next lua scripts/fix_markdown.lua README.md CHANGELOG.md`
- Debug Report Generation: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --coverage --format=html tests/reporting_test.lua`
- Test Quality Validation: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --quality --quality-level=2 tests/quality_test.lua`

## Project Structure

- `/lib`: Modular codebase with logical subdirectories
  - `/lib/core`: Core utilities (type checking, fix_expect, version)
  - `/lib/async`: Asynchronous testing functionality 
  - `/lib/coverage`: Code coverage tracking
  - `/lib/quality`: Quality validation
  - `/lib/reporting`: Test reporting system
    - `/lib/reporting/formatters`: Individual formatter implementations
  - `/lib/tools`: Utilities (codefix, watcher, interactive CLI, markdown)
  - `/lib/mocking`: Mocking system (spy, stub, mock)
- `/tests`: Test files for framework functionality
- `/examples`: Example scripts demonstrating usage
- `/scripts`: Utility scripts for running tests
- `lust-next.lua`: Main framework file
- `lust.lua`: Compatibility layer for original lust
- `run_all_tests.lua`: Improved test runner for proper test state isolation

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

All modules in lust-next follow these consistent error handling patterns:

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

1. **Assertion Module Extraction**
   - Extract assertion functions into a standalone module (lib/assertion.lua)
   - Resolve circular dependencies
   - Implement consistent error handling across assertions

2. **Coverage/init.lua Error Handling Rewrite**
   - Implement comprehensive error handling throughout
   - Ensure proper data validation
   - Fix report generation issues
   - Improve file tracking

3. **Error Handling Test Suite**
   - Create a comprehensive test suite for error handling
   - Test error scenarios across all modules
   - Verify proper error propagation
   - Test recovery mechanisms

4. **Static Analyzer and Debug Hook Enhancements**
   - Improve line classification system
   - Enhance function detection
   - Perfect block boundary identification
   - Fix data flow between components

## Future Enhancements

Once the core coverage system is repaired, we plan to:

1. **Enhance Reporting and Visualization**
   - Add hover tooltips for execution count
   - Implement visualization for block execution frequency
   - Add function complexity metrics to reports

2. **Improve Instrumentation Approach**
   - Refactor for clarity and stability
   - Fix sourcemap handling
   - Enhance module require instrumentation

3. **Integration and Documentation**
   - Create pre-commit hooks for coverage checks
   - Add continuous integration examples
   - Update comprehensive documentation

## Documentation Links

- Tasks: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/tasks/lust-next-tasks.md`
- Architecture: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/plans/lust-next-architecture.md`
- Project Status: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/project-status.md`