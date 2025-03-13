-- reporting_test.lua
-- Tests for the reporting module

-- Import the test framework properly
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local before, after = lust.before, lust.after
local before_each, after_each = lust.before, lust.after

-- Try to load the logging module
local logging, logger
local function try_load_logger()
  if not logger then
    local ok, log_module = pcall(require, "lib.tools.logging")
    if ok and log_module then
      logging = log_module
      logger = logging.get_logger("test.reporting")
      
      if logger and logger.debug then
        logger.debug("Reporting tests initialized", {
          module = "test.reporting",
          test_type = "integration",
          assertion_focus = "reporting API"
        })
      end
    end
  end
  return logger
end

-- Initialize logger
local log = try_load_logger()

-- Import central_config
local central_config = require("lib.core.central_config")

if log then
  log.debug("Loading test dependencies", {
    component = "TestSetup",
    dependencies = {
      "reporting_module",
      "coverage_module",
      "quality_module"
    }
  })
end

-- Load modules for testing
local reporting_module = package.loaded["lib.reporting"] or require("lib.reporting")
local coverage_module = package.loaded["lib.coverage"] or require("lib.coverage")
local quality_module = package.loaded["lib.quality"] or require("lib.quality")

if log then
  log.debug("Test dependencies loaded", {
    component = "TestSetup",
    modules_loaded = {
      reporting = reporting_module ~= nil,
      coverage = coverage_module ~= nil,
      quality = quality_module ~= nil
    }
  })
end

