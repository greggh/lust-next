-- Example to demonstrate coverage tracking
local firmo = require('firmo')
local coverage = require("lib.coverage")  -- Directly reference the coverage module

-- OS detection helper function
function is_windows()
  return package.config:sub(1,1) == '\\'
end

-- Expose the test functions and assertions
local describe, it = firmo.describe, firmo.it

-- Create shorthand for expect
local expect = firmo.expect

-- Import the functions we want to test
local example_module = {}

-- A simple math utility module to demonstrate coverage
example_module.is_even = function(n)
  return n % 2 == 0
end

example_module.is_odd = function(n)
  return n % 2 ~= 0
end

-- Function with different paths to show branch coverage
example_module.categorize_number = function(n)
  if type(n) ~= "number" then
    return "not a number"
  end
  
  if n < 0 then
    return "negative"
  elseif n == 0 then
    return "zero"
  elseif n > 0 and n < 10 then
    return "small positive"
  else
    return "large positive"
  end
end

-- A function we won't test to show incomplete coverage
example_module.unused_function = function(n)
  return n * n
end

-- Tests for the example module
describe("Example module coverage demo", function()
  -- Test is_even
  it("should correctly identify even numbers", function()
    expect(example_module.is_even(2)).to.equal(true)
    expect(example_module.is_even(4)).to.equal(true)
    expect(example_module.is_even(0)).to.equal(true)
    expect(example_module.is_even(1)).to.equal(false)
    expect(example_module.is_even(3)).to.equal(false)
  end)
  
  -- Test is_odd
  it("should correctly identify odd numbers", function()
    expect(example_module.is_odd(1)).to.equal(true)
    expect(example_module.is_odd(3)).to.equal(true)
    expect(example_module.is_odd(2)).to.equal(false)
    expect(example_module.is_odd(4)).to.equal(false)
    expect(example_module.is_odd(0)).to.equal(false)
  end)
  
  -- Test categorize_number (partially)
  describe("categorize_number", function()
    it("should handle non-numbers", function()
      expect(example_module.categorize_number("hello")).to.equal("not a number")
      expect(example_module.categorize_number({})).to.equal("not a number")
      expect(example_module.categorize_number(nil)).to.equal("not a number")
    end)
    
    it("should identify negative numbers", function()
      expect(example_module.categorize_number(-1)).to.equal("negative")
      expect(example_module.categorize_number(-10)).to.equal("negative")
    end)
    
    it("should identify zero", function()
      expect(example_module.categorize_number(0)).to.equal("zero")
    end)
    
    -- Note: We don't test the "small positive" or "large positive" branches
    -- This will show up as incomplete coverage
  end)
  
  -- Note: We don't test the unused_function at all
  -- This will show up as a completely uncovered function
end)

-- Enable coverage with comprehensive options
firmo.coverage_options = {
  enabled = true,                   -- Enable coverage tracking
  source_dirs = {".", "examples"}, -- Directories to scan for source files
  discover_uncovered = true,        -- Find files that aren't executed by tests
  debug = true,                     -- Enable verbose debug output
  threshold = 70,                   -- Set coverage threshold to 70%
  
  -- Override default patterns to focus just on example files
  use_default_patterns = false,     -- Don't use default patterns
  include = {
    "examples/*.lua",              -- Include just files in examples directory
  },
  exclude = {
    "examples/*_test.lua",         -- Exclude test files
  }
}

-- Initialize and start coverage tracking
coverage.init({
  enabled = true,
  debug = true,
  discover_uncovered = true,
  threshold = 70
})

-- Start tracking coverage
print("\nStarting coverage tracking...")
coverage.start()

-- Manually run the tests to demonstrate coverage
print("Running tests with custom runner:")
-- We need to manually simulate the testing framework

-- Run tests for is_even function
print("Testing is_even function:")
local is_even_results = {
  { value = 2, expected = true },
  { value = 4, expected = true },
  { value = 0, expected = true },
  { value = 1, expected = false },
  { value = 3, expected = false }
}

for _, test in ipairs(is_even_results) do
  local result = example_module.is_even(test.value)
  print(string.format("  is_even(%d) -> %s - %s", 
                      test.value, 
                      tostring(result), 
                      result == test.expected and "PASS" or "FAIL"))
end

-- Run tests for is_odd function
print("\nTesting is_odd function:")
local is_odd_results = {
  { value = 1, expected = true },
  { value = 3, expected = true },
  { value = 2, expected = false },
  { value = 4, expected = false },
  { value = 0, expected = false }
}

for _, test in ipairs(is_odd_results) do
  local result = example_module.is_odd(test.value)
  print(string.format("  is_odd(%d) -> %s - %s", 
                      test.value, 
                      tostring(result), 
                      result == test.expected and "PASS" or "FAIL"))
end

-- Run tests for categorize_number function
print("\nTesting categorize_number function:")
local categorize_results = {
  { value = "hello", expected = "not a number" },
  { value = {}, expected = "not a number" },
  { value = nil, expected = "not a number" },
  { value = -1, expected = "negative" },
  { value = -10, expected = "negative" },
  { value = 0, expected = "zero" },
  { value = 5, expected = "small positive" },
  { value = 15, expected = "large positive" }
}

for _, test in ipairs(categorize_results) do
  local result = example_module.categorize_number(test.value)
  print(string.format("  categorize_number(%s) -> %s - %s", 
                      tostring(test.value), 
                      tostring(result), 
                      result == test.expected and "PASS" or "FAIL"))
end

-- Stop coverage tracking
print("\nStopping coverage tracking...")
coverage.stop()

-- Generate and display a coverage report
if coverage then
  -- First, get a summary report for the console
  print("\nCoverage Report Summary:")
  local report = coverage.report("summary")
  print(report)

  -- Generate detailed HTML report
  local html_path = "/tmp/coverage_example_report.html"
  local success = coverage.save_report(html_path, "html")
  
  if success then
    print("\nHTML coverage report saved to: " .. html_path)
    
    -- Try to open the report in the browser automatically
    if is_windows() then
      os.execute('start "" "' .. html_path .. '"')
    elseif package.config:match("^/") then -- Unix-like
      local _, err = os.execute('xdg-open "' .. html_path .. '" > /dev/null 2>&1 &')
      if err then
        os.execute('open "' .. html_path .. '" > /dev/null 2>&1 &')
      end
      print("(Report should open automatically in browser)")
    end
    
    -- Also save in the standard location
    local standard_path = "./coverage-reports/coverage-example.html"
    coverage.save_report(standard_path, "html")
    print("Additional copy saved to: " .. standard_path)
  else
    print("Failed to generate HTML report")
  end
  
  -- Check if we meet the coverage threshold
  local report_data = coverage.get_report_data()
  if report_data and report_data.summary.overall_percent >= 70 then
    print("\nCoverage meets the threshold of 70%!")
    print("Overall coverage: " .. string.format("%.2f%%", report_data.summary.overall_percent))
  else
    print("\nWarning: Coverage is below the threshold of 70%!")
    if report_data then
      print("Overall coverage: " .. string.format("%.2f%%", report_data.summary.overall_percent))
    end
  end
end

-- Run this example with coverage enabled:
-- lua examples/coverage_example.lua
-- 
-- Or from command line:
-- lua firmo.lua --coverage --discover-uncovered=true --source-dirs=".,examples" examples/coverage_example.lu
