-- report_example.lua
-- Example demonstrating the reporting module in lust-next

-- Make sure we're using lust-next with globals
local lust_next = require('../lust-next')
lust_next.expose_globals()

-- Import the filesystem module
local fs = require("lib.tools.filesystem")

-- Load reporting module directly
local reporting_module = package.loaded["lib.reporting"] or require("lib.reporting")

-- Some sample code to test coverage
local function calculator_add(a, b)
  return a + b
end

local function calculator_subtract(a, b)
  return a - b
end

local function calculator_multiply(a, b)
  return a * b
end

local function calculator_divide(a, b)
  if b == 0 then
    error("Division by zero")
  end
  return a / b
end

local function calculator_power(a, b)
  return a ^ b
end

-- Example tests with assertions for quality analysis
describe("Report Example - Calculator", function()
  describe("Basic functions", function()
    it("should add two numbers correctly", function()
      assert.equal(5, calculator_add(2, 3))
      assert.equal(0, calculator_add(-2, 2))
      assert.equal(-10, calculator_add(-5, -5))
    end)
    
    it("should subtract two numbers correctly", function()
      assert.equal(5, calculator_subtract(10, 5))
      assert.equal(-5, calculator_subtract(5, 10))
      assert.equal(0, calculator_subtract(5, 5))
    end)
    
    it("should multiply two numbers correctly", function()
      assert.equal(6, calculator_multiply(2, 3))
      assert.equal(-6, calculator_multiply(-2, 3))
      assert.equal(6, calculator_multiply(-2, -3))
    end)
  end)
  
  describe("Advanced functions", function()
    it("should divide two numbers correctly", function()
      assert.equal(2, calculator_divide(10, 5))
      assert.equal(-2, calculator_divide(-10, 5))
      assert.is_true(math.abs(calculator_divide(1, 3) - 0.33333) < 0.001)
    end)
    
    it("should throw error when dividing by zero", function()
      assert.has_error(function() calculator_divide(5, 0) end)
    end)
  end)
  
  -- The power function isn't tested, so coverage won't be 100%
end)

-- After running tests, we can manually generate reports with the reporting module
after_each(function()
  -- Note: In actual usage, the reporting would be handled by lust-next.cli_run
  -- This example shows the direct use of the reporting module
end)

describe("Reporting Module Examples", function()
  it("demonstrates how to manually use the reporting module", function()
    -- Skip this test if the reporting module isn't available
    if not reporting_module then
      print("Reporting module not available, skipping demonstration")
      return
    end
    
    -- Example of how to use reporting module with coverage data
    -- In real usage, lust-next.cli_run handles this automatically
    local coverage = package.loaded["lib.coverage"] or require("lib.coverage")
    if coverage and coverage.get_report_data then
      local coverage_data = coverage.get_report_data()
      
      -- Example of formatting a coverage report
      local html_report = reporting_module.format_coverage(coverage_data, "html")
      local json_report = reporting_module.format_coverage(coverage_data, "json")
      local lcov_report = reporting_module.format_coverage(coverage_data, "lcov")
      
      -- Example of saving a coverage report using filesystem module
      local report_dir = "./coverage-reports"
      fs.ensure_directory_exists(report_dir)
      local report_path = fs.join_paths(report_dir, "example-coverage.html")
      
      -- Uncomment to actually save the report
      -- reporting_module.save_coverage_report(report_path, coverage_data, "html")
      
      -- Print some report info to demonstrate it works
      print("Generated HTML report with length: " .. #html_report .. " bytes")
      print("Generated JSON report with length: " .. #json_report .. " bytes")
      print("Generated LCOV report with length: " .. #lcov_report .. " bytes")
    end
    
    -- Example of how to use reporting module with quality data
    local quality = package.loaded["lib.quality"] or require("lib.quality")
    if quality and quality.get_report_data then
      local quality_data = quality.get_report_data()
      
      -- Example of formatting a quality report
      local html_report = reporting_module.format_quality(quality_data, "html")
      local json_report = reporting_module.format_quality(quality_data, "json")
      
      -- Example of saving a quality report using filesystem module
      local report_dir = "./coverage-reports"
      fs.ensure_directory_exists(report_dir)
      local report_path = fs.join_paths(report_dir, "example-quality.html")
      
      -- Uncomment to actually save the report
      -- reporting_module.save_quality_report(report_path, quality_data, "html")
      
      -- Print some report info to demonstrate it works
      print("Generated quality HTML report with length: " .. #html_report .. " bytes")
      print("Generated quality JSON report with length: " .. #json_report .. " bytes")
    end
    
    -- Example of auto-saving both reports with advanced configuration
    if coverage and coverage.get_report_data and quality and quality.get_report_data then
      local coverage_data = coverage.get_report_data()
      local quality_data = quality.get_report_data()
      
      -- Create reports directory with filesystem module
      local reports_dir = "./example-reports"
      fs.ensure_directory_exists(reports_dir)
      
      -- Example of advanced config with templates and timestamp
      local config = {
        report_dir = reports_dir,
        report_suffix = "-example",
        timestamp_format = "%Y-%m-%d",
        coverage_path_template = "coverage/coverage-{format}{suffix}",
        quality_path_template = "quality/quality-{format}{suffix}",
        results_path_template = "results/results-{format}{suffix}",
        verbose = true
      }
      
      -- Uncomment to actually save the reports
      -- local results = reporting_module.auto_save_reports(coverage_data, quality_data, nil, config)
      -- print("Auto-save completed with path normalization and directory creation handled by filesystem module")
    end
  end)
end)

-- Run the example tests with coverage enabled
-- Note: This would typically be handled by the CLI with appropriate options
print("\nRunning example tests with coverage and quality tracking")
lust_next.coverage_options.enabled = true
lust_next.quality_options.enabled = true

-- Note: In a normal CLI invocation, lust_next.cli_run would handle
-- setup/teardown of coverage, running tests, and generating reports
local coverage = package.loaded["lib.coverage"] or require("lib.coverage")
if coverage then
  coverage.init(lust_next.coverage_options)
  coverage.reset()
  coverage.start()
end

local quality = package.loaded["lib.quality"] or require("lib.quality")
if quality then
  quality.init(lust_next.quality_options)
  quality.reset()
end

print("\nExample complete!")

-- Note: The purpose of this example is to show how the reporting module works.
-- In practice, you would run tests with lust-next's CLI which handles coverage
-- and report generation automatically.