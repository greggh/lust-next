-- Schema validation test suite
local firmo = require("firmo")
local expect = firmo.expect
local it = firmo.it
---@diagnostic disable-next-line: unused-local
local before = firmo.before
---@diagnostic disable-next-line: unused-local
local after = firmo.after

-- Import modules
local reporting = require("lib.reporting")
---@diagnostic disable-next-line: unused-local
local validation

-- Try to load validation module directly
local ok, module = pcall(require, "lib.reporting.validation")
if ok then
  ---@diagnostic disable-next-line: unused-local
  validation = module
end

-- Try to load schema module
local schema_ok, schema = pcall(require, "lib.reporting.schema")
if not schema_ok then
  schema = nil
end

-- Test helper: Create mock coverage data
local function create_mock_coverage_data(valid)
  local data = {
    summary = {
      total_files = 2,
      covered_files = 2,
      total_lines = 150,
      covered_lines = 120,
      line_coverage_percent = 80.0,
      function_coverage_percent = 80.0,
      overall_percent = 80.0,
    },
    files = {
      ["/path/to/example.lua"] = {
        total_lines = 100,
        covered_lines = 80,
        line_coverage_percent = 80.0,
        function_coverage_percent = 80.0,
      },
      ["/path/to/another.lua"] = {
        total_lines = 50,
        covered_lines = 40,
        line_coverage_percent = 80.0,
        function_coverage_percent = 80.0,
      },
    },
  }

  -- If we want invalid data, introduce schema violations
  if not valid then
    -- Remove required property
    data.summary.total_lines = nil
  end

  return data
end

-- Test helper: Create mock test results data
local function create_mock_test_results_data(valid)
  local data = {
    name = "Test Suite",
    timestamp = "2023-01-01T00:00:00",
    tests = 10,
    failures = 2,
    errors = 1,
    skipped = 1,
    time = 0.5,
    test_cases = {
      {
        name = "test_one",
        classname = "TestClass",
        time = 0.1,
        status = "pass",
      },
      {
        name = "test_two",
        classname = "TestClass",
        time = 0.2,
        status = "fail",
        failure = {
          message = "Assertion failed",
          type = "AssertionError",
          details = "Expected 5, got 4",
        },
      },
    },
  }

  -- If we want invalid data, introduce schema violations
  if not valid then
    -- Set invalid enum value
    data.test_cases[1].status = "invalid_status"
  end

  return data
end

-- Test helper: Create mock formatted outputs
local function create_mock_formatted_output(format, valid)
  if format == "html" then
    if valid then
      return "<!DOCTYPE html><html><head><title>Coverage Report</title></head><body></body></html>"
    else
      return "<wrong>Invalid HTML</wrong>"
    end
  elseif format == "json" then
    if valid then
      return {
        files = {
          ["/path/to/file.lua"] = {
            total_lines = 100,
            covered_lines = 80,
            line_coverage_percent = 80.0,
          },
        },
        summary = {
          total_files = 1,
          total_lines = 100,
          covered_lines = 80,
          line_coverage_percent = 80.0,
        },
      }
    else
      return {
        wrong_key = "Invalid JSON structure",
      }
    end
  elseif format == "lcov" then
    if valid then
      return "TN:lcov\nSF:/path/to/file.lua\nDA:1,1\nend_of_record"
    else
      return "INVALID:lcov\nInvalid LCOV format"
    end
  end

  return "Unknown format"
end

