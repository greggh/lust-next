--[[
  multiline_detection_report.lua
  
  This example demonstrates the improved multiline comment detection in coverage reports.
  It contains various comment types including:
  
  1. Standard single-line comments
  2. Multiline comments spanning multiple lines
  3. Inline multiline comments
  
  Running this file directly will test if all print statements are correctly marked as
  executed and all comments are properly identified as non-executable.
]]

-- Create temporary directory for report
---@type FilesystemModule
local fs = require("lib.tools.filesystem")
---@type TempFileModule
local temp_file = require("lib.tools.temp_file")
---@type string|nil report_dir Path to the temporary directory or nil if creation failed
---@type table|nil err Error object if directory creation failed
local report_dir, err = temp_file.create_temp_directory()
if not report_dir then
  print("Failed to create temp directory:", err)
  os.exit(1)
end

-- Start coverage tracking
---@type CoverageModule
local coverage = require("lib.coverage")
coverage.start()

-- Explicitly track this file
local current_file = debug.getinfo(1, "S").source:sub(2)  -- Remove '@' prefix
coverage.track_file(current_file)

-- A function with various comment types and print statements
---@return number sum The sum of x and y
local function test_comments()
  -- Single line comment
  print("Executing line after single-line comment") -- End-of-line comment
  
  --[[ This is a multiline comment
  spanning across multiple
  lines that should be detected
  as non-executable ]]
  
  print("Executing line after multiline comment")
  
  ---@type number x First number to add
  local x = 5 --[[ Inline multiline comment ]] 
  ---@type number y Second number to add
  local y = 10
  
  --[[ Another multiline
  comment block ]]
  
  print("Final executable line")
  
  return x + y
end

-- Run the test function
print("\n== Running test_comments() function ==")
local result = test_comments()
print("Function returned:", result)
print("== Function execution complete ==\n")

-- Stop coverage tracking
coverage.stop()

-- Get coverage data
---@type table report_data Coverage data for generating reports
local report_data = coverage.get_report_data()

-- Print coverage data for debugging
print("Coverage data summary:", report_data.summary.total_lines, "lines,", 
      report_data.summary.covered_lines, "covered,", 
      report_data.summary.files and #report_data.files, "files")

-- Use the reporting module to generate an HTML report
---@type ReportingModule
local reporting = require("lib.reporting")
---@type string html_path Path to the HTML report file
local html_path = fs.join_paths(report_dir, "multiline-comment-test.html")

-- Generate HTML report
---@type boolean success Whether the report was successfully generated
---@type table|nil err Error object if report generation failed
local success, err = reporting.save_coverage_report(
  html_path,
  report_data,
  "html",
  {
    theme = "dark",
    show_line_numbers = true,
    highlight_syntax = true
  }
)

if success then
  print("\nReport successfully generated!")
  print("HTML report saved to:", html_path)
  print("\nCheck this report to verify that:")
  print("1. All print statements are correctly marked as executed")
  print("2. All comment lines (both single-line and multiline) are marked as non-executable")
  print("3. No incorrectly marked lines where print statements were executed but shown as not executed")
else
  print("\nFailed to generate report:", err)
end