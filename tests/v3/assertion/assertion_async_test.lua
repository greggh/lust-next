-- Tests for async assertion tracking using source instrumentation
local data_store = require("lib.coverage.v3.runtime.data_store")
local transformer = require("lib.coverage.v3.instrumentation.transformer")
local tracker = require("lib.coverage.v3.runtime.tracker")
local test_helper = require("lib.tools.test_helper")

-- Now load firmo and get test functions
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local it_async = firmo.it_async
local async = firmo.async
local parallel_async = firmo.parallel_async

-- Create tracking functions in global scope
__firmo_v3_track_function_entry = tracker.__firmo_v3_track_function_entry
__firmo_v3_track_line = tracker.__firmo_v3_track_line
__firmo_v3_track_assertion = tracker.__firmo_v3_track_assertion

describe("Async Assertion Mapping", function()
  -- Reset coverage data before each test
  before(function()
    -- Reset coverage tracking
    data_store.reset()
    tracker.reset()
    
    -- Create calculator table
    calculator = {}
    
    -- Transform calculator module
    local source = [[
      function calculator.add(a, b)
        return a + b
      end
      
      function calculator.subtract(a, b)
        return a - b
      end
      
      function calculator.multiply(a, b)
        return a * b
      end
      
      function calculator.divide(a, b)
        if b == 0 then
          error("Division by zero")
        end
        return a / b
      end
    ]]
    
    local instrumented = transformer.transform(source, "lib/samples/calculator.lua")
    local chunk, err = load(instrumented)
    if not chunk then
      error("Failed to load instrumented code: " .. tostring(err))
    end
    chunk()
  end)
  
  after(function()
    -- Clean up global
    calculator = nil
  end)
  
  it_async("should map assertions in async context", function()
    -- Create async operation that uses calculator
    local async_calc = async(function(a, b)
      local cleanup = __firmo_v3_track_assertion("lib/samples/calculator.lua", 1)
      __firmo_v3_track_line("lib/samples/calculator.lua", 1)
      __firmo_v3_track_function_entry("lib/samples/calculator.lua", 1)
      local result = calculator.add(a, b)
      cleanup()
      return result
    end)
    
    -- Run async operation and verify result
    local result = async_calc(5, 3)()
    expect(result).to.equal(8)
    
    -- Get mappings for calculator.lua
    local mappings = data_store.get_assertion_mappings("lib/samples/calculator.lua")
    
    -- Should have one assertion
    expect(#mappings).to.equal(1)
    
    -- Assertion should map to add function
    local found_add = false
    for _, covered in ipairs(mappings[1].covered_lines) do
      if covered.line == 1 then found_add = true; break end
    end
    expect(found_add).to.be_truthy()
  end)

  it_async("should map assertions in parallel operations", async(function()
    -- Create parallel operations
    local ops = {
      async(function()
        local cleanup = __firmo_v3_track_assertion("lib/samples/calculator.lua", 9)
        __firmo_v3_track_line("lib/samples/calculator.lua", 9)
        __firmo_v3_track_function_entry("lib/samples/calculator.lua", 9)
        local result = calculator.multiply(4, 5)
        cleanup()
        return result
      end)(),
      async(function()
        local cleanup = __firmo_v3_track_assertion("lib/samples/calculator.lua", 13)
        __firmo_v3_track_line("lib/samples/calculator.lua", 13)
        __firmo_v3_track_function_entry("lib/samples/calculator.lua", 13)
        local result = calculator.divide(10, 2)
        cleanup()
        return result
      end)()
    }
    
    -- Run in parallel
    local results = parallel_async(ops)
    
    -- Verify results
    expect(results[1]).to.equal(20)
    expect(results[2]).to.equal(5)
    
    -- Get mappings for calculator.lua
    local mappings = data_store.get_assertion_mappings("lib/samples/calculator.lua")
    
    -- Should have two assertions
    expect(#mappings).to.equal(2)
    
    -- Should map to multiply and divide functions
    local found_multiply = false
    local found_divide = false
    for _, assertion in ipairs(mappings) do
      for _, covered in ipairs(assertion.covered_lines) do
        if covered.line == 9 then found_multiply = true end
        if covered.line == 13 then found_divide = true end
      end
    end
    expect(found_multiply).to.be_truthy()
    expect(found_divide).to.be_truthy()
  end))

  it_async("should map assertions in callbacks", function()
    -- Create async operation with callback
    local function async_with_callback(callback)
      local cleanup = __firmo_v3_track_assertion("lib/samples/calculator.lua", 5)
      __firmo_v3_track_line("lib/samples/calculator.lua", 5)
      __firmo_v3_track_function_entry("lib/samples/calculator.lua", 5)
      local result = calculator.subtract(10, 4)
      cleanup()
      callback(result)
    end
    
    -- Run operation and make assertion in callback
    local done = false
    async_with_callback(function(result)
      expect(result).to.equal(6)
      done = true
    end)
    
    -- Wait for callback
    firmo.wait_until(function() return done end)
    
    -- Get mappings for calculator.lua
    local mappings = data_store.get_assertion_mappings("lib/samples/calculator.lua")
    
    -- Should have one assertion
    expect(#mappings).to.equal(1)
    
    -- Should map to subtract function
    local found_subtract = false
    for _, covered in ipairs(mappings[1].covered_lines) do
      if covered.line == 5 then found_subtract = true; break end
    end
    expect(found_subtract).to.be_truthy()
  end)
end)