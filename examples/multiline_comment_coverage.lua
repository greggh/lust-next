--[[
  This is a test file to verify that multiline comments
  are correctly identified and not marked as executable
  in coverage reports.
]]

local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local coverage = require("lib.coverage")

-- Test module with multiline comments
local TestModule = {}

--[[
function this_is_inside_comment(value)
  -- This function should NOT be executed or even considered executable
  -- since it's inside a multiline comment
  if value > 0 then
    return "positive"
  else
    return "negative"
  end
end
]]

-- This is a real function that will be executed
function TestModule.test_function(value)
  if value > 0 then
    return "positive"
  else
    return "non-positive"
  end
end

-- This tests a different style of multiline comment
--[[
This is another style of multiline comment
where there's no indentation at the beginning
]]--

-- Run tests
describe("Multiline Comment Coverage Test", function()
  -- Initialize coverage tracking
  coverage.init({
    enabled = true,
    debug = true,
    use_static_analysis = true,
    track_blocks = true,
    discover_uncovered = false,
    include = {"examples/multiline_comment_coverage.lua"},
    exclude = {},
    source_dirs = {"."}
  })
  
  -- Start coverage tracking
  coverage.start()
  
  it("should handle functions correctly", function()
    expect(TestModule.test_function(5)).to.equal("positive")
    expect(TestModule.test_function(-5)).to.equal("non-positive")
  end)
  
  -- Stop coverage tracking
  coverage.stop()
  
  -- Generate HTML report
  local html_path = "/tmp/multiline-comment-coverage.html"
  coverage.save_report(html_path, "html")
  print("\nHTML report saved to: " .. html_path)
  
  -- Print summary statistics
  print("\nCoverage Statistics:")
  local report_data = coverage.get_report_data()
  for file_path, file_data in pairs(report_data.files) do
    if file_path:match("multiline_comment_coverage.lua") then
      print("  File: " .. file_path)
      print("  Line coverage: " .. file_data.covered_lines .. "/" .. file_data.total_lines .. 
            " (" .. string.format("%.1f%%", file_data.line_coverage_percent) .. ")")
      
      -- Get original file data for source code
      local original_file = report_data.original_files[file_path]
      
      -- Print line-by-line coverage for first 50 lines
      print("\n  Line coverage details:")
      for i = 1, 50 do
        -- Get source line
        local line_text = original_file and original_file.source and original_file.source[i] or ""
        if #line_text == 0 then break end
        
        -- Truncate long lines
        if #line_text > 40 then
          line_text = line_text:sub(1, 37) .. "..."
        end
        
        -- Get coverage status
        local is_executable = file_data.executable_lines and file_data.executable_lines[i]
        local is_covered = file_data.lines and file_data.lines[i]
        
        -- Determine if this line is inside a multiline comment
        local in_comment = line_text:match("^%s*%-%-%[%[") or 
                          (i > 1 and line_text:match("^%s*function%s+this_is_inside_comment"))
        
        -- Print line info
        print(string.format("    Line %2d: %-40s | executable=%s, covered=%s%s", 
          i,
          line_text,
          tostring(is_executable),
          tostring(is_covered),
          in_comment and " (should be non-executable)" or ""))
      end
    end
  end
end)