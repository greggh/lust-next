--[[
  html_coverage_example.lua
  
  Example demonstrating HTML output format for both coverage and quality reporting
  in lust-next, with syntax highlighting and detailed statistics.
]]

package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect
local reporting = require("src.reporting")

-- We'll create a simple mock of the coverage data structure
-- This simulates what would be collected during a real test run
local mock_coverage_data = {
  files = {},
  summary = {
    total_files = 2,
    covered_files = 2,
    total_lines = 40,
    covered_lines = 35,
    line_coverage_percent = 87.5,
    functions = {
      total = 8, 
      covered = 6,
      percent = 75.0
    },
    overall_percent = 81.3
  }
}

-- Add mock file coverage data
local calculatorCode = [[
-- Calculator module for basic arithmetic operations
local Calculator = {}

-- Add two numbers
function Calculator.add(a, b)
  return a + b
end

-- Subtract b from a
function Calculator.subtract(a, b)
  return a - b
end

-- Multiply two numbers
function Calculator.multiply(a, b)
  return a * b
end

-- Divide a by b
function Calculator.divide(a, b)
  if b == 0 then
    error("Division by zero is not allowed")
  end
  return a / b
end

-- Calculate power: a^b
function Calculator.power(a, b)
  return a ^ b
end

return Calculator
]]

local utilsCode = [[
-- Utility functions for number formatting
local Utils = {}

-- Format a number with specified decimals
function Utils.formatNumber(num, decimals)
  decimals = decimals or 2
  local fmt = string.format("%%.%df", decimals)
  return string.format(fmt, num)
end

-- Check if a number is an integer
function Utils.isInteger(num)
  return type(num) == "number" and math.floor(num) == num
end

-- Check if a number is positive
function Utils.isPositive(num)
  return type(num) == "number" and num > 0
end

return Utils
]]

-- Helper to add lines to the mock coverage data
local function addFileCoverage(filePath, code, uncoveredLines)
  uncoveredLines = uncoveredLines or {}
  local uncoveredSet = {}
  for _, line in ipairs(uncoveredLines) do
    uncoveredSet[line] = true
  end
  
  local lines = {}
  local lineNum = 1
  for line in code:gmatch("[^\r\n]+") do
    lines[lineNum] = {
      hits = uncoveredSet[lineNum] and 0 or 1,
      line = line
    }
    lineNum = lineNum + 1
  end
  
  -- Add function data too
  local functions = {}
  local pattern = "function%s+([%w_%.]+)%s*%("
  local lineNum = 1
  for line in code:gmatch("[^\r\n]+") do
    local funcName = line:match(pattern)
    if funcName then
      local isUncovered = false
      for _, l in ipairs(uncoveredLines) do
        if l == lineNum then
          isUncovered = true
          break
        end
      end
      
      functions[funcName] = {
        calls = isUncovered and 0 or math.random(1, 5),
        name = funcName,
        line = lineNum
      }
    end
    lineNum = lineNum + 1
  end
  
  mock_coverage_data.files[filePath] = {
    lines = lines,
    functions = functions
  }
end

-- Add mock file data
addFileCoverage("/path/to/calculator.lua", calculatorCode, {20, 24})
addFileCoverage("/path/to/utils.lua", utilsCode, {15})

-- Create mock quality data
local mock_quality_data = {
  level = 3,
  level_name = "Comprehensive",
  tests = {
    ["CalculatorTests"] = {
      quality_level = 3,
      quality_level_name = "Comprehensive",
      assertion_count = 12,
      assertion_types = {
        ["equal"] = 5,
        ["fail"] = 2,
        ["match"] = 1,
        ["type"] = 2,
        ["truthy"] = 2
      }
    },
    ["UtilsTests"] = {
      quality_level = 2,
      quality_level_name = "Standard",
      assertion_count = 6,
      assertion_types = {
        ["equal"] = 3,
        ["type"] = 1,
        ["truthy"] = 2
      }
    }
  },
  summary = {
    tests_analyzed = 2,
    tests_passing_quality = 2,
    quality_percent = 100.0,
    assertions_total = 18,
    assertions_per_test_avg = 9.0,
    issues = {}
  }
}

-- Run a simple test to demonstrate HTML report generation
describe("HTML Reporting", function()
  it("generates HTML code coverage report", function()
    -- Generate HTML coverage report
    local html_report = reporting.format_coverage(mock_coverage_data, "html")
    
    -- Save the report to a file
    local report_file = "coverage-report.html"
    local success, err = reporting.write_file(report_file, html_report)
    
    -- Verify report generation was successful
    expect(success).to.be.truthy()
    expect(html_report).to.match("<html")
    expect(html_report).to.match("<title>Code Coverage Report</title>")
    
    print("\n=== HTML Coverage Report Generated ===")
    print("Report saved to: " .. report_file)
    print("Coverage statistics:")
    print("  Total files: " .. mock_coverage_data.summary.total_files)
    print("  Total lines: " .. mock_coverage_data.summary.total_lines)
    print("  Covered lines: " .. mock_coverage_data.summary.covered_lines)
    print("  Line coverage: " .. mock_coverage_data.summary.line_coverage_percent .. "%")
    print("  Function coverage: " .. mock_coverage_data.summary.functions.percent .. "%")
    print("  Overall coverage: " .. mock_coverage_data.summary.overall_percent .. "%")
  end)
  
  it("generates HTML quality report", function()
    -- Generate HTML quality report
    local html_report = reporting.format_quality(mock_quality_data, "html")
    
    -- Save the report to a file
    local report_file = "quality-report.html"
    local success, err = reporting.write_file(report_file, html_report)
    
    -- Verify report generation was successful
    expect(success).to.be.truthy()
    expect(html_report).to.match("<html")
    expect(html_report).to.match("<title>Test Quality Report</title>")
    
    print("\n=== HTML Quality Report Generated ===")
    print("Report saved to: " .. report_file)
    print("Quality statistics:")
    print("  Quality level: " .. mock_quality_data.level .. " (" .. mock_quality_data.level_name .. ")")
    print("  Tests analyzed: " .. mock_quality_data.summary.tests_analyzed)
    print("  Tests passing quality: " .. mock_quality_data.summary.tests_passing_quality)
    print("  Total assertions: " .. mock_quality_data.summary.assertions_total)
    print("  Assertions per test: " .. mock_quality_data.summary.assertions_per_test_avg)
  end)
  
  it("generates all report formats with auto_save", function()
    -- Save all report formats with a single call
    local reports_dir = "html-reports"
    local results = reporting.auto_save_reports(mock_coverage_data, mock_quality_data, nil, reports_dir)
    
    -- Verify HTML reports were created successfully
    expect(results.html.success).to.be.truthy()
    expect(results.quality_html.success).to.be.truthy()
    
    print("\n=== All Reports Generated ===")
    print("Reports saved to directory: " .. reports_dir)
    print("Report formats generated:")
    print("  - HTML coverage report: " .. reports_dir .. "/coverage-report.html")
    print("  - HTML quality report: " .. reports_dir .. "/quality-report.html")
    print("  - JSON coverage report: " .. reports_dir .. "/coverage-report.json")
    print("  - JSON quality report: " .. reports_dir .. "/quality-report.json")
    print("  - LCOV coverage report: " .. reports_dir .. "/coverage-report.lcov")
    
    print("\nOpen these HTML files in a browser to view the formatted reports")
  end)
end)