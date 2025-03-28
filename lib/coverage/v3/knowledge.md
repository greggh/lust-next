# V3 Coverage System Knowledge

## Core Principles

1. Use instrumentation-based coverage tracking instead of debug hooks
2. Track function coverage through function wrapping and assertion mapping
3. Keep original function identity for proper coverage tracking
4. Skip test files to avoid tracking test code

## Error Handling in Tests

When testing error conditions:

1. Mark test with `expect_error = true`:
```lua
it("handles invalid data", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return function_that_should_error()
  end)()
  
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.message).to.match("expected error message")
end)
```

2. ALWAYS use `test_helper.with_error_capture()` to properly capture errors
3. ALWAYS verify both that the error exists and its message matches
4. NEVER try to catch errors with pcall directly
5. NEVER suppress expected errors - they should be part of the test contract

## Function Coverage Tracking

When tracking function coverage:

1. Store original functions before wrapping
2. Use original functions for tracking and mapping
3. Wrap functions to track when they're called
4. Clear tracking state between assertions

## File Organization

1. Keep all v3 code in lib/coverage/v3/
2. Maintain separation from old coverage system
3. Follow architecture.md structure