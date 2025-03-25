-- Minimal Coverage Test
-- Tests basic calculator functions without any special coverage code

local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Simply require the calculator module to test it
local calculator = require("lib.samples.calculator")

describe("Calculator Test Suite", function()
  it("should add numbers correctly", function()
    local result = calculator.add(3, 5)
    expect(result).to.equal(8)
  end)
  
  it("should subtract numbers correctly", function()
    local result = calculator.subtract(10, 4)
    expect(result).to.equal(6)
  end)
  
  it("should multiply numbers correctly", function()
    local result = calculator.multiply(2, 3)
    expect(result).to.equal(6)
  end)
  
  it("should divide numbers correctly", function()
    local result = calculator.divide(10, 2)
    expect(result).to.equal(5)
  end)
  
  it("should throw an error when dividing by zero", function()
    expect(function()
      calculator.divide(5, 0)
    end).to.fail()
  end)
end)