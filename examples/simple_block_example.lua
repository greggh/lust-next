-- Simple example of block coverage for quick testing
local firmo = require("firmo")
local coverage = require("lib.coverage")
local expect = firmo.expect

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
firmo.describe("Simple Block Example", function()
  firmo.it("should handle large value", function()
    expect(check_value(15)).to.equal("large")
  end)
  
  firmo.it("should handle small value", function()
    expect(check_value(5)).to.equal("small")
  end)
end)

-- Stop tracking and generate report
coverage.stop()
local html_path = "./coverage-reports/simple-block-example.html"
-- Use the reporting module instead of coverage.save_report
local report_data = coverage.get_report_data()
local reporting = require("lib.reporting")
reporting.save_coverage_report(html_path, report_data, "html")
print("Report saved to: " .. html_path)
