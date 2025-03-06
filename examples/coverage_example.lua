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

-- Run this example with coverage enabled:
-- lua lust-next.lua --coverage examples/coverage_example.lua
-- 
-- Or with specific coverage options:
-- lua lust-next.lua --coverage --coverage-threshold=80 examples/coverage_example.lua