# Error Line Tracking Enhancement in Coverage Module

## Problem Description

The coverage system had an issue with tracking lines containing `error()` calls. When a test would use `expect(...).to.fail()` to test error conditions, the error line would never be marked as covered in the coverage report. This is because the Lua debug hook system doesn't get a chance to track the line before the error is thrown, as the error interrupts normal execution flow.

## Implemented Solution

We implemented a solution that overrides Lua's global `error()` function to track error lines before throwing the actual error. This ensures that lines with error calls are properly marked as covered when tested with `expect(...).to.fail()`.

### Technical Implementation

1. **Custom Error Handler**: We override the global `error()` function with our own implementation that:
   - Captures information about where the error is thrown (file path and line number)
   - Marks the error line as executed in our coverage data
   - Passes control to the original error function to maintain normal error behavior

2. **Integration with Coverage Lifecycle**:
   - The error tracking is enabled when coverage starts
   - The original error function is restored when coverage stops
   - Debug logging is provided to track when error lines are marked as covered

3. **Seamless Integration**:
   - The solution works without requiring any changes to test code
   - Tests using `expect(...).to.fail()` now automatically track error lines
   - No special case handling required for different file types

### Code Changes

The main changes were made in `lib/coverage/debug_hook.lua`:

1. Added a variable to store the original error function
2. Implemented a `setup_error_line_tracking()` function that overrides the global error function
3. Modified the `start()` function to enable error tracking
4. Modified the `stop()` function to restore the original error function

### Results

The enhancement ensures that error lines are properly tracked in coverage reports. This leads to:

1. More accurate coverage metrics
2. More representative coverage reports that correctly show error handling code as covered
3. Better identification of genuinely uncovered code paths

## Example

In our `calculator.lua` test case:

```lua
-- Before: This line wasn't marked as covered despite being tested
if b == 0 then
  error("Division by zero") -- This line was reported as uncovered
end

-- After: The error line is now properly marked as covered when tested with:
expect(function()
  calculator.divide(5, 0)
end).to.fail()
```

## Additional Benefits

This fix provides several advantages:

1. **Comprehensive Coverage**: All aspects of code, including error handling, are now tracked
2. **No False Negatives**: Error handling code no longer appears as uncovered when it's actually tested
3. **Accurate Metrics**: Coverage percentages more accurately reflect the true test coverage
4. **Zero Impact on Performance**: The solution adds minimal overhead and only affects code with error() calls
5. **No Special Cases**: The solution works for all files and doesn't require special handling for specific files

## Considerations and Limitations

While the solution is highly effective, there are a few considerations:

1. It only tracks errors thrown via the standard Lua `error()` function
2. Custom error mechanisms or C-level errors will not be tracked
3. The solution relies on overriding a global function, which could potentially conflict with other libraries that might do the same

## Future Improvements

Potential future enhancements could include:

1. Tracking other error mechanisms beyond the standard `error()` function
2. Providing a more detailed breakdown of error handling coverage in reports
3. Supporting tracking of pcall/xpcall error recovery paths

These improvements could be considered for future enhancements to the coverage module.