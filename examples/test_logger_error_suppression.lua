-- Test script for logger error suppression
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Create test loggers
local logger1 = logging.get_logger("TestLogger1")
local logger2 = logging.get_logger("TestLogger2")

-- Set debug level for TestLogger2
logging.set_module_level("TestLogger2", logging.LEVELS.DEBUG)

-- Test function that simulates being in a test with expect_error flag
local function run_with_expected_errors(func)
  -- Setup: set the current test metadata to expect errors
  error_handler.set_current_test_metadata({
    name = "test_example",
    expect_error = true
  })
  
  -- Run the test function
  func()
  
  -- Teardown: clear the test metadata
  error_handler.set_current_test_metadata(nil)
end

print("\nTest 1: Regular errors (should all show)")
logger1.error("Regular error 1 - should show")
logger2.error("Regular error 2 - should show")
logger1.warn("Regular warning 1 - should show")
logger2.warn("Regular warning 2 - should show")
logger1.debug("Regular debug 1 - shouldn't show (debug level not enabled)")
logger2.debug("Regular debug 2 - should show (debug level enabled)")

print("\nTest 2: Expected errors (should be suppressed or downgraded)")
run_with_expected_errors(function()
  logger1.error("Expected error 1 - should NOT show")
  logger2.error("Expected error 2 - should show as DEBUG with [EXPECTED] prefix")
  logger1.warn("Expected warning 1 - should NOT show")
  logger2.warn("Expected warning 2 - should show as DEBUG with [EXPECTED] prefix")
  logger1.debug("Expected debug 1 - shouldn't show (debug level not enabled)")
  logger2.debug("Expected debug 2 - should show normally")
end)

print("\nTest 3: Check error history")
local expected_errors = error_handler.get_expected_test_errors()
print("Number of captured expected errors: " .. #expected_errors)
for i, err in ipairs(expected_errors) do
  print(string.format("[%s] From module %s: %s", 
    os.date("%H:%M:%S", err.timestamp),
    err.module or "unknown", 
    err.message))
end

-- Clear error history
error_handler.clear_expected_test_errors()
print("Errors cleared: " .. #error_handler.get_expected_test_errors())