-- Tests for JUnit XML formatter
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import test_helper for error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Import reporting module directly for testing
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")

describe("JUnit Formatter", function()
  -- Create test data that will be used for all tests
  local results_data = {
    name = "Test Suite",
    timestamp = "2023-01-01T12:00:00",
    hostname = "test-machine",
    tests = 5,
    failures = 1,
    errors = 1,
    skipped = 1,
    time = 0.123,
    test_cases = {
      {
        name = "passing test",
        classname = "TestFile",
        time = 0.01,
        status = "pass"
      },
      {
        name = "failing test",
        classname = "TestFile",
        time = 0.02,
        status = "fail",
        failure = {
          message = "Expected values to match",
          type = "AssertionError",
          details = "Expected: 1\nGot: 2"
        }
      },
      {
        name = "error test",
        classname = "TestFile",
        time = 0.01,
        status = "error",
        error = {
          message = "Runtime error occurred",
          type = "Error",
          details = "Error: Something went wrong"
        }
      },
      {
        name = "skipped test",
        classname = "TestFile",
        time = 0.00,
        status = "skipped",
        skip_message = "Not implemented yet"
      },
      {
        name = "another passing test",
        classname = "TestFile",
        time = 0.01,
        status = "pass"
      }
    }
  }
  
  -- Test directory for file tests
  local test_dir = "./test-tmp-junit-formatter"
  
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
  
  it("generates valid JUnit XML", function()
    local xml_output = reporting.format_results(results_data, "junit")
    
    -- Check basic XML structure
    expect(xml_output).to.exist()
    expect(type(xml_output)).to.equal("string")
    
    -- Basic XML validation
    expect(xml_output).to.match("<%?xml")
    expect(xml_output).to.match("<testsuites")
    expect(xml_output).to.match("</testsuites>")
    
    -- Verify key elements
    expect(xml_output).to.match("<testsuite")
    expect(xml_output).to.match("<testcase")
    expect(xml_output).to.match("<failure")
    expect(xml_output).to.match("<error")
    expect(xml_output).to.match("<skipped")
    
    -- Verify test attributes
    expect(xml_output).to.match('name="Test Suite"')
    expect(xml_output).to.match('tests="5"')
    expect(xml_output).to.match('failures="1"')
    expect(xml_output).to.match('errors="1"')
    expect(xml_output).to.match('skipped="1"')
    
    -- Verify test case attributes
    expect(xml_output).to.match('name="passing test"')
    expect(xml_output).to.match('classname="TestFile"')
    
    -- Verify failure message
    expect(xml_output).to.match("Expected values to match")
    expect(xml_output).to.match("AssertionError")
    
    -- Verify error message
    expect(xml_output).to.match("Runtime error occurred")
    expect(xml_output).to.match("Error:")
    
    -- Verify skipped message
    expect(xml_output).to.match("Not implemented yet")
  end)
  
  it("handles empty test results gracefully", function()
    local empty_data = {
      name = "Empty Suite",
      tests = 0,
      failures = 0,
      errors = 0,
      skipped = 0,
      test_cases = {}
    }
    
    local xml_output = reporting.format_results(empty_data, "junit")
    
    -- Should still return valid XML
    expect(xml_output).to.exist()
    expect(type(xml_output)).to.equal("string")
    
    -- Should contain minimal XML structure
    expect(xml_output).to.match("<%?xml")
    expect(xml_output).to.match("<testsuites")
    expect(xml_output).to.match("</testsuites>")
    expect(xml_output).to.match("<testsuite")
    expect(xml_output).to.match("</testsuite>")
    
    -- Should have zero counts
    expect(xml_output).to.match('tests="0"')
    expect(xml_output).to.match('failures="0"')
    expect(xml_output).to.match('errors="0"')
    expect(xml_output).to.match('skipped="0"')
  end)
  
  it("handles nil test results with fallback", { expect_error = true }, function()
    -- Use error_capture to handle expected errors
    local result, err = test_helper.with_error_capture(function()
      return reporting.format_results(nil, "junit")
    end)()
    
    -- Test should pass whether the formatter returns a fallback or returns error
    if result then
      -- If we got a result, it should be a string with XML structure
      expect(type(result)).to.equal("string")
      expect(result).to.match("<%?xml")
      expect(result).to.match("<testsuites")
    else
      -- If we got an error, it should be a valid error object
      expect(err).to.exist()
      expect(err.message).to.exist()
    end
  end)
  
  it("handles malformed test results gracefully", { expect_error = true }, function()
    -- Test with incomplete test results data
    local malformed_data = {
      -- Missing most fields
      name = "Malformed Suite",
      test_cases = {
        {
          -- Missing required fields
          name = "malformed test"
        }
      }
    }
    
    -- Use error_capture to handle expected errors
    local result, err = test_helper.with_error_capture(function()
      return reporting.format_results(malformed_data, "junit")
    end)()
    
    -- Test should pass whether the formatter returns a fallback or returns error
    if result then
      -- If we got a result, it should be a string with XML structure
      expect(type(result)).to.equal("string")
      expect(result).to.match("<%?xml")
      expect(result).to.match("<testsuites")
      -- Should have our malformed suite name
      expect(result).to.match("Malformed Suite")
    else
      -- If we got an error, it should be a valid error object
      expect(err).to.exist()
      expect(err.message).to.exist()
    end
  end)
  
  it("handles file operation errors properly", { expect_error = true }, function()
    -- Generate XML and save it to a file
    local file_path = test_dir .. "/results.xml"
    local success = reporting.save_results_report(file_path, results_data, "junit")
    
    -- Should succeed
    expect(success).to.equal(true)
    expect(fs.file_exists(file_path)).to.equal(true)
    
    -- Try to save to an invalid path
    local invalid_path = "/tmp/firmo-test*?<>|/results.xml"
    
    -- Use error_capture to handle expected errors
    local success_invalid_save, save_err = test_helper.with_error_capture(function()
      local result, err = reporting.save_results_report(invalid_path, results_data, "junit")
      if err then
        return false, err
      else
        return result
      end
    end)()
    
    -- Try to save with nil data
    test_helper.with_error_capture(function()
      return reporting.save_results_report(file_path, nil, "junit")
    end)()
    
    -- The test passes implicitly if we reach this point without crashing
  end)
  
  it("respects formatter configuration options", function()
    -- Configure formatter 
    local config = require("lib.core.central_config")
    config.set("reporting.formatters.junit", {
      schema_version = "2.0",
      include_timestamp = true,
      include_hostname = true,
      include_system_out = true,
      format_output = true -- Enable pretty formatting
    })
    
    local xml_output = reporting.format_results(results_data, "junit")
    
    -- Verify timestamp and hostname are included
    expect(xml_output).to.match('timestamp="2023%-01%-01T12:00:00"')
    expect(xml_output).to.match('hostname="test%-machine"')
    
    -- With format_output enabled, we should see indentation
    expect(xml_output).to.match("\n%s+<.+>")
    
    -- Reset configuration to avoid affecting other tests
    config.delete("reporting.formatters.junit")
  end)
end)