-- Minimal example to test multiline comment coverage detection
local coverage = require("lib.coverage")
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")

-- Start coverage tracking
coverage.start()

-- Define a function with multiline comments
local function test_comments()
  -- Single line comment above code
  print("Line after single-line comment")

  --[[ This is a multiline comment
  spanning across multiple
  lines ]]

  print("Line after multiline comment")

  local x = 5 --[[ Inline multiline comment ]]
  local y = 10

  return x + y -- Inline comment
end

-- Execute the function to produce coverage data
print("\nRunning test_comments() function:")
local result = test_comments()
print("Function returned:", result)

-- Stop coverage tracking
coverage.stop()

-- Create output directory for report
local report_dir = "./test-reports-tmp"
fs.ensure_directory_exists(report_dir)
local html_path = fs.join_paths(report_dir, "multiline-minimal.html")

-- Get file path of this script
local file_path = debug.getinfo(1, "S").source:sub(2) -- Remove '@' prefix

-- Generate HTML report
---@diagnostic disable-next-line: redundant-parameter
local report_data = coverage.get_report_data({
  include = { file_path },
})

local success, err =
  reporting.save_coverage_report(html_path, report_data, "html", { theme = "dark", show_line_numbers = true })

if success then
  print("\nCoverage report generated at:", html_path)
  print("\nCheck if:")
  print("1. Multiline comments are marked as non-executable")
  print("2. Print statements are marked as executed")
else
  print("\nFailed to generate report:", err)
end
