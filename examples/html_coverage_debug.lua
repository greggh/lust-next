--[[
  html_coverage_debug.lua
  
  Debugging version of the HTML coverage report to diagnose issues with 
  source code display in the HTML formatter.
]]

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("Debug")
local error_handler = require("lib.tools.error_handler")

-- Enable debug logging
logging.configure_from_config("Debug")

-- Sample Calculator implementation to test
local Calculator = {}

-- This function will be covered (executed and validated)
function Calculator.add(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a + b
end

-- This function will be executed but not validated
function Calculator.subtract(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a - b
end

-- This function will not be executed at all
function Calculator.multiply(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Both arguments must be numbers"
  end
  return a * b
end

-- Initialize coverage
local coverage = require("lib.coverage")
coverage.init({
  use_static_analysis = true,
  pre_analyze_files = true,
})

-- Start coverage explicitly
local current_file = debug.getinfo(1, "S").source:sub(2)
print("Current file:", current_file)

coverage.start()
coverage.track_file(current_file)

-- Run tests
describe("HTML Coverage Debug", function()
  describe("add function", function()
    it("correctly adds two numbers", function()
      local result = Calculator.add(5, 3)
      expect(result).to.equal(8)
    end)
    
    it("returns error for non-numbers", function()
      local result, err = Calculator.add("5", 3)
      expect(result).to_not.exist()
      expect(err).to.equal("Both arguments must be numbers")
    end)
  end)
  
  describe("subtract function", function()
    it("executes subtraction without validation", function()
      local result = Calculator.subtract(10, 4)
      -- No assertion to validate the result
    end)
  end)
  
  -- No tests for multiply, so it won't be executed at all
end)

-- Stop coverage
coverage.stop()

-- Get coverage data
local report_data = coverage.get_report_data()

-- Print detailed report data for debugging
print("Report Data Summary:")
print("  Total files:", report_data.summary.total_files)
print("  Covered files:", report_data.summary.covered_files)
print("  Total lines:", report_data.summary.total_lines)
print("  Covered lines:", report_data.summary.covered_lines)
print("  Executed lines:", report_data.summary.executed_lines)
print("  Coverage %:", report_data.summary.line_coverage_percent)

print("\nFiles in coverage data:")
for file_path, file_data in pairs(report_data.files) do
  print("  File:", file_path)
  print("    Lines:", file_data.total_lines or 0, 
               "Covered:", file_data.covered_lines or 0,
               "Executed:", file_data.executed_lines_count or 0)
               
  -- Check if source code is present
  print("    Source code available:", file_data.source ~= nil and #file_data.source > 0)
  
  -- Count the execution & coverage data
  local line_count = 0
  if file_data.lines then
    for line_num, _ in pairs(file_data.lines) do
      line_count = line_count + 1
    end
  end
  print("    Line data entries:", line_count)
  
  -- Add original content to file_data
  if not file_data.source or #file_data.source == 0 then
    local file_success, file_content = error_handler.safe_io_operation(
      function() return fs.read_file(file_path) end,
      file_path,
      {operation = "read_file_for_debug"}
    )
    
    if file_success and file_content then
      print("    Reading file content manually")
      file_data.source = file_content
    end
  end
end

-- Generate HTML report
local reporting = require("lib.reporting")
local html_report = reporting.format_coverage(report_data, "html")

-- Create a debug directory to save the HTML file
local debug_dir = "examples/reports/debug"
fs.ensure_directory_exists(debug_dir)

-- Write the report
local html_path = fs.join_paths(debug_dir, "coverage-debug.html")
fs.write_file(html_path, html_report)

-- Also save the raw coverage data for inspection
local json = require("lib.reporting.json")
local json_data = json.encode(report_data)
local json_path = fs.join_paths(debug_dir, "coverage-debug.json")
fs.write_file(json_path, json_data)

print("\nDebug files saved:")
print("  HTML report:", html_path)
print("  Raw JSON data:", json_path)
print("\nPlease check these files to diagnose the source code display issue.")
