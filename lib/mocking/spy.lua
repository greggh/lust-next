-- spy.lua - Function spying implementation for lust-next

local spy = {}

-- Helper functions
local function is_spy(obj)
  return type(obj) == "table" and obj._is_lust_spy == true
end

-- Deep comparison of tables for equality
local function tables_equal(t1, t2)
  if type(t1) ~= "table" or type(t2) ~= "table" then
    return t1 == t2
  end
  
  -- Check each key-value pair in t1
  for k, v in pairs(t1) do
    if not tables_equal(v, t2[k]) then
      return false
    end
  end
  
  -- Check for any extra keys in t2
  for k, _ in pairs(t2) do
    if t1[k] == nil then
      return false
    end
  end
  
  return true
end

-- Helper to check if value matches another value with matcher support
local function matches_arg(expected, actual)
  -- If expected is a matcher, use its match function
  if type(expected) == "table" and expected._is_matcher then
    return expected.match(actual)
  end
  
  -- If both are tables, do deep comparison
  if type(expected) == "table" and type(actual) == "table" then
    return tables_equal(expected, actual)
  end
  
  -- Otherwise do direct comparison
  return expected == actual
end

-- Check if args match a set of expected args
local function args_match(expected_args, actual_args)
  if #expected_args ~= #actual_args then
    return false
  end
  
  for i, expected in ipairs(expected_args) do
    if not matches_arg(expected, actual_args[i]) then
      return false
    end
  end
  
  return true
end

