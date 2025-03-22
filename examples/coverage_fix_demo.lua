--[[
  coverage_fix_demo.lua
  
  A demonstration of fixes to the coverage module
]]

package.path = package.path .. ";./?.lua"
local coverage = require("lib.coverage")

print("Starting coverage fix demonstration...")

-- Create a simple test module with various code structures
local TestModule = {}

-- Define a function we'll execute - should be properly covered
function TestModule.add(a, b)
  return a + b
end

-- Define a function with conditionals - only one branch will be covered
function TestModule.check_value(value)
  if value > 10 then
    return "greater than 10"
  else
    return "10 or less"
  end
end

--[[ 
  This is a multiline comment containing code that should NOT be counted
  function this_is_in_comment(a, b) 
    return a * b
  end
]]

-- Start coverage tracking
print("\nInitializing coverage...")
coverage.init({
  enabled = true,
  debug = true,
  use_static_analysis = true,
  track_blocks = true,
  include = {"examples/coverage_fix_demo.lua"},
  exclude = {},
  source_dirs = {"."}
})

-- Start coverage
print("Starting coverage tracking...")
coverage.start()

-- Execute some code - this should be marked as covered
print("\nExecuting code with coverage active:")
print("TestModule.add(5, 3) =", TestModule.add(5, 3))
print("TestModule.check_value(15) =", TestModule.check_value(15))

-- Stop coverage
print("\nStopping coverage tracking...")
coverage.stop()

-- Generate HTML report
local html_path = "/tmp/coverage-fix-demo.html"
-- Use the reporting module instead of coverage.save_report
local report_data = coverage.get_report_data()
local reporting = require("lib.reporting")
reporting.save_coverage_report(html_path, report_data, "html")
print("\nHTML report saved to:", html_path)

-- Print out coverage statistics
local report_data = coverage.get_report_data()
print("\nCoverage statistics:")

for file_path, file_data in pairs(report_data.files) do
  if file_path:match("coverage_fix_demo.lua") then
    print("  File:", file_path)
    print("  Line coverage:", file_data.covered_lines, "/", file_data.total_lines,
          string.format("(%.1f%%)", file_data.line_coverage_percent))
    print("  Function coverage:", file_data.covered_functions, "/", file_data.total_functions,
          string.format("(%.1f%%)", file_data.function_coverage_percent))
          
    -- Print line-by-line coverage details
    local origin = report_data.original_files[file_path] or {}
    print("\n  Line coverage details:")
    
    for i = 1, 40 do  -- Just check the first 40 lines
      local line_text = origin.source and origin.source[i] or ""
      if #line_text == 0 then break end
      
      if #line_text > 40 then 
        line_text = line_text:sub(1, 37) .. "..." 
      end
      
      local is_executable = file_data.executable_lines and file_data.executable_lines[i]
      local is_covered = file_data.lines and file_data.lines[i]
      
      -- Print if this is a multiline comment line
      local comment_info = ""
      if line_text:match("^%s*%-%-%[%[") then
        comment_info = " (multiline comment start)"
      elseif line_text:match("%]%]") then
        comment_info = " (multiline comment end)"
      elseif i > 1 and line_text:match("function this_is_in_comment") then
        comment_info = " (inside multiline comment)"
      end
      
      print(string.format("    Line %2d: %-40s | executable=%s, covered=%s%s",
        i, line_text, tostring(is_executable), tostring(is_covered), comment_info))
    end
  end
end

print("\nCoverage fix demonstration completed.")