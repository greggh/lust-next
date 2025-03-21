-- Basic usage example for firmo
-- This example demonstrates the correct usage patterns for firmo tests

-- Import the firmo framework
local firmo = require("firmo")

-- Extract testing functions (preferred way to import)
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Optional: Import error handling utilities for testing errors
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- A simple calculator module to test
local calculator = {
  add = function(a, b) return a + b end,
  subtract = function(a, b) return a - b end,
  multiply = function(a, b) return a * b end,
  divide = function(a, b)
    if b == 0 then 
      return nil, error_handler.validation_error(
        "Cannot divide by zero", 
        {parameter = "b", provided_value = b}
      )
    end
    return a / b
  end
}

-- Test suite using nested describe blocks
describe("Calculator", function()
  -- Setup that runs before each test
  before(function()
    -- Use structured logging
    firmo.log.info("Setting up test", {
      module = "calculator",
      timestamp = os.time()
    })
  end)
  
  -- Cleanup that runs after each test
  after(function()
    firmo.log.info("Cleaning up test", {
      module = "calculator",
      timestamp = os.time()
    })
  end)
  
  describe("Basic Operations", function()
    describe("addition", function()
      it("adds two positive numbers", function()
        expect(calculator.add(2, 3)).to.equal(5)
      end)
      
      it("adds a positive and a negative number", function()
        expect(calculator.add(2, -3)).to.equal(-1)
      end)
    end)
    
    describe("subtraction", function()
      it("subtracts two numbers", function()
        expect(calculator.subtract(5, 3)).to.equal(2)
      end)
    end)
    
    describe("multiplication", function()
      it("multiplies two numbers", function()
        expect(calculator.multiply(2, 3)).to.equal(6)
      end)
    end)
  end)
  
  describe("Advanced Operations", function()
    describe("division", function()
      it("divides two numbers", function()
        expect(calculator.divide(6, 3)).to.equal(2)
      end)
      
      -- Example of proper error testing using expect_error flag
      it("handles division by zero", { expect_error = true }, function()
        -- Use with_error_capture to safely call functions that may return errors
        local result, err = test_helper.with_error_capture(function()
          return calculator.divide(5, 0)
        end)()
        
        -- Make assertions about the error
        expect(result).to_not.exist()
        expect(err).to.exist()
        expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
        expect(err.message).to.match("divide by zero")
      end)
    end)
  end)
end)

-- NOTE: Run this example using the standard test runner:
-- lua test.lua examples/basic_example.lua
