-- Tests for enhanced type checking functionality

local lust = require("../lust-next")
lust.expose_globals()

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
  describe("Exact Type Checking (is_exact_type)", function()
    it("correctly identifies exact primitive types", function()
      -- Using assert.satisfies directly
      assert.satisfies(123, function(v) return type(v) == "number" end)
      
      -- Using assert syntax
      assert.is_exact_type("string value", "string")
      assert.is_exact_type(true, "boolean")
      assert.is_exact_type(nil, "nil")
      assert.is_exact_type({}, "table")
      assert.is_exact_type(function() end, "function")
    end)
    
    it("fails when types don't match exactly", function()
      assert.has_error(function()
        assert.is_exact_type(123, "string")
      end)
      
      assert.has_error(function()
        assert.is_exact_type("123", "number")
      end)
    end)
    
    it("handles error messages correctly", function()
      local ok, err = pcall(function()
        assert.is_exact_type(123, "string", "Custom error message")
      end)
      
      assert.is_false(ok)
      assert.contains(err, "Custom error message")
      
      ok, err = pcall(function()
        assert.is_exact_type(123, "string")
      end)
      
      assert.is_false(ok)
      assert.contains(err, "Expected value to be exactly of type 'string', but got 'number'")
    end)
  end)
  
  describe("Instance Checking (is_instance_of)", function()
    it("correctly identifies direct instances", function()
      local instance = TestClass.new()
      assert.is_instance_of(instance, TestClass)
    end)
    
    it("correctly identifies instances of parent classes", function()
      local instance = TestSubclass.new()
      assert.is_instance_of(instance, TestClass)
    end)
    
    it("fails when object is not an instance of class", function()
      local instance = TestClass.new()
      
      assert.has_error(function()
        assert.is_instance_of(instance, TestSubclass)
      end)
      
      assert.has_error(function()
        assert.is_instance_of({}, TestClass)
      end)
    end)
    
    it("fails when non-table values are provided", function()
      assert.has_error(function()
        assert.is_instance_of("string", TestClass)
      end)
      
      assert.has_error(function()
        assert.is_instance_of(TestClass.new(), "not a class")
      end)
    end)
  end)
  
  describe("Interface Implementation Checking (implements)", function()
    it("passes when all interface requirements are met", function()
      local obj = {
        required_method = function() return true end,
        required_property = "some value",
        extra_property = 123 -- Extra properties are allowed
      }
      
      assert.implements(obj, TestInterface)
    end)
    
    it("fails when required properties are missing", function()
      local obj = {
        required_method = function() return true end
        -- Missing required_property
      }
      
      assert.has_error(function()
        assert.implements(obj, TestInterface)
      end)
    end)
    
    it("fails when method types don't match", function()
      local obj = {
        required_method = "not a function", -- Wrong type
        required_property = "value"
      }
      
      assert.has_error(function()
        assert.implements(obj, TestInterface)
      end)
    end)
    
    it("reports missing keys and wrong types in error messages", function()
      local obj = {
        required_method = "string instead of function"
        -- Missing required_property
      }
      
      local ok, err = pcall(function()
        assert.implements(obj, TestInterface)
      end)
      
      assert.is_false(ok)
      assert.contains(err, "missing: required_property")
      assert.contains(err, "wrong types: required_method")
    end)
  end)
  
  describe("The enhanced contains assertion", function()
    it("works with tables", function()
      local t = {1, 2, 3, "test"}
      assert.contains(t, 2)
      assert.contains(t, "test")
      
      assert.has_error(function()
        assert.contains(t, 5)
      end)
    end)
    
    it("works with strings", function()
      local s = "This is a test string"
      assert.contains(s, "test")
      assert.contains(s, "This")
      assert.contains(s, " is ")
      
      assert.has_error(function()
        assert.contains(s, "banana")
      end)
    end)
    
    it("converts non-string values to strings for string containment", function()
      assert.contains("Testing 123", 123)
      assert.contains("true value", true)
    end)
    
    it("fails with appropriate error messages", function()
      local ok, err = pcall(function()
        assert.contains("test string", "banana")
      end)
      
      assert.is_false(ok)
      assert.contains(err, "Expected string 'test string' to contain 'banana'")
      
      ok, err = pcall(function()
        assert.contains({1, 2, 3}, 5)
      end)
      
      assert.is_false(ok)
      assert.contains(err, "Expected table to contain 5")
    end)
  end)
  
  describe("Integration with existing assertion system", function()
    it("works alongside other assertions", function()
      local instance = TestClass.new()
      
      -- Chain assertions
      assert.is_true(true)
      assert.is_exact_type(instance, "table")
      assert.is_instance_of(instance, TestClass)
      assert.not_nil(instance)
    end)
  end)
end)