-- Test for the new tagging and filtering functionality
package.path = "../?.lua;" .. package.path
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Tagging and Filtering", function()
  it("basic test with no tags", function()
    expect(true).to.be.truthy()
  end)

  firmo.tags("unit")
  it("test with unit tag", function()
    expect(1 + 1).to.equal(2)
  end)

  firmo.tags("integration", "slow")
  it("test with integration and slow tags", function()
    expect("integration").to.be.a("string")
  end)

  firmo.tags("unit", "fast")
  it("test with unit and fast tags", function()
    expect({}).to.be.a("table")
  end)

  -- Testing filter pattern matching
  it("test with numeric value 12345", function()
    expect(12345).to.be.a("number")
  end)

  it("test with different numeric value 67890", function()
    expect(67890).to.be.a("number")
  end)
end)

-- These tests demonstrate how to use the tagging functionality
-- Run with different filters to see how it works:
--
-- Run only unit tests:
--   lua firmo.lua --tags unit tests/tagging_test.lua
--
-- Run only integration tests:
--   lua firmo.lua --tags integration tests/tagging_test.lua
--
-- Run tests with numeric pattern in the name:
--   lua firmo.lua --filter "numeric" tests/tagging_test.lua
--
-- Run tests with specific number pattern:
--   lua firmo.lua --filter "12345" tests/tagging_test.lu
