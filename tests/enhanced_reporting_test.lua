-- Test for enhanced reporting functionality in lust-next

local lust = require("../lust-next")
lust.expose_globals()

-- Attempt to load the reporting module
local reporting

-- Try different paths to handle different testing environments
local function load_reporting()
  local paths = {
    "../src/reporting",
    "src/reporting",
    "./src/reporting"
  }
  
  for _, path in ipairs(paths) do
    local ok, mod = pcall(require, path)
    if ok then
      return mod
    end
  end
  
  return nil
end

reporting = load_reporting()

-- Mock coverage data for testing
local function create_mock_coverage_data()
  return {
    files = {
      ["/path/to/example.lua"] = {
        lines = {
          [1] = true,
          [2] = true,
          [5] = true,
          [8] = true,
          [9] = true,
          [10] = true
        },
        functions = {
          ["example_function"] = true,
          ["another_function"] = true
        },
        line_count = 12,
        total_lines = 12,
        covered_lines = 6,
        total_functions = 2,
        covered_functions = 2
      },
      ["/path/to/another_example.lua"] = {
        lines = {
          [3] = true,
          [4] = true,
          [7] = true
        },
        functions = {
          ["test_function"] = true
        },
        line_count = 10,
        total_lines = 10,
        covered_lines = 3,
        total_functions = 1,
        covered_functions = 1
      }
    },
    summary = {
      total_files = 2,
      covered_files = 2,
      total_lines = 22,
      covered_lines = 9,
      total_functions = 3,
      covered_functions = 3,
      line_coverage_percent = 40.9,
      function_coverage_percent = 100,
      overall_percent = 52.72
    }
  }
end

describe("Enhanced Reporting Module", function()
  it("should exist and be loadable", function()
    assert.not_nil(reporting, "Reporting module could not be loaded")
  end)
  
  describe("HTML Coverage Reporting with Syntax Highlighting", function()
    -- Skip this test if the reporting module couldn't be loaded
    if not reporting then
      print("Skipping HTML tests - reporting module not available")
      return
    end
    
    it("should generate HTML with syntax highlighting", function()
      local mock_data = create_mock_coverage_data()
      local html_report = reporting.format_coverage(mock_data, "html")
      
      -- Verify the HTML contains the key elements for syntax highlighting
      assert.contains(html_report, "<style>", "HTML should contain style definitions")
      assert.contains(html_report, ".source-container", "HTML should include source container styles")
      assert.contains(html_report, ".source-line-content", "HTML should include line content styles")
      assert.contains(html_report, ".keyword", "HTML should include syntax highlighting for keywords")
      assert.contains(html_report, ".string", "HTML should include syntax highlighting for strings")
      assert.contains(html_report, ".comment", "HTML should include syntax highlighting for comments")
      assert.contains(html_report, ".number", "HTML should include syntax highlighting for numbers")
      assert.contains(html_report, ".function-name", "HTML should include syntax highlighting for function names")
      assert.contains(html_report, "toggleSource", "HTML should include JavaScript for toggling source display")
    end)
    
    it("should include coverage information in the report", function()
      local mock_data = create_mock_coverage_data()
      local html_report = reporting.format_coverage(mock_data, "html")
      
      -- Verify the HTML contains the coverage stats
      assert.contains(html_report, "Overall Coverage: 52.72%", "HTML should contain overall coverage percentage")
      assert.contains(html_report, "Lines: 9 / 22", "HTML should contain line coverage stats")
      assert.contains(html_report, "Functions: 3 / 3", "HTML should contain function coverage stats")
      assert.contains(html_report, "Files: 2 / 2", "HTML should contain file coverage stats")
    end)
    
    it("should include source code containers in the report", function()
      local mock_data = create_mock_coverage_data()
      local html_report = reporting.format_coverage(mock_data, "html")
      
      -- Verify the HTML contains source code containers
      assert.contains(html_report, "source-container", "HTML should include source code containers")
      assert.contains(html_report, "source-header", "HTML should include source headers")
      assert.contains(html_report, "source-code", "HTML should include source code blocks")
      assert.contains(html_report, "source-line-number", "HTML should include line numbers")
    end)
  end)
end)