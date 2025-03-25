-- Calculator Test with Coverage Check
-- Tests calculator.lua functionality and checks coverage reporting

local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

describe("Calculator Test with Coverage", function()
  -- Local variables for test usage
  local calculator = require("lib.samples.calculator") 
  local coverage = require("lib.coverage")
  local fs = require("lib.tools.filesystem")
  
  before(function()
    if not package.loaded["lib.coverage"] then
      -- Make sure coverage module is loaded
      require("lib.coverage")
    end
  end)
  
  after(function() 
    -- Check for coverage data in after block
    if package.loaded["lib.coverage"] then
      local cov = package.loaded["lib.coverage"]
      local report_dir = "coverage-reports"
      
      -- Ensure directory exists
      if not fs.directory_exists(report_dir) then
        fs.create_directory(report_dir)
      end
      
      -- Save a coverage report for inspection
      local report_data = cov.get_report_data()
      
      -- Process functions to enhance report data
      if package.loaded["lib.coverage.process_functions"] then
        local process_functions = package.loaded["lib.coverage.process_functions"]
        report_data = process_functions.enhance_report_data(report_data)
      end
      
      -- Write report data to diagnostics file
      local report_file = io.open(report_dir .. "/coverage-data.txt", "w")
      if report_file then
        report_file:write("Coverage Report Summary:\n")
        if report_data and report_data.summary then
          report_file:write(string.format("  Files: %d\n", report_data.summary.total_files or 0)) 
          report_file:write(string.format("  Functions: %d (covered: %d)\n", 
                          report_data.summary.total_functions or 0,
                          report_data.summary.covered_functions or 0))
        end
        report_file:close()
      end
    end
  end)
  
  it("should execute calculator functions", function()
    -- Execute calculator functions to test normal functionality
    local add_result = calculator.add(5, 10)
    expect(add_result).to.equal(15)
    
    local subtract_result = calculator.subtract(15, 7)
    expect(subtract_result).to.equal(8)
    
    local multiply_result = calculator.multiply(4, 5)
    expect(multiply_result).to.equal(20)
    
    local divide_result = calculator.divide(20, 4)
    expect(divide_result).to.equal(5)
  end)
end)