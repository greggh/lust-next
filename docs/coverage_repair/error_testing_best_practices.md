# Error Testing Best Practices in firmo

This guide provides detailed information on how to effectively test error conditions in the firmo framework using the test_helper module and expect_error flag.

## Overview

Testing error conditions is a critical part of ensuring your code works correctly. firmo provides specialized tools and patterns to make testing error conditions cleaner, more reliable, and more informative.

## Error Testing Approaches

firmo supports these approaches for testing error conditions:

### 1. Using the expect_error Flag

For tests that intentionally produce errors, add the `expect_error` flag to tell the test system these errors are expected:

```lua
it("should handle invalid input", { expect_error = true }, function()
  local result, err = function_that_returns_error()
  
  -- Make assertions about the error
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
end)
```

This flag tells the test runner to:
- Suppress error messages for this test
- Not mark the test as failed if errors occur
- Allow you to make assertions about the errors

### 2. Using test_helper.with_error_capture()

For complex scenarios where you need to capture errors thrown by functions:

```lua
local test_helper = require("lib.tools.test_helper")

it("should handle exceptions", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    -- Code that might throw an error
    error("Expected error")
  end)()
  
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.message).to.match("Expected error")
end)
```

This approach:
- Safely executes the function inside a protected call
- Converts thrown errors into structured error objects
- Returns nil + error when an error occurs
- Returns the function result when successful

### 3. Using test_helper.expect_error()

For concisely testing that a function throws a specific error:

```lua
it("should throw the right error", { expect_error = true }, function()
  local err = test_helper.expect_error(
    function_that_should_throw,
    "expected error message pattern"
  )
  
  -- Additional assertions about the error
  expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
end)
```

This approach:
- Verifies the function throws an error (fails if no error is thrown)
- Checks the error message matches the pattern (optional)
- Returns the error object for additional assertions

## Testing Different Error Types

### 1. Functions That Return nil + error

For functions that follow the nil + error Lua pattern:

```lua
function calc_square_root(n)
  if n < 0 then
    return nil, "Cannot calculate square root of negative number"
  end
  return math.sqrt(n)
end

-- Test the error case
it("should reject negative numbers", { expect_error = true }, function()
  local result, err = calc_square_root(-5)
  expect(result).to_not.exist()
  expect(err).to.equal("Cannot calculate square root of negative number")
end)
```

### 2. Functions That Throw Errors

For functions that throw errors:

```lua
function parse_config(str)
  if not str or str == "" then
    error("Empty config string")
  end
  -- Parsing logic...
end

-- Test the error case
it("should reject empty input", { expect_error = true }, function()
  local err = test_helper.expect_error(function()
    parse_config("")
  end, "Empty config string")
  
  expect(err).to.exist()
end)
```

### 3. Functions That Return Structured Errors

For functions that return structured error objects:

```lua
function validate_input(input)
  if not input then
    return nil, error_handler.validation_error(
      "Input is required",
      {parameter = "input", operation = "validate_input"}
    )
  end
  return input
end

-- Test the error case
it("should validate input presence", { expect_error = true }, function()
  local result, err = validate_input(nil)
  
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
  expect(err.message).to.equal("Input is required")
  expect(err.context.parameter).to.equal("input")
end)
```

## Best Practices

### 1. Always Use expect_error Flag

Always add the `expect_error = true` flag to tests that intentionally test error conditions:

```lua
it("should handle the error case", { expect_error = true }, function()
  -- Test code...
end)
```

### 2. Be Specific with Error Assertions

Make assertions that are as specific as possible about the error:

```lua
expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
expect(err.message).to.match("Invalid input")
expect(err.context.parameter).to.equal("user_id")
```

### 3. Test All Error Paths

Ensure you test all possible error conditions, not just the happy path:

```lua
describe("Input validation", function()
  it("handles valid input", function()
    -- Test the success case
  end)
  
  it("rejects nil input", { expect_error = true }, function()
    -- Test nil input error
  end)
  
  it("rejects invalid type", { expect_error = true }, function()
    -- Test type error
  end)
  
  it("rejects out of range values", { expect_error = true }, function()
    -- Test range error
  end)
end)
```

### 4. Use the Right Tool for the Job

- For functions that throw errors: use `test_helper.expect_error()`
- For complex code with multiple error paths: use `test_helper.with_error_capture()`
- For returning structured errors: test directly with assertions

### 5. Test Error Propagation

Test that errors propagate correctly through function calls:

```lua
it("should propagate validation errors", { expect_error = true }, function()
  local result, err = outer_function_that_calls_inner_function()
  
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.message).to.match("Original error from inner function")
end)
```

## Examples

See the following examples for comprehensive error testing patterns:
- `/examples/test_error_handling_example.lua`
- `/examples/enhanced_error_testing_example.lua`

## Conclusion

Properly testing error conditions is essential for building robust code. By using the expect_error flag and test_helper module, you can create clear, consistent, and reliable tests for all error scenarios in your code.

The test system will automatically distinguish between expected errors (in tests with the expect_error flag) and unexpected errors (real test failures), leading to cleaner test output and more accurate test results.