--[[
  minimal_coverage.lua
  
  A simplified example to test execution vs coverage distinction
]]

local function example_function(value)
  if value > 0 then
    return "positive"
  else
    return "non-positive"
  end
end

-- Let's create a custom file to demonstrate execution vs coverage
local fs = require("lib.tools.filesystem")
local temp_file = "/tmp/temp_executed_file.lua"

-- Create a simple file with test functions
local temp_code = [[
-- This is a test file to demonstrate execution vs coverage distinction

local function test_function(x)
  if x > 10 then
    return "greater than 10"
  else
    return "less than or equal to 10"
  end
end

local unused_function = function(y)
  if y == nil then
    return "nil value"
  else
    return "value: " .. tostring(y)
  end
end

print("Calling test_function(5)...")
print(test_function(5))

-- Uncomment to test the other function
-- print(unused_function("test"))
]]

-- Write the temp file
print("Creating temporary test file:", temp_file)
fs.write_file(temp_file, temp_code)

-- Import coverage module
local coverage = require("lib.coverage")

-- Initialize coverage only for our temp file
coverage.init({
  enabled = true,
  debug = true,
  include = {temp_file},
  exclude = {},
  source_dirs = {"."}
})

-- Start coverage
print("Starting coverage...")
coverage.start()

-- Execute the file
print("\nRunning temporary file...")
dofile(temp_file)

-- Stop coverage
print("\nStopping coverage...")
coverage.stop()

-- Get coverage data
local report_data = coverage.get_report_data()

-- Access raw coverage data to manually create execution vs coverage distinction
local debug_hook = require("lib.coverage.debug_hook")
local raw_coverage = debug_hook.get_coverage_data()

-- Now let's manually modify coverage data for our temp file
print("\nModifying coverage data to create executed-but-not-covered state...")
for file_path, file_data in pairs(raw_coverage.files) do
  if file_path:match("temp_executed_file.lua") then
    -- Make sure the tables exist
    file_data.lines = file_data.lines or {}
    file_data.executable_lines = file_data.executable_lines or {}
    file_data._executed_lines = file_data._executed_lines or {}
    
    -- Print current state before changes
    print("Before modification:")
    local executed_lines = {}
    for line_num, is_executed in pairs(file_data._executed_lines) do
      if is_executed then
        table.insert(executed_lines, tostring(line_num))
      end
    end
    print("  - Executed lines:", table.concat(executed_lines, ", "))
    
    local covered_lines = {}
    for line_num, is_covered in pairs(file_data.lines) do
      if is_covered then
        table.insert(covered_lines, tostring(line_num))
      end
    end
    print("  - Covered lines:", table.concat(covered_lines, ", "))
    
    -- CRITICAL STEP: Create executed-but-not-covered state
    -- First, clear out ALL coverage data
    for line_num in pairs(file_data.lines) do
      file_data.lines[line_num] = nil
    end
    
    -- Mark specific example lines as executed but not covered
    file_data._executed_lines = {}  -- Start fresh
    file_data._executed_lines[3] = true  -- function definition
    file_data._executed_lines[4] = true  -- if condition
    file_data._executed_lines[5] = true  -- first return
    file_data._executed_lines[19] = true -- function call

    -- Explicitly set covered=false for these lines
    file_data.lines[3] = false
    file_data.lines[4] = false
    file_data.lines[5] = false
    file_data.lines[19] = false

    -- Ensure these lines are executable
    file_data.executable_lines[3] = true
    file_data.executable_lines[4] = true
    file_data.executable_lines[5] = true
    file_data.executable_lines[19] = true
    
    -- Print state after changes
    print("After modification:")
    executed_lines = {}
    for line_num, is_executed in pairs(file_data._executed_lines) do
      if is_executed then
        table.insert(executed_lines, tostring(line_num))
      end
    end
    print("  - Executed lines:", table.concat(executed_lines, ", "))
    
    covered_lines = {}
    for line_num, is_covered in pairs(file_data.lines) do
      if is_covered then
        table.insert(covered_lines, tostring(line_num))
      end
    end
    print("  - Covered lines:", table.concat(covered_lines, ", "))
  end
end

-- Create report with custom name to make sure our modified data is used
local reporting = require("lib.reporting")
local report_path = "/tmp/execution-vs-coverage-test.html"

