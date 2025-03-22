--[[
  Enhanced HTML Formatter Example
  
  This example demonstrates how to use the enhanced HTML formatter 
  with the line classification data from the enhanced line classification system.
]]

local firmo = require("firmo")
local fs = require("lib.tools.filesystem")
local html_formatter = require("lib.reporting.formatters.html")

-- Create a test file with different code constructs
local function create_test_file()
  local tmp_dir = os.getenv("TMPDIR") or "/tmp"
  local file_path = fs.join_paths(tmp_dir, "html_formatter_example_" .. os.time() .. ".lua")
  
  local content = [==[
-- Single line comment
local simple_var = "simple string"

--[[ 
  Multiline comment
  that spans
  multiple lines
]]

local multiline_string = [[
  This is a multiline string
  that also spans multiple lines
  and should be handled properly
]]

-- Function with branches for testing
local function test_branches(x)
  local result
  
  if x > 10 then
    result = "large"
  elseif x == 0 then
    result = "zero" 
  else
    result = "small"
  end
  
  return result
end

-- Mixed constructs
local mixed_constructs = function()
  -- Single line comment inside function
  local comment = "comment string"
  
  local str = [[
    String with -- comment inside
  ]]
  
  return comment, str
end

-- Mixed code and comments on same line
local mixed = "string" -- Comment after code

return {
  test_branches = test_branches,
  mixed_constructs = mixed_constructs,
  mixed = mixed
}
]==]
  
  -- Write the test file
  local success, err = fs.write_file(file_path, content)
  if not success then
    print("Error creating test file: " .. tostring(err))
    return nil
  end
  
  return file_path
end

-- Generate coverage data with enhanced classification
local function generate_coverage_data_with_classification(file_path)
  -- Start coverage with enhanced options
  firmo.coverage.start({
    use_enhanced_classification = true,
    track_multiline_context = true
  })
  
  -- Load and execute the test file
  local module_to_test, err = loadfile(file_path)
  if not module_to_test then
    print("Error loading module: " .. tostring(err))
    return nil
  end
  
  -- Run the module to execute its code
  local success, result = pcall(module_to_test)
  if not success then
    print("Error running module: " .. tostring(result))
    return nil
  end
  
  -- Call some functions to ensure they're executed
  if result then
    if result.test_branches then
      result.test_branches(15) -- large branch
      result.test_branches(0)  -- zero branch
      result.test_branches(5)  -- small branch
    end
    
    if result.mixed_constructs then
      result.mixed_constructs()
    end
  end
  
  -- Stop coverage
  local coverage_data = firmo.coverage.stop()
  
  return coverage_data
end

-- Generate and save HTML report with enhanced classification
local function generate_enhanced_html_report(coverage_data, output_path)
  -- Configure formatter to show classification details
  local formatter_config = {
    show_classification_details = true,
    classification_tooltip_style = "both",
    highlight_multiline_constructs = true,
    show_classification_reasons = true
  }
  
  -- Get any existing formatter configuration
  local reporting = require("lib.reporting")
  if reporting.set_formatter_config then
    reporting.set_formatter_config("html", formatter_config)
  end
  
  -- Generate HTML report
  local html_report = html_formatter.format_coverage(coverage_data)
  
  -- Write report to file
  local success, err = fs.write_file(output_path, html_report)
  if not success then
    print("Error writing report: " .. tostring(err))
    return nil
  end
  
  return output_path
end

-- Demonstrate both enhanced classification and HTML formatter
local function run_example()
  print("Enhanced HTML Formatter Example\n")
  
  -- Create a test file
  print("Creating test file...")
  local file_path = create_test_file()
  if not file_path then
    print("Failed to create test file")
    return
  end
  
  print("Created test file: " .. file_path)
  
  -- Generate coverage data with enhanced classification
  print("\nGenerating coverage data with enhanced classification...")
  local coverage_data = generate_coverage_data_with_classification(file_path)
  if not coverage_data then
    print("Failed to generate coverage data")
    os.remove(file_path)
    return
  end
  
  print("Coverage data generated successfully")
  
  -- Generate HTML report with enhanced formatting
  local report_path = file_path:gsub("%.lua$", "_report.html")
  print("\nGenerating enhanced HTML report...")
  local report_file = generate_enhanced_html_report(coverage_data, report_path)
  if not report_file then
    print("Failed to generate HTML report")
    os.remove(file_path)
    return
  end
  
  print("HTML report generated: " .. report_file)
  
  -- Print information about how to view the report
  print("\nTo view the HTML report:")
  print("1. Open " .. report_file .. " in your web browser")
  print("2. You should see enhanced line classification information:")
  print("   - Hover over lines to see tooltips with classification details")
  print("   - Click on lines to see more detailed classification information")
  print("   - Different colors highlight different line types (code, comments, strings)")
  print("   - The classification legend explains the different line types")
  
  -- Clean up when done
  print("\nKeeping files for inspection. To clean up:")
  print("rm " .. file_path)
  print("rm " .. report_path)
end

-- Run the example
run_example()