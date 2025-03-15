--[[
  html_coverage_example.lua
  
  Example that demonstrates HTML coverage reports with execution vs. coverage distinction.
  This example is designed to clearly show the difference between:
  
  1. Code that is executed and validated by tests (covered)
  2. Code that is executed but not validated (executed-not-covered)
  3. Code that is never executed (uncovered)
]]

-- Import modules
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local fs = require("lib.tools.filesystem")

-- Sample Calculator implementation to test
local Calculator = {}

-- This function will be covered (executed and validated)
function Calculator.add(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a + b
end

-- This function will be executed but not validated
function Calculator.subtract(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a - b
end

-- This function will not be executed at all
function Calculator.multiply(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a * b
end

-- Run tests with coverage tracking
describe("HTML Coverage Report Example", function()
  
  -- Tests that both execute and validate code (coverage)
  describe("add function", function()
    it("correctly adds two numbers", function()
      local result = Calculator.add(5, 3)
      expect(result).to.equal(8) -- This validates the execution
    end)
    
    it("handles invalid inputs", function()
      local result, err = Calculator.add("string", 10)
      expect(result).to_not.exist()
      expect(err).to.equal("Both arguments must be numbers")
    end)
  end)
  
  -- Tests that execute code but don't validate it
  describe("subtract function", function()
    it("executes the subtract function without validating it", function()
      local result = Calculator.subtract(10, 4)
      -- No validations here, so this is executed but not covered
    end)
  end)
  
  -- No tests for multiply function, so it will not be executed at all
end)

-- Display instructions
print("\nRunning this example with the coverage flag will generate an HTML report.")
print("Execute the following command to see the HTML coverage report:")
print("\n  lua test.lua --coverage --format=html examples/html_coverage_example.lua\n")
print("The HTML report will show:")
print("1. add function: Covered (green) - executed and validated by tests")
print("2. subtract function: Executed-not-covered (yellow) - executed but not validated")
print("3. multiply function: Uncovered (red) - never executed during tests")
print("\nAfter running the command, open the generated HTML file in a web browser.\n")