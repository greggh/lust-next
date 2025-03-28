-- Tests for v3 coverage reporting
local reporting = require("lib.coverage.v3.reporting")
local html_formatter = require("lib.coverage.v3.reporting.formatters.html")
local test_helper = require("lib.tools.test_helper")

-- Now load firmo and get test functions
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local fs = require("lib.tools.filesystem")

describe("V3 Coverage Reporting", function()
  local sample_data = {
    files = {
      ["test.lua"] = {
        executed_lines = {[1] = true, [2] = true, [3] = true},
        covered_lines = {[1] = true, [2] = true},
        functions = {
          add = {
            name = "add",
            start_line = 1,
            end_line = 3,
            executed = true,
            covered = true
          }
        },
        source = "function add(a, b)\n  return a + b\nend",
        source_lines = {"function add(a, b)", "  return a + b", "end"},
        source_map = {[1] = 1, [2] = 2, [3] = 3}
      }
    },
    assertions = {
      ["test.lua"] = {
        assertions = {
          {line = 2, async_context = nil},
          {line = 2, async_context = "async_op_1"}
        },
        covered_lines = {[1] = true, [2] = true},
        async_context = {
          async_op_1 = {
            assertions = {{line = 2}}
          }
        }
      }
    }
  }
  
  local sample_config = {
    include = {"test.lua"},
    exclude = {},
    report_dir = "coverage-reports"
  }
  
  describe("Report Creation", function()
    it("creates valid report from coverage data", function()
      local report = reporting.create_report(sample_data, sample_config)
      
      -- Verify report structure
      expect(report.files).to.exist()
      expect(report.assertions).to.exist()
      expect(report.statistics).to.exist()
      expect(report.metadata).to.exist()
      
      -- Verify file data
      local file = report.files["test.lua"]
      expect(file.executed_lines[1]).to.be_truthy()
      expect(file.covered_lines[1]).to.be_truthy()
      expect(file.functions.add).to.exist()
      
      -- Verify assertion data
      local assertions = report.assertions["test.lua"]
      expect(assertions.assertions).to.have_length(2)
      expect(assertions.covered_lines[1]).to.be_truthy()
      
      -- Verify statistics
      expect(report.statistics.total_lines).to.equal(3)
      expect(report.statistics.executed_lines).to.equal(3)
      expect(report.statistics.covered_lines).to.equal(2)
      expect(report.statistics.total_functions).to.equal(1)
      expect(report.statistics.executed_functions).to.equal(1)
      expect(report.statistics.covered_functions).to.equal(1)
      expect(report.statistics.total_assertions).to.equal(2)
      expect(report.statistics.async_assertions).to.equal(1)
    end)
  end)
  
  describe("Report Validation", function()
    it("validates correct report structure", function()
      local report = reporting.create_report(sample_data, sample_config)
      local success = reporting.validate_report(report)
      expect(success).to.be_truthy()
    end)
    
    it("detects missing sections", function()
      local report = reporting.create_report(sample_data, sample_config)
      report.files = nil
      local success, err = reporting.validate_report(report)
      expect(success).to.be_falsy()
      expect(err).to.match("Missing files section")
    end)
    
    it("detects invalid statistics", function()
      local report = reporting.create_report(sample_data, sample_config)
      report.statistics.total_lines = "invalid"
      local success, err = reporting.validate_report(report)
      expect(success).to.be_falsy()
      expect(err).to.match("Invalid total_lines")
    end)
  end)
  
  describe("HTML Formatting", function()
    local temp_dir
    
    before(function()
      temp_dir = os.tmpname()
      os.remove(temp_dir)
      os.execute("mkdir -p " .. temp_dir)
    end)
    
    after(function()
      os.execute("rm -rf " .. temp_dir)
    end)
    
    it("generates HTML report files", function()
      local report = reporting.create_report(sample_data, sample_config)
      local success = html_formatter.generate_report(report, temp_dir)
      expect(success).to.be_truthy()
      
      -- Check that files were created
      expect(fs.file_exists(temp_dir .. "/index.html")).to.be_truthy()
      expect(fs.file_exists(temp_dir .. "/test.lua.html")).to.be_truthy()
    end)
    
    it("includes all coverage information", function()
      local report = reporting.create_report(sample_data, sample_config)
      html_formatter.generate_report(report, temp_dir)
      
      -- Read index.html
      local content = fs.read_file(temp_dir .. "/index.html")
      
      -- Check for key elements
      expect(content).to.match("Coverage Report")
      expect(content).to.match("Statistics")
      expect(content).to.match("test.lua")
      expect(content).to.match("100.0%%")  -- Function coverage
      expect(content).to.match("66.7%%")   -- Line coverage
    end)
  end)
end)
