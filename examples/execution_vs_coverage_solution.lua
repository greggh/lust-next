--[[
  execution_vs_coverage_solution.lua
  
  This is a clean, simple demonstration of the execution vs. coverage distinction.
  It shows:
  
  1. Lines that are both executed and validated by tests (covered)
  2. Lines that are executed but not validated by tests (executed-not-covered)
  3. Lines that are never executed (uncovered)
  4. Non-executable lines (comments, blank lines, etc.)
]]

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import required modules
local coverage = require("lib.coverage")
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")

-- Simple calculator functions for testing execution vs. coverage
local Calculator = {}

-- This function will be covered (executed and validated)
function Calculator.add(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a + b
end

-- This function will be executed but NOT covered (executed without validation)
function Calculator.subtract(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a - b
end

-- This function will NOT be executed at all (uncovered)
function Calculator.multiply(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a * b
end

-- Initialize coverage tracking
coverage.init({
  use_static_analysis = true,
  pre_analyze_files = true,
})

-- Start tracking coverage for this file
coverage.start({
  include_patterns = {".*"}
})

local this_file = debug.getinfo(1, "S").source:sub(2)
coverage.track_file(this_file)

-- Run test suite 
describe("Calculator", function()
  describe("add function", function()
    it("correctly adds two numbers", function()
      -- This test EXECUTES AND VALIDATES the add function
      local result = Calculator.add(5, 3)
      expect(result).to.equal(8)  -- This validation marks the code as covered
    end)
    
    it("returns error for non-number arguments", function()
      -- This test EXECUTES AND VALIDATES the error handling in add
      local result, err = Calculator.add("5", 3)
      expect(result).to_not.exist()
      expect(err).to.equal("Both arguments must be numbers")
    end)
  end)
  
  describe("subtract function", function()
    it("executes subtraction without validating the result", function()
      -- This test EXECUTES the subtract function but doesn't VALIDATE the result
      -- The subtract function will be marked as executed but NOT covered
      local result = Calculator.subtract(10, 4)
      -- Intentionally no assertions/validations here
    end)
  end)
  
  -- No tests for multiply function
  -- The multiply function will not be executed at all
end)

-- Stop coverage tracking
coverage.stop()

-- Generate coverage report
local report_data = coverage.get_report_data()

-- Print coverage summary
print("\nCoverage Summary:")
print("  Total files: " .. report_data.summary.total_files)
print("  Total lines: " .. report_data.summary.total_lines)
print("  Covered lines: " .. report_data.summary.covered_lines)
print("  Executed lines: " .. report_data.summary.executed_lines)
print("  Coverage percentage: " .. string.format("%.1f%%", report_data.summary.line_coverage_percent))
print("  Execution percentage: " .. string.format("%.1f%%", report_data.summary.execution_coverage_percent))

-- Generate HTML report
local html_report = reporting.format_coverage(report_data, "html")

-- Save the HTML report
local report_dir = "examples/reports/coverage-reports"
fs.ensure_directory_exists(report_dir)
local report_path = fs.join_paths(report_dir, "execution_vs_coverage_solution.html")
fs.write_file(report_path, html_report)

print("\nHTML coverage report saved to: " .. report_path)
print("Open this file in your web browser to see the enhanced visualization\n")

print("This report demonstrates the four possible line states:")
print("1. ✅ Covered (green): Lines that were executed AND validated by test assertions")
print("2. ⚠️ Executed-not-covered (yellow): Lines that executed but weren't validated by assertions")
print("3. ❌ Uncovered (red): Lines that never executed during tests")
print("4. Non-executable (gray): Comments, blank lines, and other non-code lines")
