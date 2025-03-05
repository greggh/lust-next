-- Basic test for lust-next
package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

describe("lust-next", function()
  it("has required functions", function()
    expect(lust_next.describe).to.be.a("function")
    expect(lust_next.it).to.be.a("function")
    expect(lust_next.expect).to.be.a("function")
    expect(lust_next.spy).to.be.a("function")
  end)
  
  it("passes simple tests", function()
    expect(1).to.be(1)
    expect("hello").to.equal("hello")
    expect({1, 2}).to.equal({1, 2})
  end)
  
  it("has spy functionality", function()
    local function add(a, b) return a + b end
    local spy = lust_next.spy(add)
    spy(1, 2)
    expect(#spy).to.equal(1)
    expect(spy[1][1]).to.equal(1)
    expect(spy[1][2]).to.equal(2)
  end)
end)