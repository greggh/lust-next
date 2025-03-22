-- A simple file to verify multiline comment detection in coverage

-- First, enable coverage tracking
---@type Firmo
local firmo = require("firmo")
---@type CoverageModule
local coverage = require("lib.coverage")
---@type fun(description: string, callback: function) describe Test suite container function
---@type fun(description: string, options: table|nil, callback: function) it Test case function with optional parameters
---@type fun(value: any) expect Assertion generator function
---@type fun(callback: function) before Setup function that runs before each test
---@type fun(callback: function) after Teardown function that runs after each test
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

-- A function with print statements and multiline comments
---@return number sum The sum of x and y
local function func_with_comments()
  --[[ This is a multiline comment
  that spans across multiple
  lines and should be detected
  as non-executable ]]
  
  print("This line should be marked as executed")
  
  local x = 10 --[[ inline multiline comment ]] local y = 20
  
  print("This is another executed line")
  
  --[[ Another
  multiline comment ]]
  
  return x + y
end

describe("Multiline Comment Verification", function()
  ---@type TempFileModule
  local temp_file = require("lib.tools.temp_file")
  ---@type string report_dir Path to the temporary directory for test reports
  local report_dir
  
  before(function()
    -- Create temporary directory for report
    ---@type string|nil dir_path Path to created temporary directory or nil if failed
    ---@type table|nil err Error object if directory creation failed
    local dir_path, err = temp_file.create_temp_directory()
    if not dir_path then
      print("Failed to create temp directory:", err)
      os.exit(1)
    end
    report_dir = dir_path
    
    coverage.start({
      output_dir = report_dir,
      include = {".*/multiline_comment_verification.lua$"},
      format = "html"
    })
  end)
  
  after(function()
    coverage.stop()
    ---@type table report_data Coverage data for generating reports
    local report_data = coverage.get_report_data()
    
    -- Generate HTML report
    ---@type ReportingModule
    local reporting = require("lib.reporting")
    ---@type FilesystemModule
    local fs = require("lib.tools.filesystem")
    ---@type string html_path Path to the HTML report file
    local html_path = fs.join_paths(report_dir, "coverage.html")
    
    ---@type boolean success Whether the report was successfully generated
    ---@type table|nil err Error object if report generation failed
    local success, err = reporting.save_coverage_report(
      html_path,
      report_data,
      "html",
      { theme = "dark", show_line_numbers = true }
    )
    
    if success then
      print("Coverage report generated at: " .. html_path)
    else
      print("Failed to generate report: " .. tostring(err))
    end
  end)
  
  it("should execute all print statements", function()
    local result = func_with_comments()
    print("Result:", result)
    expect(result).to.equal(30)
  end)
end)
