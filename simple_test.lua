-- Simple test to verify firmo functionality
local firmo = require("firmo")

-- Define a simple test
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Math operations", function()
  it("should add numbers correctly", function()
    expect(1 + 1).to.equal(2)
  end)
  
  it("should multiply numbers correctly", function()
    expect(2 * 3).to.equal(6)
  end)
end)