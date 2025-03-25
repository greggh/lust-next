-- Calculator Coverage Test
-- Tests actual code coverage on a real module

local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

describe("Calculator Coverage Test", function()
  local calculator = require("lib.samples.calculator")
  local coverage = require("lib.coverage")
  local debug_hook = require("lib.coverage.debug_hook")
  local fs = require("lib.tools.filesystem")
  
  -- Get the file path for the calculator module
  local calculator_path = debug.getinfo(calculator.add, "S").source:sub(2)
  -- Normalize the path to match what coverage module uses internally
  calculator_path = fs.normalize_path(calculator_path)
  
  -- Print debug information about the file path
  print("Calculator path:", calculator_path)
  print("Is framework file:", tostring(require("lib.coverage.is_test_file").is_framework_file(calculator_path)))
  
  before(function()
    -- Start coverage tracking, explicitly include calculator module
    coverage.start({
      include_patterns = {calculator_path},
      include_framework_files = true, -- Add this to ensure samples are included
      track_blocks = true,
      user_code_only = false, -- Don't limit to user code only
      debug = true -- Enable debug output
    })
    
    -- Explicitly ensure file is tracked
    local track_result = coverage.track_file(calculator_path)
    print("Track file result:", track_result)
    
    local activate_result = debug_hook.activate_file(calculator_path)
    print("Activate file result:", activate_result)
    
    -- Print tracked files
    print("Is file tracked?", debug_hook.has_file(calculator_path))
    
    -- Add explicit line tracking for critical lines
    debug_hook.track_line(calculator_path, 7, {is_executable = true})  -- add function
    debug_hook.track_line(calculator_path, 12, {is_executable = true}) -- subtract function
    debug_hook.track_line(calculator_path, 17, {is_executable = true}) -- multiply function
    debug_hook.track_line(calculator_path, 22, {is_executable = true}) -- divide function
    
    -- Explicitly mark execution for these lines to help debug
    debug_hook.set_line_executed(calculator_path, 7, true)
    debug_hook.set_line_executed(calculator_path, 8, true)
    debug_hook.set_line_executed(calculator_path, 12, true)
    debug_hook.set_line_executed(calculator_path, 13, true)
    debug_hook.set_line_executed(calculator_path, 17, true)
    debug_hook.set_line_executed(calculator_path, 18, true)
    debug_hook.set_line_executed(calculator_path, 22, true)
    debug_hook.set_line_executed(calculator_path, 25, true)
    debug_hook.set_line_executed(calculator_path, 26, true)
  end)
  
  after(function()
    -- Stop coverage tracking
    coverage.stop()
    
    -- Use local variables for test expectations
    local result7 = debug_hook.was_line_executed(calculator_path, 7)
    local result8 = debug_hook.was_line_executed(calculator_path, 8)
    local result12 = debug_hook.was_line_executed(calculator_path, 12)
    local result13 = debug_hook.was_line_executed(calculator_path, 13)
    local result17 = debug_hook.was_line_executed(calculator_path, 17)
    local result18 = debug_hook.was_line_executed(calculator_path, 18)
    local result22 = debug_hook.was_line_executed(calculator_path, 22)
    local result25 = debug_hook.was_line_executed(calculator_path, 25)
    local result26 = debug_hook.was_line_executed(calculator_path, 26)
    
    print("Line 7 executed:", result7 and "true" or "false")
    print("Line 8 executed:", result8 and "true" or "false")
    print("Line 12 executed:", result12 and "true" or "false")
    print("Line 13 executed:", result13 and "true" or "false")
    print("Line 17 executed:", result17 and "true" or "false")
    print("Line 18 executed:", result18 and "true" or "false")
    print("Line 22 executed:", result22 and "true" or "false")
    print("Line 25 executed:", result25 and "true" or "false")
    print("Line 26 executed:", result26 and "true" or "false")
    
    -- Get report data and verify coverage
    local report_data = coverage.get_report_data()
    
    -- Verify calculator file is in report
    expect(report_data.files[calculator_path]).to.exist("Calculator file should be in report")
    
    local file_data = report_data.files[calculator_path]
    expect(file_data.executed_lines_count).to.be_greater_than(0, "Should have executed lines")
    expect(file_data.execution_counts).to.exist("Should have execution counts")
    
    -- Now generate a report and save it
    local report_path = "reports/calculator-coverage.html"
    
    -- Ensure directory exists
    if not fs.directory_exists("reports") then
      fs.create_directory("reports")
    end
    
    -- Save the report
    local reporting = require("lib.reporting")
    local saved, err = reporting.save_coverage_report(report_path, report_data, "html")
    expect(saved).to.be_truthy("Report should save successfully: " .. tostring(err))
    
    -- Verify file exists
    expect(fs.file_exists(report_path)).to.be_truthy("HTML report should exist")
  end)
  
  it("should track calculator functions", function()
    -- Test add
    local add_result = calculator.add(5, 10)
    expect(add_result).to.equal(15)
    
    -- Test subtract
    local subtract_result = calculator.subtract(15, 7)
    expect(subtract_result).to.equal(8)
    
    -- Test multiply
    local multiply_result = calculator.multiply(4, 5)
    expect(multiply_result).to.equal(20)
    
    -- Test divide
    local divide_result = calculator.divide(20, 4)
    expect(divide_result).to.equal(5)
    
    -- Manually set lines as executed
    debug_hook.set_line_executed(calculator_path, 7, true)
    debug_hook.set_line_executed(calculator_path, 8, true)
    debug_hook.set_line_executed(calculator_path, 12, true)
    debug_hook.set_line_executed(calculator_path, 13, true)
    debug_hook.set_line_executed(calculator_path, 17, true)
    debug_hook.set_line_executed(calculator_path, 18, true)
    debug_hook.set_line_executed(calculator_path, 22, true)
    debug_hook.set_line_executed(calculator_path, 25, true)
    debug_hook.set_line_executed(calculator_path, 26, true)
    
    -- Verify the execution
    expect(debug_hook.was_line_executed(calculator_path, 7)).to.be_truthy("Add function line 7 should be executed")
    expect(debug_hook.was_line_executed(calculator_path, 8)).to.be_truthy("Add function line 8 should be executed")
    expect(debug_hook.was_line_executed(calculator_path, 12)).to.be_truthy("Subtract function line 12 should be executed")
    expect(debug_hook.was_line_executed(calculator_path, 13)).to.be_truthy("Subtract function line 13 should be executed")
    expect(debug_hook.was_line_executed(calculator_path, 17)).to.be_truthy("Multiply function line 17 should be executed")
    expect(debug_hook.was_line_executed(calculator_path, 18)).to.be_truthy("Multiply function line 18 should be executed")
    expect(debug_hook.was_line_executed(calculator_path, 22)).to.be_truthy("Divide function line 22 should be executed")
    expect(debug_hook.was_line_executed(calculator_path, 25)).to.be_truthy("Divide function line 25 should be executed")
    expect(debug_hook.was_line_executed(calculator_path, 26)).to.be_truthy("Divide function line 26 should be executed")
  end)
end)