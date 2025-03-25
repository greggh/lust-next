local firmo = require("firmo")
local calculator = require("lib.samples.calculator") 
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- HTML coverage report test
describe("HTML Coverage Report Generation", function()
  -- Create a temporary directory for our test
  local test_dir

  before(function()
    test_dir = test_helper.create_temp_test_directory()
  end)

  after(function()
    -- Cleanup happens automatically
  end)

  it("should generate valid HTML coverage report", function()
    -- Execute some calculator functions to track coverage
    calculator.add(5, 10)
    calculator.multiply(3, 7)
    
    -- Run a test command with coverage and HTML format
    local report_dir = test_dir.path .. "/coverage-html"
    local cmd = "lua test.lua --coverage --format=html --output=" .. report_dir .. " tests/coverage/html_report_test.lua"
    
    -- Execute the command
    local result, err = test_helper.with_error_capture(function()
      local f = io.popen(cmd)
      local output = f:read("*a")
      f:close()
      return output
    end)()
    
    -- Verify command executed successfully
    expect(err).to_not.exist("Error executing test command: " .. tostring(err))
    expect(result).to.exist("Test command produced no output")
    
    -- Verify report directory was created
    expect(fs.directory_exists(report_dir)).to.be_truthy("HTML report directory was not created")
    
    -- Check for index.html
    local index_path = report_dir .. "/index.html"
    expect(fs.file_exists(index_path)).to.be_truthy("index.html was not created")
    
    -- Read index.html content
    local index_content, read_err = fs.read_file(index_path)
    expect(read_err).to_not.exist("Error reading index.html: " .. tostring(read_err))
    expect(index_content).to.exist("index.html is empty")
    
    -- Check for critical content in the HTML
    expect(index_content).to.match("<!DOCTYPE html>", "Missing DOCTYPE declaration")
    expect(index_content).to.match("<html", "Missing html tag")
    expect(index_content).to.match("<head>", "Missing head tag")
    expect(index_content).to.match("<body>", "Missing body tag")
    
    -- Check for title
    expect(index_content).to.match("<title>Coverage Report</title>", "Missing or incorrect title")
    
    -- Check for summary information
    expect(index_content).to.match("Summary", "Missing summary section")
    expect(index_content).to.match("calculator%.lua", "Missing calculator.lua in the report")
    
    -- Check for function information
    expect(index_content).to.match("Function Coverage", "Missing function coverage information")
    
    -- Check for file detail links
    local calculator_file_path
    for file_path in index_content:gmatch('href="([^"]+)"') do
      if file_path:match("calculator%.lua%.html") then
        calculator_file_path = report_dir .. "/" .. file_path
        break
      end
    end
    
    expect(calculator_file_path).to.exist("No link to calculator.lua detail page found")
    
    -- Verify the calculator.lua detail page exists
    if calculator_file_path then
      expect(fs.file_exists(calculator_file_path)).to.be_truthy("calculator.lua detail page not created")
      
      -- Read calculator.lua detail content
      local calc_content, calc_read_err = fs.read_file(calculator_file_path)
      expect(calc_read_err).to_not.exist("Error reading calculator detail page: " .. tostring(calc_read_err))
      expect(calc_content).to.exist("Calculator detail page is empty")
      
      -- Check for critical content in the calculator detail page
      expect(calc_content).to.match("add", "Missing add function in detail page")
      expect(calc_content).to.match("multiply", "Missing multiply function in detail page")
      expect(calc_content).to.match("subtract", "Missing subtract function in detail page")
      expect(calc_content).to.match("divide", "Missing divide function in detail page")
      
      -- Check for execution information (lines are highlighted)
      expect(calc_content).to.match("covered%-line", "No covered lines found in detail page")
    end
  end)
end)