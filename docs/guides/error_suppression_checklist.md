# Error Suppression Checklist

Use this checklist when updating tests to use the error suppression system.

## Identifying Tests That Need Updates

A test should be updated to use the error suppression system if it:

- [ ] Tests functions that intentionally throw errors
- [ ] Has assertions about error messages or error objects
- [ ] Uses `pcall` to capture expected errors
- [ ] Is generating noisy ERROR/WARNING logs during normal test runs
- [ ] Tests validation failures or other expected error conditions

## Step-by-Step Update Process

For each test file that needs updating:

1. [ ] Add test_helper import:
   ```lua
   local test_helper = require("lib.tools.test_helper")
   ```

2. [ ] Add error_handler import if needed:
   ```lua
   local error_handler = require("lib.tools.error_handler")
   ```

3. [ ] For each test that expects errors, add the `expect_error` flag:
   ```lua
   it("should handle error condition", { expect_error = true }, function()
     -- Test code here
   end)
   ```

4. [ ] Replace manual error handling with test_helper:
   - [ ] Replace `pcall()` with `test_helper.with_error_capture()`
   - [ ] Replace explicit error checking with `expect(err).to.exist()`

5. [ ] Update test assertions to use pattern matching for error messages:
   ```lua
   expect(err.message).to.match("expected pattern")
   ```

6. [ ] Run tests with and without debug flag to verify:
   ```bash
   lua test.lua tests/my_test.lua
   lua test.lua --debug tests/my_test.lua
   ```

## Common Error Handling Patterns

### Replace pcall() Pattern

```lua
-- OLD
local ok, result = pcall(function() return risky_function() end)
expect(ok).to_not.be_truthy()
expect(result).to.contain("error message")

-- NEW
local result, err = test_helper.with_error_capture(function()
  return risky_function()
end)()

expect(result).to_not.exist()
expect(err).to.exist()
expect(err.message).to.match("error message")
```

### Replace try-catch Pattern

```lua
-- OLD
local success, result = nil, nil
try {
  function()
    result = risky_function()
    success = true
  end,
  catch {
    function(e)
      success = false
      result = e
    end
  }
}
expect(success).to_not.be_truthy()
expect(result).to.contain("error message")

-- NEW
it("should handle errors correctly", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return risky_function()
  end)()
  
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.message).to.match("error message")
end)
```

### Replace nil, err Return Pattern

```lua
-- OLD
local result, err = function_that_returns_nil_and_error()
expect(result).to.equal(nil)
expect(err).to.contain("error message")

-- NEW
it("should handle errors correctly", { expect_error = true }, function()
  local result, err = function_that_returns_nil_and_error()
  
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.message).to.match("error message")
end)
```

## Additional Tips

1. Test files may have different error handling patterns. Take time to understand the existing pattern before updating.

2. Use debug flag to verify errors are still accessible when needed:
   ```bash
   lua test.lua --debug tests/path/to/test.lua
   ```

3. For more complex error handling, consider using the error history API:
   ```lua
   local errors = error_handler.get_expected_errors()
   ```

4. Be cautious when updating tests that:
   - Create and manipulate files
   - Involve timeouts or async operations
   - Use custom error handling mechanisms

5. Always run the tests after updating to ensure they still pass and correctly validate error conditions.