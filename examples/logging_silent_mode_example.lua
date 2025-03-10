-- Example demonstrating silent mode for tests
local logging = require("lib.tools.logging")

-- Create a testing function that uses logging
local function test_function_with_logging()
  local logger = logging.get_logger("test_module")
  
  logger.info("Starting test function")
  
  for i = 1, 3 do
    logger.debug("Processing item", {index = i})
  end
  
  logger.error("Test error message", {error_code = 123})
  
  logger.info("Test function completed")
  
  return "Test result"
end

print("=== Silent Mode Example ===")
print("")
print("This example demonstrates:")
print("1. Using silent mode to suppress all logs during tests")
print("2. Testing functions that produce log output")
print("3. Verifying function behavior without log interference")
print("")

print("Running test function WITH logging:")
print("-----------------------------------")
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  silent = false -- Logging enabled
})

local result1 = test_function_with_logging()
print("Function returned: " .. result1)

print("\nRunning test function WITH silent mode:")
print("-----------------------------------------")
logging.configure({
  silent = true -- Suppress all logs
})

local result2 = test_function_with_logging()
print("Function returned: " .. result2)

-- Re-enable logging for final message
logging.configure({
  silent = false
})

print("\nAs you can see, the function worked properly in both cases,")
print("but in silent mode no log messages were displayed.")
print("")
print("This is useful for:")
print("- Running tests without cluttering output")
print("- Testing functions that produce log messages")
print("- Verifying functionality independent of logging")

-- Get a logger for this example
local logger = logging.get_logger("silent_example")
logger.info("Logging is working again", {mode = "normal"})

print("\nTips for using silent mode in tests:")
print("1. Enable silent mode before test runs")
print("2. Run your test functions")
print("3. Verify results without log interference")
print("4. Disable silent mode after tests if needed")