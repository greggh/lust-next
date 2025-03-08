#!/usr/bin/env lua
-- Example demonstrating the report path configuration features in lust-next
-- This example shows how to organize a CI/CD-friendly report directory structure

-- Set up package path so we can run this from the examples directory
package.path = "../?.lua;" .. package.path

-- Load lust-next and required modules
local lust = require("lust-next")
local reporting = require("src.reporting")

-- Define a version for report naming
local VERSION = "1.0.0"
local TIMESTAMP = os.date("%Y%m%d")

-- Get today's date for report directory naming
local TODAY = os.date("%Y-%m-%d")

-- Define a test structure
lust.describe("Report Path Configuration Test", function()
  lust.it("generates multiple reports in organized structure", function()
    lust.expect(1 + 1).to.equal(2)
    lust.expect("test").to.be.a("string")  -- Using the proper type checker
    lust.expect({1, 2, 3}).to.contain(2)
  end)
  
  lust.it("generates data for report analysis", function()
    lust.expect(5 * 5).to.equal(25)
    lust.expect(true).to.be_truthy()
  end)
end)

-- Run the tests to produce actual test results
-- Normally this happens automatically, but for this example we need to run them explicitly
lust.reset() -- Make sure we start fresh

-- End with a simple summary
print("\n============================================")
print("Report Path Configuration Example")
print("============================================")
print("Reports will be generated in ./reports-example directory")
print("Version for reports:", VERSION)
print("Timestamp:", TIMESTAMP)
print("\nReport paths:")

-- Create a report configuration
local config = {
  report_dir = "./reports-example", -- Base directory
  report_suffix = "-" .. VERSION .. "-" .. TIMESTAMP, -- Version and timestamp suffix
  coverage_path_template = "coverage/{date}/{format}/coverage{suffix}", -- Organized by date and format
  quality_path_template = "quality/{date}/{format}/quality{suffix}", -- Similar structure for quality
  results_path_template = "tests/{date}/{format}/results{suffix}", -- Similar structure for test results
  timestamp_format = "%Y-%m-%d",
  verbose = true -- Enable verbose output to see paths
}

-- Get test results data from lust
local results_data = {
  name = "Report Path Example",
  timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
  tests = 2,
  failures = 0,
  errors = 0, 
  skipped = 0,
  time = 0.001,
  test_cases = {
    {
      name = "generates multiple reports in organized structure",
      classname = "Report Path Configuration Test",
      time = 0.001,
      status = "pass"
    },
    {
      name = "generates data for report analysis",
      classname = "Report Path Configuration Test",
      time = 0.001,
      status = "pass"
    }
  }
}

-- Save reports using the configured paths
local results = reporting.auto_save_reports(nil, nil, results_data, config)

-- Show the paths that were generated
print("\nGenerated reports:")
for format, result in pairs(results) do
  if result.success then
    print(format .. ": " .. result.path)
  else
    print(format .. ": ERROR - " .. (result.error or "Unknown error"))
  end
end

print("\nTo view the reports, navigate to the reports-example directory")
print("You can achieve the same results with command-line arguments:")
print('lua run_tests.lua --output-dir ./reports-example \\')
print('                  --report-suffix "-' .. VERSION .. '-' .. TIMESTAMP .. '" \\')
print('                  --coverage-path "coverage/{date}/{format}/coverage{suffix}" \\')
print('                  --quality-path "quality/{date}/{format}/quality{suffix}" \\')
print('                  --results-path "tests/{date}/{format}/results{suffix}" \\')
print('                  --timestamp-format "%Y-%m-%d" \\')
print('                  --verbose-reports')