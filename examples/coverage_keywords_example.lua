--[[
  coverage_keywords_example.lua
  
  This example demonstrates how the control_flow_keywords_executable option
  affects coverage calculation and visualization.
]]

-- Use a dedicated test file that's part of the examples directory
local example_file = "./examples/control_flow_test.lua"

-- Define a function we'll call with different coverage options
local function run_coverage_test(control_flow_keywords_executable)
  -- Clear any existing coverage data
  package.loaded["lib.coverage"] = nil
  
  -- Start coverage tracking with specified option
  local coverage = require "lib.coverage"
  
  -- Initialize with specified option
  coverage.init({
    enabled = true,
    source_dirs = {"."},
    include = {example_file},
    exclude = {},
    track_blocks = true,
    use_static_analysis = true,
    control_flow_keywords_executable = control_flow_keywords_executable,
    debug = false -- Minimize debug output
  })
  
  -- Start coverage
  coverage.start()
  
  -- Execute the example file
  print("Running with control_flow_keywords_executable = " .. tostring(control_flow_keywords_executable))
  dofile(example_file)
  
  -- Stop coverage tracking
  coverage.stop()
  
  -- Generate and save HTML report
  local setting_name = control_flow_keywords_executable and "executable" or "non_executable"
  local report_path = "/tmp/keywords-" .. setting_name .. "-example.html"
  
  -- Save the report
  local success = coverage.save_report(report_path, "html")
  
  -- Get coverage data
  local coverage_data = coverage.get_report_data()
  
  -- Create a simplified report
  print("\nFile coverage with control_flow_keywords_executable = " .. tostring(control_flow_keywords_executable))
  
  local normalized_path = example_file
  local file_data = nil
  
  -- Find the file in coverage data
  if coverage_data and coverage_data.files then
    for path, data in pairs(coverage_data.files) do
      if path == normalized_path or path:match(normalized_path) then
        file_data = data
        normalized_path = path
        break
      end
    end
  end
  
  if file_data then
    local executable_count = 0
    local covered_count = 0
    
    -- Count executable and covered lines
    if file_data.executable_lines then
      for line_num, is_executable in pairs(file_data.executable_lines) do
        if is_executable then
          executable_count = executable_count + 1
          if file_data.lines and file_data.lines[line_num] then
            covered_count = covered_count + 1
          end
        end
      end
    end
    
    print("  Executable lines: " .. executable_count)
    print("  Covered lines: " .. covered_count)
    
    local coverage_percent = 0
    if executable_count > 0 then
      coverage_percent = (covered_count / executable_count) * 100
    end
    
    print("  Coverage percent: " .. string.format("%.1f%%", coverage_percent))
    
    -- Print line classification if available
    print("  Report saved to: " .. report_path)
  else
    print("  Error: Could not find file data for " .. example_file)
  end
  
  return report_path
end

-- First run: control flow keywords ARE executable (default behavior)
print("=== TEST 1: Control flow keywords ARE executable (strict coverage) ===")
local path1 = run_coverage_test(true)

-- Clear stats between runs
collectgarbage("collect")

-- Second run: control flow keywords are NOT executable
print("\n=== TEST 2: Control flow keywords are NOT executable (lenient coverage) ===")
local path2 = run_coverage_test(false)

-- No cleanup needed for permanent example file

-- Compare results
print("\n=== COMPARISON ===")
print("1. When control_flow_keywords_executable = true:")
print("   - Keywords like 'end', 'else', etc. are treated as executable lines")
print("   - This leads to stricter coverage requirements")
print("   - Usually results in lower coverage percentages")
print("   - Report: " .. path1)
print("\n2. When control_flow_keywords_executable = false:")
print("   - Keywords like 'end', 'else', etc. are treated as non-executable")
print("   - This leads to more lenient coverage requirements")
print("   - Usually results in higher coverage percentages")
print("   - Report: " .. path2)

print("\nOpen the HTML reports to visually compare the differences!")
print("Opening reports in browser...")
os.execute("xdg-open " .. path1 .. " &>/dev/null")
os.execute("xdg-open " .. path2 .. " &>/dev/null")

print("\nExample complete!")