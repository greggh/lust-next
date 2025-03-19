# Logger Error Suppression in Expected Error Tests

## Problem

In tests that use the `{ expect_error = true }` flag, expected errors were showing up in the test output logs, even though the tests were passing correctly. This created confusion and made it difficult to identify real issues versus expected errors during test runs.

## Solution

The solution implemented integrates the logging system with the error handling system, specifically for tests that expect errors. Here's how it works:

1. **Test Context Awareness**: The logger now checks with the error handler whether the current test expects errors before deciding how to log an error message.

2. **Level Downgrading**: Instead of completely suppressing errors, ERROR and WARNING level messages are downgraded to DEBUG level with an [EXPECTED] prefix.

3. **Selective Filtering**: This downgrading only happens in tests that explicitly set the `expect_error = true` flag.

4. **Diagnostic Support**: When debug logging is enabled, expected errors will still be visible but clearly marked.

5. **Zero Configuration**: Test authors don't need to make any changes to their tests - it just works with the existing patterns.

## Implementation Details

The implementation required one change to the core logging module:

### 1. Error Handler Integration in the Logger

Added logic to the logger to check with the error handler if a test expects errors before deciding how to log:

```lua
-- Lazy load error_handler module
local _error_handler
local function get_error_handler()
  if not _error_handler then
    local success, module = pcall(require, "lib.tools.error_handler")
    if success then
      _error_handler = module
    end
  end
  return _error_handler
end

-- Check with error_handler if the current test expects errors
local function current_test_expects_errors()
  local error_handler = get_error_handler()
  
  -- If error_handler is loaded and has the function, call it
  if error_handler and error_handler.current_test_expects_errors then
    return error_handler.current_test_expects_errors()
  end
  
  -- Default to false if we couldn't determine
  return false
end

-- The core logging function
local function log(level, module_name, message, params)
  -- For expected errors in tests, downgrade ERROR and WARNING to DEBUG level
  -- This ensures they're available when debug logging is enabled
  if level <= M.LEVELS.WARN then
    if current_test_expects_errors() then
      -- Prefix message to indicate this is an expected error
      message = "[EXPECTED] " .. message
      
      -- Check if debug logging is enabled
      if is_enabled(M.LEVELS.DEBUG, module_name) then
        -- Log as DEBUG instead of ERROR/WARNING
        level = M.LEVELS.DEBUG
      else
        -- If debug logging is not enabled, skip this log
        return
      end
    end
  end
  
  -- Rest of logging function...
}
```

This solution leverages the existing `current_test_expects_errors()` function in the error handler module to check if the current test has the `expect_error = true` flag.

## Benefits

1. **Clean Test Output**: Expected errors no longer appear in the console output during regular test runs.

2. **Debugging Support**: When debug logging is enabled, expected errors still appear but with the `[EXPECTED]` prefix for clarity.

3. **No Test Changes Required**: Existing tests using the `{ expect_error = true }` flag work automatically without modifications.

4. **Selective Processing**: Only errors in tests that expect them are processed differently, while real errors continue to be logged normally.

5. **Integrated with Existing Pattern**: Uses the established `expect_error` flag that's already part of the test framework.

## Usage Example

Tests can continue to be written using the existing pattern:

```lua
it("handles malformed coverage data without crashing", { expect_error = true }, function()
  -- Test with incomplete coverage data
  local malformed_data = {
    -- Missing summary field
    files = {
      ["/path/to/malformed.lua"] = {
        -- Missing required fields
      }
    }
  }
  
  -- Use error_capture to suppress expected errors from showing in output
  local result = test_helper.with_error_capture(function()
    return reporting.format_coverage(malformed_data, "json")
  end)()
  
  -- Should return valid JSON even with malformed input
  expect(result).to.exist()
  expect(type(result)).to.equal("string")
  
  -- Should contain defaults for missing values
  expect(result).to.match("overall_pct")
end)
```

When this test runs:
- With normal logging: No error messages will appear for expected errors
- With debug logging: Error messages will appear but with the `[EXPECTED]` prefix

## Accessing Expected Errors for Diagnostics

The implementation provides two complementary ways to access expected errors for diagnostics:

### 1. Module-Specific Debug Logging

The error suppression system works by downgrading ERROR and WARNING logs to DEBUG level in tests with the `expect_error = true` flag. This means you'll only see these logs when:

1. The module that generates the error has DEBUG logging enabled
2. The error occurs in a test with the `expect_error = true` flag

For example, to see expected errors from the Reporting module:

```bash
# Enable DEBUG logging for specific modules that generate errors
lua test.lua --set-module-level=Reporting=DEBUG tests/reporting/formatters/json_formatter_test.lua
```

**Example Output** with DEBUG enabled for TestModule:

```
# Regular ERROR (outside a test with expect_error flag)
2025-03-19 12:06:51 | ERROR | TestModule | Regular error message

# ERROR in a test with expect_error flag (downgraded to DEBUG with prefix)
2025-03-19 12:06:51 | DEBUG | TestModule | [EXPECTED] Expected error message
```

**Behavior explained**:
* Errors from modules without DEBUG logging are completely suppressed in tests with `expect_error = true`
* Errors from modules with DEBUG logging show as DEBUG level with [EXPECTED] prefix
* All expected errors are captured in the error history regardless of log level

### 2. Error History

All expected errors are automatically stored in a global registry that can be accessed programmatically:

```lua
-- After running tests with expected errors
local error_handler = require("lib.tools.error_handler")
local expected_errors = error_handler.get_expected_test_errors()

-- Print all expected errors
for i, err in ipairs(expected_errors) do
  print(string.format("[%s] From module %s: %s", 
    os.date("%H:%M:%S", err.timestamp),
    err.module or "unknown", 
    err.message))
end

-- Clear expected errors when done
error_handler.clear_expected_test_errors()
```

This is particularly useful in interactive debugging sessions or when you want to analyze expected errors without enabling debug logging for the entire test run.

## Considerations

1. **Multiple Diagnostics Approaches**: 
   - Enable debug logging to see expected errors in real-time with [EXPECTED] prefix
   - Use the error history API to access errors programmatically
   - Access error information through the returned error objects in tests

2. **Level-Awareness**: Downgrading happens only for ERROR and WARNING levels, not for INFO or DEBUG logs.

3. **Circular Dependency Management**: The implementation carefully manages circular dependencies between the logging and error handling modules through lazy loading.

## Future Enhancements

1. **Error History**: Could implement an optional error history for tests with `expect_error = true` for advanced debugging.

2. **Custom Log Outputs**: Could extend to allow selective suppression in file-based logs versus console logs.

3. **Module-specific Suppression**: Could add more granular control to suppress errors only from specific modules.