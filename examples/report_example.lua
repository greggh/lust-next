-- report_example.lua 
-- Example demonstrating the reporting module in firmo
-- Updated to follow current best practices

-- Import the firmo framework with proper function extraction
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import helper modules
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Load reporting module directly
local reporting_module = require("lib.reporting")

-- Some sample code to test coverage
local calculator = {
  add = function(a, b)
    return a + b
  end,
  
  subtract = function(a, b)
    return a - b
  end,
  
  multiply = function(a, b)
    return a * b
  end,
  
  divide = function(a, b)
    if b == 0 then
      return nil, error_handler.validation_error(
        "Cannot divide by zero", 
        { parameter = "b", provided_value = b }
      )
    end
    return a / b
  end,
  
  power = function(a, b)
    return a ^ b
  end
}

-- Example tests using expect-style assertions (not assert style)
describe("Report Example - Calculator", function()
  -- Track any resources that need cleanup
  local test_files = {}
  
  -- Cleanup any resources after tests
  after(function()
    for _, file_path in ipairs(test_files) do
      local success, err = pcall(function() 
        if fs.file_exists(file_path) then
          fs.delete_file(file_path)
        end
      end)
      
      if not success and firmo.log then
        firmo.log.warn("Failed to remove test file: " .. tostring(err), {
          file_path = file_path
        })
      end
    end
    test_files = {}
  end)
  
  describe("Basic functions", function()
    it("should add two numbers correctly", function()
      expect(calculator.add(2, 3)).to.equal(5)
      expect(calculator.add(-2, 2)).to.equal(0)
      expect(calculator.add(-5, -5)).to.equal(-10)
    end)

    it("should subtract two numbers correctly", function()
      expect(calculator.subtract(10, 5)).to.equal(5)
      expect(calculator.subtract(5, 10)).to.equal(-5)
      expect(calculator.subtract(5, 5)).to.equal(0)
    end)

    it("should multiply two numbers correctly", function()
      expect(calculator.multiply(2, 3)).to.equal(6)
      expect(calculator.multiply(-2, 3)).to.equal(-6)
      expect(calculator.multiply(-2, -3)).to.equal(6)
    end)
  end)

  describe("Advanced functions", function()
    it("should divide two numbers correctly", function()
      expect(calculator.divide(10, 5)).to.equal(2)
      expect(calculator.divide(-10, 5)).to.equal(-2)
      
      -- Example of approximate comparison
      local result = calculator.divide(1, 3)
      expect(math.abs(result - 0.33333) < 0.001).to.be_truthy()
    end)

    -- Example of proper error testing using expect_error flag
    it("should handle division by zero", { expect_error = true }, function()
      -- Use with_error_capture to safely call functions that may return errors
      local result, err = test_helper.with_error_capture(function()
        return calculator.divide(5, 0)
      end)()
      
      -- Make assertions about the error
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("divide by zero")
    end)
  end)

  -- The power function isn't tested, so coverage won't be 100%
end)

-- Examples of how to work with the reporting module
describe("Reporting Module Examples", function()
  it("demonstrates how to generate various report formats", function()
    -- Skip this test if the reporting module isn't available
    if not reporting_module then
      firmo.log.warn("Reporting module not available, skipping demonstration")
      return
    end

    -- Example of how to use reporting module with coverage data
    -- In real usage, this would happen via command line: lua test.lua --coverage examples/report_example.lua
    local coverage = package.loaded["lib.coverage"] or require("lib.coverage")
    if coverage and coverage.get_report_data then
      local coverage_data = coverage.get_report_data() or {}
      
      -- Example of getting different report formats
      local html_report = reporting_module.format_coverage(coverage_data, "html") or ""
      local json_report = reporting_module.format_coverage(coverage_data, "json") or ""
      local lcov_report = reporting_module.format_coverage(coverage_data, "lcov") or ""
      
      -- Create a temp directory for report output
      local temp_dir = test_helper.create_temp_test_directory()
      local report_path = temp_dir.path .. "/example-coverage.html"
      
      -- Save a report if we got any data
      if html_report and #html_report > 100 then
        local success, err = fs.write_file(report_path, html_report)
        if success then
          table.insert(test_files, report_path)
          firmo.log.info("Created coverage report", {
            path = report_path,
            size = #html_report
          })
        else
          firmo.log.warn("Failed to write report", {
            error = tostring(err)
          })
        end
      else
        firmo.log.info("No meaningful coverage data available in this example run",
          { note = "Run with --coverage flag to generate real data" })
      end
    end
  end)
  
  it("shows advanced report configuration options", function()
    -- Create a temp directory
    local temp_dir = test_helper.create_temp_test_directory()
    
    -- Example of structured configuration for reports
    local config = {
      report_dir = temp_dir.path,
      formats = {"html", "json", "lcov"},
      timestamp_format = "%Y-%m-%d",
      coverage_path_template = "{format}/coverage-{timestamp}.{format}",
      quality_path_template = "{format}/quality-{timestamp}.{format}",
      results_path_template = "{format}/results-{timestamp}.{format}",
    }
    
    -- In a real scenario, you would:
    -- 1. Run tests with coverage enabled
    -- 2. Get coverage data using coverage.get_report_data()
    -- 3. Configure the reporting module
    -- 4. Generate and save reports
    
    firmo.log.info("Advanced reporting configuration ready", {
      directory = temp_dir.path,
      formats = table.concat(config.formats, ", "),
      templates = {
        coverage = config.coverage_path_template,
        quality = config.quality_path_template
      }
    })
  end)
end)

-- NOTE: Do not include coverage.start() or quality.init() here
-- In a real scenario, you would run this with: 
-- env -C /path/to/firmo lua test.lua --coverage --quality examples/report_example.lua
