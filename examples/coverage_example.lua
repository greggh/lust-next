-- Example to demonstrate coverage tracking functionality
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")

-- Extract testing functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- OS detection helper function (needed for browser opening)
local function is_windows()
  return package.config:sub(1, 1) == "\\"
end

-- A sample module to demonstrate coverage analysis
local MathUtilities = {}

-- A simple function to check if a number is even
MathUtilities.is_even = function(n)
  if type(n) ~= "number" then
    return nil, error_handler.validation_error(
      "Input must be a number",
      {parameter = "n", provided_type = type(n)}
    )
  end
  return n % 2 == 0
end

-- A function to check if a number is odd
MathUtilities.is_odd = function(n)
  if type(n) ~= "number" then
    return nil, error_handler.validation_error(
      "Input must be a number",
      {parameter = "n", provided_type = type(n)}
    )
  end
  return n % 2 ~= 0
end

-- Function with different paths to demonstrate branch coverage
MathUtilities.categorize_number = function(n)
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

-- A function we intentionally won't test to show incomplete coverage
MathUtilities.unused_function = function(n)
  return n * n
end

-- Tests for the math utilities module
describe("MathUtilities Module Tests", function()
  -- Test is_even function with valid inputs
  describe("is_even", function()
    it("correctly identifies even numbers", function()
      expect(MathUtilities.is_even(2)).to.equal(true)
      expect(MathUtilities.is_even(4)).to.equal(true)
      expect(MathUtilities.is_even(0)).to.equal(true)
    end)

    it("correctly identifies non-even numbers", function()
      expect(MathUtilities.is_even(1)).to.equal(false)
      expect(MathUtilities.is_even(3)).to.equal(false)
      expect(MathUtilities.is_even(-5)).to.equal(false)
    end)

    it("handles invalid input", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return MathUtilities.is_even("not a number")
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("must be a number")
    end)
  end)

  -- Test is_odd function
  describe("is_odd", function()
    it("correctly identifies odd numbers", function()
      expect(MathUtilities.is_odd(1)).to.equal(true)
      expect(MathUtilities.is_odd(3)).to.equal(true)
      expect(MathUtilities.is_odd(-7)).to.equal(true)
    end)

    it("correctly identifies non-odd numbers", function()
      expect(MathUtilities.is_odd(2)).to.equal(false)
      expect(MathUtilities.is_odd(4)).to.equal(false)
      expect(MathUtilities.is_odd(0)).to.equal(false)
    end)

    it("handles invalid input", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return MathUtilities.is_odd({})
      end)()

      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("must be a number")
    end)
  end)

  -- Test categorize_number (purposely incomplete coverage)
  describe("categorize_number", function()
    it("handles non-numbers", function()
      expect(MathUtilities.categorize_number("hello")).to.equal("not a number")
      expect(MathUtilities.categorize_number({})).to.equal("not a number")
      expect(MathUtilities.categorize_number(nil)).to.equal("not a number")
    end)

    it("identifies negative numbers", function()
      expect(MathUtilities.categorize_number(-1)).to.equal("negative")
      expect(MathUtilities.categorize_number(-10)).to.equal("negative")
    end)

    it("identifies zero", function()
      expect(MathUtilities.categorize_number(0)).to.equal("zero")
    end)

    it("identifies small positive numbers", function()
      expect(MathUtilities.categorize_number(5)).to.equal("small positive")
    end)

    -- Note: We don't test the "large positive" branch
    -- This will intentionally show up as incomplete coverage
  end)

  -- Note: We don't test unused_function at all
  -- This will show up as a completely uncovered function
end)

print("\n=== Coverage Example ===")
print("To run this example with coverage enabled, use the command:")
print("lua test.lua --coverage --pattern=MathUtilities examples/coverage_example.lua")
print("\nThis will generate a coverage report showing:")
print("1. Fully covered functions (is_even, is_odd)")
print("2. Partially covered function (categorize_number)")
print("3. Completely uncovered function (unused_function)")
print("\nThe coverage report will show:")
print("- Line-by-line execution counts")
print("- Branch coverage gaps")
print("- Overall coverage percentage")
print("- Files that aren't covered at all\n")