-- Block Relationship Fix Test
-- Tests the block_relationship_fixing functionality in the coverage module

local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

describe("Block Relationship Fix Test", function()
  local calculator = require("lib.samples.calculator")
  local coverage = require("lib.coverage")
  local debug_hook = require("lib.coverage.debug_hook")
  local fs = require("lib.tools.filesystem")
  local reporting = require("lib.reporting")
  
  -- Get the file path for the calculator module
  local calculator_path = debug.getinfo(calculator.add, "S").source:sub(2)
  -- Normalize the path to match what coverage module uses internally
  calculator_path = fs.normalize_path(calculator_path)
  
  before(function()
    -- Start coverage tracking with block tracking enabled
    coverage.start({
      include_patterns = {calculator_path},
      include_framework_files = true, -- Include framework files
      track_blocks = true, -- Enable block tracking
      user_code_only = false, -- Don't limit to user code only
      debug = true -- Enable debug output
    })
    
    -- Ensure file is tracked
    coverage.track_file(calculator_path)
    -- debug_hook.activate_file is no longer needed - file will be automatically tracked
  end)
  
  after(function()
    -- Stop coverage tracking, triggering block relationship fixing
    coverage.stop()
    
    -- Get coverage data
    local report_data = coverage.get_report_data()
    
    -- Verify calculator file is in report
    expect(report_data.files[calculator_path]).to.exist("Calculator file should be in report")
    
    -- Save reports in different formats
    local report_dir = "reports"
    if not fs.directory_exists(report_dir) then
      fs.create_directory(report_dir)
    end
    
    -- Save HTML report
    local html_report_path = report_dir .. "/block-relationship-fix.html"
    local saved, err = reporting.save_coverage_report(html_report_path, report_data, "html")
    expect(saved).to.be_truthy("HTML report should save successfully: " .. tostring(err))
    
    -- Save JSON report
    local json_report_path = report_dir .. "/block-relationship-fix.json"
    local saved_json, err_json = reporting.save_coverage_report(json_report_path, report_data, "json")
    expect(saved_json).to.be_truthy("JSON report should save successfully: " .. tostring(err_json))
    
    -- Save LCOV report
    local lcov_report_path = report_dir .. "/block-relationship-fix.lcov"
    local saved_lcov, err_lcov = reporting.save_coverage_report(lcov_report_path, report_data, "lcov")
    expect(saved_lcov).to.be_truthy("LCOV report should save successfully: " .. tostring(err_lcov))
    
    -- Save Cobertura report
    local cobertura_report_path = report_dir .. "/block-relationship-fix.cobertura"
    local saved_cobertura, err_cobertura = reporting.save_coverage_report(cobertura_report_path, report_data, "cobertura")
    expect(saved_cobertura).to.be_truthy("Cobertura report should save successfully: " .. tostring(err_cobertura))
  end)
  
  it("should track block relationships for calculator functions", function()
    -- Execute all calculator functions to ensure they're tracked
    local add_result = calculator.add(5, 10)
    expect(add_result).to.equal(15)
    
    local subtract_result = calculator.subtract(15, 7)
    expect(subtract_result).to.equal(8)
    
    local multiply_result = calculator.multiply(4, 5)
    expect(multiply_result).to.equal(20)
    
    local divide_result = calculator.divide(20, 4)
    expect(divide_result).to.equal(5)
    
    -- Call the block relationship fixing function directly
    local stats = debug_hook.fix_block_relationships()
    
    -- Verify that the function returned statistics
    expect(stats).to.exist("Block relationship fixing should return statistics")
    expect(stats.files_processed).to.be_greater_than(0, "Should have processed files")
    
    -- Process functions from our new module
    local process_functions = require("lib.coverage.process_functions")
    local func_stats = process_functions.process_functions_from_file(calculator_path)
    
    -- Verify functions were identified
    expect(func_stats.functions_identified).to.be_greater_than(0, "Should have identified functions")
    
    -- Get the coverage data to check block relationships
    local coverage_data = debug_hook.get_coverage_data()
    
    -- Verify file is tracked
    expect(coverage_data.files[calculator_path]).to.exist("Calculator file should be in coverage data")
    
    -- Verify function blocks are in the logical chunks
    local logical_chunks = coverage_data.files[calculator_path].logical_chunks or {}
    
    -- Print debug info about logical chunks
    print("Logical chunks:")
    for block_id, block_data in pairs(logical_chunks) do
      print("  - " .. block_id .. ": " .. (block_data.type or "unknown") .. 
            " (line " .. (block_data.start_line or "unknown") .. ")")
    end
    
    -- Get the functions data
    local functions = coverage_data.files[calculator_path].functions or {}
    
    -- Print debug info about functions
    print("Functions tracked:")
    for func_id, func_data in pairs(functions) do
      print("  - " .. func_id .. ": " .. (func_data.name or "unnamed") .. 
            " (line " .. (func_data.line or "unknown") .. ")")
    end
    
    -- Get function statistics
    local function_stats = process_functions.get_function_stats()
    print("Function coverage stats:")
    print("  - Total functions:", function_stats.total_functions)
    print("  - Executed functions:", function_stats.executed_functions)
    print("  - Function coverage:", function_stats.function_coverage_percent .. "%")
    
    -- Verify the add function is tracked
    local add_function_found = false
    for _, func_data in pairs(func_stats.functions) do
      if func_data.line == 7 or (func_data.name and func_data.name:find("add")) then
        add_function_found = true
        break
      end
    end
    
    expect(add_function_found).to.be_truthy("Add function should be tracked")
    
    -- Verify that we have at least 4 functions tracked (add, subtract, multiply, divide)
    expect(func_stats.functions_identified >= 4).to.be_truthy("Should track at least 4 functions (add, subtract, multiply, divide)")
  end)
end)