-- Instrumentation-based Coverage Test
-- Tests the new instrumentation-based coverage system

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Dependencies
local fs = require("lib.tools.filesystem")
local coverage = require("lib.coverage")
local loader_hook = require("lib.coverage.loader.hook")

-- Load calculator module with instrumentation hook (bypass normal require)
local calculator

describe("Instrumentation-based Coverage", function()
  -- Test basic coverage functionality
  it("should track execution of code", function()
    -- Start coverage tracking
    coverage.start()
    
    -- Load the calculator module with instrumentation
    local calc, err = loader_hook.load_module("lib.samples.calculator")
    expect(err).to_not.exist("Failed to load module: " .. tostring(err))
    calculator = calc
    
    -- Execute some code
    local result = calculator.add(3, 5)
    expect(result).to.equal(8)
    
    -- Stop coverage tracking
    coverage.stop()
    
    -- Get coverage data
    local data = coverage.get_data()
    
    -- Verify that coverage data exists
    expect(data).to.exist()
    expect(data.summary).to.exist()
    expect(data.summary.executable_lines).to.be_greater_than(0)
    expect(data.summary.executed_lines).to.be_greater_than(0)
    
    -- Reset coverage data
    coverage.reset()
  end)
  
  -- Test three-state coverage model
  it("should distinguish between covered, executed, and not covered code", function()
    -- Start coverage tracking
    coverage.start()
    
    -- Load the calculator module with instrumentation
    local calc, err = loader_hook.load_module("lib.samples.calculator")
    expect(err).to_not.exist("Failed to load module: " .. tostring(err))
    calculator = calc
    
    -- Execute some code with assertions
    local result1 = calculator.add(3, 5)
    expect(result1).to.equal(8)  -- This should mark add() as covered
    
    -- Execute code without assertions
    local result2 = calculator.subtract(10, 4)  -- This should mark subtract() as executed but not covered
    
    -- Stop coverage tracking
    coverage.stop()
    
    -- Get coverage data
    local data = coverage.get_data()
    
    -- Verify coverage data
    expect(data.summary.covered_lines).to.be_greater_than(0)
    expect(data.summary.executed_lines).to.be_greater_than(data.summary.covered_lines)
    
    -- Reset coverage data
    coverage.reset()
  end)
  
  -- Test report generation
  it("should generate HTML coverage reports", function()
    -- Start coverage tracking
    coverage.start()
    
    -- Load the calculator module with instrumentation
    local calc, err = loader_hook.load_module("lib.samples.calculator")
    expect(err).to_not.exist("Failed to load module: " .. tostring(err))
    calculator = calc
    
    -- Execute all calculator functions
    local add_result = calculator.add(3, 5)
    expect(add_result).to.equal(8)
    
    local subtract_result = calculator.subtract(10, 4)
    expect(subtract_result).to.equal(6)
    
    local multiply_result = calculator.multiply(2, 3)
    expect(multiply_result).to.equal(6)
    
    local divide_result = calculator.divide(10, 2)
    expect(divide_result).to.equal(5)
    
    -- Try to divide by zero (will throw an error)
    expect(function()
      calculator.divide(5, 0)
    end).to.fail()
    
    -- Stop coverage tracking
    coverage.stop()
    
    -- Generate HTML report
    local html_output_path = "./coverage-reports/instrumentation-test.html"
    local html_success = coverage.generate_report("html", html_output_path)
    
    -- Verify HTML report generation
    expect(html_success).to.be_truthy()
    expect(fs.file_exists(html_output_path)).to.be_truthy()
    
    -- Generate JSON report
    local json_output_path = "./coverage-reports/instrumentation-test.json"
    local json_success = coverage.generate_report("json", json_output_path)
    
    -- Verify JSON report generation
    expect(json_success).to.be_truthy()
    expect(fs.file_exists(json_output_path)).to.be_truthy()
    
    -- Reset coverage data
    coverage.reset()
  end)
end)