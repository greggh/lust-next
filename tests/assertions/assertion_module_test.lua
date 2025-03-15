-- Tests for the dedicated assertion module
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Explicitly require the standalone assertion module
local assertion = require("lib.assertion")

describe("Assertion Module", function()
  describe("Basic functionality", function()
    it("should export an expect function", function()
      expect(assertion.expect).to.be.a("function")
    end)
    
    it("should export utility functions", function()
      expect(assertion.eq).to.be.a("function")
      expect(assertion.isa).to.be.a("function")
    end)
    
    it("should export paths for extension", function()
      expect(assertion.paths).to.be.a("table")
      expect(assertion.paths.to).to.be.a("table")
      expect(assertion.paths.to_not).to.be.a("table")
    end)
  end)
  
  describe("expect() function", function()
    it("should return an assertion object", function()
      local result = assertion.expect(42)
      expect(result).to.be.a("table")
      expect(result.val).to.equal(42)
    end)
    
    it("should support chaining assertions", function()
      local result = assertion.expect(42)
      expect(result.to).to_not.be(nil)
      expect(result.to_not).to_not.be(nil)
    end)
  end)
  
  describe("Basic assertions", function()
    it("should support equality assertions", function()
      -- This assertion should pass
      assertion.expect(42).to.equal(42)
      
      -- This assertion should fail
      local success, err = pcall(function()
        assertion.expect(42).to.equal(43)
      end)
      expect(success).to.be_falsy()
      expect(err).to.match("not equal")
    end)
    
    it("should support type assertions", function()
      -- These assertions should pass
      assertion.expect(42).to.be.a("number")
      assertion.expect("test").to.be.a("string")
      assertion.expect({}).to.be.a("table")
      
      -- This assertion should fail
      local success, err = pcall(function()
        assertion.expect(42).to.be.a("string")
      end)
      expect(success).to.be_falsy()
      expect(err).to.match("expected 42 to be a string")
    end)
    
    it("should support truthiness assertions", function()
      -- These assertions should pass
      assertion.expect(true).to.be_truthy()
      assertion.expect(1).to.be_truthy()
      assertion.expect("test").to.be_truthy()
      
      assertion.expect(false).to_not.be_truthy()
      assertion.expect(nil).to_not.be_truthy()
      
      -- This assertion should fail
      local success, err = pcall(function()
        assertion.expect(false).to.be_truthy()
      end)
      expect(success).to.be_falsy()
      expect(err).to.match("expected false to be truthy")
    end)
    
    it("should support existence assertions", function()
      -- These assertions should pass
      assertion.expect(42).to.exist()
      assertion.expect("").to.exist()
      assertion.expect(false).to.exist()
      
      assertion.expect(nil).to_not.exist()
      
      -- This assertion should fail
      local success, err = pcall(function()
        assertion.expect(nil).to.exist()
      end)
      expect(success).to.be_falsy()
      expect(err).to.match("expected nil to exist")
    end)
  end)
  
  describe("Advanced assertions", function()
    it("should support matching assertions", function()
      -- These assertions should pass
      assertion.expect("hello world").to.match("world")
      assertion.expect("12345").to.match("%d+")
      
      -- This assertion should fail
      local success, err = pcall(function()
        assertion.expect("hello").to.match("world")
      end)
      expect(success).to.be_falsy()
      expect(err).to.match('expected "hello" to match pattern "world"')
    end)
    
    it("should support table containment assertions", function()
      -- These assertions should pass
      assertion.expect({1, 2, 3}).to.contain(2)
      assertion.expect({a = 1, b = 2}).to.have.key("a")
      
      -- This assertion should fail
      local success, err = pcall(function()
        assertion.expect({1, 2, 3}).to.contain(4)
      end)
      expect(success).to.be_falsy()
      expect(err).to.match("expected table to contain")
    end)
    
    it("should support numeric comparison assertions", function()
      -- These assertions should pass
      assertion.expect(5).to.be_greater_than(3)
      assertion.expect(3).to.be_less_than(5)
      assertion.expect(5).to.be_between(3, 7)
      
      -- This assertion should fail
      local success, err = pcall(function()
        assertion.expect(3).to.be_greater_than(5)
      end)
      expect(success).to.be_falsy()
      expect(err).to.match("expected 3 to be greater than 5")
    end)
  end)
  
  describe("Error handling", function()
    it("should properly handle errors in test functions", function()
      -- This should be caught and reported properly
      local success, err = pcall(function()
        assertion.expect("not a table").to.have.key("foo")
      end)
      expect(success).to.be_falsy()
      expect(err).to.match("to be a table")
    end)
    
    it("should handle errors in custom predicates", function()
      -- This should be caught and reported properly
      local success, err = pcall(function()
        assertion.expect(5).to.satisfy(function(v)
          error("Intentional error")
        end)
      end)
      expect(success).to.be_falsy()
      expect(err).to.match("predicate function failed")
    end)
  end)
  
  describe("Negation support", function()
    it("should support negated assertions with to_not", function()
      -- These assertions should pass
      assertion.expect(42).to_not.equal(43)
      assertion.expect("test").to_not.be.a("number")
      assertion.expect(false).to_not.be_truthy()
      
      -- This assertion should fail
      local success, err = pcall(function()
        assertion.expect(42).to_not.equal(42)
      end)
      expect(success).to.be_falsy()
      expect(err).to.match("expected .* to not be equal")
    end)
  end)
  
  describe("Table comparisons", function()
    it("should support deep equality assertions", function()
      -- These assertions should pass
      assertion.expect({1, 2, 3}).to.equal({1, 2, 3})
      assertion.expect({a = 1, b = {c = 2}}).to.equal({a = 1, b = {c = 2}})
      
      -- This assertion should fail
      local success, err = pcall(function()
        assertion.expect({1, 2, 3}).to.equal({1, 2, 4})
      end)
      expect(success).to.be_falsy()
      expect(err).to.match("not equal")
    end)
    
    it("should provide detailed diffs for table differences", function()
      -- This should provide a detailed diff
      local success, err = pcall(function()
        assertion.expect({a = 1, b = 2}).to.equal({a = 1, b = 3})
      end)
      expect(success).to.be_falsy()
      expect(err).to.match("Different value for key")
    end)
  end)
end)
