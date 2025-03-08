-- Basic test for lust-next
package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

describe("lust-next", function()
  it("has required functions", function()
    expect(lust_next.describe).to.be.a("function")
    expect(lust_next.it).to.be.a("function")
    expect(lust_next.expect).to.be.a("function")
    expect(lust_next.spy).to_not.be(nil)
  end)
  
  it("passes simple tests", function()
    expect(1).to.be(1)
    expect("hello").to.equal("hello")
    expect({1, 2}).to.equal({1, 2})
  end)
  
  it("has spy functionality", function()
    -- Test the spy functionality which is now implemented
    expect(lust_next.spy).to_not.be(nil)
    -- The spy is a module with new and on functions
    expect(lust_next.spy.new).to.be.a("function")
    expect(lust_next.spy.on).to.be.a("function")
    
    -- Test basic spy functionality
    local test_fn = function(a, b) return a + b end
    local spied = lust_next.spy.new(test_fn)
    
    -- Spy should work like the original function
    expect(spied(2, 3)).to.be(5)
    
    -- Spy should track calls
    expect(spied.calls).to.be.a("table")
    expect(#spied.calls).to.be(1)
    expect(spied.calls[1][1]).to.be(2)
    expect(spied.calls[1][2]).to.be(3)
    expect(spied.call_count).to.be(1)
  end)
end)