-- Create a new spy function
function spy.new(fn)
  fn = fn or function() end
  
  local spy_obj = {
    _is_lust_spy = true,
    calls = {},
    called = false,
    call_count = 0,
    call_sequence = {}, -- For sequence tracking
    call_history = {}   -- For backward compatibility
  }
  
  -- Function that captures all calls
  local function capture(...)
    -- Update call tracking state
    spy_obj.called = true
    spy_obj.call_count = spy_obj.call_count + 1
    
    -- Record arguments
    local args = {...}
    table.insert(spy_obj.calls, args)
    table.insert(spy_obj.call_history, args)
    
    -- Sequence tracking for order verification
    if not _G._lust_next_sequence_counter then
      _G._lust_next_sequence_counter = 0
    end
    _G._lust_next_sequence_counter = _G._lust_next_sequence_counter + 1
    
    -- Store sequence number
    local sequence_number = _G._lust_next_sequence_counter
    table.insert(spy_obj.call_sequence, sequence_number)
    
    -- Call the original function
    return fn(...)
  end
  
  -- Set up the spy's call method
  setmetatable(spy_obj, {
    __call = function(_, ...)
      return capture(...)
    end
  })
  
  -- Add spy methods, both as instance methods and properties
  -- Define helper methods
  local function make_method_callable_prop(obj, method_name, method_fn)
    obj[method_name] = setmetatable({}, {
      __call = function(_, ...)
        return method_fn(obj, ...)
      end
    })
  end
  
  -- Define the called_with method
  function spy_obj:called_with(...)
    local expected_args = {...}
    local found = false
    local matching_call_index = nil
    
    for i, call_args in ipairs(self.calls) do
      if args_match(expected_args, call_args) then
        found = true
        matching_call_index = i
        break
      end
    end
    
    -- If no matching call was found, return false
    if not found then
      return false
    end
    
    -- Return an object with chainable methods
    local result = {
      result = true,
      call_index = matching_call_index
    }
    
    -- Make it work in boolean contexts
    setmetatable(result, {
      __call = function() return true end,
      __tostring = function() return "true" end
    })
    
    return result
  end
  make_method_callable_prop(spy_obj, "called_with", spy_obj.called_with)
  
  -- Define the called_times method  
  function spy_obj:called_times(n)
    return self.call_count == n
  end
  make_method_callable_prop(spy_obj, "called_times", spy_obj.called_times)
  
  -- Define the not_called method
  function spy_obj:not_called()
    return self.call_count == 0
  end
  make_method_callable_prop(spy_obj, "not_called", spy_obj.not_called)
  
  -- Define the called_once method
  function spy_obj:called_once()
    return self.call_count == 1
  end
  make_method_callable_prop(spy_obj, "called_once", spy_obj.called_once)
  
  -- Define the last_call method
  function spy_obj:last_call()
    if #self.calls > 0 then
      return self.calls[#self.calls]
    end
    return nil
  end
  make_method_callable_prop(spy_obj, "last_call", spy_obj.last_call)
  
  -- Check if this spy was called before another spy
  function spy_obj:called_before(other_spy, call_index)
    call_index = call_index or 1
    
    -- Safety checks
    if not other_spy or type(other_spy) ~= "table" then
      error("called_before requires a spy object as argument")
    end
    
    if not other_spy.call_sequence then
      error("called_before requires a spy object with call_sequence")
    end
    
    -- Make sure both spies have been called
    if self.call_count == 0 or other_spy.call_count == 0 then
      return false
    end
    
    -- Make sure other_spy has been called enough times
    if other_spy.call_count < call_index then
      return false
    end
    
    -- Get sequence number of the other spy's call
    local other_sequence = other_spy.call_sequence[call_index]
    if not other_sequence then
      return false
    end
    
    -- Check if any of this spy's calls happened before that
    for _, sequence in ipairs(self.call_sequence) do
      if sequence < other_sequence then
        return true
      end
    end
    
    return false
  end
  make_method_callable_prop(spy_obj, "called_before", spy_obj.called_before)
  
  -- Check if this spy was called after another spy
  function spy_obj:called_after(other_spy, call_index)
    call_index = call_index or 1
    
    -- Safety checks
    if not other_spy or type(other_spy) ~= "table" then
      error("called_after requires a spy object as argument")
    end
    
    if not other_spy.call_sequence then
      error("called_after requires a spy object with call_sequence")
    end
    
    -- Make sure both spies have been called
    if self.call_count == 0 or other_spy.call_count == 0 then
      return false
    end
    
    -- Make sure other_spy has been called enough times
    if other_spy.call_count < call_index then
      return false
    end
    
    -- Get sequence of the other spy's call
    local other_sequence = other_spy.call_sequence[call_index]
    if not other_sequence then
      return false
    end
    
    -- Check if any of this spy's calls happened after that
    local last_self_sequence = self.call_sequence[self.call_count]
    if last_self_sequence > other_sequence then
      return true
    end
    
    return false
  end
  make_method_callable_prop(spy_obj, "called_after", spy_obj.called_after)
  
  return spy_obj
end

-- Create a spy on an object method
function spy.on(obj, method_name)
  if type(obj) ~= "table" then
    error("spy.on requires a table as its first argument")
  end
  
  if type(obj[method_name]) ~= "function" then
    error("spy.on requires a method name that exists on the object")
  end
  
  local original_fn = obj[method_name]
  
  local spy_obj = spy.new(original_fn)
  spy_obj.target = obj
  spy_obj.name = method_name
  spy_obj.original = original_fn
  
  -- Add restore method
  function spy_obj:restore()
    if self.target and self.name then
      self.target[self.name] = self.original
    end
  end
  
  -- Create a table that will be both callable and have all spy properties
  local wrapper = {
    calls = spy_obj.calls,
    called = spy_obj.called,
    call_count = spy_obj.call_count,
    call_sequence = spy_obj.call_sequence,
    call_history = spy_obj.call_history,
    
    -- Copy methods
    restore = function() 
      return spy_obj:restore() 
    end,
    called_with = function(self, ...) 
      return spy_obj:called_with(...) 
    end,
    called_times = function(self, n) 
      return spy_obj:called_times(n) 
    end,
    not_called = function(self) 
      return spy_obj:not_called() 
    end,
    called_once = function(self) 
      return spy_obj:called_once() 
    end,
    last_call = function(self) 
      return spy_obj:last_call() 
    end,
    called_before = function(self, other, idx) 
      return spy_obj:called_before(other, idx) 
    end,
    called_after = function(self, other, idx) 
      return spy_obj:called_after(other, idx) 
    end
  }
  
  -- Make it callable
  setmetatable(wrapper, {
    __call = function(_, ...)
      -- When called, update our wrapper's properties too
      local result = spy_obj(...)
      wrapper.called = spy_obj.called
      wrapper.call_count = spy_obj.call_count
      return result
    end
  })
  
  -- Replace the method with our spy wrapper
  obj[method_name] = wrapper
  
  return wrapper
end

-- Create and record the call sequence used for spy.on and spy.new methods
spy._next_sequence = 0
spy._new_sequence = function()
  spy._next_sequence = spy._next_sequence + 1
  return spy._next_sequence
end

return spy