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

-- Create output directory
local fs = require("lib.tools.filesystem")
local report_dir = "./test-reports-tmp"
fs.ensure_directory_exists(report_dir)

-- Start coverage tracking
local coverage = require("lib.coverage")
coverage.start()

-- Explicitly track this file
local current_file = debug.getinfo(1, "S").source:sub(2)  -- Remove '@' prefix
coverage.track_file(current_file)

-- A function with various comment types and print statements
local function test_comments()
  -- Single line comment
  print("Executing line after single-line comment") -- End-of-line comment
  
  --[[ This is a multiline comment
  spanning across multiple
  lines that should be detected
  as non-executable ]]
  
  print("Executing line after multiline comment")
  
  local x = 5 --[[ Inline multiline comment ]] local y = 10
  
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
local report_data = coverage.get_report_data()

-- Print coverage data for debugging
print("Coverage data summary:", report_data.summary.total_lines, "lines,", 
      report_data.summary.covered_lines, "covered,", 
      report_data.summary.files and #report_data.files, "files")

-- Use the reporting module to generate an HTML report
local reporting = require("lib.reporting")
local html_path = fs.join_paths(report_dir, "multiline-comment-test.html")

-- Generate HTML report
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