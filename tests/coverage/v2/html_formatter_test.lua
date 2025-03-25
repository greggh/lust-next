local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local coverage_v2 = require("lib.coverage.v2")
local html_formatter = require("lib.coverage.v2.formatters.html")
local data_structure = require("lib.coverage.v2.data_structure")

local test_helper = require("lib.tools.test_helper")
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

describe("Coverage V2 HTML Formatter", function()
  local test_file_path
  local test_file_content = [==[local function add(a, b)
  return a + b
end

local function subtract(a, b)
  return a - b
end

-- This is a comment
local function multiply(a, b) -- Inline comment
  return a * b
end

--[[
  Multiline comment
  Not executable
]]

local result = add(5, 3)
print("Result:", result)]==]
  
  local report_path
  
  before(function()
    -- Create a test file
    local path, err = temp_file.create_with_content(test_file_content, "lua")
    expect(err).to_not.exist("Failed to create test file: " .. tostring(err))
    test_file_path = path
    
    -- Create a temporary report file
    report_path = os.tmpname()
    
    -- Register for cleanup
    test_helper.register_temp_file(report_path)
    
    -- Reset coverage data
    coverage_v2.reset()
  end)
  
  after(function()
    -- Ensure coverage is stopped
    if coverage_v2.is_running() then
      coverage_v2.stop()
    end
  end)
  
  it("should generate HTML report correctly", function()
    -- Start coverage
    coverage_v2.start()
    
    -- Execute the test file
    local chunk = loadfile(test_file_path)
    chunk()
    
    -- Stop coverage
    coverage_v2.stop()
    
    -- Get coverage data
    local coverage_data = coverage_v2.get_report_data()
    
    -- Generate HTML report
    local success, err = html_formatter.generate(coverage_data, report_path)
    expect(err).to_not.exist("Failed to generate HTML report: " .. tostring(err))
    expect(success).to.equal(true)
    
    -- Verify report was created
    local exists = fs.file_exists(report_path)
    expect(exists).to.equal(true)
    
    -- Read report content
    local content, read_err = fs.read_file(report_path)
    expect(read_err).to_not.exist("Failed to read HTML report: " .. tostring(read_err))
    
    -- Check basic content
    expect(content).to.match("<!DOCTYPE html>")
    expect(content).to.match("<title>Coverage Report</title>")
    
    -- Check for file inclusion
    local normalized_path = data_structure.normalize_path(test_file_path)
    expect(content).to.match(normalized_path)
    
    -- Check for executed lines
    expect(content).to.match("covered")
    expect(content).to.match("execution%-count")
    
    -- Check for line numbers
    expect(content).to.match("<div class=\"line%-number\">1</div>")
    
    -- Check for summary information
    expect(content).to.match("Coverage Summary")
    expect(content).to.match("Total Files:")
    expect(content).to.match("Covered Files:")
    expect(content).to.match("Executable Lines:")
  end)
end)