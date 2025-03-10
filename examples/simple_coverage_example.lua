--[[
  simple_coverage_example.lua
  
  A simpler example for generating HTML coverage reports.
]]

package.path = "./?.lua;" .. package.path
local lust_next = require("lust-next")
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")

-- Create a simplified coverage data structure
local coverage_data = {
  files = {
    ["/path/to/module.lua"] = {
      -- Covered lines with a map of line numbers
      lines = {
        [2] = true,  -- local Module = {}
        [4] = true,  -- function Module.func1()
        [5] = true,  -- return true
        [8] = true,  -- function Module.func2()
      },
      -- Keep track of total lines in the file
      line_count = 10,
      -- Actual file contents for rendering
      source = {
        "-- Test module",
        "local Module = {}",
        "",
        "function Module.func1()",
        "  return true",
        "end",
        "",
        "function Module.func2()",
        "  return false -- uncovered",
        "end"
      },
      -- Executable line information
      executable_lines = {
        [1] = false,  -- comment
        [2] = true,   -- variable declaration
        [3] = false,  -- blank line
        [4] = true,   -- function declaration
        [5] = true,   -- return statement
        [6] = false,  -- end keyword
        [7] = false,  -- blank line
        [8] = true,   -- function declaration
        [9] = true,   -- return statement (uncovered)
        [10] = false  -- end keyword
      },
      -- Function coverage
      functions = {
        ["func1"] = {
          name = "Module.func1",
          line = 4,
          executed = true
        },
        ["func2"] = {
          name = "Module.func2",
          line = 8,
          executed = false
        }
      },
      -- Block coverage info
      logical_chunks = {
        ["Function_1"] = {
          id = "Function_1",
          type = "function",
          start_line = 4,
          end_line = 6,
          parent_id = "root",
          executed = true
        },
        ["Function_2"] = {
          id = "Function_2",
          type = "function",
          start_line = 8,
          end_line = 10,
          parent_id = "root",
          executed = false
        }
      },
      -- Line coverage stats
      covered_lines = 4,
      total_lines = 6,  -- Only count executable lines
      line_coverage_percent = 66.7,
      -- Function coverage stats
      covered_functions = 1,
      total_functions = 2,
      function_coverage_percent = 50.0
    }
  },
  original_files = {
    ["/path/to/module.lua"] = {
      -- Same content as above for the original file
      lines = {
        [2] = true,
        [4] = true,
        [5] = true,
        [8] = true,
      },
      line_count = 10,
      source = {
        "-- Test module",
        "local Module = {}",
        "",
        "function Module.func1()",
        "  return true",
        "end",
        "",
        "function Module.func2()",
        "  return false -- uncovered",
        "end"
      },
      executable_lines = {
        [1] = false,
        [2] = true,
        [3] = false,
        [4] = true,
        [5] = true,
        [6] = false,
        [7] = false,
        [8] = true,
        [9] = true,
        [10] = false
      },
      logical_chunks = {
        ["Function_1"] = {
          id = "Function_1",
          type = "function",
          start_line = 4,
          end_line = 6,
          parent_id = "root",
          executed = true
        },
        ["Function_2"] = {
          id = "Function_2",
          type = "function",
          start_line = 8,
          end_line = 10,
          parent_id = "root",
          executed = false
        }
      }
    }
  },
  -- Summary statistics
  summary = {
    total_files = 1,
    covered_files = 1,
    total_lines = 6,    -- Only executable lines
    covered_lines = 4,
    line_coverage_percent = 66.7,
    total_functions = 2,
    covered_functions = 1,
    function_coverage_percent = 50.0,
    total_blocks = 2,
    covered_blocks = 1,
    block_coverage_percent = 50.0,
    overall_percent = 65.0
  }
}

-- Let's use the coverage module directly to generate the report
print("Generating HTML coverage report...")

-- Create a temporary file with our test code
local test_file = "/tmp/test_module.lua"
local test_code = [[
-- Test module
local Module = {}

function Module.func1()
  return true
end

function Module.func2()
  return false -- uncovered
end

return Module
]]

fs.write_file(test_file, test_code)

-- Start coverage tracking
local coverage = require("lib.coverage")

-- Initialize coverage properly
coverage.init({
  enabled = true,
  debug = true,
  track_blocks = true,
  include = {"**/test_module.lua"},
  exclude = {},
  source_dirs = {"/tmp"},
  use_static_analysis = true
})

-- Start coverage tracking
coverage.start()

-- Load and use the module
local module = dofile(test_file)
assert(module.func1() == true, "Function should return true")
-- Deliberately don't call func2 to test coverage

-- Stop coverage
coverage.stop()

-- Generate the report
local report_data = coverage.get_report_data()
local reporting = require("lib.reporting")

-- Save the report to a file
local file_path = "/tmp/simple-coverage-example.html"

-- Create the HTML report using the coverage module's built-in reporting
local html_content
print("Generating HTML coverage report...")

-- Try to use the built-in save_report function first (preferred method)
local success = coverage.save_report(file_path, "html")

if not success then
  -- Fallback to manual report generation
  print("Falling back to manual HTML report generation...")
  
  -- First initialize the formatters
  local formatters = { coverage = {}, quality = {} }
  require("lib.reporting.formatters.html")(formatters)
  
  -- Now use the registered formatter
  if formatters.coverage.html then
    html_content = formatters.coverage.html(report_data)
  else
    -- One more fallback - hardcoded minimal HTML
    html_content = [[
    <html>
      <head><title>Simple Coverage Report</title></head>
      <body>
        <h1>Simple Coverage Report</h1>
        <p>Coverage data available in console output.</p>
      </body>
    </html>
    ]]
  end
  
  -- Save the report manually
  success = fs.write_file(file_path, html_content)
end

-- Print the report summary
print("HTML coverage report saved to: " .. file_path)
print("Coverage statistics:")
print("  Files: " .. report_data.summary.covered_files .. "/" .. report_data.summary.total_files)
print("  Lines: " .. report_data.summary.covered_lines .. "/" .. report_data.summary.total_lines)
print("  Functions: " .. report_data.summary.covered_functions .. "/" .. report_data.summary.total_functions)
print("  Blocks: " .. report_data.summary.covered_blocks .. "/" .. report_data.summary.total_blocks)
print("  Line coverage: " .. string.format("%.1f%%", report_data.summary.line_coverage_percent))
print("  Function coverage: " .. string.format("%.1f%%", report_data.summary.function_coverage_percent))
print("  Block coverage: " .. string.format("%.1f%%", report_data.summary.block_coverage_percent))
print("  Overall coverage: " .. string.format("%.1f%%", report_data.summary.overall_percent))
  
print("\nOpening report in browser...")
os.execute("xdg-open " .. file_path .. " &>/dev/null")