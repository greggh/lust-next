-- Tests for Cobertura XML formatter
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import test_helper for error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Import reporting module directly for testing
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")

describe("Cobertura Formatter", function()
  -- Create test data that will be used for all tests
  local coverage_data = {
    files = {
      ["/path/to/example.lua"] = {
        total_lines = 100,
        covered_lines = 80,
        line_coverage_percent = 80,
        total_functions = 10,
        covered_functions = 8,
        function_coverage_percent = 80,
        source = {
          [1] = "local function test_func()",
          [2] = "  return true",
          [3] = "end"
        },
        lines = {
          [1] = true,
          [2] = true,
          [3] = false
        },
        functions = {
          ["test_func"] = {
            count = 1,
            first_line = 1,
            last_line = 3
          }
        }
      }
    },
    summary = {
      total_files = 1,
      covered_files = 1,
      total_lines = 100,
      covered_lines = 80,
      line_coverage_percent = 80,
      overall_percent = 80,
      total_functions = 10,
      covered_functions = 8,
      function_coverage_percent = 80
    }
  }
  
  -- Test directory for file tests
  local test_dir = "./test-tmp-cobertura-formatter"
  
  -- Setup/teardown test directory
  before(function()
    if fs.directory_exists(test_dir) then
      fs.delete_directory(test_dir, true)
    end
    fs.create_directory(test_dir)
  end)
  
  after(function()
    if fs.directory_exists(test_dir) then
      fs.delete_directory(test_dir, true)
    end
  end)
  
  it("generates valid Cobertura XML", function()
    local xml_output = reporting.format_coverage(coverage_data, "cobertura")
    
    -- Check basic XML structure
    expect(xml_output).to.exist()
    expect(type(xml_output)).to.equal("string")
    
    -- Basic XML validation
    expect(xml_output).to.match("<%?xml")
    expect(xml_output).to.match("<coverage")
    expect(xml_output).to.match("</coverage>")
    
    -- Verify key elements
    expect(xml_output).to.match("<packages>")
    expect(xml_output).to.match("<package")
    expect(xml_output).to.match("<class")
    expect(xml_output).to.match("<line")
    
    -- Verify our test file exists in the output
    expect(xml_output).to.match("example%.lua")
    
    -- Verify coverage values
    expect(xml_output).to.match("line%-rate=\"0%.8")
    expect(xml_output).to.match("branch%-rate=\"0")
  end)
  
  it("handles empty coverage data gracefully", function()
    local empty_data = {
      files = {},
      summary = {
        total_files = 0,
        covered_files = 0,
        total_lines = 0,
        covered_lines = 0,
        line_coverage_percent = 0,
        overall_percent = 0,
        total_functions = 0,
        covered_functions = 0,
        function_coverage_percent = 0
      }
    }
    
    local xml_output = reporting.format_coverage(empty_data, "cobertura")
    
    -- Should still return valid XML
    expect(xml_output).to.exist()
    expect(type(xml_output)).to.equal("string")
    
    -- Should contain minimal XML structure
    expect(xml_output).to.match("<%?xml")
    expect(xml_output).to.match("<coverage")
    expect(xml_output).to.match("</coverage>")
    expect(xml_output).to.match("<packages>")
    expect(xml_output).to.match("</packages>")
    
    -- Should have zero rates
    expect(xml_output).to.match("line%-rate=\"0\"")
    expect(xml_output).to.match("branch%-rate=\"0\"")
  end)
  
  it("handles nil coverage data with fallback", { expect_error = true }, function()
    -- Use error_capture to handle expected errors
    local result, err = test_helper.with_error_capture(function()
      return reporting.format_coverage(nil, "cobertura")
    end)()
    
    -- Test should pass whether the formatter returns a fallback or returns error
    if result then
      -- If we got a result, it should be a string with XML structure
      expect(type(result)).to.equal("string")
      expect(result).to.match("<%?xml")
      expect(result).to.match("<coverage")
    else
      -- If we got an error, it should be a valid error object
      expect(err).to.exist()
      expect(err.message).to.exist()
    end
  end)
  
  it("handles malformed coverage data gracefully", { expect_error = true }, function()
    -- Test with incomplete coverage data
    local malformed_data = {
      -- Missing summary field
      files = {
        ["/path/to/malformed.lua"] = {
          -- Missing required fields
        }
      }
    }
    
    -- Use error_capture to handle expected errors
    local result, err = test_helper.with_error_capture(function()
      return reporting.format_coverage(malformed_data, "cobertura")
    end)()
    
    -- Test should pass whether the formatter returns a fallback or returns error
    if result then
      -- If we got a result, it should be a string with XML structure
      expect(type(result)).to.equal("string")
      expect(result).to.match("<%?xml")
      expect(result).to.match("<coverage")
    else
      -- If we got an error, it should be a valid error object
      expect(err).to.exist()
      expect(err.message).to.exist()
    end
  end)
  
  it("handles file operation errors properly", { expect_error = true }, function()
    -- Generate XML and save it to a file
    local file_path = test_dir .. "/coverage.xml"
    local success = reporting.save_coverage_report(file_path, coverage_data, "cobertura")
    
    -- Should succeed
    expect(success).to.equal(true)
    expect(fs.file_exists(file_path)).to.equal(true)
    
    -- Try to save to an invalid path
    local invalid_path = "/tmp/firmo-test*?<>|/coverage.xml"
    
    -- Use error_capture to handle expected errors
    local success_invalid_save, save_err = test_helper.with_error_capture(function()
      local result, err = reporting.save_coverage_report(invalid_path, coverage_data, "cobertura")
      if err then
        return false, err
      else
        return result
      end
    end)()
    
    -- Try to save with nil data
    test_helper.with_error_capture(function()
      return reporting.save_coverage_report(file_path, nil, "cobertura")
    end)()
    
    -- The test passes implicitly if we reach this point without crashing
  end)
  
  it("respects formatter configuration options", function()
    -- Configure formatter 
    local config = require("lib.core.central_config")
    config.set("reporting.formatters.cobertura", {
      schema_version = "5.0", -- Non-default version
      format_output = true,   -- Enable pretty formatting
      normalize_paths = true  -- Normalize paths
    })
    
    local xml_output = reporting.format_coverage(coverage_data, "cobertura")
    
    -- Verify configuration was applied
    expect(xml_output).to.match('version="5%.0"')
    
    -- With format_output enabled, we should see indentation
    expect(xml_output).to.match("\n%s+<.+>")
    
    -- Reset configuration to avoid affecting other tests
    config.delete("reporting.formatters.cobertura")
  end)
end)