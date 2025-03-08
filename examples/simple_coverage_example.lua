--[[
  simple_coverage_example.lua
  
  A simpler example for generating HTML coverage reports.
]]

package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local reporting = require("src.reporting")

-- Create a simplified coverage data structure
local coverage_data = {
  files = {
    ["/path/to/module.lua"] = {
      lines = {
        [1] = { hits = 1, line = "-- Test module" },
        [2] = { hits = 1, line = "local Module = {}" },
        [3] = { hits = 1, line = "" },
        [4] = { hits = 1, line = "function Module.func1()" },
        [5] = { hits = 1, line = "  return true" },
        [6] = { hits = 1, line = "end" },
        [7] = { hits = 1, line = "" },
        [8] = { hits = 1, line = "function Module.func2()" },
        [9] = { hits = 0, line = "  return false -- uncovered" },
        [10] = { hits = 0, line = "end" }
      }
    }
  },
  summary = {
    total_files = 1,
    covered_files = 1,
    total_lines = 10,
    covered_lines = 8,
    line_coverage_percent = 80.0,
    functions = {
      total = 2,
      covered = 1,
      percent = 50.0
    },
    overall_percent = 65.0
  }
}

-- Generate coverage report in HTML format 
print("Generating HTML coverage report...")
local html = reporting.format_coverage(coverage_data, "html")

-- Save the report to a file
local file_path = "simple-coverage.html"
local success, err = reporting.write_file(file_path, html)

if success then
  print("HTML coverage report saved to: " .. file_path)
  print("Coverage statistics:")
  print("  Files: " .. coverage_data.summary.covered_files .. "/" .. coverage_data.summary.total_files)
  print("  Lines: " .. coverage_data.summary.covered_lines .. "/" .. coverage_data.summary.total_lines)
  print("  Functions: " .. coverage_data.summary.functions.covered .. "/" .. coverage_data.summary.functions.total)
  print("  Line coverage: " .. coverage_data.summary.line_coverage_percent .. "%")
  print("  Function coverage: " .. coverage_data.summary.functions.percent .. "%")
  print("  Overall coverage: " .. coverage_data.summary.overall_percent .. "%")
else
  print("Failed to save report: " .. tostring(err))
end