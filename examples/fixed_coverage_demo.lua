--[[
  fixed_coverage_demo.lua
  
  A minimal example demonstrating the fixed coverage module
]]

-- Import modules
package.path = package.path .. ";./?.lua"
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local coverage = require("lib.coverage")

-- Sample module with functions to test
local TestModule = {}

-- Function with a simple branch
function TestModule.check_value(value)
  -- This is a comment that should NOT be marked as covered
  
  -- Another comment that should not be covered
  if value > 0 then
    return "positive"
  else
    return "non-positive"
  end
  -- This comment should also not be covered
end

-- Function with nested branches
function TestModule.classify_number(num)
  if type(num) ~= "number" then
    return "not a number"
  end
  
  if num == 0 then
    return "zero"
  elseif num > 0 then
    if num > 100 then
      return "large positive"
    else
      return "small positive"
    end
  else
    if num < -100 then
      return "large negative"
    else
      return "small negative"
    end
  end
end

-- Function that won't be called
function TestModule.unused_function(a, b)
  return a + b
end

-- Run tests with coverage
describe("Fixed Coverage Demo", function()
  -- Initialize coverage with debugging enabled
  coverage.init({
    enabled = true,
    debug = true,
    use_static_analysis = true,
    track_blocks = true,
    discover_uncovered = false,
    include = {"examples/fixed_coverage_demo.lua"},
    exclude = {},
    source_dirs = {"."}
  })
  
  -- Start coverage
  coverage.start()
  
  it("should correctly check values", function()
    expect(TestModule.check_value(5)).to.equal("positive")
    expect(TestModule.check_value(-3)).to.equal("non-positive")
    expect(TestModule.check_value(0)).to.equal("non-positive")
  end)
  
  it("should correctly classify numbers", function()
    expect(TestModule.classify_number("string")).to.equal("not a number")
    expect(TestModule.classify_number(0)).to.equal("zero")
    expect(TestModule.classify_number(50)).to.equal("small positive")
    expect(TestModule.classify_number(200)).to.equal("large positive")
    expect(TestModule.classify_number(-50)).to.equal("small negative")
    
    -- Deliberately don't test large negative path
  end)
  
  -- Stop coverage
  coverage.stop()
  
  -- Generate HTML report
  local html_path = "/tmp/fixed-coverage-demo.html"
  -- Use the reporting module instead of coverage.save_report
  local report_data = coverage.get_report_data()
  local reporting = require("lib.reporting")
  reporting.save_coverage_report(html_path, report_data, "html")
  print("\nHTML report saved to: " .. html_path)
  
  -- Get report data
  local report_data = coverage.get_report_data()
  
  -- Print summary statistics
  print("\nCoverage Statistics:")
  print("  Files: " .. report_data.summary.covered_files .. "/" .. report_data.summary.total_files)
  print("  Lines: " .. report_data.summary.covered_lines .. "/" .. report_data.summary.total_lines .. 
        " (" .. string.format("%.1f%%", report_data.summary.line_coverage_percent) .. ")")
  print("  Functions: " .. report_data.summary.covered_functions .. "/" .. report_data.summary.total_functions .. 
        " (" .. string.format("%.1f%%", report_data.summary.function_coverage_percent) .. ")")
  
  if report_data.summary.total_blocks then
    print("  Blocks: " .. report_data.summary.covered_blocks .. "/" .. report_data.summary.total_blocks .. 
          " (" .. string.format("%.1f%%", report_data.summary.block_coverage_percent) .. ")")
  end
  
  -- Print details for this file
  print("\nDetailed Coverage for this file:")
  for file_path, file_data in pairs(report_data.files) do
    if file_path:match("fixed_coverage_demo.lua") then
      print("  File: " .. file_path)
      print("  Line coverage: " .. file_data.covered_lines .. "/" .. file_data.total_lines .. 
            " (" .. string.format("%.1f%%", file_data.line_coverage_percent) .. ")")
      print("  Function coverage: " .. file_data.covered_functions .. "/" .. file_data.total_functions .. 
            " (" .. string.format("%.1f%%", file_data.function_coverage_percent) .. ")")
      
      -- Print function details
      print("\n  Function details:")
      for _, func in ipairs(file_data.functions) do
        print(string.format("    %s (line %d): executed=%s, calls=%d", 
          func.name or "anonymous",
          func.line,
          tostring(func.executed),
          func.calls or 0))
      end
      
      -- Print line-by-line coverage for first 60 lines
      print("\n  Line coverage details:")
      
      -- Get original file data for source code
      local original_file = report_data.original_files[file_path]
      local source_lines = original_file and original_file.source or {}
      
      for i = 1, 60 do
        -- Skip if beyond the file length
        if i > #source_lines then break end
        
        -- Get source line (truncated if too long)
        local line_text = source_lines[i] or ""
        if #line_text > 30 then
          line_text = line_text:sub(1, 27) .. "..."
        end
        
        -- Get coverage status
        local is_executable = file_data.executable_lines and file_data.executable_lines[i]
        local is_covered = file_data.lines and file_data.lines[i]
        
        -- Get line type if available
        local line_type = "unknown"
        if original_file and original_file.code_map and
           original_file.code_map.lines and 
           original_file.code_map.lines[i] then
          line_type = original_file.code_map.lines[i].type or "unknown"
        end
        
        -- Print the info
        print(string.format("    Line %2d: %-30s | executable=%s, covered=%s, type=%s", 
          i,
          line_text,
          tostring(is_executable),
          tostring(is_covered),
          line_type))
      end
    end
  end
end)

-- The tests will run automatically when the script executes
