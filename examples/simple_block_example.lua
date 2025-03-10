-- Simple example of block coverage for quick testing
local lust = require("lust-next")
local coverage = require("lib.coverage")
local expect = lust.expect

-- Simple function with conditions
local function check_value(value)
  if value > 10 then
    return "large"
  else
    return "small"
  end
end

-- Initialize coverage
coverage.init({
  enabled = true,
  track_blocks = true,
  debug = false,
  use_static_analysis = true
})

-- Start tracking
coverage.start()

-- Run tests
lust.describe("Simple Block Example", function()
  lust.it("should handle large value", function()
    expect(check_value(15)).to.equal("large")
  end)
  
  lust.it("should handle small value", function()
    expect(check_value(5)).to.equal("small")
  end)
end)

-- Stop tracking and generate report
coverage.stop()
local html_path = "./coverage-reports/simple-block-example.html"
coverage.save_report(html_path, "html")
print("Report saved to: " .. html_path)