--[[
  execution_vs_coverage_verification.lua
  
  A simple script to verify the execution vs. coverage distinction
  and generate an HTML report showing all four possible states:
  
  1. Non-executable lines (comments, blank lines)
  2. Uncovered lines (executable but never executed)
  3. Executed-not-covered lines (executed but not validated by tests)
  4. Covered lines (executed and validated by tests)
]]

-- Import required modules
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")
local reporting = require("lib.reporting")

-- Path for this file itself to track
local current_file = debug.getinfo(1, "S").source:sub(2)
local report_dir = "examples/reports/coverage-reports"
local report_path = fs.join_paths(report_dir, "execution_vs_coverage_verification.html")

-- Create a test function with different branches to demonstrate coverage
local function test_calculation(a, b, operation)
  local result
  
  -- This block will be covered (executed and validated)
  if not a or not b then
    return nil, "Missing operands"
  end
  
  -- This block will be covered (executed and validated)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Operands must be numbers"
  end
  
  -- This block will be executed but not covered (executed but not validated)
  if operation == "add" then
    result = a + b
  -- This block will be covered (executed and validated)
  elseif operation == "subtract" then
    result = a - b
  -- This block will never be executed
  elseif operation == "multiply" then
    result = a * b
  -- This block will never be executed  
  elseif operation == "divide" then
    if b == 0 then
      return nil, "Division by zero"
    end
    result = a / b
  -- This block will be executed but not covered
  else
    return nil, "Unsupported operation"
  end
  
  return result
end

-- Start coverage tracking
print("Starting coverage tracking...")
coverage.start({
  include_patterns = {current_file},
  track_blocks = true,
  verbose = true,
  debug = true
})

-- Explicitly track this file
coverage.track_file(current_file)

-- Run a series of tests to exercise different code paths
describe("Calculation Tests", function()
  it("should handle nil values correctly", function()
    local result, err = test_calculation(nil, 5, "add")
    expect(result).to_not.exist()
    expect(err).to.equal("Missing operands")
    
    -- Mark lines as covered (validated by assertions)
    coverage.mark_line_covered(current_file, 30)
    coverage.mark_line_covered(current_file, 31)
  end)
  
  it("should validate input types", function()
    local result, err = test_calculation("string", 5, "add")
    expect(result).to_not.exist()
    expect(err).to.equal("Operands must be numbers")
    
    -- Mark lines as covered (validated by assertions)
    coverage.mark_line_covered(current_file, 35)
    coverage.mark_line_covered(current_file, 36)
  end)
  
  it("should perform addition without validating the result", function()
    -- This will execute the add branch but NOT validate it
    local result = test_calculation(5, 3, "add")
    
    -- No assertions here to demonstrate execution without coverage
    -- Lines 40-41 will be marked as executed but not covered
    -- because we don't call mark_line_covered() here
  end)
  
  it("should validate subtraction results", function()
    local result = test_calculation(10, 4, "subtract")
    expect(result).to.equal(6)
    
    -- Mark lines as covered (validated by assertions)
    coverage.mark_line_covered(current_file, 43)
    coverage.mark_line_covered(current_file, 44)
  end)
  
  it("should handle unsupported operations without validation", function()
    local result, err = test_calculation(5, 3, "unknown")
    
    -- No assertions here to demonstrate execution without coverage
    -- Line 56 will be marked as executed but not covered
    -- because we don't call mark_line_covered() here
  end)
  
  -- The multiply and divide paths (lines 46-53) are never executed,
  -- demonstrating uncovered lines
end)

-- Stop coverage tracking
coverage.stop()

-- Generate a report that should clearly show all four states
print("\nGenerating HTML coverage report...")
local report_data = coverage.get_report_data()

-- Make sure the report directory exists
fs.ensure_directory_exists(report_dir)

-- Format the coverage data as HTML
local html_report = reporting.format_coverage(report_data, "html")

-- Save the HTML report to a file
fs.write_file(report_path, html_report)

-- Print coverage summary
print("\nCoverage Summary:")
print("  Total files: " .. report_data.summary.total_files)
print("  Covered files: " .. report_data.summary.covered_files)
print("  Total lines: " .. report_data.summary.total_lines)
print("  Covered lines: " .. report_data.summary.covered_lines)
print("  Executed lines: " .. report_data.summary.executed_lines)
print("  Line coverage percent: " .. report_data.summary.line_coverage_percent .. "%")
print("  Execution coverage percent: " .. report_data.summary.execution_coverage_percent .. "%")

-- Print the location of the HTML report
print("\nHTML coverage report generated at:")
print(report_path)
print("Open this file in a web browser to see the four coverage states:")
print("1. Non-executable lines (comments, blank lines)")
print("2. Uncovered lines (executable but never executed)")
print("3. Executed-not-covered lines (executed but not validated)")
print("4. Covered lines (executed and validated)")