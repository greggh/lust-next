-- Test helper module for improved error handling in tests
--
-- This module provides utilities to make it easier to test error conditions.
-- It works in conjunction with the { expect_error = true } flag that can be
-- added to test cases.
--
-- Usage examples:
-- 
-- 1. Using with_error_capture to safely test functions that throw errors:
--    ```lua
--    -- This captures errors and returns them as structured objects
--    local result, err = test_helper.with_error_capture(function()
--      some_function_that_throws()
--    end)()
--    
--    -- Now you can make assertions about the error
--    expect(err).to.exist()
--    expect(err.message).to.match("expected error message")
--    ```
--
-- 2. Using expect_error to verify a function throws an error with a specific message:
--    ```lua
--    -- This will automatically check that the function fails with the right message
--    local err = test_helper.expect_error(fails_with_message, "expected error")
--    ```
--
-- 3. Adding the expect_error flag to tests that are expected to have errors:
--    ```lua
--    it("should handle error conditions", { expect_error = true }, function()
--      -- Any errors in this test will be properly handled
--      local result, err = function_that_errors()
--      expect(result).to_not.exist()
--      expect(err).to.exist()
--    end)
--    ```
--
local error_handler = require("lib.tools.error_handler")

local helper = {}

-- Function that safely wraps test functions expected to fail
-- This provides a standardized way to test error conditions
function helper.with_error_capture(fn)
  return function()
    -- Set up test to expect errors
    error_handler.set_current_test_metadata({
      name = debug.getinfo(2, "n").name or "unknown",
      expect_error = true
    })
    
    -- Use protected call
    local success, result = pcall(fn)
    
    -- Clear test metadata
    error_handler.set_current_test_metadata(nil)
    
    if not success then
      -- Captured an expected error - process it
      
      -- Return a structured error object for easy inspection
      if type(result) == "string" then
        return nil, error_handler.test_expected_error(result, {
          captured_error = result,
          source = debug.getinfo(2, "S").source
        })
      else
        return nil, result
      end
    end
    
    return result
  end
end

-- Function to verify that a function throws an error
-- Returns the error object/message for further inspection
function helper.expect_error(fn, message_pattern)
  local result, err = helper.with_error_capture(fn)()
  
  if result ~= nil then
    error(error_handler.test_expected_error(
      "Function was expected to throw an error but it returned a value",
      { returned_value = result }
    ))
  end
  
  if not err then
    error(error_handler.test_expected_error(
      "Function was expected to throw an error but no error was thrown"
    ))
  end
  
  if message_pattern and type(err) == "table" and err.message then
    if not err.message:match(message_pattern) then
      error(error_handler.test_expected_error(
        "Error message does not match expected pattern",
        {
          expected_pattern = message_pattern,
          actual_message = err.message
        }
      ))
    end
  end
  
  return err
end

return helper