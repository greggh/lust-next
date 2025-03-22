--[[
  A simple file to test multiline comment detection
]]

package.path = package.path .. ";./?.lua"
local coverage = require("lib.coverage")

-- Define a test module for coverage
local TestModule = {}

-- A simple function that will be executed
function TestModule.add(a, b)
  return a + b
end

--[[
function TestModule.inside_comment(a, b)
  -- This is inside a multiline comment and should not count as executable
  if a > b then
    return a
  else
    return b
  end
end
]]

-- Another function that will be executed
function TestModule.subtract(a, b)
  return a - b
end

-- Initialize coverage
coverage.init({
  enabled = true,
  debug = true,
  use_static_analysis = true,
  track_blocks = true,
  include = {"examples/simple_multiline_comment_test.lua"},
  exclude = {},
  source_dirs = {"."}
})

-- Start coverage tracking
coverage.start()

-- Execute code
print("1 + 2 =", TestModule.add(1, 2))
print("5 - 3 =", TestModule.subtract(5, 3))

-- Stop coverage tracking
coverage.stop()

-- Generate report
local html_path = "coverage-reports/simple-multiline-test.html"
-- Use the reporting module instead of coverage.save_report
local report_data = coverage.get_report_data()
local reporting = require("lib.reporting")
reporting.save_coverage_report(html_path, report_data, "html")
print("\nHTML report saved to: " .. html_path)

-- Print statistics
local report_data = coverage.get_report_data()
print("\nCoverage Statistics:")
for file_path, file_data in pairs(report_data.files) do
  if file_path:match("simple_multiline_comment_test.lua") then
    print("  File: " .. file_path)
    print("  Line coverage: " .. file_data.covered_lines .. "/" .. file_data.total_lines .. 
          " (" .. string.format("%.1f%%", file_data.line_coverage_percent) .. ")")
    
    -- Print line-by-line details
    print("\n  Line coverage details:")
    
    local original_file = report_data.original_files[file_path]
    local source_lines = original_file and original_file.source or {}
    
    -- Determine multiline comment state for each line
    local in_comment = false
    local comment_state = {}
    
    for i = 1, #source_lines do
      local line = source_lines[i]
      local starts = line:match("^%s*%-%-%[%[")
      local ends = line:match("%]%]")
      
      if starts and not ends then
        in_comment = true
      elseif ends and in_comment then
        in_comment = false
      end
      
      comment_state[i] = in_comment
    end
    
    -- Print info for each line
    for i = 1, #source_lines do
      local line = source_lines[i]
      if #line > 40 then line = line:sub(1, 37) .. "..." end
      
      local is_executable = file_data.executable_lines and file_data.executable_lines[i]
      local is_covered = file_data.lines and file_data.lines[i]
      
      local comment_info = ""
      if line:match("^%s*%-%-%[%[") then
        comment_info = " (comment start)"
      elseif line:match("%]%]") and comment_state[i-1] then
        comment_info = " (comment end)"
      elseif comment_state[i] then
        comment_info = " (in comment)"
      end
      
      print(string.format("    Line %2d: %-40s | executable=%s, covered=%s%s", 
        i, line, tostring(is_executable), tostring(is_covered), comment_info))
    end
  end
end