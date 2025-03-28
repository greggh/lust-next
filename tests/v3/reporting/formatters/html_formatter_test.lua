-- Tests for HTML formatter
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before = firmo.before
local test_helper = require("lib.tools.test_helper")

local html_formatter = require("lib.coverage.v3.reporting.formatters.html")

describe("HTML Formatter", function()
  local mock_coverage_data
  
  before(function()
    -- Create mock coverage data for testing
    mock_coverage_data = {
      files = {
        ["test.lua"] = {
          path = "test.lua",
          total_lines = 10,
          executable_lines = 8,
          executed_lines = 6,
          covered_lines = 4,
          lines = {
            [1] = { executable = true, executed = true, covered = true, content = "function add(a, b)" },
            [2] = { executable = true, executed = true, covered = true, content = "  return a + b" },
            [3] = { executable = true, executed = true, covered = false, content = "end" },
            [4] = { executable = false, executed = false, covered = false, content = "" },
            [5] = { executable = true, executed = false, covered = false, content = "function sub(a, b)" },
            [6] = { executable = true, executed = false, covered = false, content = "  return a - b" },
            [7] = { executable = true, executed = true, covered = true, content = "function mul(a, b)" },
            [8] = { executable = true, executed = true, covered = true, content = "  return a * b" },
            [9] = { executable = true, executed = true, covered = false, content = "end" },
            [10] = { executable = false, executed = false, covered = false, content = "" }
          },
          functions = {
            add = { name = "add", start_line = 1, end_line = 3, executed = true, covered = true },
            sub = { name = "sub", start_line = 5, end_line = 6, executed = false, covered = false },
            mul = { name = "mul", start_line = 7, end_line = 9, executed = true, covered = true }
          }
        }
      },
      summary = {
        total_files = 1,
        covered_files = 1,
        total_lines = 10,
        executable_lines = 8,
        executed_lines = 6,
        covered_lines = 4,
        total_functions = 3,
        executed_functions = 2,
        covered_functions = 2
      }
    }
  end)
  
  describe("Coverage Formatting", function()
    it("should format coverage data as HTML", function()
      local result = html_formatter.format_coverage(mock_coverage_data)
      expect(result).to.exist()
      expect(result).to.be.a("string")
      
      -- Should contain HTML structure
      expect(result:find("<!DOCTYPE html>")).to.exist()
      expect(result:find("<html>")).to.exist()
      expect(result:find("</html>")).to.exist()
      
      -- Should contain coverage data
      expect(result:find("Coverage Report")).to.exist()
      expect(result:find("test.lua")).to.exist()
      expect(result:find("function add")).to.exist()
      expect(result:find("function sub")).to.exist()
      expect(result:find("function mul")).to.exist()
    end)
    
    it("should handle invalid coverage data", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return html_formatter.format_coverage({})
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Invalid coverage data structure")
    end)
  end)
end)