-- Main test suite
describe("Schema Validation", function()
  -- Skip tests if schema module is not available
  if not schema then
    it("SKIPPED: Schema module not available", function()
      expect(true).to.be_truthy() -- Dummy test to avoid empty suite
    end)
    return
  end

  describe("Schema definitions", function()
    it("should provide schema for coverage data", function()
      expect(schema.COVERAGE_SCHEMA).to.be.a("table")
      expect(schema.COVERAGE_SCHEMA.type).to.equal("table")
      expect(schema.COVERAGE_SCHEMA.required).to.be.a("table")
    end)

    it("should provide schema for test results data", function()
      expect(schema.TEST_RESULTS_SCHEMA).to.be.a("table")
      expect(schema.TEST_RESULTS_SCHEMA.type).to.equal("table")
      expect(schema.TEST_RESULTS_SCHEMA.required).to.be.a("table")
    end)

    it("should provide schemas for various report formats", function()
      -- String-based schemas
      expect(schema.HTML_COVERAGE_SCHEMA).to.be.a("table")
      expect(schema.HTML_COVERAGE_SCHEMA.type).to.equal("string")

      expect(schema.LCOV_COVERAGE_SCHEMA).to.be.a("table")
      expect(schema.LCOV_COVERAGE_SCHEMA.type).to.equal("string")

      expect(schema.COBERTURA_COVERAGE_SCHEMA).to.be.a("table")
      expect(schema.COBERTURA_COVERAGE_SCHEMA.type).to.equal("string")

      expect(schema.TAP_RESULTS_SCHEMA).to.be.a("table")
      expect(schema.TAP_RESULTS_SCHEMA.type).to.equal("string")

      expect(schema.JUNIT_RESULTS_SCHEMA).to.be.a("table")
      expect(schema.JUNIT_RESULTS_SCHEMA.type).to.equal("string")
    end)
  end)

  describe("Schema validation", function()
    it("should validate valid coverage data", function()
      local valid_data = create_mock_coverage_data(true)
      local is_valid, err = schema.validate(valid_data, "COVERAGE_SCHEMA")

      expect(is_valid).to.be_truthy()
      expect(err).to_not.exist()
    end)

    it("should detect invalid coverage data", function()
      local invalid_data = create_mock_coverage_data(false)
      local is_valid, err = schema.validate(invalid_data, "COVERAGE_SCHEMA")

      expect(is_valid).to_not.be_truthy()
      expect(err).to.exist()
      -- Should contain details about the missing required property
      expect(err).to.match("total_lines")
    end)

    it("should validate valid test results data", function()
      local valid_data = create_mock_test_results_data(true)
      local is_valid, err = schema.validate(valid_data, "TEST_RESULTS_SCHEMA")

      expect(is_valid).to.be_truthy()
      expect(err).to_not.exist()
    end)

    it("should detect invalid test results data", function()
      local invalid_data = create_mock_test_results_data(false)
      local is_valid, err = schema.validate(invalid_data, "TEST_RESULTS_SCHEMA")

      expect(is_valid).to_not.be_truthy()
      expect(err).to.exist()
      -- Should contain details about the invalid enum value
      expect(err).to.match("allowed values")
    end)
  end)

  describe("Format validation", function()
    it("should validate valid HTML output", function()
      local valid_html = create_mock_formatted_output("html", true)
      local is_valid, err = schema.validate_format(valid_html, "html")

      expect(is_valid).to.be_truthy()
      expect(err).to_not.exist()
    end)

    it("should detect invalid HTML output", function()
      local invalid_html = create_mock_formatted_output("html", false)
      local is_valid, err = schema.validate_format(invalid_html, "html")

      expect(is_valid).to_not.be_truthy()
      expect(err).to.exist()
    end)

    it("should validate valid JSON output", function()
      local valid_json = create_mock_formatted_output("json", true)
      local is_valid, err = schema.validate_format(valid_json, "json")

      expect(is_valid).to.be_truthy()
      expect(err).to_not.exist()
    end)

    it("should detect invalid JSON output", function()
      local invalid_json = create_mock_formatted_output("json", false)
      local is_valid, err = schema.validate_format(invalid_json, "json")

      expect(is_valid).to_not.be_truthy()
      expect(err).to.exist()
    end)

    it("should validate valid LCOV output", function()
      local valid_lcov = create_mock_formatted_output("lcov", true)
      local is_valid, err = schema.validate_format(valid_lcov, "lcov")

      expect(is_valid).to.be_truthy()
      expect(err).to_not.exist()
    end)

    it("should detect invalid LCOV output", function()
      local invalid_lcov = create_mock_formatted_output("lcov", false)
      local is_valid, err = schema.validate_format(invalid_lcov, "lcov")

      expect(is_valid).to_not.be_truthy()
      expect(err).to.exist()
    end)
  end)

  describe("Auto-detection", function()
    it("should detect schema for coverage data", function()
      local data = create_mock_coverage_data(true)
      local detected_schema = schema.detect_schema(data)

      expect(detected_schema).to.equal("COVERAGE_SCHEMA")
    end)

    it("should detect schema for test results data", function()
      local data = create_mock_test_results_data(true)
      local detected_schema = schema.detect_schema(data)

      expect(detected_schema).to.equal("TEST_RESULTS_SCHEMA")
    end)

    it("should detect schema for HTML output", function()
      local html = create_mock_formatted_output("html", true)
      local detected_schema = schema.detect_schema(html)

      expect(detected_schema).to.equal("HTML_COVERAGE_SCHEMA")
    end)

    it("should detect schema for LCOV output", function()
      local lcov = create_mock_formatted_output("lcov", true)
      local detected_schema = schema.detect_schema(lcov)

      expect(detected_schema).to.equal("LCOV_COVERAGE_SCHEMA")
    end)
  end)

  describe("Integration with reporting module", function()
    it("should provide format validation function", function()
      expect(reporting.validate_report_format).to.be.a("function")
    end)

    it("should validate formats through reporting module", function()
      local valid_html = create_mock_formatted_output("html", true)
      local is_valid, err = reporting.validate_report_format(valid_html, "html")

      expect(is_valid).to.be_truthy()
      expect(err).to_not.exist()
    end)

    it("should detect invalid formats through reporting module", function()
      local invalid_html = create_mock_formatted_output("html", false)
      local is_valid, err = reporting.validate_report_format(invalid_html, "html")

      expect(is_valid).to_not.be_truthy()
      expect(err).to.exist()
    end)

    it("should include format validation in comprehensive report validation", function()
      local coverage_data = create_mock_coverage_data(true)
      local formatted_output = create_mock_formatted_output("html", true)

      local result = reporting.validate_report(coverage_data, formatted_output, "html")

      expect(result).to.be.a("table")
      expect(result.format_validation).to.be.a("table")
      expect(result.format_validation.is_valid).to.be_truthy()
    end)
  end)
end)

-- Return test result
return true
