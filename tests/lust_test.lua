-- Basic test for lust
local lust = require("../lust")
local describe, it, expect = lust.describe, lust.it, lust.expect

describe("lust", function()
  it("has required functions", function()
    expect(lust.describe).to.be.a("function")
    expect(lust.it).to.be.a("function")
    expect(lust.expect).to.be.a("function")
    expect(lust.spy).to.be.a("function")
  end)
  
  it("passes simple tests", function()
    expect(1).to.be(1)
    expect("hello").to.equal("hello")
    expect({1, 2}).to.equal({1, 2})
  end)
  
  it("has spy functionality", function()
    local function add(a, b) return a + b end
    local spy = lust.spy(add)
    spy(1, 2)
    expect(#spy).to.equal(1)
    expect(spy[1][1]).to.equal(1)
    expect(spy[1][2]).to.equal(2)
  end)
end)