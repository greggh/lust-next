--[[
  A test for validator.lua coverage
  
  This test specifically targets the validator.lua file to verify
  that the multiline comment fixes work properly.
]]

package.path = package.path .. ";./?.lua"
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local coverage = require("lib.coverage")
local validator = require("lib.tools.parser.validator")

describe("Validator Coverage Test", function()
  -- Initialize coverage tracking with debugging enabled
  coverage.init({
    enabled = true,
    debug = true,
    use_static_analysis = true,
    track_blocks = true,
    discover_uncovered = false,
    include = {"lib/tools/parser/validator.lua"},
    exclude = {},
    source_dirs = {"."}
  })
  
  -- Start coverage tracking
  coverage.start()
  
  it("should validate a simple AST", function()
    -- Create a simple AST to validate
    local ast = {
      {
        tag = "Set",
        {
          tag = "VarList",
          { tag = "Id", "x" }
        },
        {
          tag = "ExpList",
          { tag = "Number", 10 }
        }
      }
    }
    
    -- Create error info
    local errorinfo = {
      subject = "x = 10",
      filename = "test.lua"
    }
    
    -- Validate AST
    local result = validator.validate(ast, errorinfo)
    expect(result).to.equal(ast)
  end)
  
  it("should validate complex AST structures", function()
    -- Create a more complex AST with various structures
    local ast = {
      -- Function declaration
      {
        tag = "Function",
        { tag = "Id", "test_func" },
        { { tag = "Id", "a" }, { tag = "Id", "b" } }, -- params
        { -- body
          {
            tag = "If",
            { -- condition
              tag = "Op",
              ">",
              { tag = "Id", "a" },
              { tag = "Id", "b" }
            },
            { -- then block
              {
                tag = "Return",
                { tag = "Id", "a" }
              }
            },
            { -- else block
              {
                tag = "Return",
                { tag = "Id", "b" }
              }
            }
          }
        }
      }
    }
    
    -- Create error info
    local errorinfo = {
      subject = "function test_func(a, b) if a > b then return a else return b end end",
      filename = "test.lua"
    }
    
    -- Validate AST - this should exercise more of the validator's code
    local result = validator.validate(ast, errorinfo)
    expect(result).to.equal(ast)
  end)
  
  -- Stop coverage tracking
  coverage.stop()
  
  -- Generate HTML report
  local html_path = "coverage-reports/validator-coverage-test.html"
  coverage.save_report(html_path, "html")
  print("\nHTML report saved to: " .. html_path)
  
  -- Print summary
  local report_data = coverage.get_report_data()
  print("\nCoverage Statistics:")
  for file_path, file_data in pairs(report_data.files) do
    if file_path:match("validator.lua") then
      print("  File: " .. file_path)
      print("  Line coverage: " .. file_data.covered_lines .. "/" .. file_data.total_lines .. 
           " (" .. string.format("%.1f%%", file_data.line_coverage_percent) .. ")")
      print("  Function coverage: " .. file_data.covered_functions .. "/" .. file_data.total_functions .. 
           " (" .. string.format("%.1f%%", file_data.function_coverage_percent) .. ")")
      
      -- Check the first few lines to verify multiline comment detection
      print("\n  First 10 line coverage details:")
      local file_source = report_data.original_files[file_path].source
      for i = 1, 10 do
        local line_text = file_source[i] or ""
        if #line_text > 30 then
          line_text = line_text:sub(1, 27) .. "..."
        end
        
        local is_executable = file_data.executable_lines and file_data.executable_lines[i]
        local is_covered = file_data.lines and file_data.lines[i]
        
        print(string.format("    Line %2d: %-30s | executable=%s, covered=%s", 
          i, line_text, tostring(is_executable), tostring(is_covered)))
      end
    end
  end
end)