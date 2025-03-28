-- Tests for assertion tracking in v3 coverage system
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local data_store = require("lib.coverage.v3.runtime.data_store")
local analyzer = require("lib.coverage.v3.assertion.analyzer")

describe("Assertion Tracking", function()
  -- Reset coverage data before each test
  firmo.before(function()
    data_store.reset()
  end)
  
  it("should track lines verified by simple assertions", function()
    -- Define a simple function to test
    local function add(a, b)
      return a + b
    end
    
    -- Make an assertion that should verify the function
    expect(add(2, 3)).to.equal(5)
    
    -- Get coverage data
    local file = debug.getinfo(1, "S").source:sub(2)  -- Current file
    local data = data_store.get_file_data(file)
    
    -- The function definition and body should be covered
    expect(data_store.get_line_state(file, debug.getinfo(add).linedefined)).to.equal("covered")
    expect(data_store.get_line_state(file, debug.getinfo(add).lastlinedefined)).to.equal("covered")
  end)
  
  it("should track lines verified by chained assertions", function()
    -- Define an object with properties
    local obj = {
      name = "test",
      value = 42
    }
    
    -- Make chained assertions
    expect(obj).to.have.property("name")
    expect(obj).to.have.property("value", 42)
    
    -- Get coverage data
    local file = debug.getinfo(1, "S").source:sub(2)
    local data = data_store.get_file_data(file)
    
    -- The object definition lines should be covered
    local obj_line = debug.getinfo(1).currentline - 7  -- Line where obj is defined
    expect(data_store.get_line_state(file, obj_line)).to.equal("covered")
    expect(data_store.get_line_state(file, obj_line + 1)).to.equal("covered")
    expect(data_store.get_line_state(file, obj_line + 2)).to.equal("covered")
  end)
  
  it("should track lines verified by nested function assertions", function()
    -- Define nested functions
    local function outer(x)
      local function inner(y)
        return x + y
      end
      return inner
    end
    
    -- Make assertions that verify both functions
    local inner = outer(5)
    expect(inner(3)).to.equal(8)
    
    -- Get coverage data
    local file = debug.getinfo(1, "S").source:sub(2)
    local data = data_store.get_file_data(file)
    
    -- Both function definitions and bodies should be covered
    local outer_info = debug.getinfo(outer)
    local inner_info = debug.getinfo(inner)
    
    expect(data_store.get_line_state(file, outer_info.linedefined)).to.equal("covered")
    expect(data_store.get_line_state(file, outer_info.lastlinedefined)).to.equal("covered")
    expect(data_store.get_line_state(file, inner_info.linedefined)).to.equal("covered")
    expect(data_store.get_line_state(file, inner_info.lastlinedefined)).to.equal("covered")
  end)
end)