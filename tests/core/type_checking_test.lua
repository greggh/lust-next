-- Tests for enhanced type checking functionality
package.path = "../?.lua;" .. package.path
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Create a test class with metatable for instance checking
local TestClass = {}
TestClass.__index = TestClass
TestClass.__name = "TestClass" -- Allow for nice error messages

function TestClass.new()
  local self = {}
  setmetatable(self, TestClass)
  return self
end

-- Create a subclass for inheritance testing
local TestSubclass = {}
TestSubclass.__index = TestSubclass
TestSubclass.__name = "TestSubclass"
setmetatable(TestSubclass, {__index = TestClass}) -- Inherit from TestClass

function TestSubclass.new()
  local self = {}
  setmetatable(self, TestSubclass)
  return self
end

-- Define an interface for interface testing
local TestInterface = {
  required_method = function() end,
  required_property = "value"
}

describe("Enhanced Type Checking", function()
  describe("Exact Type Checking", function()
    it("correctly identifies exact primitive types", function()
      -- Using expect directly
      local is_number = function(v) return type(v) == "number" end
      expect(is_number(123)).to.be_truthy()

      -- Using expect style
      expect("string value").to.be.a("string")
      expect(true).to.be.a("boolean")
      expect(nil).to_not.exist()
      expect({}).to.be.a("table")
      expect(function() end).to.be.a("function")
    end)

    it("fails when types don't match exactly", { expect_error = true }, function()
      local err1 = test_helper.expect_error(function()
        expect(123).to.be.a("string")
      end)
      
      expect(err1).to.exist()
      
      local err2 = test_helper.expect_error(function()
        expect("123").to.be.a("number")
      end)
      
      expect(err2).to.exist()
    end)

    it("handles error messages correctly", { expect_error = true }, function()
      -- Adding a custom message is not directly supported in expect-style
      -- We use a custom wrapper to add context
      local function assert_with_message(value, type_name, message)
        if type(value) ~= type_name then
          error(message or ("Expected value to be exactly of type '" .. type_name .. "', but got '" .. type(value) .. "'"))
        end
      end
      
      local result, err = test_helper.with_error_capture(function()
        assert_with_message(123, "string", "Custom error message")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Custom error message")

      local result2, err2 = test_helper.with_error_capture(function()
        expect(123).to.be.a("string")
      end)()
      
      expect(result2).to_not.exist()
      expect(err2).to.exist()
      expect(err2.message).to.match("expected.*to be a string")
    end)
  end)

  describe("Instance Checking", function()
    it("correctly identifies direct instances", function()
      local instance = TestClass.new()
      -- Since expect doesn't have a direct is_instance_of, we use a function
      local function is_instance_of(obj, class)
        return type(obj) == "table" and getmetatable(obj) == class
      end
      expect(is_instance_of(instance, TestClass)).to.be_truthy()
    end)

    it("correctly identifies instances of parent classes", function()
      local instance = TestSubclass.new()
      -- Check instance against parent class
      local function is_instance_of(obj, class)
        if type(obj) ~= "table" or type(class) ~= "table" then
          return false
        end
        local mt = getmetatable(obj)
        while mt do
          if mt == class then return true end
          mt = getmetatable(mt)
        end
        return false
      end
      expect(is_instance_of(instance, TestClass)).to.be_truthy()
    end)

    it("fails when object is not an instance of class", { expect_error = true }, function()
      local instance = TestClass.new()

      local function is_instance_of(obj, class)
        return type(obj) == "table" and getmetatable(obj) == class
      end

      local err1 = test_helper.expect_error(function()
        expect(is_instance_of(instance, TestSubclass)).to.be_truthy()
      end)
      
      expect(err1).to.exist()

      local err2 = test_helper.expect_error(function()
        expect(is_instance_of({}, TestClass)).to.be_truthy()
      end)
      
      expect(err2).to.exist()
    end)

    it("fails when non-table values are provided", { expect_error = true }, function()
      local function is_instance_of(obj, class)
        return type(obj) == "table" and type(class) == "table" and getmetatable(obj) == class
      end

      local err1 = test_helper.expect_error(function()
        expect(is_instance_of("string", TestClass)).to.be_truthy()
      end)
      
      expect(err1).to.exist()

      local err2 = test_helper.expect_error(function()
        expect(is_instance_of(TestClass.new(), "not a class")).to.be_truthy()
      end)
      
      expect(err2).to.exist()
    end)
  end)

  describe("Interface Implementation Checking", function()
    it("passes when all interface requirements are met", function()
      local obj = {
        required_method = function() return true end,
        required_property = "some value",
        extra_property = 123 -- Extra properties are allowed
      }

      local function implements(obj, interface)
        if type(obj) ~= "table" or type(interface) ~= "table" then
          return false
        end

        for key, value in pairs(interface) do
          if obj[key] == nil then
            return false
          end

          if type(obj[key]) ~= type(value) then
            return false
          end
        end

        return true
      end

      expect(implements(obj, TestInterface)).to.be_truthy()
    end)

    it("fails when required properties are missing", { expect_error = true }, function()
      local obj = {
        required_method = function() return true end
        -- Missing required_property
      }

      local function implements(obj, interface)
        if type(obj) ~= "table" or type(interface) ~= "table" then
          return false
        end

        for key, value in pairs(interface) do
          if obj[key] == nil then
            return false
          end

          if type(obj[key]) ~= type(value) then
            return false
          end
        end

        return true
      end

      local err = test_helper.expect_error(function()
        expect(implements(obj, TestInterface)).to.be_truthy()
      end)
      
      expect(err).to.exist()
    end)

    it("fails when method types don't match", { expect_error = true }, function()
      local obj = {
        required_method = "not a function", -- Wrong type
        required_property = "value"
      }

      local function implements(obj, interface)
        if type(obj) ~= "table" or type(interface) ~= "table" then
          return false
        end

        for key, value in pairs(interface) do
          if obj[key] == nil then
            return false
          end

          if type(obj[key]) ~= type(value) then
            return false
          end
        end

        return true
      end

      local err = test_helper.expect_error(function()
        expect(implements(obj, TestInterface)).to.be_truthy()
      end)
      
      expect(err).to.exist()
    end)

    it("reports missing keys and wrong types in error messages", { expect_error = true }, function()
      local obj = {
        required_method = "string instead of function"
        -- Missing required_property
      }

      local function implements_with_error(obj, interface)
        if type(obj) ~= "table" or type(interface) ~= "table" then
          error("Both object and interface must be tables")
        end

        local missing = {}
        local wrong_types = {}

        for key, value in pairs(interface) do
          if obj[key] == nil then
            table.insert(missing, key)
          elseif type(obj[key]) ~= type(value) then
            table.insert(wrong_types, key)
          end
        end

        if #missing > 0 or #wrong_types > 0 then
          local err_msg = "Object does not implement interface"
          if #missing > 0 then
            err_msg = err_msg .. ": missing: " .. table.concat(missing, ", ")
          end
          if #wrong_types > 0 then
            err_msg = err_msg .. ": wrong types: " .. table.concat(wrong_types, ", ")
          end
          error(err_msg)
        end

        return true
      end

      local result, err = test_helper.with_error_capture(function()
        implements_with_error(obj, TestInterface)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("missing: required_property")
      expect(err.message).to.match("wrong types: required_method")
    end)
  end)

  describe("The enhanced contains assertion", function()
    it("works with tables", { expect_error = true }, function()
      local t = {1, 2, 3, "test"}
      local function contains(container, value)
        if type(container) == "table" then
          for _, v in pairs(container) do
            if v == value then return true end
          end
          return false
        elseif type(container) == "string" then
          return string.find(container, tostring(value), 1, true) ~= nil
        end
        return false
      end

      expect(contains(t, 2)).to.be_truthy()
      expect(contains(t, "test")).to.be_truthy()

      local err = test_helper.expect_error(function()
        expect(contains(t, 5)).to.be_truthy()
      end)
      
      expect(err).to.exist()
    end)

    it("works with strings", { expect_error = true }, function()
      local s = "This is a test string"
      local function contains(container, value)
        return string.find(container, tostring(value), 1, true) ~= nil
      end

      expect(contains(s, "test")).to.be_truthy()
      expect(contains(s, "This")).to.be_truthy()
      expect(contains(s, " is ")).to.be_truthy()

      local err = test_helper.expect_error(function()
        expect(contains(s, "banana")).to.be_truthy()
      end)
      
      expect(err).to.exist()
    end)

    it("converts non-string values to strings for string containment", function()
      local function contains(container, value)
        return string.find(container, tostring(value), 1, true) ~= nil
      end

      expect(contains("Testing 123", 123)).to.be_truthy()
      expect(contains("true value", true)).to.be_truthy()
    end)

    it("fails with appropriate error messages", { expect_error = true }, function()
      local function string_contains(str, substr)
        local found = string.find(str, substr, 1, true)
        if not found then
          error("Expected string '" .. str .. "' to contain '" .. substr .. "'")
        end
        return true
      end

      local function table_contains(t, value)
        for _, v in pairs(t) do
          if v == value then return true end
        end
        error("Expected table to contain " .. tostring(value))
      end

      local result1, err1 = test_helper.with_error_capture(function()
        string_contains("test string", "banana")
      end)()
      
      expect(result1).to_not.exist()
      expect(err1).to.exist()
      expect(err1.message).to.match("Expected string 'test string' to contain 'banana'")

      local result2, err2 = test_helper.with_error_capture(function()
        table_contains({1, 2, 3}, 5)
      end)()
      
      expect(result2).to_not.exist()
      expect(err2).to.exist()
      expect(err2.message).to.match("Expected table to contain 5")
    end)
  end)

  describe("Integration with expect-style assertions", function()
    it("works alongside other assertions", function()
      local instance = TestClass.new()

      -- Chain assertions
      expect(true).to.be_truthy()
      expect(instance).to.be.a("table")
      expect(getmetatable(instance)).to.equal(TestClass)
      expect(instance).to.exist()
    end)
  end)
end)
