-- Example to demonstrate test quality validation
local lust_next = require('lust-next')

-- A simple calculator module to test
local calculator = {}

-- Basic operations
calculator.add = function(a, b)
  return a + b
end

calculator.subtract = function(a, b)
  return a - b
end

calculator.multiply = function(a, b)
  return a * b
end

calculator.divide = function(a, b)
  if b == 0 then
    error("Division by zero")
  end
  return a / b
end

-- Advanced operation with boundary checking
calculator.power = function(base, exponent)
  if exponent < 0 then
    return 1 / calculator.power(base, -exponent)
  elseif exponent == 0 then
    return 1
  else
    local result = base
    for i = 2, exponent do
      result = result * base
    end
    return result
  end
end

-- Level 1 tests - Basic tests with minimal assertions
describe("Calculator - Level 1 (Basic)", function()
  -- This test has only one assertion
  it("adds two numbers", function()
    assert.equal(calculator.add(2, 3), 5)
  end)
end)

-- Level 2 tests - Standard tests with more assertions
describe("Calculator - Level 2 (Standard)", function()
  it("should add two positive numbers correctly", function()
    assert.equal(calculator.add(2, 3), 5)
    assert.equal(calculator.add(0, 5), 5)
    assert(calculator.add(10, 20) == 30, "10 + 20 should equal 30")
  end)
  
  it("should subtract properly", function()
    assert.equal(calculator.subtract(5, 3), 2)
    assert.equal(calculator.subtract(10, 5), 5)
  end)
  
  -- Setup and teardown functions
  before(function()
    -- Set up any test environment needed
    print("Setting up test environment")
  end)
  
  after(function()
    -- Clean up after tests
    print("Cleaning up test environment")
  end)
end)

-- Level 3 tests - Comprehensive with edge cases
describe("Calculator - Level 3 (Comprehensive)", function()
  -- Using context nesting
  describe("when performing division", function()
    it("should divide two numbers", function()
      assert.equal(calculator.divide(10, 2), 5)
      assert.equal(calculator.divide(7, 2), 3.5)
      assert.type(calculator.divide(10, 2), "number", "Result should be a number")
    end)
    
    it("should handle division with edge cases", function()
      assert.equal(calculator.divide(0, 5), 0)
      assert.equal(calculator.divide(-10, 2), -5)
      assert.almost_equal(calculator.divide(1, 3), 0.333333, 0.001)
    end)
    
    it("should throw error for division by zero", function()
      assert.error(function() calculator.divide(10, 0) end)
    end)
  end)
  
  before(function()
    -- Set up state
  end)
  
  after(function()
    -- Clean up state
  end)
end)

-- Level 4 tests - Advanced with mocks and boundary testing
describe("Calculator - Level 4 (Advanced)", function()
  describe("when performing power operations", function()
    it("should calculate powers with various exponents", function()
      assert.equal(calculator.power(2, 3), 8)
      assert.equal(calculator.power(5, 2), 25)
      assert.equal(calculator.power(10, 0), 1)
      assert.equal(calculator.power(2, 1), 2)
    end)
    
    it("should handle boundary conditions", function()
      -- Testing upper bounds
      local result = calculator.power(2, 10)
      assert.equal(result, 1024)
      assert(result < 2^11, "Result should be less than 2^11")
      
      -- Testing lower bounds
      local small_result = calculator.power(2, -2)
      assert.almost_equal(small_result, 0.25, 0.0001)
    end)
    
    it("should handle negative exponents correctly", function()
      assert.almost_equal(calculator.power(2, -1), 0.5, 0.0001)
      assert.almost_equal(calculator.power(4, -2), 0.0625, 0.0001)
    end)
    
    -- Mock test with call verification
    it("should track power calculations", function()
      local original_power = calculator.power
      
      -- Create a spy that tracks calls to the power function
      local spy = lust_next.spy(calculator, "power")
      
      calculator.power(3, 2)
      calculator.power(2, 8)
      
      -- Verify spy was called
      assert(spy.call_count == 2, "Power function should be called twice")
      assert(spy:called_with(3, 2), "Should be called with 3, 2")
      assert(spy:called_with(2, 8), "Should be called with 2, 8")
      
      -- Restore original function
      calculator.power = original_power
    end)
  end)
  
  before(function() end)
  after(function() end)
end)

-- Level 5 tests - Complete with security and performance
describe("Calculator - Level 5 (Complete)", function()
  describe("when considering security implications", function()
    it("should validate inputs to prevent overflow", function()
      -- Security test: very large inputs
      local large_result = calculator.power(2, 20)
      assert(large_result > 0, "Result should be positive")
      assert(large_result < 2^30, "Result should be within safe range")
      assert.type(large_result, "number", "Result should remain a number")
      assert(not tostring(large_result):match("inf"), "Result should not be infinity")
      assert(not tostring(large_result):match("nan"), "Result should not be NaN")
    end)
    
    it("should sanitize inputs from external sources", function()
      -- Simulating external input validation
      local input_a = "10" -- String input
      local input_b = "5"  -- String input
      
      -- Sanitize inputs by converting to numbers
      local a = tonumber(input_a)
      local b = tonumber(input_b)
      
      -- Verify sanitization worked
      assert.type(a, "number", "Input a should be converted to number")
      assert.type(b, "number", "Input b should be converted to number")
      
      -- Verify calculation works with sanitized inputs
      assert.equal(calculator.add(a, b), 15)
      assert.equal(calculator.divide(a, b), 2)
    end)
  end)
  
  describe("when measuring performance", function()
    it("should calculate power efficiently", function()
      -- Performance test: measure execution time
      local start_time = os.clock()
      calculator.power(2, 20)
      local end_time = os.clock()
      local execution_time = end_time - start_time
      
      -- Verify performance is within acceptable range
      assert(execution_time < 0.01, "Power calculation should be fast")
      assert(execution_time >= 0, "Execution time should be non-negative")
      assert.type(execution_time, "number", "Execution time should be a number")
      assert(not tostring(execution_time):match("nan"), "Execution time should not be NaN")
      assert(not tostring(execution_time):match("inf"), "Execution time should not be infinity")
    end)
  end)
  
  before(function() end)
  after(function() end)
end)

-- Run this example with quality validation:
-- lua lust-next.lua --quality --quality-level=3 examples/quality_example.lua
-- 
-- Try different quality levels:
-- lua lust-next.lua --quality --quality-level=1 examples/quality_example.lua
-- lua lust-next.lua --quality --quality-level=5 examples/quality_example.lua