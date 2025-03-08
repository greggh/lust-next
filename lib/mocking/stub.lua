-- stub.lua - Function stubbing implementation for lust-next

local spy = require("lib.mocking.spy")
local stub = {}

-- Helper function to add sequential return values implementation
local function add_sequence_methods(stub_obj, implementation, sequence_table)
  -- Add sequence tracking to the stub object
  stub_obj._sequence_values = sequence_table or nil
  stub_obj._sequence_index = 1
  stub_obj._sequence_cycles = false
  stub_obj._sequence_exhausted_behavior = "nil" -- Options: nil, fallback, custom
  stub_obj._sequence_exhausted_value = nil
  
  -- Store the original implementation in case sequences are exhausted
  stub_obj._original_implementation = implementation
  
  -- Modify the implementation to use sequence values if available
  local function sequence_implementation(...)
    if stub_obj._sequence_values and #stub_obj._sequence_values > 0 then
      -- Get the current value from the sequence
      local current_index = stub_obj._sequence_index
      
      -- Handle cycling more robustly
      if current_index > #stub_obj._sequence_values then
        if stub_obj._sequence_cycles then
          -- Apply modular arithmetic to wrap around to the beginning of the sequence
          -- This formula ensures we go from 1 to length and back to 1 (Lua's 1-based indexing)
          current_index = ((current_index - 1) % #stub_obj._sequence_values) + 1
          stub_obj._sequence_index = current_index
        else
          -- If not cycling and sequence is exhausted, return nil or fallback value if set
          if stub_obj._sequence_exhausted_behavior == "fallback" and stub_obj._original_implementation then
            return stub_obj._original_implementation(...)
          elseif stub_obj._sequence_exhausted_value ~= nil then
            return stub_obj._sequence_exhausted_value
          else
            -- Default behavior: return nil when sequence exhausted
            stub_obj._sequence_index = current_index + 1
            return nil
          end
        end
      end
      
      -- Get the value
      local value = stub_obj._sequence_values[current_index]
      
      -- Advance to the next value in the sequence
      stub_obj._sequence_index = current_index + 1
      
      -- If value is a function, call it with the arguments
      if type(value) == "function" then
        return value(...)
      else
        return value
      end
    else
      -- Use the original implementation if no sequence values
      return stub_obj._original_implementation(...)
    end
  end
  
  return sequence_implementation
end

-- Create a standalone stub function
function stub.new(return_value_or_implementation)
  local implementation
  if type(return_value_or_implementation) == "function" then
    implementation = return_value_or_implementation
  else
    implementation = function() return return_value_or_implementation end
  end
  
  local stub_obj = spy.new(implementation)
  stub_obj._is_lust_stub = true
  
  -- Add stub-specific methods
  function stub_obj:returns(value)
    -- Create a function that returns the value
    local new_impl = function() return value end
    
    -- Create a new stub with the implementation
    local new_stub = stub.new(new_impl)
    
    -- Copy important properties
    for k, v in pairs(self) do
      if k ~= "calls" and k ~= "call_count" and k ~= "called" and k ~= "call_sequence" then
        new_stub[k] = v
      end
    end
    
    return new_stub
  end
  
  function stub_obj:throws(error_message)
    -- Create a function that throws the error
    local new_impl = function() error(error_message, 2) end
    
    -- Create a new stub with the implementation
    local new_stub = stub.new(new_impl)
    
    -- Copy important properties
    for k, v in pairs(self) do
      if k ~= "calls" and k ~= "call_count" and k ~= "called" and k ~= "call_sequence" then
        new_stub[k] = v
      end
    end
    
    return new_stub
  end
  
  -- Add method for sequential return values
  function stub_obj:returns_in_sequence(values)
    if type(values) ~= "table" then
      error("returns_in_sequence requires a table of values")
    end
    
    -- Create a spy with sequence implementation
    local sequence_impl = add_sequence_methods(self, implementation, values)
    local new_stub = stub.new(sequence_impl)
    
    -- Copy sequence properties
    new_stub._sequence_values = values
    new_stub._sequence_index = 1
    new_stub._original_implementation = implementation
    
    -- Copy other important properties
    for k, v in pairs(self) do
      if k ~= "calls" and k ~= "call_count" and k ~= "called" and k ~= "call_sequence" and
         k ~= "_sequence_values" and k ~= "_sequence_index" and k ~= "_original_implementation" then
        new_stub[k] = v
      end
    end
    
    return new_stub
  end
  
  -- Add method to enable cycling through sequence values
  function stub_obj:cycle_sequence(enable)
    if enable == nil then enable = true end
    self._sequence_cycles = enable
    return self
  end
  
  -- Add method to specify behavior when sequence is exhausted
  function stub_obj:when_exhausted(behavior, custom_value)
    if behavior == "nil" then
      self._sequence_exhausted_behavior = "nil"
      self._sequence_exhausted_value = nil
    elseif behavior == "fallback" then
      self._sequence_exhausted_behavior = "fallback"
    elseif behavior == "custom" then
      self._sequence_exhausted_behavior = "custom"
      self._sequence_exhausted_value = custom_value
    else
      error("Invalid exhausted behavior. Use 'nil', 'fallback', or 'custom'")
    end
    return self
  end
  
  -- Add method to reset sequence to the beginning
  function stub_obj:reset_sequence()
    self._sequence_index = 1
    return self
  end
  
  return stub_obj
end

-- Create a stub for an object method
function stub.on(obj, method_name, return_value_or_implementation)
  if type(obj) ~= "table" then
    error("stub.on requires a table as its first argument")
  end
  
  if not obj[method_name] then
    error("stub.on requires a method name that exists on the object")
  end
  
  local original_fn = obj[method_name]
  
  -- Create the stub
  local implementation
  if type(return_value_or_implementation) == "function" then
    implementation = return_value_or_implementation
  else
    implementation = function() return return_value_or_implementation end
  end
  
  local stub_obj = spy.new(implementation)
  stub_obj._is_lust_stub = true
  stub_obj.target = obj
  stub_obj.name = method_name
  stub_obj.original = original_fn
  
  -- Add restore method
  function stub_obj:restore()
    if self.target and self.name then
      self.target[self.name] = self.original
    end
  end
  
  -- Add stub-specific methods
  function stub_obj:returns(value)
    -- Create a new stub
    local new_stub = stub.on(obj, method_name, function() return value end)
    return new_stub
  end
  
  function stub_obj:throws(error_message)
    -- Create a new stub
    local new_stub = stub.on(obj, method_name, function() error(error_message, 2) end)
    return new_stub
  end
  
  -- Add method for sequential return values
  function stub_obj:returns_in_sequence(values)
    if type(values) ~= "table" then
      error("returns_in_sequence requires a table of values")
    end
    
    -- Create a sequence implementation
    local sequence_impl = add_sequence_methods({}, implementation, values)
    
    -- Create a new stub with the sequence implementation
    local new_stub = stub.on(obj, method_name, function(...)
      return sequence_impl(...)
    end)
    
    -- Copy sequence properties
    new_stub._sequence_values = values
    new_stub._sequence_index = 1
    new_stub._original_implementation = implementation
    
    return new_stub
  end
  
  -- Add method to enable cycling through sequence values
  function stub_obj:cycle_sequence(enable)
    if enable == nil then enable = true end
    self._sequence_cycles = enable
    return self
  end
  
  -- Add method to specify behavior when sequence is exhausted
  function stub_obj:when_exhausted(behavior, custom_value)
    if behavior == "nil" then
      self._sequence_exhausted_behavior = "nil"
      self._sequence_exhausted_value = nil
    elseif behavior == "fallback" then
      self._sequence_exhausted_behavior = "fallback"
    elseif behavior == "custom" then
      self._sequence_exhausted_behavior = "custom"
      self._sequence_exhausted_value = custom_value
    else
      error("Invalid exhausted behavior. Use 'nil', 'fallback', or 'custom'")
    end
    return self
  end
  
  -- Add method to reset sequence to the beginning
  function stub_obj:reset_sequence()
    self._sequence_index = 1
    return self
  end
  
  -- Replace the method with our stub
  obj[method_name] = stub_obj
  
  return stub_obj
end

return stub