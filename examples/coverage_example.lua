-- Example to demonstrate coverage tracking
local lust_next = require('lust-next')

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
    assert(example_module.is_even(2))
    assert(example_module.is_even(4))
    assert(example_module.is_even(0))
    assert(not example_module.is_even(1))
    assert(not example_module.is_even(3))
  end)
  
  -- Test is_odd
  it("should correctly identify odd numbers", function()
    assert(example_module.is_odd(1))
    assert(example_module.is_odd(3))
    assert(not example_module.is_odd(2))
    assert(not example_module.is_odd(4))
    assert(not example_module.is_odd(0))
  end)
  
  -- Test categorize_number (partially)
  describe("categorize_number", function()
    it("should handle non-numbers", function()
      assert.equal(example_module.categorize_number("hello"), "not a number")
      assert.equal(example_module.categorize_number({}), "not a number")
      assert.equal(example_module.categorize_number(nil), "not a number")
    end)
    
    it("should identify negative numbers", function()
      assert.equal(example_module.categorize_number(-1), "negative")
      assert.equal(example_module.categorize_number(-10), "negative")
    end)
    
    it("should identify zero", function()
      assert.equal(example_module.categorize_number(0), "zero")
    end)
    
    -- Note: We don't test the "small positive" or "large positive" branches
    -- This will show up as incomplete coverage
  end)
  
  -- Note: We don't test the unused_function at all
  -- This will show up as a completely uncovered function
end)

-- Enable coverage with comprehensive options
lust_next.coverage_options = {
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

-- Start coverage tracking 
if lust_next.start_coverage then
  lust_next.start_coverage()
end

-- Run all the tests
lust_next.run() -- This will run all the tests defined above

-- Stop coverage tracking
if lust_next.stop_coverage then
  lust_next.stop_coverage()
end

-- Generate and display a coverage report
if lust_next.generate_coverage_report then
  print("\nCoverage Report:")
  local report = lust_next.generate_coverage_report("summary")
  print(report)
  
  -- Check if we meet the coverage threshold
  if lust_next.coverage_meets_threshold(70) then
    print("\nCoverage meets the threshold!")
  else
    print("\nWarning: Coverage is below the threshold!")
  end
  
  -- Generate an HTML report
  local success = lust_next.save_coverage_report("./coverage-reports/enhanced-example.html", "html")
  if success then
    print("\nHTML coverage report saved to: ./coverage-reports/enhanced-example.html")
  end
end

-- Run this example with coverage enabled:
-- lua examples/coverage_example.lua
-- 
-- Or from command line:
-- lua lust-next.lua --coverage --discover-uncovered=true --source-dirs=".,examples" examples/coverage_example.lua