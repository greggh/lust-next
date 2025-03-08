-- mock.lua - Object mocking implementation for lust-next

local spy = require("lib.mocking.spy")
local stub = require("lib.mocking.stub")

local mock = {}
local _mocks = {}

-- Helper function to check if a table is a mock
local function is_mock(obj)
  return type(obj) == "table" and obj._is_lust_mock == true
end

-- Helper function to register a mock for cleanup
local function register_mock(mock_obj)
  table.insert(_mocks, mock_obj)
  return mock_obj
end

-- Helper function to restore all mocks
function mock.restore_all()
  for _, mock_obj in ipairs(_mocks) do
    mock_obj:restore()
  end
  _mocks = {}
end

-- Convert value to string representation for error messages
local function value_to_string(value, max_depth)
  max_depth = max_depth or 3
  if max_depth < 0 then return "..." end
  
  if type(value) == "string" then
    return '"' .. value .. '"'
  elseif type(value) == "table" then
    if max_depth == 0 then return "{...}" end
    
    local parts = {}
    for k, v in pairs(value) do
      local key_str = type(k) == "string" and k or "[" .. tostring(k) .. "]"
      table.insert(parts, key_str .. " = " .. value_to_string(v, max_depth - 1))
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
  elseif type(value) == "function" then
    return "function(...)"
  else
    return tostring(value)
  end
end

-- Format args for error messages
local function format_args(args)
  local parts = {}
  for i, arg in ipairs(args) do
    if type(arg) == "table" and arg._is_matcher then
      table.insert(parts, arg.description)
    else
      table.insert(parts, value_to_string(arg))
    end
  end
  return table.concat(parts, ", ")
end

-- Create a mock object with verifiable behavior
function mock.create(target, options)
  options = options or {}
  
  local mock_obj = {
    _is_lust_mock = true,
    target = target,
    _stubs = {},
    _originals = {},
    _expectations = {},
    _verify_all_expectations_called = options.verify_all_expectations_called ~= false
  }
  
  -- Method to stub a function with a return value or implementation
  function mock_obj:stub(name, implementation_or_value)
    if not self.target[name] then
      error("Cannot stub non-existent method '" .. name .. "'")
    end
    
    self._originals[name] = self.target[name]
    
    -- Create the stub
    local stub_obj
    if type(implementation_or_value) == "function" then
      stub_obj = stub.on(self.target, name, implementation_or_value)
    else
      stub_obj = stub.on(self.target, name, function() return implementation_or_value end)
    end
    
    self._stubs[name] = stub_obj
    return self
  end
  
  -- Method to stub a function with sequential return values
  function mock_obj:stub_in_sequence(name, sequence_values)
    if not self.target[name] then
      error("Cannot stub non-existent method '" .. name .. "'")
    end
    
    if type(sequence_values) ~= "table" then
      error("stub_in_sequence requires a table of values")
    end
    
    self._originals[name] = self.target[name]
    
    -- Create the stub with sequential return values
    local stub_obj = stub.on(self.target, name, function() end)
    stub_obj = stub_obj:returns_in_sequence(sequence_values)
    
    self._stubs[name] = stub_obj
    return stub_obj -- Return the stub for method chaining
  end
  
  -- Restore a specific stub
  function mock_obj:restore_stub(name)
    if self._originals[name] then
      self.target[name] = self._originals[name]
      self._originals[name] = nil
      self._stubs[name] = nil
    end
    return self
  end
  
  -- Restore all stubs for this mock
  function mock_obj:restore()
    for name, _ in pairs(self._originals) do
      self.target[name] = self._originals[name]
    end
    self._stubs = {}
    self._originals = {}
    return self
  end
  
  -- Verify all expected stubs were called
  function mock_obj:verify()
    local failures = {}
    
    if self._verify_all_expectations_called then
      for name, stub in pairs(self._stubs) do
        if not stub.called then
          table.insert(failures, "Expected '" .. name .. "' to be called, but it was not")
        end
      end
    end
    
    if #failures > 0 then
      error("Mock verification failed:\n  " .. table.concat(failures, "\n  "), 2)
    end
    
    return true
  end
  
  -- Register for auto-cleanup
  register_mock(mock_obj)
  
  return mock_obj
end

-- Context manager for mocks that auto-restores
function mock.with_mocks(fn)
  -- Keep a local registry of all mocks created within this context
  local context_mocks = {}
  
  -- Track function result and error
  local ok, result, error_during_restore
  
  -- Create a mock function wrapper compatible with example usage
  local mock_fn = function(target, method_name, impl_or_value)
    if method_name then
      -- Called as mock_fn(obj, "method", impl)
      local mock_obj = mock.create(target)
      mock_obj:stub(method_name, impl_or_value)
      table.insert(context_mocks, mock_obj)
      return mock_obj
    else
      -- Called as mock_fn(obj)
      local mock_obj = mock.create(target)
      table.insert(context_mocks, mock_obj)
      return mock_obj
    end
  end
  
  -- Run the function with mocking modules
  ok, result = pcall(function()
    -- Create stub.on and spy.on wrappers that register created objects
    local context_spy = {
      new = spy.new,
      on = function(obj, method_name)
        local spy_obj = spy.on(obj, method_name)
        table.insert(context_mocks, spy_obj)
        return spy_obj
      end
    }
    
    local context_stub = {
      new = stub.new,
      on = function(obj, method_name, value_or_impl)
        local stub_obj = stub.on(obj, method_name, value_or_impl)
        table.insert(context_mocks, stub_obj)
        return stub_obj
      end
    }
    
    -- Create a mock wrapper that registers created objects
    local context_mock = {
      create = function(target, options)
        local mock_obj = mock.create(target, options)
        table.insert(context_mocks, mock_obj)
        return mock_obj
      end
    }
    
    -- Call the function with our wrappers
    -- Support both calling styles:
    -- with_mocks(function(mock_fn)) -- for old/example style 
    -- with_mocks(function(mock, spy, stub)) -- for new style
    return fn(mock_fn, context_spy, context_stub)
  end)
  
  -- Always restore mocks, even on failure
  for _, mock_obj in ipairs(context_mocks) do
    -- Use pcall to ensure we restore all mocks even if one fails
    local restore_ok, restore_err = pcall(function() 
      if mock_obj.restore then
        mock_obj:restore() 
      end
    end)
    
    -- If restoration fails, capture the error but continue
    if not restore_ok then
      error_during_restore = error_during_restore or {}
      table.insert(error_during_restore, "Error restoring mock: " .. tostring(restore_err))
    end
  end
  
  -- If there was an error during the function execution
  if not ok then
    error(result, 2)
  end
  
  -- If there was an error during mock restoration, report it
  if error_during_restore then
    error("Errors occurred during mock restoration:\n" .. table.concat(error_during_restore, "\n"), 2)
  end
  
  -- Return the result from the function
  return result
end

return mock