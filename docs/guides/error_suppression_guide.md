# Error Suppression Guide

This guide explains how to use Firmo's error suppression system for tests that intentionally trigger errors.

## Overview

When writing tests that verify error conditions, we want to:
1. Confirm that errors are thrown correctly
2. Validate the error properties
3. Keep test output clean by suppressing expected errors
4. Make error details available when debugging

The error suppression system provides a standardized way to accomplish these goals.

## Key Components

The error suppression system consists of:

1. **Test Annotation**: Using `{ expect_error = true }` to mark tests that expect errors
2. **Error Capture**: Using `test_helper.with_error_capture()` to safely capture errors
3. **Logging Downgrade**: Automatic downgrading of expected ERROR/WARNING logs to DEBUG level
4. **Error Marking**: Adding `[EXPECTED]` prefix to suppressed errors in debug mode
5. **Error History**: Global registry to access expected errors programmatically

## Usage Examples

### Basic Error Testing Pattern

```lua
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Import firmo testing functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("MyModule", function()
  -- Mark test as expecting errors with { expect_error = true }
  it("should reject invalid input", { expect_error = true }, function()
    -- Use with_error_capture to safely call functions that may throw
    local result, err = test_helper.with_error_capture(function()
      return my_module.process("invalid input")
    end)()
    
    -- Make assertions about the error
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Invalid input")
  end)
end)
```

### Testing Functions with Different Error Patterns

Some functions return `nil, error` while others return `false`:

```lua
it("handles both error patterns", { expect_error = true }, function()
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
```

### Using the Error History API

For advanced use cases, you can access expected errors programmatically:

```lua
local function count_expected_errors()
  local errors = error_handler.get_expected_errors()
  return #errors
end

it("should record multiple errors", { expect_error = true }, function()
  local start_count = count_expected_errors()
  
  -- Generate multiple errors
  test_helper.with_error_capture(function() error("Error 1") end)()
  test_helper.with_error_capture(function() error("Error 2") end)()
  
  -- Verify errors were recorded
  local end_count = count_expected_errors()
  expect(end_count - start_count).to.equal(2)
end)
```

## Implementation Details

### Logging Downgrade Logic

The logging system automatically detects if a test has the `expect_error = true` flag and downgrades ERROR/WARNING logs to DEBUG level. This happens in the core logging function:

```lua
-- In lib/tools/logging.lua
local function log_with_level(level, message, metadata)
  -- Check if we're in a test that expects errors
  local in_error_test = error_handler and error_handler.is_in_expect_error_test()
  
  -- For ERROR/WARNING in expected error tests, downgrade to DEBUG
  if in_error_test and (level == LEVEL.ERROR or level == LEVEL.WARNING) then
    -- Prefix message with [EXPECTED]
    message = "[EXPECTED] " .. message
    
    -- Only show expected errors if in debug mode
    if not debug_flag_enabled() then
      level = LEVEL.DEBUG
    end
  end
  
  -- Normal logging logic continues...
end
```

### Debug Mode

To see expected errors during debugging, run tests with the `--debug` flag:

```bash
lua test.lua --debug tests/my_module_test.lua
```

This will show all expected errors with the `[EXPECTED]` prefix while maintaining regular log levels.

## Best Practices

1. **Always use `expect_error = true`** for tests that expect errors
2. **Always use `test_helper.with_error_capture()`** to safely capture errors
3. **Be flexible with error checking** - use `match()` instead of `equal()` for error messages
4. **Test for existence first** - check that values exist before making assertions about them
5. **Use the debug flag** when troubleshooting error tests: `lua test.lua --debug`
6. **Clean up resources properly** even in error tests (use pcall or try/finally patterns)

## Troubleshooting

### Errors Still Showing in Test Output

If errors are still appearing in normal test output:

1. Check that the test has `{ expect_error = true }` annotation
2. Verify that you're using `test_helper.with_error_capture()` for the error-generating code
3. Ensure your test module imports `test_helper` correctly
4. If testing third-party code, make sure errors are caught before reaching the test engine

### Debugging Suppressed Errors

To see suppressed errors:

1. Run tests with debug flag: `lua test.lua --debug [test path]`
2. Look for entries with the `[EXPECTED]` prefix
3. Use `error_handler.get_expected_errors()` to programmatically access error history

## Related Documentation

For more information, see:
- [Error Handling Guidelines](../api/error_handling_guide.md)
- [Test Helper API Reference](../api/test_helper.md)
- [Logger Configuration](../configuration/logging.md)