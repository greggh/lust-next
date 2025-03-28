-- Tests for mapping assertions to covered code
local hook = require("lib.coverage.v3.assertion.hook")
local assertion = require("lib.assertion")
local data_store = require("lib.coverage.v3.runtime.data_store")
local analyzer = require("lib.coverage.v3.assertion.analyzer")
local tracker = require("lib.coverage.v3.runtime.tracker")
local calculator = require("lib.samples.calculator")
local test_helper = require("lib.tools.test_helper")

-- Install hooks before loading firmo
hook.install()

-- Now load firmo and get test functions
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Assertion Mapping", function()
  -- Reset coverage data before each test
  firmo.before(function()
    data_store.reset()
    analyzer.reset()
    tracker.reset()
    hook.reset()
    tracker.start()
    hook.install()
    
    -- Register calculator functions
    hook.register_function(calculator.add, "add")
    hook.register_function(calculator.subtract, "subtract")
    hook.register_function(calculator.multiply, "multiply")
    hook.register_function(calculator.divide, "divide")
  end)
  
  firmo.after(function()
    tracker.stop()
  end)
  
  it("should map assertions to calculator functions", function()
    -- Test calculator functions
    expect(calculator.add(5, 3)).to.equal(8)
    expect(calculator.subtract(10, 4)).to.equal(6)
    
    -- Get mappings for calculator.lua
    local mappings = hook.get_assertion_mappings("lib/samples/calculator.lua")
    
    -- Should have two assertions
    expect(#mappings).to.equal(2)
    
    -- First assertion should map to add function
    local found_add = false
    for _, prop in ipairs(mappings[1].properties) do
      if prop == "add" then found_add = true; break end
    end
    expect(found_add).to.be_truthy()
    
    -- Second assertion should map to subtract function
    local found_subtract = false
    for _, prop in ipairs(mappings[2].properties) do
      if prop == "subtract" then found_subtract = true; break end
    end
    expect(found_subtract).to.be_truthy()
  end)

  it("should map assertions to calculator error paths", { expect_error = true }, function()
    -- Test divide by zero error
    local result, err = test_helper.with_error_capture(function()
      return calculator.divide(10, 0)
    end)()
    
    -- Verify error was captured
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Division by zero")
    
    -- Get mappings for calculator.lua
    local mappings = hook.get_assertion_mappings("lib/samples/calculator.lua")
    
    -- Should have one assertion
    expect(#mappings).to.equal(1)
    
    -- Assertion should map to divide function
    local found_divide = false
    for _, prop in ipairs(mappings[1].properties) do
      if prop == "divide" then found_divide = true; break end
    end
    expect(found_divide).to.be_truthy()
    
    -- Should include error check line
    local found_error_line = false
    for _, line in ipairs(mappings[1].lines) do
      if line == 20 then -- Line number of error check in calculator.lua
        found_error_line = true
        break
      end
    end
    expect(found_error_line).to.be_truthy()
  end)
  
  it("should map assertions to calculator function bodies", function()
    -- Test multiply function
    expect(calculator.multiply(5, 4)).to.equal(20)
    
    -- Get mappings for calculator.lua
    local mappings = hook.get_assertion_mappings("lib/samples/calculator.lua")
    
    -- Should have one assertion
    expect(#mappings).to.equal(1)
    
    -- Assertion should map to multiply function
    local found_multiply = false
    for _, prop in ipairs(mappings[1].properties) do
      if prop == "multiply" then found_multiply = true; break end
    end
    expect(found_multiply).to.be_truthy()
    
    -- Should include function body lines
    local found_body_line = false
    for _, line in ipairs(mappings[1].lines) do
      if line == 17 then -- Line number of result = a * b in calculator.lua
        found_body_line = true
        break
      end
    end
    expect(found_body_line).to.be_truthy()
  end)
end)
