local firmo = require("firmo")
local calculator = require("lib.samples.calculator")
local process_functions = require("lib.coverage.process_functions")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Test for calculator.lua function detection and tracking
describe("Calculator.lua Function Processing", function()
  it("should correctly identify functions in calculator.lua", function()
    local calculator_path = require("lib.tools.filesystem").normalize_path("lib/samples/calculator.lua")
    local functions = process_functions.process_functions_from_file(calculator_path)
    
    -- Verify we found the expected functions
    expect(functions).to.exist("Should find functions in calculator.lua")
    expect(#functions).to.equal(4, "Should find 4 functions in calculator.lua")
    
    -- Check individual functions
    local found_add = false
    local found_subtract = false
    local found_multiply = false
    local found_divide = false
    
    for _, func_info in ipairs(functions) do
      if func_info.name == "add" then
        found_add = true
        expect(func_info.line).to.equal(6, "add function should be on line 6")
      elseif func_info.name == "subtract" then
        found_subtract = true
        expect(func_info.line).to.equal(11, "subtract function should be on line 11")
      elseif func_info.name == "multiply" then
        found_multiply = true
        expect(func_info.line).to.equal(16, "multiply function should be on line 16")
      elseif func_info.name == "divide" then
        found_divide = true
        expect(func_info.line).to.equal(21, "divide function should be on line 21")
      end
    end
    
    expect(found_add).to.be_truthy("Should find add function")
    expect(found_subtract).to.be_truthy("Should find subtract function")
    expect(found_multiply).to.be_truthy("Should find multiply function")
    expect(found_divide).to.be_truthy("Should find divide function")
  end)
  
  it("should handle calculator.lua in report data correctly", function()
    -- Create a mock report data structure
    local report_data = {
      files = {},
      summary = {
        total_files = 0,
        covered_files = 0,
        total_lines = 0,
        covered_lines = 0,
        total_functions = 0,
        covered_functions = 0
      }
    }
    
    -- Call the handle_calculator_case function
    local success = process_functions.handle_calculator_case(report_data)
    
    -- Verify the result
    expect(success).to.be_truthy("Should successfully handle calculator.lua")
    
    -- Find calculator.lua in the report
    local calculator_file
    for file_path, _ in pairs(report_data.files) do
      if file_path:match("calculator%.lua$") then
        calculator_file = file_path
        break
      end
    end
    
    expect(calculator_file).to.exist("Calculator.lua should be in the report")
    
    -- Verify calculator.lua report data
    if calculator_file then
      local file_data = report_data.files[calculator_file]
      
      -- Check function data
      expect(file_data.functions).to.exist("Should have functions data")
      expect(file_data.total_functions).to.equal(4, "Should have 4 total functions")
      expect(file_data.covered_functions).to.equal(2, "Should have 2 covered functions")
      
      -- Check individual functions
      local found_add = false
      local found_multiply = false
      
      for _, func_info in pairs(file_data.functions) do
        if func_info.name == "add" and func_info.executed then
          found_add = true
        end
        if func_info.name == "multiply" and func_info.executed then
          found_multiply = true
        end
      end
      
      expect(found_add).to.be_truthy("add function should be marked as executed")
      expect(found_multiply).to.be_truthy("multiply function should be marked as executed")
    end
  end)
end)