describe("Reporting Module", function()
  -- Mock data for testing
  local mock_coverage_data
  local mock_quality_data
  
  before_each(function()
    -- Create mock coverage data for testing
    mock_coverage_data = {
      files = {
        ["/path/to/example.lua"] = {
          total_lines = 100,
          covered_lines = 80,
          total_functions = 10,
          covered_functions = 8,
          lines = { [5] = true, [10] = true, [15] = true },
          functions = { ["test_func"] = true }
        },
        ["/path/to/another.lua"] = {
          total_lines = 50,
          covered_lines = 40,
          total_functions = 5,
          covered_functions = 4,
          lines = { [5] = true, [10] = true },
          functions = { ["another_func"] = true }
        }
      },
      summary = {
        total_files = 2,
        covered_files = 2,
        total_lines = 150,
        covered_lines = 120,
        total_functions = 15,
        covered_functions = 12,
        line_coverage_percent = 80,
        function_coverage_percent = 80,
        overall_percent = 80
      }
    }
    
    -- Create mock quality data for testing
    mock_quality_data = {
      level = 3,
      level_name = "comprehensive",
      tests = {
        ["test1"] = {
          assertion_count = 5,
          quality_level = 3,
          quality_level_name = "comprehensive",
          assertion_types = {
            equality = 2,
            truth = 1,
            error_handling = 1,
            type_checking = 1
          }
        },
        ["test2"] = {
          assertion_count = 3,
          quality_level = 2,
          quality_level_name = "standard",
          assertion_types = {
            equality = 2,
            truth = 1
          }
        }
      },
      summary = {
        tests_analyzed = 2,
        tests_passing_quality = 1,
        quality_percent = 50,
        assertions_total = 8,
        assertions_per_test_avg = 4,
        assertion_types_found = {
          equality = 4,
          truth = 2,
          error_handling = 1,
          type_checking = 1
        },
        issues = {
          {
            test = "test2",
            issue = "Missing required assertion types: need 3 type(s), found 2"
          }
        }
      }
    }
  end)
  
  describe("Module Interface", function()
    it("should export expected functions", function()
      expect(reporting_module.format_coverage).to.exist()
      expect(reporting_module.format_quality).to.exist()
      expect(reporting_module.save_coverage_report).to.exist()
      expect(reporting_module.save_quality_report).to.exist()
      expect(reporting_module.write_file).to.exist()
      expect(reporting_module.auto_save_reports).to.exist()
    end)
    
    it("should define standard data structures", function()
      expect(reporting_module.CoverageData).to.exist()
      expect(reporting_module.QualityData).to.exist()
    end)
  end)
  
  describe("Coverage Formatting", function()
    it("should format coverage data as summary", function()
      local result = reporting_module.format_coverage(mock_coverage_data, "summary")
      expect(result).to.exist()
      expect(result.overall_pct).to.equal(80)
      expect(result.total_files).to.equal(2)
      expect(result.total_lines).to.equal(150)
      expect(result.covered_lines).to.equal(120)
    end)
    
    it("should format coverage data as JSON", function()
      local result = reporting_module.format_coverage(mock_coverage_data, "json")
      expect(result).to.exist()
      expect(result).to.be.a("string")
      -- Should contain some expected strings
      expect(result:find('"overall_pct":80') ~= nil or 
             result:find('"overall_pct": 80') ~= nil).to.be_truthy()
    end)
    
    it("should format coverage data as HTML", function()
      local result = reporting_module.format_coverage(mock_coverage_data, "html")
      expect(result).to.exist()
      expect(result).to.be.a("string")
      -- Should contain HTML structure
      expect(result:find("<!DOCTYPE html>") ~= nil).to.be_truthy()
      expect(result:find("Lust%-Next Coverage Report") ~= nil).to.be_truthy()
    end)
    
    it("should format coverage data as LCOV", function()
      local result = reporting_module.format_coverage(mock_coverage_data, "lcov")
      expect(result).to.exist()
      expect(result).to.be.a("string")
      -- Should contain LCOV format elements
      expect(result:find("SF:") ~= nil).to.be_truthy()
      expect(result:find("end_of_record") ~= nil).to.be_truthy()
    end)
    
    it("should default to summary format if format is invalid", function()
      local result = reporting_module.format_coverage(mock_coverage_data, "invalid_format")
      expect(result).to.exist()
      expect(result.overall_pct).to.equal(80)
    end)
  end)
  
  describe("Quality Formatting", function()
    it("should format quality data as summary", function()
      local result = reporting_module.format_quality(mock_quality_data, "summary")
      expect(result).to.exist()
      expect(result.level).to.equal(3)
      expect(result.level_name).to.equal("comprehensive")
      expect(result.quality_pct).to.equal(50)
      expect(result.tests_analyzed).to.equal(2)
    end)
    
    it("should format quality data as JSON", function()
      local result = reporting_module.format_quality(mock_quality_data, "json")
      expect(result).to.exist()
      expect(result).to.be.a("string")
      -- Should contain some expected strings
      expect(result:find('"level":3') ~= nil or 
             result:find('"level": 3') ~= nil).to.be_truthy()
    end)
    
    it("should format quality data as HTML", function()
      local result = reporting_module.format_quality(mock_quality_data, "html")
      expect(result).to.exist()
      expect(result).to.be.a("string")
      -- Should contain HTML structure
      expect(result:find("<!DOCTYPE html>") ~= nil).to.be_truthy()
      expect(result:find("Lust%-Next Test Quality Report") ~= nil).to.be_truthy()
    end)
    
    it("should default to summary format if format is invalid", function()
      local result = reporting_module.format_quality(mock_quality_data, "invalid_format")
      expect(result).to.exist()
      expect(result.level).to.equal(3)
    end)
  end)
  
  describe("File Operations", function()
    local fs = require("lib.tools.filesystem")
    local temp_file = "/tmp/lust-next-test-report.txt"
    local test_content = "Test content for file operations"
    
    after_each(function()
      -- Clean up test file
      fs.delete_file(temp_file)
    end)
    
    it("should write content to a file", function()
      local success, err = reporting_module.write_file(temp_file, test_content)
      expect(success).to.be_truthy()
      
      -- Verify content was written
      local content = fs.read_file(temp_file)
      expect(content).to.exist()
      expect(content).to.equal(test_content)
    end)
    
    it("should create directories if needed", function()
      local nested_dir = "/tmp/lust-next-test-nested/subdir"
      local nested_file = nested_dir .. "/test-file.txt"
      local test_content = "Test content for nested directory test"
      
      -- Clean up first in case the directory already exists
      fs.delete_file(nested_file)
      fs.delete_directory(nested_dir, true)
      fs.delete_directory("/tmp/lust-next-test-nested", true)
      
      -- Try to write to nested file (should create directories)
      local success, err = reporting_module.write_file(nested_file, test_content)
      expect(success).to.be_truthy()
      
      -- Verify content was written
      local content = fs.read_file(nested_file)
      expect(content).to.exist()
      expect(content).to.equal(test_content)
      
      -- Clean up
      fs.delete_file(nested_file)
      fs.delete_directory(nested_dir, true)
      fs.delete_directory("/tmp/lust-next-test-nested", true)
    end)
  end)
  
  describe("Report Saving", function()
    local fs = require("lib.tools.filesystem")
    local temp_dir = "/tmp/lust-next-test-reports"
    local formats = {"html", "json", "lcov"}
    
    after_each(function()
      -- Clean up test files
      for _, format in ipairs(formats) do
        fs.delete_file(temp_dir .. "/coverage-report." .. format)
        fs.delete_file(temp_dir .. "/quality-report." .. format)
      end
      -- Remove the directory
      fs.delete_directory(temp_dir, true)
    end)
    
    it("should save coverage reports to file", function()
      for _, format in ipairs(formats) do
        local file_path = temp_dir .. "/coverage-report." .. format
        local success, err = reporting_module.save_coverage_report(
          file_path,
          mock_coverage_data,
          format
        )
        
        expect(success).to.be_truthy()
        
        -- Verify file exists
        expect(fs.file_exists(file_path)).to.be_truthy()
      end
    end)
    
    it("should save quality reports to file", function()
      for _, format in ipairs({"html", "json"}) do
        local file_path = temp_dir .. "/quality-report." .. format
        local success, err = reporting_module.save_quality_report(
          file_path,
          mock_quality_data,
          format
        )
        
        expect(success).to.be_truthy()
        
        -- Verify file exists
        expect(fs.file_exists(file_path)).to.be_truthy()
      end
    end)
    
    it("should auto-save multiple report formats", function()
      local results = reporting_module.auto_save_reports(
        mock_coverage_data,
        mock_quality_data,
        temp_dir
      )
      
      -- Check we have the expected results
      expect(results.html).to.exist()
      expect(results.lcov).to.exist()
      expect(results.json).to.exist()
      expect(results.quality_html).to.exist()
      expect(results.quality_json).to.exist()
      
      -- Verify success values
      expect(results.html.success).to.be_truthy()
      expect(results.lcov.success).to.be_truthy()
      expect(results.json.success).to.be_truthy()
      expect(results.quality_html.success).to.be_truthy()
      expect(results.quality_json.success).to.be_truthy()
      
      -- Verify files exist
      for _, result in pairs(results) do
        if result.success then
          expect(fs.file_exists(result.path)).to.be_truthy()
        end
      end
    end)
  end)
  
  describe("Integration with Coverage Module", function()
    it("should work with coverage module", function()
      -- Skip if coverage module not available
      if not coverage_module then
        if log then
          log.warn("Skipping coverage module integration test", {
            component = "CoverageIntegration",
            reason = "Coverage module not available",
            test = "should work with coverage module"
          })
        else
          print("Coverage module not available, skipping test")
        end
        return
      end
      
      if not coverage_module.get_report_data then
        if log then
          log.warn("Skipping coverage module integration test", {
            component = "CoverageIntegration",
            reason = "get_report_data method not available",
            test = "should work with coverage module"
          })
        else
          print("Coverage module doesn't have get_report_data, skipping test")
        end
        return
      end
      
      if log then
        log.debug("Initializing coverage module for integration test", {
          component = "CoverageIntegration",
          options = {enabled = true}
        })
      end
      
      -- Initialize coverage module
      coverage_module.init({enabled = true})
      coverage_module.reset()
      
      -- Get data and format it
      local data = coverage_module.get_report_data()
      local result = reporting_module.format_coverage(data, "summary")
      
      if log then
        log.debug("Coverage data formatted", {
          component = "CoverageIntegration",
          format = "summary",
          has_data = data ~= nil,
          has_result = result ~= nil
        })
      end
      
      -- Basic validation
      expect(result).to.exist()
      expect(result.overall_pct).to.exist()
    end)
  end)
  
  describe("Integration with Quality Module", function()
    if log then
      log.debug("Testing quality module integration", {
        component = "QualityIntegration"
      })
    end
    
    it("should work with quality module", function()
      -- Skip if quality module not available
      if not quality_module then
        if log then
          log.warn("Skipping quality module integration test", {
            component = "QualityIntegration",
            reason = "Quality module not available",
            test = "should work with quality module"
          })
        else
          print("Quality module not available, skipping test")
        end
        return
      end
      
      if not quality_module.get_report_data then
        if log then
          log.warn("Skipping quality module integration test", {
            component = "QualityIntegration",
            reason = "get_report_data method not available",
            test = "should work with quality module"
          })
        else
          print("Quality module doesn't have get_report_data, skipping test")
        end
        return
      end
      
      if log then
        log.debug("Initializing quality module for integration test", {
          component = "QualityIntegration",
          options = {enabled = true}
        })
      end
      
      -- Initialize quality module
      quality_module.init({enabled = true})
      quality_module.reset()
      
      -- Get data and format it
      local data = quality_module.get_report_data()
      local result = reporting_module.format_quality(data, "summary")
      
      if log then
        log.debug("Quality data formatted", {
          component = "QualityIntegration",
          format = "summary",
          has_data = data ~= nil,
          has_result = result ~= nil
        })
      end
      
      -- Basic validation
      expect(result).to.exist()
      expect(result.level).to.exist()
    end)
  end)
  
  describe("Test Results Reporting", function()
    -- Mock test results data for testing
    local mock_test_results
    
    before_each(function()
      -- Create mock test results for JUnit XML generation
      mock_test_results = {
        name = "TestSuite",
        timestamp = "2023-01-01T00:00:00",
        tests = 5,
        failures = 1,
        errors = 1,
        skipped = 1,
        time = 0.245,
        properties = {
          lua_version = "Lua 5.3",
          platform = "Linux",
          framework = "lust-next"
        },
        test_cases = {
          {
            name = "should add numbers correctly",
            classname = "MathTests",
            time = 0.05,
            status = "pass"
          },
          {
            name = "should handle negative numbers",
            classname = "MathTests",
            time = 0.05,
            status = "fail",
            failure = {
              message = "Expected values to be equal",
              type = "AssertionError",
              details = "Expected -2, got 2"
            }
          },
          {
            name = "should throw on invalid input",
            classname = "MathTests",
            time = 0.05,
            status = "error",
            error = {
              message = "Runtime error",
              type = "Error",
              details = "attempt to perform arithmetic on a nil value"
            },
            stdout = "Processing input...",
            stderr = "Error: nil value"
          },
          {
            name = "should format results correctly",
            classname = "StringTests",
            time = 0.05,
            status = "pass"
          },
          {
            name = "should handle advanced calculations",
            classname = "MathTests",
            time = 0.04,
            status = "skipped",
            skip_message = "Not implemented yet"
          }
        }
      }
    end)
    
    it("should export test results formatting functions", function()
      expect(reporting_module.format_results).to.exist()
      expect(reporting_module.save_results_report).to.exist()
    end)
    
    it("should format test results as JUnit XML", function()
      local result = reporting_module.format_results(mock_test_results, "junit")
      expect(result).to.exist()
      expect(result).to.be.a("string")
      
      -- Should contain XML structure
      expect(result:find('<[?]xml') ~= nil).to.be_truthy("Missing XML declaration")
      expect(result:find('<testsuite') ~= nil).to.be_truthy("Missing testsuite tag")
      
      -- Basic structure verification
      expect(#result > 100).to.be_truthy("XML output seems too short")
      
      -- Simpler attribute tests
      expect(result:find('tests=') ~= nil).to.be_truthy("Missing tests attribute")
      expect(result:find('failures=') ~= nil).to.be_truthy("Missing failures attribute")
      expect(result:find('errors=') ~= nil).to.be_truthy("Missing errors attribute")
      expect(result:find('skipped=') ~= nil).to.be_truthy("Missing skipped attribute")
      
      -- Should have testcases with different statuses
      expect(result:find('<testcase') ~= nil).to.be_truthy("Missing testcase tag")
    end)
    
    it("should save test results report to file", function()
      local fs = require("lib.tools.filesystem")
      local temp_file = "/tmp/lust-next-test-junit.xml"
      
      -- Clean up first in case the file exists
      fs.delete_file(temp_file)
      
      -- Save report
      local success, err = reporting_module.save_results_report(
        temp_file,
        mock_test_results,
        "junit"
      )
      
      expect(success).to.be_truthy()
      
      -- Verify file exists
      expect(fs.file_exists(temp_file)).to.be_truthy()
      
      -- Read content
      local content = fs.read_file(temp_file)
      expect(content).to.exist()
      
      -- Verify content
      expect(#content > 100).to.be_truthy("XML file content too short")
      expect(content:find('xml') ~= nil).to.be_truthy("Missing XML content")
      expect(content:find('test') ~= nil).to.be_truthy("Missing test content")
      
      -- Clean up
      fs.delete_file(temp_file)
    end)
    
    it("should include JUnit XML in auto-save reports", function()
      local fs = require("lib.tools.filesystem")
      local temp_dir = "/tmp/lust-next-test-reports-junit"
      
      -- Clean up first
      fs.delete_directory(temp_dir, true)
      
      -- Auto-save reports with test results
      local results = reporting_module.auto_save_reports(
        nil,  -- No coverage data
        nil,  -- No quality data
        mock_test_results,
        temp_dir
      )
      
      -- Check we have the JUnit result
      expect(results.junit).to.exist()
      expect(results.junit.success).to.be_truthy()
      
      -- Verify file exists
      expect(fs.file_exists(results.junit.path)).to.be_truthy()
      
      -- Clean up
      fs.delete_directory(temp_dir, true)
    end)
  end)
  
  if log then
    log.info("Reporting module tests completed", {
      status = "success",
      test_group = "reporting"
    })
  end
end)

-- Tests are run by run_all_tests.lua or scripts/runner.lua
-- No need to call lust() explicitly here