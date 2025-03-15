-- Report validation example
--
-- This example demonstrates the report validation capabilities of lust-next.
-- It shows how to validate coverage data, formatted outputs, and perform
-- comprehensive validation with anomaly detection.

-- Load required modules
local lust = require("lust-next")
local coverage = require("lib.coverage")
local reporting = require("lib.reporting")
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")

-- Enable error handling
error_handler.configure({
  verbose = true,
  trace_errors = true,
  log_all_errors = true
})

-- Create a simple test suite for demonstration
local describe, it = lust.describe, lust.it

describe("Report Validation Example", function()
  -- Create a simple test to generate coverage data
  it("should generate valid coverage data", function()
    local x = 10
    local y = 5
    
    -- This line will be executed
    local sum = x + y
    assert(sum == 15, "Addition failed")
    
    -- This branch will be taken
    if sum > 10 then
      assert(true, "Sum is greater than 10")
    else
      -- This branch will not be taken
      assert(false, "Sum should be greater than 10")
    end
  end)
end)

-- Initialize coverage with basic configuration
coverage.init({
  enabled = true,
  discover_uncovered = true
})

-- Start coverage tracking
coverage.start()

-- Run the tests (this will generate coverage data)
lust.reset() -- Reset any previous tests
-- In lust-next, tests are automatically collected but we need to call reset
-- to make sure they're properly initialized
-- The actual test execution happens when the test definitions are loaded

-- Stop coverage tracking to process the data
coverage.stop()

-- Get the coverage report data
print("Generating coverage report data...")
local coverage_data = coverage.get_report_data()

-- Ensure we have valid data
if not coverage_data then
  print("Error: No coverage data available")
  return
end

-- Print summary info
print(string.format("Coverage data contains %d files", coverage_data.summary.total_files))
print(string.format("Total lines: %d, Covered lines: %d, Coverage: %.1f%%", 
  coverage_data.summary.total_lines or 0,
  coverage_data.summary.covered_lines or 0,
  coverage_data.summary.line_coverage_percent or 0
))

-- Example 1: Basic Data Validation
print("\n--- Example 1: Basic Data Validation ---")

local is_valid, issues = reporting.validate_coverage_data(coverage_data)

if is_valid then
  print("Coverage data validation: PASSED")
else
  print("Coverage data validation: FAILED")
  print("Issues found: " .. #issues)
  for i, issue in ipairs(issues) do
    print(string.format("  Issue %d: %s (%s)", i, issue.message, issue.category))
  end
end

-- Example 2: Format Validation
print("\n--- Example 2: Format Validation ---")

-- Format coverage data in multiple formats
local formats = {"html", "json", "lcov", "cobertura"}
local formatted_outputs = {}

for _, format in ipairs(formats) do
  -- Format the report
  print(string.format("Formatting coverage report as %s...", format))
  local formatted = reporting.format_coverage(coverage_data, format)
  
  -- Store formatted content
  local content
  if type(formatted) == "table" and formatted.output then
    content = formatted.output
  else
    content = formatted
  end
  formatted_outputs[format] = content
  
  -- Validate the format
  local format_valid, format_err = reporting.validate_report_format(content, format)
  
  if format_valid then
    print(string.format("  %s format validation: PASSED", format))
  else
    print(string.format("  %s format validation: FAILED - %s", format, format_err or "unknown error"))
  end
end

-- Example 3: Comprehensive Validation
print("\n--- Example 3: Comprehensive Validation ---")

-- Get HTML format for validation
local html_output = formatted_outputs["html"]

-- Perform comprehensive validation
local result = reporting.validate_report(coverage_data, html_output, "html")

-- Print validation results
if result.validation.is_valid then
  print("Data validation: PASSED")
else
  print("Data validation: FAILED")
  print("Issues found: " .. #result.validation.issues)
end

if result.format_validation.is_valid then
  print("Format validation: PASSED")
else
  print("Format validation: FAILED")
  print("Issues found: " .. #result.format_validation.issues)
end

-- Check for outliers and anomalies
if #result.statistics.outliers > 0 then
  print("\nStatistical outliers detected:")
  for i, outlier in ipairs(result.statistics.outliers) do
    print(string.format("  %d: %s (Coverage: %.1f%%, Z-score: %.2f)", 
      i, outlier.file, outlier.coverage, outlier.z_score))
  end
end

if #result.statistics.anomalies > 0 then
  print("\nAnomalies detected:")
  for i, anomaly in ipairs(result.statistics.anomalies) do
    print(string.format("  %d: %s - %s", i, anomaly.file, anomaly.reason))
  end
end

-- Print cross-check results
print(string.format("\nCross-check with static analysis: %d files checked", 
  result.cross_check.files_checked))

if result.cross_check.discrepancies and next(result.cross_check.discrepancies) then
  print("Discrepancies found in static analysis:")
  for file, issues in pairs(result.cross_check.discrepancies) do
    print(string.format("  File: %s - %d issues", file, #issues))
  end
end

-- Example 4: Creating an Invalid Report for Testing
print("\n--- Example 4: Creating and Validating an Invalid Report ---")

-- Create a copy of the coverage data with intentional issues
local invalid_data = {
  summary = {},  -- Empty summary (missing required fields)
  files = coverage_data.files  -- Keep the original files data
}

-- Validate the invalid data
local invalid_valid, invalid_issues = reporting.validate_coverage_data(invalid_data)

if invalid_valid then
  print("Invalid data validation: Unexpectedly PASSED")
else
  print("Invalid data validation: FAILED (expected)")
  print("Issues found: " .. #invalid_issues)
  for i, issue in ipairs(invalid_issues) do
    print(string.format("  Issue %d: %s (%s)", i, issue.message, issue.category))
  end
end

-- Example 5: Saving Reports with Validation
print("\n--- Example 5: Saving Reports with Validation ---")

-- Create directory for reports if it doesn't exist
local reports_dir = "./examples/reports/validation"
fs.ensure_directory_exists(reports_dir)

-- Save with validation (default behavior)
local ok, err = reporting.save_coverage_report(
  reports_dir .. "/coverage-validation-default.html", 
  coverage_data, 
  "html"
)

if ok then
  print("Saved report with default validation: SUCCESS")
else
  print("Saved report with default validation: FAILED - " .. tostring(err))
end

-- Save with strict validation (will reject invalid data)
local ok, err = reporting.save_coverage_report(
  reports_dir .. "/coverage-validation-strict.html", 
  invalid_data,  -- Using our invalid data
  "html", 
  {strict_validation = true}
)

if ok then
  print("Saved report with strict validation: SUCCESS (unexpected)")
else
  print("Saved report with strict validation: FAILED (expected) - " .. tostring(err))
end

-- Save with validation disabled
local ok, err = reporting.save_coverage_report(
  reports_dir .. "/coverage-validation-disabled.html", 
  invalid_data,  -- Using our invalid data 
  "html", 
  {validate = false}
)

if ok then
  print("Saved report with validation disabled: SUCCESS")
else
  print("Saved report with validation disabled: FAILED - " .. tostring(err))
end

print("\nReport Validation Example Complete")