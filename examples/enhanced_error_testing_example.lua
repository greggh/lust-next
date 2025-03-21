-- Enhanced Error Testing Example
--
-- This example demonstrates the various approaches for testing error conditions
-- using firmo's improved error handling system.

local firmo = require("firmo")

-- Import test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import test helper
local test_helper = require("lib.tools.test_helper")

-- Import error handler
local error_handler = require("lib.tools.error_handler")

-- -------------------------------------------------
-- Functions to test
-- -------------------------------------------------

-- 1. Function that returns nil + error string
local function divide(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  
  if b == 0 then
    return nil, "Division by zero"
  end
  
  return a / b
end

-- 2. Function that throws errors
local function parse_json(json_string)
  if type(json_string) ~= "string" then
    error("Input must be a string")
  end
  
  if json_string:match("^%s*$") then
    error("Cannot parse empty JSON")
  end
  
  -- In a real implementation, we'd do actual parsing here
  return {parsed = true}
end

-- 3. Function that returns structured error objects
local function validate_user(user)
  if not user then
    return nil, error_handler.validation_error(
      "User cannot be nil",
      {parameter = "user", operation = "validate_user"}
    )
  end
  
  if not user.name or type(user.name) ~= "string" then
    return nil, error_handler.validation_error(
      "User name must be a non-empty string",
      {parameter = "user.name", operation = "validate_user"}
    )
  end
  
  return user
end

-- -------------------------------------------------
-- Test suites
-- -------------------------------------------------

describe("Enhanced Error Testing Examples", function()
  -- -------------------------------------------------
  -- Testing functions that return nil + error string
  -- -------------------------------------------------
  describe("Testing functions that return nil + error", function()
    it("handles success case properly", function()
      local result, err = divide(10, 2)
      expect(result).to.equal(5)
      expect(err).to_not.exist()
    end)
    
    it("detects invalid types with expect_error flag", { expect_error = true }, function()
      local result, err = divide("10", 2)
      
      -- These assertions will pass because we used expect_error flag
      expect(result).to_not.exist()
      expect(err).to.equal("Both arguments must be numbers")
    end)
    
    it("detects division by zero", { expect_error = true }, function()
      local result, err = divide(10, 0)
      
      expect(result).to_not.exist()
      expect(err).to.equal("Division by zero")
    end)
  end)
  
  -- -------------------------------------------------
  -- Testing functions that throw errors
  -- -------------------------------------------------
  describe("Testing functions that throw errors", function()
    it("handles success case", function()
      local result = parse_json('{"key":"value"}')
      expect(result).to.exist()
      expect(result.parsed).to.equal(true)
    end)
    
    it("detects invalid input using expect_error and test_helper", { expect_error = true }, function()
      -- This approach is recommended for functions that throw errors
      local err = test_helper.expect_error(function()
        parse_json(nil)
      end, "Input must be a string")
      
      -- Additional assertions about the error if needed
      expect(err).to.exist()
      expect(err.message).to.match("Input must be a string")
    end)
    
    it("captures errors with with_error_capture", { expect_error = true }, function()
      -- Alternative approach with more detailed error handling
      local result, err = test_helper.with_error_capture(function()
        return parse_json("   ")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Cannot parse empty JSON")
    end)
  end)
  
  -- -------------------------------------------------
  -- Testing functions that return structured errors
  -- -------------------------------------------------
  describe("Testing structured error objects", function()
    it("handles valid data", function()
      local result, err = validate_user({name = "John"})
      expect(result).to.exist()
      expect(result.name).to.equal("John")
      expect(err).to_not.exist()
    end)
    
    it("detects nil user with detailed error info", { expect_error = true }, function()
      local result, err = validate_user(nil)
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.equal("User cannot be nil")
      expect(err.context.parameter).to.equal("user")
      expect(err.context.operation).to.equal("validate_user")
    end)
    
    it("detects missing user name", { expect_error = true }, function()
      local result, err = validate_user({})
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.equal("User name must be a non-empty string")
      expect(err.context.parameter).to.equal("user.name")
    end)
  end)
  
  -- -------------------------------------------------
  -- Special error testing patterns
  -- -------------------------------------------------
  describe("Special error testing patterns", function()
    it("can test error propagation", { expect_error = true }, function()
      local function outer_function(value)
        local result, err = validate_user(value)
        if not result then
          return nil, err
        end
        return result
      end
      
      local result, err = outer_function(nil)
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.equal("User cannot be nil")
    end)
    
    it("can directly check if a function throws", { expect_error = true }, function()
      -- This test checks that the function throws, but doesn't care about the error details
      test_helper.expect_error(function()
        error("This should throw")
      end)
    end)
    
    it("can extract error details for complex assertions", { expect_error = true }, function()
      local err = test_helper.expect_error(function()
        error({
          code = 501, 
          message = "Not implemented"
        })
      end)
      
      -- If the error is a table, it will be preserved
      if type(err.message) == "table" then
        expect(err.message.code).to.equal(501)
        expect(err.message.message).to.equal("Not implemented")
      end
    end)
  end)
end)

print("\nEnhanced error testing example complete!")
print("This example shows various ways to test error conditions using the expect_error flag and test_helper module.")
print("\nRun this example with:")
print("lua test.lua examples/enhanced_error_testing_example.lua")