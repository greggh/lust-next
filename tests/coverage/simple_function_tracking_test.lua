local firmo = require("firmo")
local coverage = require("lib.coverage")
local calculator = require("lib.samples.calculator")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- A simpler test that verifies calculator.lua is tracked in coverage
describe("Calculator Coverage Verification", function()
  local report_data
  
  before(function()
    -- Start coverage with specific config to include calculator.lua
    coverage.start({
      source_dirs = {"lib/samples"},
      include = {"lib/samples/calculator.lua"},
      should_track_example_files = true,
      track_functions = true
    })
    
    -- Execute calculator functions
    calculator.add(5, 3)
    calculator.multiply(7, 2)
    
    -- Stop coverage to trigger special handling
    report_data = coverage.stop()
  end)
  
  it("should include calculator.lua in coverage reports", function()
    -- Check if calculator.lua appears in the report
    local calculator_file
    
    for file_path, _ in pairs(report_data.files or {}) do
      if file_path:match("calculator%.lua$") then
        calculator_file = file_path
        break
      end
    end
    
    -- Verify calculator.lua is in the report
    expect(calculator_file).to.exist("Calculator.lua should be in coverage report")
    
    -- If found, verify function data is present
    if calculator_file then
      -- Check functions are tracked
      local file_data = report_data.files[calculator_file]
      local function_data = file_data and file_data.functions
      
      expect(function_data).to.exist("Function data should exist")
      
      -- Check if key calculator functions are present
      local found_add = false
      local found_multiply = false
      
      for key, func_info in pairs(function_data or {}) do
        if func_info.name == "add" then
          found_add = true
        elseif func_info.name == "multiply" then
          found_multiply = true
        end
      end
      
      expect(found_add).to.be_truthy("'add' function should be tracked")
      expect(found_multiply).to.be_truthy("'multiply' function should be tracked")
    end
  end)
end)