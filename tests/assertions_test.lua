-- Tests for the enhanced assertions in lust-next
package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

describe("Enhanced Assertions", function()
  -- Table assertions
  describe("Table Assertions", function()
    it("checks if a table contains a specific key", function()
      local t = {a = 1, b = 2, c = 3}
      
      expect(t).to.contain.key("a")
      expect(t).to.contain.key("b")
      expect(t).to.contain.key("c")
      expect(t).to_not.contain.key("d")
    end)
    
    it("checks if a table contains all specified keys", function()
      local t = {a = 1, b = 2, c = 3, d = 4}
      
      expect(t).to.contain.keys({"a", "b"})
      expect(t).to.contain.keys({"a", "b", "c"})
      expect(t).to_not.contain.keys({"x", "y"})
    end)
    
    it("checks if a table contains a specific value", function()
      local t = {1, 2, 3, x = "test"}
      
      expect(t).to.contain.value(1)
      expect(t).to.contain.value(2)
      expect(t).to.contain.value("test")
      expect(t).to_not.contain.value("missing")
    end)
    
    it("checks if a table contains all specified values", function()
      local t = {1, 2, 3, 4, x = "test", y = "example"}
      
      expect(t).to.contain.values({1, 2})
      expect(t).to.contain.values({"test", "example"})
      expect(t).to_not.contain.values({"missing"})
    end)
    
    it("checks if a table is a subset of another table", function()
      local subset = {a = 1, b = 2}
      local superset = {a = 1, b = 2, c = 3, d = 4}
      
      expect(subset).to.contain.subset(superset)
      expect({a = 1}).to.contain.subset(superset)
      expect(superset).to_not.contain.subset({x = 10})
    end)
    
    it("checks if a table contains exactly the specified keys", function()
      local t = {a = 1, b = 2, c = 3}
      
      expect(t).to.contain.exactly({"a", "b", "c"})
      expect(t).to_not.contain.exactly({"a", "b"})
      expect(t).to_not.contain.exactly({"a", "b", "c", "d"})
    end)
  end)
  
  -- String assertions
  describe("String Assertions", function()
    it("checks if a string starts with a prefix", function()
      expect("hello world").to.start_with("hello")
      expect("testing").to.start_with("test")
      expect("hello").to_not.start_with("world")
    end)
    
    it("checks if a string ends with a suffix", function()
      expect("hello world").to.end_with("world")
      expect("testing").to.end_with("ing")
      expect("hello").to_not.end_with("test")
    end)
  end)
  
  -- Type assertions
  describe("Type Assertions", function()
    it("checks if a value is callable", function()
      local function fn() end
      local callable_table = setmetatable({}, {__call = function() end})
      
      expect(fn).to.be_type("callable")
      expect(callable_table).to.be_type("callable")
      expect({}).to_not.be_type("callable")
    end)
    
    it("checks if a value is comparable", function()
      expect(1).to.be_type("comparable")
      expect("a").to.be_type("comparable")
      -- Functions are not comparable with < operator
      expect(function() end).to_not.be_type("comparable")
    end)
    
    it("checks if a value is iterable", function()
      expect({}).to.be_type("iterable")
      expect({1, 2, 3}).to.be_type("iterable")
      expect(1).to_not.be_type("iterable")
      expect("string").to_not.be_type("iterable") -- In Lua, strings are not directly iterable
    end)
  end)
  
  -- Numeric assertions
  describe("Numeric Assertions", function()
    it("checks if a number is greater than another", function()
      expect(5).to.be_greater_than(3)
      expect(10).to.be_greater_than(0)
      expect(5).to_not.be_greater_than(5)
      expect(5).to_not.be_greater_than(10)
    end)
    
    it("checks if a number is less than another", function()
      expect(3).to.be_less_than(5)
      expect(0).to.be_less_than(1)
      expect(5).to_not.be_less_than(5)
      expect(10).to_not.be_less_than(5)
    end)
    
    it("checks if a number is between a range", function()
      expect(5).to.be_between(1, 10)
      expect(5).to.be_between(5, 10)
      expect(5).to.be_between(1, 5)
      expect(5).to_not.be_between(6, 10)
      expect(5).to_not.be_between(1, 4)
    end)
    
    it("checks if a number is approximately equal to another", function()
      expect(0.1 + 0.2).to.be_approximately(0.3, 0.0001)
      expect(5).to.be_approximately(5, 0)
      expect(5.001).to.be_approximately(5, 0.01)
      expect(5.1).to_not.be_approximately(5, 0.01)
    end)
  end)
  
  -- Error assertions
  describe("Error Assertions", function()
    it("checks if a function throws an error", function()
      local function throws_error() error("test error") end
      local function no_error() return true end
      
      expect(throws_error).to.throw.error()
      expect(no_error).to_not.throw.error()
    end)
    
    it("checks if a function throws an error matching a pattern", function()
      local function throws_specific_error() error("test error pattern") end
      
      expect(throws_specific_error).to.throw.error_matching("test error")
      expect(throws_specific_error).to.throw.error_matching("pattern")
      expect(throws_specific_error).to_not.throw.error_matching("different")
    end)
    
    it("checks if a function throws an error of a specific type", function()
      local function throws_string_error() error("string error") end
      local function throws_table_error() error({message = "table error"}) end
      
      expect(throws_string_error).to.throw.error_type("string")
      expect(throws_table_error).to.throw.error_type("table")
    end)
  end)
end)