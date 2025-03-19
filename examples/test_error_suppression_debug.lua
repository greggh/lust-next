-- Test script to demonstrate error suppression with DEBUG level
local firmo = require("firmo")
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Set DEBUG level for a specific test module
logging.set_module_level("TestModule", logging.LEVELS.DEBUG)

-- Create loggers
local test_logger = logging.get_logger("TestModule")
local other_logger = logging.get_logger("OtherModule") 

-- Define a function that logs errors
local function function_with_errors()
  test_logger.error("Error from TestModule - this would be suppressed in expect_error test")
  other_logger.error("Error from OtherModule - this would be suppressed in expect_error test")
  return nil, { message = "Test error", category = "TEST" }
end

-- Regular test (no expect_error flag)
print("\n=== Regular Test (without expect_error flag) ===")
print("You should see BOTH error logs:")
function_with_errors()

-- Extract the describe and it functions
local describe, it = firmo.describe, firmo.it

-- Run a test with expect_error flag
describe("Error Suppression Test", function()
  it("suppresses errors for TestModule but shows them as DEBUG when debug level is enabled", { expect_error = true }, function()
    print("\n=== Test with expect_error flag ===")
    print("You should see ONE debug log with [EXPECTED] prefix from TestModule:")
    local result, err = function_with_errors()
    
    -- Basic test assertions
    firmo.expect(result).to_not.exist()
    firmo.expect(err).to.exist()
    firmo.expect(err.category).to.equal("TEST")
    
    -- Show captured errors for debugging
    print("\n=== Captured Error History ===")
    local errors = error_handler.get_expected_test_errors()
    print("Errors captured: " .. #errors)
    for i, err in ipairs(errors) do
      print(string.format("Error %d: [%s] %s", i, err.module or "unknown", err.message))
    end
    
    -- Clear errors
    error_handler.clear_expected_test_errors()
  end)
end)

-- Run the test function to execute the it() block
firmo.run()