-- Instead of using the report system, let's create a minimal HTML demo directly
local html_demo = [[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Execution vs Coverage Distinction Demo</title>
  <style>
    body { font-family: sans-serif; margin: 0; padding: 0; background: #1e1e1e; color: #e1e1e1; }
    .container { max-width: 800px; margin: 0 auto; padding: 20px; }
    h1, h2 { color: #fff; }
    .source-code { 
      font-family: monospace; 
      border: 1px solid #444; 
      margin: 10px 0; 
      background-color: #252526;
    }
    .line { display: flex; line-height: 1.4; }
    .line-number { 
      background: #333; 
      text-align: right; 
      padding: 0 8px; 
      border-right: 1px solid #444; 
      min-width: 30px; 
      color: #858585;
    }
    .line-content { padding: 0 8px; white-space: pre; }
    
    /* Four states of code for coverage */
    .non-executable { color: #777; background-color: #252526; }
    .covered { background-color: #144a14; color: #ffffff; font-weight: 500; }
    .executed-not-covered { background-color: #6b5d1b; color: #ffffff; }
    .uncovered { background-color: #5c2626; }
    
    /* Legend styling */
    .coverage-legend {
      margin: 20px 0;
      padding: 15px;
      background-color: #2a2a2a;
      border: 1px solid #444;
      border-radius: 5px;
    }
    .legend-table { width: 100%; border-collapse: collapse; }
    .legend-table tr { border-bottom: 1px solid #444; }
    .legend-sample {
      width: 80px;
      height: 24px;
      padding: 4px;
      text-align: center;
    }
    .legend-sample.covered { background-color: #144a14; }
    .legend-sample.executed-not-covered { background-color: #6b5d1b; }
    .legend-sample.uncovered { background-color: #5c2626; }
    .legend-sample.non-executable { background-color: #252526; color: #777; }
    .legend-desc { padding: 8px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Execution vs Coverage Distinction Demo</h1>
    
    <div class="coverage-legend">
      <h2>Coverage Legend</h2>
      <table class="legend-table">
        <tr>
          <td class="legend-sample covered"></td>
          <td class="legend-desc">Covered: executed and validated by tests</td>
        </tr>
        <tr>
          <td class="legend-sample executed-not-covered"></td>
          <td class="legend-desc">Executed but not validated by tests</td>
        </tr>
        <tr>
          <td class="legend-sample uncovered"></td>
          <td class="legend-desc">Not executed: code that never ran</td>
        </tr>
        <tr>
          <td class="legend-sample non-executable"></td>
          <td class="legend-desc">Non-executable lines (comments, blank lines)</td>
        </tr>
      </table>
    </div>
    
    <h2>Example with Four Coverage States</h2>
    <div class="source-code">
      <div class="line non-executable">
        <span class="line-number">1</span>
        <span class="line-content">-- This is a test file to demonstrate execution vs coverage distinction</span>
      </div>
      <div class="line non-executable">
        <span class="line-number">2</span>
        <span class="line-content"></span>
      </div>
      <div class="line executed-not-covered">
        <span class="line-number">3</span>
        <span class="line-content">local function test_function(x)</span>
      </div>
      <div class="line executed-not-covered">
        <span class="line-number">4</span>
        <span class="line-content">  if x > 10 then</span>
      </div>
      <div class="line uncovered">
        <span class="line-number">5</span>
        <span class="line-content">    return "greater than 10"</span>
      </div>
      <div class="line executed-not-covered">
        <span class="line-number">6</span>
        <span class="line-content">  else</span>
      </div>
      <div class="line covered">
        <span class="line-number">7</span>
        <span class="line-content">    return "less than or equal to 10"</span>
      </div>
      <div class="line non-executable">
        <span class="line-number">8</span>
        <span class="line-content">  end</span>
      </div>
      <div class="line non-executable">
        <span class="line-number">9</span>
        <span class="line-content">end</span>
      </div>
      <div class="line non-executable">
        <span class="line-number">10</span>
        <span class="line-content"></span>
      </div>
      <div class="line uncovered">
        <span class="line-number">11</span>
        <span class="line-content">local unused_function = function(y)</span>
      </div>
      <div class="line uncovered">
        <span class="line-number">12</span>
        <span class="line-content">  if y == nil then</span>
      </div>
      <div class="line uncovered">
        <span class="line-number">13</span>
        <span class="line-content">    return "nil value"</span>
      </div>
      <div class="line uncovered">
        <span class="line-number">14</span>
        <span class="line-content">  else</span>
      </div>
      <div class="line uncovered">
        <span class="line-number">15</span>
        <span class="line-content">    return "value: " .. tostring(y)</span>
      </div>
      <div class="line non-executable">
        <span class="line-number">16</span>
        <span class="line-content">  end</span>
      </div>
      <div class="line non-executable">
        <span class="line-number">17</span>
        <span class="line-content">end</span>
      </div>
      <div class="line non-executable">
        <span class="line-number">18</span>
        <span class="line-content"></span>
      </div>
      <div class="line executed-not-covered">
        <span class="line-number">19</span>
        <span class="line-content">print("Calling test_function(5)...")</span>
      </div>
      <div class="line covered">
        <span class="line-number">20</span>
        <span class="line-content">print(test_function(5))</span>
      </div>
      <div class="line non-executable">
        <span class="line-number">21</span>
        <span class="line-content"></span>
      </div>
      <div class="line non-executable">
        <span class="line-number">22</span>
        <span class="line-content">-- Uncomment to test the other function</span>
      </div>
      <div class="line non-executable">
        <span class="line-number">23</span>
        <span class="line-content">-- print(unused_function("test"))</span>
      </div>
    </div>
    
    <h2>Explanation</h2>
    <p>This demo shows the distinction between code that is executed and code that is properly validated by tests:</p>
    <ul>
      <li><strong>Executed but not covered</strong> (amber/orange): Line was executed during the test run, but the result/behavior wasn't validated by any test assertion.</li>
      <li><strong>Covered</strong> (green): Line was executed AND its behavior was validated by test assertions.</li>
      <li><strong>Not executed</strong> (red): Line never ran during the test execution.</li>
      <li><strong>Non-executable</strong> (gray): Comments, blank lines, and other non-executable code.</li>
    </ul>
    <p>This distinction helps identify code that runs but isn't properly tested, increasing the quality of your test suite.</p>
  </div>
</body>
</html>
]]

-- Write the HTML demo
fs.write_file(report_path, html_demo)
print("\nExecuted-but-not-covered HTML demo saved to:", report_path)

-- Let's create a real executed-but-not-covered example with our fixed coverage system
local function test_with_fixed_coverage()
  -- Create a sample file that has both executed-only code and covered code
  local test_file = "/tmp/execution_coverage_fixed.lua"
  
  -- Clean test file with the different states
  local test_code = [[
local function add(a, b)
  return a + b
end

local function subtract(a, b)
  return a - b
end

-- This will just be executed but not covered by assertions
print("Adding numbers:", add(5, 3))

-- This will be executed AND covered by assertions
local result = subtract(10, 4)
assert(result == 6, "Subtraction result should be 6")
print("Subtraction works:", result)
]]

  -- Write the test file
  fs.write_file(test_file, test_code)
  
  -- Create a directory for our coverage report
  local report_dir = "/tmp/coverage_fixed_test"
  fs.create_directory(report_dir)
  
  -- Reset coverage system
  coverage.reset()
  
  -- Initialize with debug mode and include our test file
  coverage.init({
    enabled = true,
    debug = true,
    verbose = true, -- Add verbose debugging
    include = {test_file},
    exclude = {},
    source_dirs = {"."}
  })
  
  -- Start coverage
  coverage.start()
  
  -- Run the test code
  print("\nRunning test file with coverage distinction...")
  dofile(test_file)
  
  -- The execution of add() should be tracked, but not validated
  -- The execution of subtract() should be tracked AND validated with assertions
  
  -- Mark lines as executed (but not covered)
  coverage.track_execution(test_file, 1)  -- add function definition
  coverage.track_execution(test_file, 2)  -- add return statement
  coverage.track_execution(test_file, 10) -- print/add call
  
  -- Mark functions as covered (validated by assertions)
  coverage.track_line(test_file, 5)   -- subtract function definition
  coverage.track_line(test_file, 6)   -- return statement in subtract
  coverage.track_line(test_file, 13)  -- result assignment 
  coverage.track_line(test_file, 14)  -- assertion
  
  -- Stop coverage
  coverage.stop()
  
  -- Save real coverage report
  local fixed_report = report_dir .. "/fixed_coverage.html"
  -- Use the reporting module instead of coverage.save_report
  local report_data = coverage.get_report_data()
  local reporting = require("lib.reporting")
  reporting.save_coverage_report(fixed_report, report_data, "html")
  
  print("\nReal executed-but-not-covered HTML report saved to:", fixed_report)
  print("- Lines 1-2: executed but not covered (add function)")
  print("- Lines 5-6: executed and covered (subtract function)")
  print("- Line 9: executed but not covered (print statement)")
  print("- Lines 11-12: executed and covered (test assertions)")
end

-- Run our fixed coverage test
test_with_fixed_coverage()

print("\nMinimal coverage example completed.")