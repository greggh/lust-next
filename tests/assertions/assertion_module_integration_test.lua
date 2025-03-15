-- Tests that the standalone assertion module works in exactly the same way as the original firmo expect

local firmo = require("firmo") 3:7:local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Explicitly require the standalone assertion module
local assertion = require("lib.assertion")

describe("Assertion Module Integration", function()
  describe("API Compatibility", function()
    it("should have the same behavior as firmo expect", function()
      -- Set up test values
      local num = 42
      local str = "test"
      local tbl = {1, 2, 3}
      
      -- Test basic assertions with both modules
      -- Equality
      expect(num).to.equal(42)
      assertion.expect(num).to.equal(42)
      
      -- Type assertions
      expect(num).to.be.a("number")
      assertion.expect(num).to.be.a("number")
      
      expect(str).to.be.a("string")
      assertion.expect(str).to.be.a("string")
      
      expect(tbl).to.be.a("table")
      assertion.expect(tbl).to.be.a("table")
      
      -- Truthiness
      expect(num).to.be_truthy()
      assertion.expect(num).to.be_truthy()
      
      expect(false).to_not.be_truthy()
      assertion.expect(false).to_not.be_truthy()
      
      -- Existence
      expect(num).to.exist()
      assertion.expect(num).to.exist()
      
      expect(nil).to_not.exist()
      assertion.expect(nil).to_not.exist()
      
      -- Pattern matching
      expect(str).to.match("te")
      assertion.expect(str).to.match("te")
      
      -- Table containment
      expect(tbl).to.contain(2)
      assertion.expect(tbl).to.contain(2)
      
      -- Numeric comparisons
      expect(num).to.be_greater_than(10)
      assertion.expect(num).to.be_greater_than(10)
      
      expect(num).to.be_less_than(100)
      assertion.expect(num).to.be_less_than(100)
      
      -- If we get here without errors, both implementations behave the same way
      expect(true).to.be_truthy() -- Just to have an explicit assertion
    end)
    
    it("should handle error cases in the same way", function()
      -- Both should generate errors for failing assertions
      local firmo_error
      pcall(function() 
        expect(5).to.equal(6)
      end, function(err) firmo_error = err end)
      
      local assertion_error
      pcall(function() 
        assertion.expect(5).to.equal(6)
      end, function(err) assertion_error = err end)
      
      -- Both errors should indicate the values are not equal
      expect(firmo_error).to_not.be(nil)
      expect(assertion_error).to_not.be(nil)
      
      -- The error messages should indicate the same fundamental issue
      if firmo_error and assertion_error then
        expect(assertion_error:match("not equal")).to_not.be(nil)
      end
    end)
  end)
end)
