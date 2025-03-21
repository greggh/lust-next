-- Example demonstrating integration between logging and test formatters
local firmo = require("firmo")
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Extract testing functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Load the formatter integration module
local formatter_integration = require("lib.tools.logging.formatter_integration")

print("=== Test Formatter Integration Example ===")
print("")
print("This example demonstrates:")
print("1. Enhancing test formatters with logging capabilities")
print("2. Creating test-specific loggers with context")
print("3. Integrating with the test reporting system")
print("4. Using a specialized log-optimized formatter")
print("")

-- Configure logging
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  output_file = "formatter_integration.log",
  json_file = "formatter_integration.json",
  log_dir = "logs"
})

-- Create a logger for this example
local logger = logging.get_logger("formatter_integration_example")
logger.info("Starting formatter integration example")

-- Enhance formatters with logging capabilities
local formatters = formatter_integration.enhance_formatters()
if not formatters then
  logger.error("Failed to enhance formatters")
  print("Failed to enhance formatters")
  return
end

logger.info("Formatters enhanced with logging capabilities")

-- Create the log formatter
local log_formatter = formatter_integration.create_log_formatter()
if not log_formatter then
  logger.error("Failed to create log formatter")
  print("Failed to create log formatter")
  return
end

logger.info("Log formatter created")

-- Integrate with reporting system
local reporting = formatter_integration.integrate_with_reporting()
if not reporting then
  logger.error("Failed to integrate with reporting")
  print("Failed to integrate with reporting")
  return
end

logger.info("Integrated with reporting system")

-- Create a test logger with context
local test_logger = formatter_integration.create_test_logger("Calculator Test", {
  suite = "Math",
  category = "Unit"
})

-- Define a test suite with logging
describe("Calculator with logging", function()
  -- Log test initialization
  test_logger.info("Initializing calculator test")
  
  -- Setup test environment using logger step
  local step_logger = test_logger.step("Setup")
  step_logger.debug("Creating calculator instance")
  
  -- Mock calculator for testing with error handling
  local calculator = {
    add = function(a, b) 
      if type(a) ~= "number" or type(b) ~= "number" then
        return nil, error_handler.validation_error(
          "Both arguments must be numbers",
          {a_type = type(a), b_type = type(b)}
        )
      end
      return a + b 
    end,
    subtract = function(a, b) 
      if type(a) ~= "number" or type(b) ~= "number" then
        return nil, error_handler.validation_error(
          "Both arguments must be numbers",
          {a_type = type(a), b_type = type(b)}
        )
      end
      return a - b 
    end,
    multiply = function(a, b) 
      if type(a) ~= "number" or type(b) ~= "number" then
        return nil, error_handler.validation_error(
          "Both arguments must be numbers",
          {a_type = type(a), b_type = type(b)}
        )
      end
      return a * b 
    end,
    divide = function(a, b) 
      if type(a) ~= "number" or type(b) ~= "number" then
        return nil, error_handler.validation_error(
          "Both arguments must be numbers",
          {a_type = type(a), b_type = type(b)}
        )
      end
      if b == 0 then
        return nil, error_handler.validation_error(
          "Division by zero",
          {operation = "divide", b = b}
        )
      end
      return a / b 
    end
  }
  
  step_logger.debug("Calculator created", {functions = {"add", "subtract", "multiply", "divide"}})
  
  -- Test addition
  it("should add two numbers correctly", function()
    -- Get a step-specific logger
    local add_logger = test_logger.step("Addition Test")
    
    -- Log the test values
    add_logger.debug("Testing addition", {a = 5, b = 3, expected = 8})
    
    -- Perform the test
    local result = calculator.add(5, 3)
    
    -- Log the result
    add_logger.debug("Got result", {actual = result})
    
    -- Verify the result
    expect(result).to.equal(8)
    
    -- Log test completion
    add_logger.info("Addition test passed")
  end)
  
  -- Test subtraction
  it("should subtract two numbers correctly", function()
    -- Get a step-specific logger
    local sub_logger = test_logger.step("Subtraction Test")
    
    -- Log the test values
    sub_logger.debug("Testing subtraction", {a = 10, b = 4, expected = 6})
    
    -- Perform the test
    local result = calculator.subtract(10, 4)
    
    -- Log the result
    sub_logger.debug("Got result", {actual = result})
    
    -- Verify the result
    expect(result).to.equal(6)
    
    -- Log test completion
    sub_logger.info("Subtraction test passed")
  end)
  
  -- Test multiplication
  it("should multiply two numbers correctly", function()
    -- Get a step-specific logger
    local mul_logger = test_logger.step("Multiplication Test")
    
    -- Log the test values
    mul_logger.debug("Testing multiplication", {a = 6, b = 7, expected = 42})
    
    -- Perform the test
    local result = calculator.multiply(6, 7)
    
    -- Log the result
    mul_logger.debug("Got result", {actual = result})
    
    -- Verify the result
    expect(result).to.equal(42)
    
    -- Log test completion
    mul_logger.info("Multiplication test passed")
  end)
  
  -- Test division
  it("should divide two numbers correctly", function()
    -- Get a step-specific logger
    local div_logger = test_logger.step("Division Test")
    
    -- Log the test values
    div_logger.debug("Testing division", {a = 20, b = 5, expected = 4})
    
    -- Perform the test
    local result = calculator.divide(20, 5)
    
    -- Log the result
    div_logger.debug("Got result", {actual = result})
    
    -- Verify the result
    expect(result).to.equal(4)
    
    -- Log test completion
    div_logger.info("Division test passed")
  end)
  
  -- Test division by zero with proper error handling
  it("should handle division by zero", { expect_error = true }, function()
    -- Get a step-specific logger
    local error_logger = test_logger.step("Division by Zero Test")
    
    -- Log the test expectation
    error_logger.debug("Testing division by zero", {a = 10, b = 0, expected = "error"})
    
    -- Call the function and expect an error
    local result, err = calculator.divide(10, 0)
    
    -- Log the result
    error_logger.debug("Got expected error", {error = err})
    
    -- Verify the error was returned
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Division by zero")
    expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
    
    -- Log test completion
    error_logger.info("Division by zero test passed")
  end)
  
  -- Log test suite completion
  test_logger.info("Calculator test completed")
end)

-- Show the results
print("\nTest execution complete.")
print("To run this example with full logging:")
print("lua test.lua examples/logging_formatter_integration_example.lua")
print("\nThe detailed logs will be written to:")
print("- logs/formatter_integration.log - Text format logs")
print("- logs/formatter_integration.json - JSON format logs")

-- Log example completion
logger.info("Formatter integration example completed")

print("")
print("This example has demonstrated how to:")
print("1. Enhance test formatters with structured logging")
print("2. Create contextual loggers for specific tests")
print("3. Log detailed test execution with step tracking")
print("4. Implement proper error handling with structured errors")
print("")
print("The enhanced logs provide:")
print("- Better traceability between test execution and logs")
print("- Detailed context for test steps and failures")
print("- Structured data for external analysis tools")
print("- Consistent log format across the testing framework")