-- Test fixtures for common Lua errors
-- This file contains functions that produce common Lua errors
-- for testing error handling and debugging functionality

local fixtures = {}

-- Generate a nil access error
function fixtures.nil_access()
  local t = nil
  return t.property -- Accessing property of nil value
end

-- Generate a type error
function fixtures.type_error()
  local num = 42
  return num:upper() -- Attempting to call method on number
end

-- Generate an arithmetic error
function fixtures.arithmetic_error()
  return 1 / 0 -- Division by zero
end

-- Generate an out of memory error (controlled)
function fixtures.out_of_memory(limit)
  limit = limit or 1000000 -- Default to reasonable limit to avoid actual OOM
  local t = {}
  for i = 1, limit do
    table.insert(t, string.rep("x", 100))
    if i % 10000 == 0 then
      collectgarbage("collect")
      -- Check if we're getting close to memory limits
      -- and abort early if needed
      if collectgarbage("count") > 1000000 then
        return t, "Memory limit approached"
      end
    end
  end
  return t
end

-- Generate a stack overflow error (controlled)
function fixtures.stack_overflow(depth)
  depth = depth or 5000 -- Default to reasonable depth to avoid actual crash
  
  local function recurse(n)
    if n <= 0 then return 0 end
    return 1 + recurse(n - 1)
  end
  
  return recurse(depth)
end

-- Generate an assertion error
function fixtures.assertion_error()
  assert(false, "This is an assertion error")
end

-- Generate an error with custom message
function fixtures.custom_error(message)
  error(message or "This is a custom error", 2)
end

-- Generate a runtime error from Lua code
function fixtures.runtime_error()
  local code = "function x() local y = 1 + 'string' end; x()"
  return load(code)()
end

-- Generate a function that takes a long time to execute
function fixtures.slow_function(seconds)
  seconds = seconds or 1
  local start = os.time()
  while os.time() - start < seconds do
    -- Busy wait
  end
  return "Completed after " .. seconds .. " seconds"
end

-- Generate a memory leak scenario
function fixtures.memory_leak(iterations)
  iterations = iterations or 10
  
  -- This is a controlled leak for testing leak detection
  _G._test_leak_storage = _G._test_leak_storage or {}
  
  for i = 1, iterations do
    table.insert(_G._test_leak_storage, string.rep("leak test data", 1000))
  end
  
  return #_G._test_leak_storage
end

-- Clear the memory leak test data
function fixtures.clear_leak_data()
  _G._test_leak_storage = nil
  collectgarbage("collect")
end

-- Generate an upvalue capture error
function fixtures.upvalue_capture_error()
  local t = {value = 10}
  local function outer()
    return function()
      return t.missing_field.something
    end
  end
  
  return outer()()
end

-- Generate a table with circular reference
function fixtures.circular_reference()
  local t = {}
  t.self = t
  return t
end

-- Generate a protected call error
function fixtures.pcall_error()
  return select(2, pcall(function() error("Error inside pcall") end))
end

return fixtures