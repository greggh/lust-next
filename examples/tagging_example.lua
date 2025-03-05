-- Example demonstrating test tagging and filtering
package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

-- Process command-line arguments for this example
local tags, filter
for i = 1, #arg do
  if arg[i] == "--tags" and arg[i+1] then
    tags = {}
    for tag in arg[i+1]:gmatch("[^,]+") do
      table.insert(tags, tag:match("^%s*(.-)%s*$"))
    end
  elseif arg[i] == "--filter" and arg[i+1] then
    filter = arg[i+1]
  end
end

-- Apply filters if provided
if tags then
  -- Use table.unpack for Lua 5.2+ or unpack for Lua 5.1
  local unpack_func = table.unpack or unpack
  lust_next.only_tags(unpack_func(tags))
end
if filter then
  lust_next.filter(filter)
end

-- To show tagging in action, run this file with:
-- lua tagging_example.lua                (runs all tests)
-- lua tagging_example.lua --tags unit    (runs only unit tests)
-- lua tagging_example.lua --tags api     (runs only api tests)
-- lua tagging_example.lua --filter calc  (runs tests with "calc" in name)

-- This represents a simple calculator API we're testing
local calculator = {
  add = function(a, b) return a + b end,
  subtract = function(a, b) return a - b end,
  multiply = function(a, b) return a * b end,
  divide = function(a, b) 
    if b == 0 then error("Cannot divide by zero") end
    return a / b 
  end
}

describe("Calculator Tests", function()
  describe("Basic Operations", function()
    -- Tag tests as "unit" and "fast"
    lust_next.tags("unit", "fast")
    
    it("adds two numbers correctly", function()
      expect(calculator.add(2, 3)).to.equal(5)
    end)
    
    it("subtracts two numbers correctly", function()
      expect(calculator.subtract(5, 3)).to.equal(2)
    end)
    
    it("multiplies two numbers correctly", function()
      expect(calculator.multiply(2, 3)).to.equal(6)
    end)
    
    it("divides two numbers correctly", function()
      expect(calculator.divide(6, 2)).to.equal(3)
    end)
  end)
  
  describe("Error Handling", function()
    -- Tag these tests as "unit" and "error-handling"
    lust_next.tags("unit", "error-handling")
    
    it("throws error when dividing by zero", function()
      expect(function() calculator.divide(5, 0) end).to.fail.with("Cannot divide by zero")
    end)
  end)
  
  describe("Advanced Calculations", function()
    -- Tag these tests as "api" and "slow"
    lust_next.tags("api", "slow")
    
    it("performs complex calculation pipeline", function()
      local result = calculator.add(
        calculator.multiply(3, 4),
        calculator.divide(10, 2)
      )
      expect(result).to.equal(17)
    end)
    
    it("handles negative number operations", function()
      expect(calculator.add(-5, 3)).to.equal(-2)
      expect(calculator.multiply(-2, -3)).to.equal(6)
    end)
  end)
end)