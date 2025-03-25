local firmo = require("firmo")
local coverage = require("lib.coverage")
local calculator = require("lib.samples.calculator")
local test_helper = require("lib.tools.test_helper")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Function Coverage Tracking", function()
  before(function()
    -- Reset coverage before each test
    coverage.reset()
    
    -- Start coverage with specific config for calculator.lua
    coverage.start({
      include = {"lib/samples/calculator.lua"},
      source_dirs = {"lib/samples"},
      should_track_example_files = true,
      track_functions = true
    })
    
    -- Force track calculator.lua
    coverage.track_file("lib/samples/calculator.lua")
  end)
  
  after(function()
    -- Stop coverage after each test
    coverage.stop()
  end)
  
  it("should track all functions in calculator.lua", function()
    -- Execute calculator functions
    calculator.add(5, 3)
    calculator.multiply(4, 7)
    
    -- Get raw data
    local raw_data = coverage.debug_hook.get_coverage_data()
    
    -- Verify file is tracked
    local is_tracked = false
    for file_path, _ in pairs(raw_data.files) do
      if file_path:match("calculator%.lua$") then
        is_tracked = true
        break
      end
    end
    expect(is_tracked).to.be_truthy("calculator.lua should be tracked")
    
    -- Get the normalized path
    local fs = require("lib.tools.filesystem")
    local normalized_path
    for file_path, _ in pairs(raw_data.files) do
      if file_path:match("calculator%.lua$") then
        normalized_path = file_path
        break
      end
    end
    
    expect(normalized_path).to.exist("Normalized path should exist for calculator.lua")
    
    -- Verify specific lines were executed
    if normalized_path then
      local executed_lines = raw_data.executed_lines[normalized_path] or {}
      expect(executed_lines[7]).to.be_truthy("Line 7 (inside add function) should be executed")
      expect(executed_lines[17]).to.be_truthy("Line 17 (inside multiply function) should be executed")
    end
    
    -- Check function tracking
    local functions_all = raw_data.functions.all or {}
    local calculator_functions = {}
    
    for file_path, funcs in pairs(functions_all) do
      if file_path:match("calculator%.lua$") then
        calculator_functions = funcs
        break
      end
    end
    
    expect(next(calculator_functions)).to.exist("Functions should be tracked in calculator.lua")
    
    -- Generate report data to verify function stats
    local report_data = coverage.get_report_data()
    local calculator_file_data
    
    for file_path, file_data in pairs(report_data.files or {}) do
      if file_path:match("calculator%.lua$") then
        calculator_file_data = file_data
        break
      end
    end
    
    expect(calculator_file_data).to.exist("Calculator.lua should be in report data")
    
    if calculator_file_data then
      local function_data = calculator_file_data.functions or {}
      local total_functions = 0
      local executed_functions = 0
      
      for _, is_executed in pairs(function_data) do
        total_functions = total_functions + 1
        if is_executed then
          executed_functions = executed_functions + 1
        end
      end
      
      expect(total_functions).to.be_greater_than(0, "Should track some functions")
      expect(executed_functions).to.be_greater_than(0, "Should have some executed functions")
    end
  end)
end)