-- reporting_test.lua
-- Tests for the reporting module

-- Load with global exposure
local lust_next = require('../lust-next')
lust_next.expose_globals()

-- Load modules for testing
local reporting_module = package.loaded["src.reporting"] or require("src.reporting")
local coverage_module = package.loaded["src.coverage"] or require("src.coverage")
local quality_module = package.loaded["src.quality"] or require("src.quality")

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
      assert.is_not_nil(reporting_module.format_coverage)
      assert.is_not_nil(reporting_module.format_quality)
      assert.is_not_nil(reporting_module.save_coverage_report)
      assert.is_not_nil(reporting_module.save_quality_report)
      assert.is_not_nil(reporting_module.write_file)
      assert.is_not_nil(reporting_module.auto_save_reports)
    end)
    
    it("should define standard data structures", function()
      assert.is_not_nil(reporting_module.CoverageData)
      assert.is_not_nil(reporting_module.QualityData)
    end)
  end)
  
  describe("Coverage Formatting", function()
    it("should format coverage data as summary", function()
      local result = reporting_module.format_coverage(mock_coverage_data, "summary")
      assert.is_not_nil(result)
      assert.equal(80, result.overall_pct)
      assert.equal(2, result.total_files)
      assert.equal(150, result.total_lines)
      assert.equal(120, result.covered_lines)
    end)
    
    it("should format coverage data as JSON", function()
      local result = reporting_module.format_coverage(mock_coverage_data, "json")
      assert.is_not_nil(result)
      assert.type_of(result, "string")
      -- Should contain some expected strings
      assert.is_true(result:find('"overall_pct":80') ~= nil or 
                     result:find('"overall_pct": 80') ~= nil)
    end)
    
    it("should format coverage data as HTML", function()
      local result = reporting_module.format_coverage(mock_coverage_data, "html")
      assert.is_not_nil(result)
      assert.type_of(result, "string")
      -- Should contain HTML structure
      assert.is_true(result:find("<!DOCTYPE html>") ~= nil)
      assert.is_true(result:find("Lust%-Next Coverage Report") ~= nil)
    end)
    
    it("should format coverage data as LCOV", function()
      local result = reporting_module.format_coverage(mock_coverage_data, "lcov")
      assert.is_not_nil(result)
      assert.type_of(result, "string")
      -- Should contain LCOV format elements
      assert.is_true(result:find("SF:") ~= nil)
      assert.is_true(result:find("end_of_record") ~= nil)
    end)
    
    it("should default to summary format if format is invalid", function()
      local result = reporting_module.format_coverage(mock_coverage_data, "invalid_format")
      assert.is_not_nil(result)
      assert.equal(80, result.overall_pct)
    end)
  end)
  
  describe("Quality Formatting", function()
    it("should format quality data as summary", function()
      local result = reporting_module.format_quality(mock_quality_data, "summary")
      assert.is_not_nil(result)
      assert.equal(3, result.level)
      assert.equal("comprehensive", result.level_name)
      assert.equal(50, result.quality_pct)
      assert.equal(2, result.tests_analyzed)
    end)
    
    it("should format quality data as JSON", function()
      local result = reporting_module.format_quality(mock_quality_data, "json")
      assert.is_not_nil(result)
      assert.type_of(result, "string")
      -- Should contain some expected strings
      assert.is_true(result:find('"level":3') ~= nil or 
                     result:find('"level": 3') ~= nil)
    end)
    
    it("should format quality data as HTML", function()
      local result = reporting_module.format_quality(mock_quality_data, "html")
      assert.is_not_nil(result)
      assert.type_of(result, "string")
      -- Should contain HTML structure
      assert.is_true(result:find("<!DOCTYPE html>") ~= nil)
      assert.is_true(result:find("Lust%-Next Test Quality Report") ~= nil)
    end)
    
    it("should default to summary format if format is invalid", function()
      local result = reporting_module.format_quality(mock_quality_data, "invalid_format")
      assert.is_not_nil(result)
      assert.equal(3, result.level)
    end)
  end)
  
  describe("File Operations", function()
    local temp_file = "/tmp/lust-next-test-report.txt"
    local test_content = "Test content for file operations"
    
    after_each(function()
      -- Clean up test file
      os.remove(temp_file)
    end)
    
    it("should write content to a file", function()
      local success, err = reporting_module.write_file(temp_file, test_content)
      assert.is_true(success)
      
      -- Verify content was written
      local file = io.open(temp_file, "r")
      assert.is_not_nil(file)
      local content = file:read("*all")
      file:close()
      
      assert.equal(test_content, content)
    end)
    
    it("should create directories if needed", function()
      local nested_dir = "/tmp/lust-next-test-nested/subdir"
      local nested_file = nested_dir .. "/test-file.txt"
      local test_content = "Test content for nested directory test"
      
      -- Clean up first in case the directory already exists
      os.remove(nested_file)
      os.execute("rmdir " .. nested_dir .. " 2>/dev/null")
      os.execute("rmdir " .. "/tmp/lust-next-test-nested" .. " 2>/dev/null")
      
      -- Try to write to nested file (should create directories)
      local success, err = reporting_module.write_file(nested_file, test_content)
      assert.is_true(success)
      
      -- Verify content was written
      local file = io.open(nested_file, "r")
      assert.is_not_nil(file)
      local content = file:read("*all")
      file:close()
      
      assert.equal(test_content, content)
      
      -- Clean up
      os.remove(nested_file)
      os.execute("rmdir " .. nested_dir .. " 2>/dev/null")
      os.execute("rmdir " .. "/tmp/lust-next-test-nested" .. " 2>/dev/null")
    end)
  end)
  
  describe("Report Saving", function()
    local temp_dir = "/tmp/lust-next-test-reports"
    local formats = {"html", "json", "lcov"}
    
    after_each(function()
      -- Clean up test files
      for _, format in ipairs(formats) do
        os.remove(temp_dir .. "/coverage-report." .. format)
        os.remove(temp_dir .. "/quality-report." .. format)
      end
      -- Try to remove directory
      os.execute("rmdir " .. temp_dir)
    end)
    
    it("should save coverage reports to file", function()
      for _, format in ipairs(formats) do
        local file_path = temp_dir .. "/coverage-report." .. format
        local success, err = reporting_module.save_coverage_report(
          file_path,
          mock_coverage_data,
          format
        )
        
        assert.is_true(success)
        
        -- Verify file exists
        local file = io.open(file_path, "r")
        assert.is_not_nil(file)
        file:close()
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
        
        assert.is_true(success)
        
        -- Verify file exists
        local file = io.open(file_path, "r")
        assert.is_not_nil(file)
        file:close()
      end
    end)
    
    it("should auto-save multiple report formats", function()
      local results = reporting_module.auto_save_reports(
        mock_coverage_data,
        mock_quality_data,
        temp_dir
      )
      
      -- Check we have the expected results
      assert.is_not_nil(results.html)
      assert.is_not_nil(results.lcov)
      assert.is_not_nil(results.json)
      assert.is_not_nil(results.quality_html)
      assert.is_not_nil(results.quality_json)
      
      -- Verify success values
      assert.is_true(results.html.success)
      assert.is_true(results.lcov.success)
      assert.is_true(results.json.success)
      assert.is_true(results.quality_html.success)
      assert.is_true(results.quality_json.success)
      
      -- Verify files exist
      for _, result in pairs(results) do
        if result.success then
          local file = io.open(result.path, "r")
          assert.is_not_nil(file)
          file:close()
        end
      end
    end)
  end)
  
  describe("Integration with Coverage Module", function()
    it("should work with coverage module", function()
      -- Skip if coverage module not available
      if not coverage_module then
        print("Coverage module not available, skipping test")
        return
      end
      
      if not coverage_module.get_report_data then
        print("Coverage module doesn't have get_report_data, skipping test")
        return
      end
      
      -- Initialize coverage module
      coverage_module.init({enabled = true})
      coverage_module.reset()
      
      -- Get data and format it
      local data = coverage_module.get_report_data()
      local result = reporting_module.format_coverage(data, "summary")
      
      -- Basic validation
      assert.is_not_nil(result)
      assert.is_not_nil(result.overall_pct)
    end)
  end)
  
  describe("Integration with Quality Module", function()
    it("should work with quality module", function()
      -- Skip if quality module not available
      if not quality_module then
        print("Quality module not available, skipping test")
        return
      end
      
      if not quality_module.get_report_data then
        print("Quality module doesn't have get_report_data, skipping test")
        return
      end
      
      -- Initialize quality module
      quality_module.init({enabled = true})
      quality_module.reset()
      
      -- Get data and format it
      local data = quality_module.get_report_data()
      local result = reporting_module.format_quality(data, "summary")
      
      -- Basic validation
      assert.is_not_nil(result)
      assert.is_not_nil(result.level)
    end)
  end)
end)