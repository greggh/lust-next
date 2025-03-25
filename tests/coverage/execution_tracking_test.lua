-- Function Execution Tracking Test
-- This test verifies that function coverage tracking works correctly
-- It uses the calculator.lua file as a test subject

local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

describe("Function Execution Tracking", function()
  local calculator = require("lib.samples.calculator")
  local coverage = require("lib.coverage")
  local debug_hook = require("lib.coverage.debug_hook")
  local process_functions = require("lib.coverage.process_functions")
  local fs = require("lib.tools.filesystem")
  local reporting = require("lib.reporting")
  
  -- Get the file path for the calculator
  local calculator_file = debug.getinfo(calculator.add, "S").source:sub(2)
  local normalized_path = fs.normalize_path(calculator_file)
  
  before(function()
    -- Start coverage manually - we're specifically testing tracking
    coverage.start({
      include_patterns = {normalized_path},
      exclude_patterns = {},
      include_framework_files = true,
      track_blocks = true,
      debug = true
    })
  end)
  
  after(function()
    -- Stop coverage tracking
    coverage.stop()
  end)
  
  it("should track function execution in calculator.lua", function()
    -- Execute all calculator functions
    local add_result = calculator.add(5, 10)
    expect(add_result).to.equal(15)
    
    local subtract_result = calculator.subtract(15, 7)
    expect(subtract_result).to.equal(8)
    
    local multiply_result = calculator.multiply(4, 5)
    expect(multiply_result).to.equal(20)
    
    local divide_result = calculator.divide(20, 4)
    expect(divide_result).to.equal(5)
    
    -- Process function execution data
    local cov_data = debug_hook.get_coverage_data()
    expect(cov_data).to.exist()
    expect(cov_data.files[normalized_path]).to.exist("Calculator file should be tracked")
    
    -- Process functions
    local result = process_functions.process_functions_from_file(normalized_path)
    expect(result.functions_identified).to.be_greater_than(0)
    
    -- Verify function stats are correct
    local stats = process_functions.get_function_stats()
    expect(stats.total_functions).to.be_greater_than_or_equal_to(4)
    expect(stats.executed_functions).to.be_greater_than_or_equal_to(4)
    
    -- Get report data
    local report_data = coverage.get_report_data()
    
    -- Enhance with function data
    report_data = process_functions.enhance_report_data(report_data)
    
    -- Verify report data includes calculator.lua
    expect(report_data.files[normalized_path]).to.exist("Calculator should be in report")
    
    -- Verify report has function data
    expect(report_data.summary.total_functions).to.be_greater_than(0)
    
    -- Save coverage report
    local report_dir = "reports"
    if not fs.directory_exists(report_dir) then
      fs.create_directory(report_dir)
    end
    
    local report_path = report_dir .. "/execution-tracking.html"
    local saved, err = reporting.save_coverage_report(report_path, report_data, "html")
    expect(saved).to.be_truthy("Report saved successfully")
    
    -- Write diagnostic file
    local diag_file = io.open(report_dir .. "/execution-diag.txt", "w")
    if diag_file then
      diag_file:write("Function Execution Report:\n\n")
      
      -- Report summary
      diag_file:write("Summary:\n")
      diag_file:write(string.format("Total Functions: %d\n", stats.total_functions))
      diag_file:write(string.format("Executed Functions: %d\n", stats.executed_functions))
      diag_file:write(string.format("Coverage: %.2f%%\n\n", stats.function_coverage_percent))
      
      -- Functions found in the file
      diag_file:write("Functions in " .. normalized_path .. ":\n")
      local file_functions = cov_data.files[normalized_path].functions or {}
      for func_id, func_data in pairs(file_functions) do
        diag_file:write(string.format("  - %s: line %s, executed: %s\n",
          func_data.name or func_id,
          func_data.line or "unknown",
          func_data.executed and "yes" or "no"))
      end
      
      -- Report data 
      diag_file:write("\nReport Data:\n")
      if report_data.files[normalized_path] then
        local file_data = report_data.files[normalized_path]
        diag_file:write(string.format("  Total Lines: %d\n", file_data.total_lines or 0))
        diag_file:write(string.format("  Total Functions: %d\n", file_data.total_functions or 0))
        diag_file:write(string.format("  Covered Functions: %d\n", file_data.covered_functions or 0))
      end
      
      diag_file:close()
    end
  end)
end)