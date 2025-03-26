#!/usr/bin/env lua
-- Ultra-simplified coverage report generation script

-- Mock coverage data for calculator.lua
local mock_data = {
  summary = {
    total_files = 1,
    covered_files = 1,
    file_coverage_percent = 100,
    total_lines = 27,
    executable_lines = 10,
    covered_lines = 8,
    line_coverage_percent = 80,
    total_functions = 4,
    covered_functions = 4,
    function_coverage_percent = 100
  },
  files = {
    ["./lib/samples/calculator.lua"] = {
      file_path = "./lib/samples/calculator.lua",
      total_lines = 27,
      executable_lines = 10,
      covered_lines = 8,
      executed_lines = 10,
      line_coverage_percent = 80,
      total_functions = 4,
      executed_functions = 4,
      function_coverage_percent = 100,
      lines = {}
    }
  }
}

-- Create lines for the calculator module
local calculator_lines = mock_data.files["./lib/samples/calculator.lua"].lines

-- Add line data
local content = {
  [1] = "-- Simple Calculator Module",
  [2] = "-- Used for testing coverage functionality",
  [3] = "",
  [4] = "local calculator = {}",
  [5] = "",
  [6] = "function calculator.add(a, b)",
  [7] = "    local result = a + b",
  [8] = "    return result",
  [9] = "end",
  [10] = "",
  [11] = "function calculator.subtract(a, b)",
  [12] = "    local result = a - b",
  [13] = "    return result",
  [14] = "end",
  [15] = "",
  [16] = "function calculator.multiply(a, b)",
  [17] = "    local result = a * b",
  [18] = "    return result",
  [19] = "end",
  [20] = "",
  [21] = "function calculator.divide(a, b)",
  [22] = "    if b == 0 then",
  [23] = "        error(\"Division by zero\")",
  [24] = "    end",
  [25] = "    local result = a / b",
  [26] = "    return result",
  [27] = "end",
  [28] = "",
  [29] = "return calculator"
}

-- Define executable lines
local executable_lines = {6, 7, 8, 11, 12, 13, 16, 17, 18, 21, 22, 23, 25, 26}

-- Define covered lines (executed + verified by assertions)
local covered_lines = {7, 8, 12, 13, 17, 18, 25, 26}

-- Define executed but not covered lines
local executed_lines = {6, 11, 16, 21, 22}

-- Define not covered lines
local not_covered_lines = {23}

-- Define comments and blank lines
local comments_and_blanks = {1, 2, 3, 5, 10, 15, 20, 28, 29}

-- Populate the lines
for i = 1, 29 do
  local is_executable = false
  local is_covered = false
  local execution_count = 0
  local line_type = "code"
  
  -- Determine line type
  for _, line in ipairs(comments_and_blanks) do
    if i == line then
      line_type = i == 3 or i == 5 or i == 10 or i == 15 or i == 20 or i == 28 or i == 29 
        and "blank" or "comment"
      break
    end
  end
  
  -- Determine if executable
  for _, line in ipairs(executable_lines) do
    if i == line then
      is_executable = true
      break
    end
  end
  
  -- Determine if covered
  for _, line in ipairs(covered_lines) do
    if i == line then
      is_covered = true
      execution_count = 5  -- Executed multiple times
      break
    end
  end
  
  -- Determine if executed but not covered
  if not is_covered then
    for _, line in ipairs(executed_lines) do
      if i == line then
        execution_count = 3  -- Executed multiple times
        break
      end
    end
  end
  
  calculator_lines[i] = {
    content = content[i] or "",
    executable = is_executable,
    covered = is_covered,
    execution_count = execution_count,
    line_type = line_type
  }
end

-- Create output directory
local fs = require("lib.tools.filesystem")
local output_dir = "./coverage-reports"
fs.ensure_directory_exists(output_dir)

-- Generate the report
local html_simple_formatter = require("lib.reporting.formatters.html_simple")
local output_path = fs.join_paths(output_dir, "coverage-report-simple.html")

print("Generating simplified HTML report...")
local success, err = html_simple_formatter.generate(mock_data, output_path)

if not success then
  print("ERROR: Failed to generate HTML report: " .. tostring(err))
  os.exit(1)
end

print("Report successfully generated at: " .. output_path)