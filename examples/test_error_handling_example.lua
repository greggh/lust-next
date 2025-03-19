-- Test Error Handling Example
--
-- This example demonstrates how to properly test error conditions
-- using the expect_error flag and the test_helper module.

-- Load firmo
package.path = "../?.lua;../lib/?.lua;../lib/?/init.lua;" .. package.path
local firmo = require("firmo")

-- Import test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import test helper
local test_helper = require("lib.tools.test_helper")

-- Import error handler
local error_handler = require("lib.tools.error_handler")

-- Example function that returns nil + error message string
local function validate_age(age)
  if type(age) ~= "number" then
    return nil, "Age must be a number"
  end
  
  if age < 0 then
    return nil, "Age cannot be negative"
  end
  
  if age > 150 then
    return nil, "Age is unrealistically high"
  end
  
  return age
end

-- Example function that throws errors
local function parse_config(config_string)
  if type(config_string) ~= "string" then
    error("Config must be a string")
  end
  
  if config_string:match("^%s*$") then
    error("Config cannot be empty")
  end
  
  -- In a real scenario, this would parse the config
  return { parsed = true }
end

-- Example function that returns structured errors
local function process_user_data(user)
  if not user then
    return nil, error_handler.validation_error(
      "User cannot be nil",
      { parameter = "user", operation = "process_user_data" }
    )
  end
  
  if not user.name then
    return nil, error_handler.validation_error(
      "User name is required",
      { parameter = "user.name", operation = "process_user_data" }
    )
  end
  
  if not user.age or type(user.age) ~= "number" then
    return nil, error_handler.validation_error(
      "User age must be a number",
      { parameter = "user.age", operation = "process_user_data" }
    )
  end
  
  return user
end

-- Test suite
describe("Test Error Handling Example", function()
  -- First, let's see tests without the expect_error flag
  -- These will generate test failures for the error cases
  describe("Without expect_error flag (will show failures)", function()
    it("should validate valid age", function()
      local result, err = validate_age(30)
      expect(result).to.equal(30)
      expect(err).to_not.exist()
    end)
    
    it("should reject non-number age", function()
      local result, err = validate_age("30")
      expect(result).to_not.exist()
      expect(err).to.equal("Age must be a number")
    end)
    
    it("should reject negative age", function()
      local result, err = validate_age(-5)
      expect(result).to_not.exist()
      expect(err).to.equal("Age cannot be negative")
    end)
  end)
  
  -- Now, let's see tests with the expect_error flag
  -- These will properly handle the expected errors without test failures
  describe("With expect_error flag (proper handling)", function()
    it("should validate valid age", function()
      local result, err = validate_age(30)
      expect(result).to.equal(30)
      expect(err).to_not.exist()
    end)
    
    it("should reject non-number age", { expect_error = true }, function()
      local result, err = validate_age("30")
      expect(result).to_not.exist()
      expect(err).to.equal("Age must be a number")
    end)
    
    it("should reject negative age", { expect_error = true }, function()
      local result, err = validate_age(-5)
      expect(result).to_not.exist()
      expect(err).to.equal("Age cannot be negative")
    end)
  end)
  
  -- Tests for functions that throw errors
  -- These tests MUST use expect_error and test_helper
  describe("Testing functions that throw errors", function()
    it("should parse valid config", function()
      local result = parse_config("key=value")
      expect(result).to.exist()
      expect(result.parsed).to.equal(true)
    end)
    
    it("should throw on non-string config", { expect_error = true }, function()
      -- Using test_helper.expect_error to verify the error message
      local err = test_helper.expect_error(function()
        parse_config(nil)
      end, "Config must be a string")
      
      expect(err).to.exist()
    end)
    
    it("should throw on empty config", { expect_error = true }, function()
      -- Using test_helper.with_error_capture for more detailed inspection
      local result, err = test_helper.with_error_capture(function()
        parse_config("   ")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Config cannot be empty")
    end)
  end)
  
  -- Tests for functions that return structured error objects
  describe("Testing structured errors", function()
    it("should process valid user data", function()
      local user = { name = "John", age = 30 }
      local result, err = process_user_data(user)
      
      expect(result).to.exist()
      expect(result.name).to.equal("John")
      expect(err).to_not.exist()
    end)
    
    it("should reject nil user", { expect_error = true }, function()
      local result, err = process_user_data(nil)
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.equal("User cannot be nil")
      expect(err.context.parameter).to.equal("user")
    end)
    
    it("should reject user without name", { expect_error = true }, function()
      local result, err = process_user_data({ age = 30 })
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.equal("User name is required")
      expect(err.context.parameter).to.equal("user.name")
    end)
    
    it("should reject user with non-number age", { expect_error = true }, function()
      local result, err = process_user_data({ name = "John", age = "30" })
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.equal("User age must be a number")
      expect(err.context.parameter).to.equal("user.age")
    end)
  end)
end)

-- Run the test suite
firmo.run()

print("\nExample complete!")
print("NOTE: The first section intentionally shows test failures to demonstrate the problem.")
print("The second section with the expect_error flag shows the proper way to handle expected errors.")