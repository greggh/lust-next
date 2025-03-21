-- Test file for quality level 1
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
describe("Sample Test Suite", function()
  it("should perform basic assertion", function()
    expect(true).to.be.truthy()
    expect(1 + 1).to.equal(2)
  end)
end)

return true
