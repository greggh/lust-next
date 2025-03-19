-- Helper module for error handling tests
local error_handler = require("lib.tools.error_handler")

local helper = {}

-- Function that safely wraps test functions expected to fail
function helper.with_error_capture(fn)
  return function()
    -- Set up test to expect errors
    error_handler.set_current_test_metadata({
      name = debug.getinfo(1, "n").name or "unknown",
      expect_error = true
    })
    
    -- Use protected call
    local success, result = pcall(fn)
    
    -- Clear test metadata
    error_handler.set_current_test_metadata(nil)
    
    if not success then
      -- Captured an expected error - just log it at debug level
      error_handler.set_test_mode(true)
      
      -- Return a structured error object for easy inspection
      if type(result) == "string" then
        return nil, error_handler.test_expected_error(result, {
          captured_error = result,
          source = debug.getinfo(1, "S").source
        })
      else
        return nil, result
      end
    end
    
    return result
  end
end

return helper