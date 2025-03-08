-- JSON Output Example
-- Shows how lust-next can output test results in JSON format with markers
-- This is used by the parallel execution system to collect results

-- Import the testing framework
local lust = require "../lust-next"

-- Define aliases
local describe, it, expect = lust.describe, lust.it, lust.expect

-- Example test suite
describe("JSON Output Example", function()
  it("should pass this test", function()
    expect(1 + 1).to.equal(2)
  end)
  
  it("should pass this test too", function()
    expect(true).to.be(true)
  end)
  
  it("should skip this test", function()
    lust.pending("Skipping for the example")
  end)
  
  it("should fail this test for demonstration", function()
    expect(1).to.equal(2) -- This will fail
  end)
end)

-- Run the tests
-- To see the JSON output markers, run with:
-- lua examples/json_output_example.lua --results-format json