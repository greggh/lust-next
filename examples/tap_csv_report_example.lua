--[[
  tap_csv_report_example.lua
  
  Example demonstrating TAP (Test Anything Protocol) and CSV output formats
  in lust-next reporting module. This example shows how to generate test results
  in these formats and save them to files.
]]

package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

-- Run a simple test suite with mixed results
describe("TAP and CSV Output Example", function()
  -- Create a group of passing tests
  describe("Math operations", function()
    it("can add numbers", function()
      expect(1 + 1).to.equal(2)
    end)
    
    it("can subtract numbers", function()
      expect(5 - 3).to.equal(2)
    end)
  end)
  
  -- A group with failing tests
  describe("String operations", function()
    it("can concatenate strings", function()
      expect("hello" .. " world").to.equal("hello world")
    end)
    
    it("fails when comparing case-sensitive strings", function()
      -- This test will deliberately fail
      expect("HELLO").to.equal("hello")
    end)
  end)
  
  -- A group with pending tests
  describe("Advanced features", function()
    it("has a pending test", function()
      return lust_next.pending("Not implemented yet")
    end)
    
    it("causes an error", function()
      -- This will cause an error
      error("This is a simulated error")
    end)
  end)
end)

-- After running the tests, generate the reports
local reporting = require("src.reporting")

-- Create a test results data structure based on test execution
local test_results = {
  name = "TAP and CSV Output Example",
  timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
  tests = 6,
  failures = 1,
  errors = 1,
  skipped = 1,
  time = 0.05, -- Execution time in seconds
  test_cases = {
    {
      name = "can add numbers",
      classname = "Math operations",
      time = 0.001,
      status = "pass"
    },
    {
      name = "can subtract numbers",
      classname = "Math operations",
      time = 0.001,
      status = "pass"
    },
    {
      name = "can concatenate strings",
      classname = "String operations",
      time = 0.001,
      status = "pass"
    },
    {
      name = "fails when comparing case-sensitive strings",
      classname = "String operations",
      time = 0.002,
      status = "fail",
      failure = {
        message = "Values are not equal",
        type = "AssertionError",
        details = "Expected: 'hello'\nReceived: 'HELLO'"
      }
    },
    {
      name = "has a pending test",
      classname = "Advanced features",
      time = 0.000,
      status = "pending",
      skip_message = "Not implemented yet"
    },
    {
      name = "causes an error",
      classname = "Advanced features",
      time = 0.001,
      status = "error",
      error = {
        message = "Runtime error in test",
        type = "Error",
        details = "This is a simulated error\nstack traceback:\n\t[C]: in function 'error'\n\texamples/tap_csv_report_example.lua:47: in function <examples/tap_csv_report_example.lua:46>"
      }
    }
  }
}

-- Generate and display TAP output
print("\n=== TAP Output ===\n")
local tap_output = reporting.format_results(test_results, "tap")
print(tap_output)

-- Generate and display CSV output 
print("\n=== CSV Output ===\n")
local csv_output = reporting.format_results(test_results, "csv")
print(csv_output)

-- Save reports to files
print("\n=== Saving Reports ===\n")

-- Save TAP report
local tap_file = "output-example.tap"
local tap_ok, tap_err = reporting.save_results_report(tap_file, test_results, "tap")
if tap_ok then
  print("TAP report saved to: " .. tap_file)
else
  print("Failed to save TAP report: " .. tostring(tap_err))
end

-- Save CSV report
local csv_file = "output-example.csv"
local csv_ok, csv_err = reporting.save_results_report(csv_file, test_results, "csv")
if csv_ok then
  print("CSV report saved to: " .. csv_file)
else
  print("Failed to save CSV report: " .. tostring(csv_err))
end

-- Generate multiple reports using auto_save feature
print("\n=== Auto-Saving Multiple Formats ===\n")
local results = reporting.auto_save_reports(nil, nil, test_results, "output-reports")
print("Reports saved to directory: output-reports")
print("Formats generated: TAP, CSV, JUnit XML")