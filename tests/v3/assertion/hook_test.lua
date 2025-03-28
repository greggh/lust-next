-- Assertion hook tests
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local assertion_hook = require("lib.coverage.v3.assertion.hook")
local optimized_store = require("lib.coverage.v3.runtime.optimized_store")
local logging = require("lib.tools.logging")

local describe, it = firmo.describe, firmo.it
local before, after = firmo.before, firmo.after

-- Initialize module logger
local logger = logging.get_logger("tests.v3.assertion.hook_test")

describe("Coverage v3 Assertion Hook", function()
  before(function()
    -- Reset data store and hooks before each test
    optimized_store.reset()
    assertion_hook.uninstall()  -- Ensure clean state
    
    -- Save original expect function
    local original_expect = firmo.expect
    
    -- Install hooks and verify installation
    local installed = assertion_hook.install()
    assert(installed, "Failed to install assertion hooks")
    
    -- Verify that expect is hooked
    assert(original_expect ~= firmo.expect, "expect function was not hooked")
  end)
  
  after(function()
    -- Uninstall hooks after each test
    assertion_hook.uninstall()
  end)

  it("should track assertions and mark lines as covered", function()
    -- Define a function to test
    local function add(a, b)
      return a + b
    end
    
    -- Test the function with assertions
    local result = add(2, 3)
    local line_before = debug.getinfo(1, "l").currentline
    firmo.expect(result).to.equal(5)  -- Use firmo.expect directly
    local line_after = debug.getinfo(1, "l").currentline
    
    -- Get coverage data
    local info = debug.getinfo(1, "S")
    print("Debug info:", info.source, info.short_src, info.what)
    local file = info.source:sub(2)  -- Current file
    print("File path:", file)
    local data = optimized_store.get_file_data(file)
    print("Coverage data:", data)
    
    -- Verify that data was recorded
    assert(data, "No coverage data was recorded")
    
    -- Print all line states for debugging
    print("\nAll line states:")
    for line = line_before - 10, line_before + 10 do
      local state = optimized_store.get_line_state(file, line)
      print(string.format("Line %d: %s", line, state))
    end
    
    print("\nFunction info:")
    local add_info = debug.getinfo(add)
    print(string.format("add() defined at line %d", add_info.linedefined))
    print(string.format("add() current line %d", add_info.currentline))
    print(string.format("add() last line %d", add_info.lastlinedefined))
    local add_state = optimized_store.get_line_state(file, add_info.linedefined)
    print(string.format("add() definition state: %s", add_state))
    
    -- Print call info
    local call_line = line_before - 1  -- Line with add(2, 3)
    print("\nCall info:")
    print(string.format("Call line: %d", call_line))
    local call_state = optimized_store.get_line_state(file, call_line)
    print(string.format("Call line state: %s", call_state))
    
    -- Print assertion info
    local assertion_line = line_before + 1  -- Line with expect()
    print("\nAssertion info:")
    print(string.format("Assertion line: %d", assertion_line))
    local assertion_state = optimized_store.get_line_state(file, assertion_line)
    print(string.format("Assertion line state: %s", assertion_state))
    
    -- Verify states
    assert(assertion_state == "covered", "Assertion line should be covered")
    assert(call_state == "covered", "Call line should be covered")
  end)

  it("should track assertions through function calls", function()
    -- Define some functions to test
    local function c(x)
      return x * 2
    end
    
    local function b(x)
      return c(x + 1)
    end
    
    local function a(x)
      return b(x + 1)
    end
    
    -- Test the functions with assertions
    local result = a(1)  -- ((1 + 1) + 1) * 2 = 6
    local line_before = debug.getinfo(1, "l").currentline
    firmo.expect(result).to.equal(6)  -- Use firmo.expect directly
    local line_after = debug.getinfo(1, "l").currentline
    
    -- Get coverage data
    local file = debug.getinfo(1, "S").source:sub(2)  -- Current file
    local data = optimized_store.get_file_data(file)
    
    -- Print function info
    print("\nFunction info:")
    local c_info = debug.getinfo(c)
    local b_info = debug.getinfo(b)
    local a_info = debug.getinfo(a)
    
    print(string.format("c() defined at line %d", c_info.linedefined))
    print(string.format("b() defined at line %d", b_info.linedefined))
    print(string.format("a() defined at line %d", a_info.linedefined))
    
    local c_state = optimized_store.get_line_state(file, c_info.linedefined)
    local b_state = optimized_store.get_line_state(file, b_info.linedefined)
    local a_state = optimized_store.get_line_state(file, a_info.linedefined)
    
    print(string.format("c() definition state: %s", c_state))
    print(string.format("b() definition state: %s", b_state))
    print(string.format("a() definition state: %s", a_state))
    
    -- Print all line states for debugging
    print("\nAll line states:")
    for line = a_info.linedefined - 5, a_info.lastlinedefined + 5 do
      local state = optimized_store.get_line_state(file, line)
      print(string.format("Line %d: %s", line, state))
    end
    
    -- Verify states
    assert(c_state == "covered", "Function c should be covered")
    assert(b_state == "covered", "Function b should be covered")
    assert(a_state == "covered", "Function a should be covered")
  end)

  it("should handle failed assertions gracefully", { expect_error = true }, function()
    -- Try an assertion that will fail
    local line_before = debug.getinfo(1, "l").currentline
    local result, err = test_helper.with_error_capture(function()
      firmo.expect(1).to.equal(2)  -- Use firmo.expect directly
    end)()
    local line_after = debug.getinfo(1, "l").currentline
    
    assert(not result, "Expected assertion to fail")
    assert(err, "Expected error to be returned")
    assert(err.message:match("expected 1 to equal 2"), "Wrong error message")
    
    -- Get coverage data
    local file = debug.getinfo(1, "S").source:sub(2)  -- Current file
    local data = optimized_store.get_file_data(file)
    
    logger.debug("Coverage data for failed assertion", {
      file = file,
      data = data,
      assertion_line = line_before + 2
    })
    
    assert(data, "No coverage data was recorded")
    
    -- The assertion line should be executed but not covered (since it failed)
    local assertion_line = line_before + 2  -- Line with expect()
    local state = optimized_store.get_line_state(file, assertion_line)
    assert(state == "executed", "Failed assertion line should be executed but not covered")
  end)

  it("should handle missing debug info gracefully", function()
    -- Create a function with no debug info
    local fn = load("return function(x) return x end")()
    
    -- Test the function
    local result = fn(42)
    local line_before = debug.getinfo(1, "l").currentline
    firmo.expect(result).to.equal(42)  -- Use firmo.expect directly
    local line_after = debug.getinfo(1, "l").currentline
    
    -- The assertion should still work even though we can't track the function
    local file = debug.getinfo(1, "S").source:sub(2)  -- Current file
    local assertion_line = line_before + 1  -- Line with expect()
    
    logger.debug("Coverage data for missing debug info", {
      file = file,
      data = optimized_store.get_file_data(file),
      assertion_line = assertion_line
    })
    
    local state = optimized_store.get_line_state(file, assertion_line)
    assert(state == "covered", "Assertion line should be covered")
  end)
end)