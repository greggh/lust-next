-- stub.lua - Function stubbing implementation for firmo

---@class stub_module
---@field _VERSION string Module version
---@field new fun(value_or_fn?: any): stub_object Create a new stub function that returns a specified value
---@field create fun(implementation?: function): stub_object Create a new stub with a custom implementation
---@field sequence fun(values: table): stub_object Create a stub that returns values in sequence
---@field from_spy fun(spy_obj: table): stub_object Create a stub from an existing spy object
---@field is_stub fun(obj: any): boolean Check if an object is a stub
---@field reset_all fun(): boolean Reset all created stubs to their initial state

---@class stub_object : spy_object
---@field returns fun(value: any): stub_object Configure stub to return a specific value
---@field returns_self fun(): stub_object Configure stub to return itself (for method chaining)
---@field returns_nil fun(): stub_object Configure stub to return nil
---@field returns_true fun(): stub_object Configure stub to return true
---@field returns_false fun(): stub_object Configure stub to return false
---@field returns_function fun(fn: function): stub_object Configure stub to execute a custom function
---@field returns_args fun(index?: number): stub_object Configure stub to return the arguments it receives
---@field throws fun(error_or_message: string|table): stub_object Configure stub to throw an error
---@field returns_sequence fun(values: table): stub_object Configure stub to return values from a sequence
---@field returns_async fun(value: any, delay?: number): stub_object Configure stub to return a value asynchronously
---@field set_sequence_behavior fun(options: {cycles?: boolean, exhausted_behavior?: string, exhausted_value?: any}): stub_object Configure sequence behavior
---@field _is_firmo_stub boolean Flag indicating this is a stub object
---@field _sequence_values table|nil Values to return in sequence
---@field _sequence_index number Current index in the sequence
---@field _sequence_cycles boolean Whether the sequence should cycle when exhausted
---@field _sequence_exhausted_behavior string Behavior when sequence is exhausted ("nil", "fallback", "custom")
---@field _sequence_exhausted_value any Value to return when sequence is exhausted
---@field _original_implementation function Original implementation function

local spy = require("lib.mocking.spy")
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("stub")
logging.configure_from_config("stub")

local stub = {
  -- Module version
  _VERSION = "1.0.0"
}

---@private
---@param stub_obj stub_object The stub object to modify
---@param implementation function The original implementation function
---@param sequence_table table|nil Table of values to return in sequence
---@return function sequence_implementation Function that implements sequence behavior
-- Helper function to add sequential return values implementation
-- Creates a function that returns values from sequence_table one by one
-- Handles cycling, exhaustion behavior, and function values in the sequence
local function add_sequence_methods(stub_obj, implementation, sequence_table)
  logger.debug("Setting up sequence methods for stub", {
    sequence_length = sequence_table and #sequence_table or 0
  })
  
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
      
      logger.debug("Sequence stub called", {
        current_index = current_index,
        sequence_length = #stub_obj._sequence_values,
        cycles_enabled = stub_obj._sequence_cycles
      })
      
      -- Handle cycling more robustly
      if current_index > #stub_obj._sequence_values then
        logger.debug("Sequence exhausted", {
          exhausted_behavior = stub_obj._sequence_exhausted_behavior,
          has_fallback = stub_obj._original_implementation ~= nil,
          has_custom_value = stub_obj._sequence_exhausted_value ~= nil
        })
        
        if stub_obj._sequence_cycles then
          -- Apply modular arithmetic to wrap around to the beginning of the sequence
          -- This formula ensures we go from 1 to length and back to 1 (Lua's 1-based indexing)
          current_index = ((current_index - 1) % #stub_obj._sequence_values) + 1
          stub_obj._sequence_index = current_index
          logger.debug("Cycling to beginning of sequence", {
            new_index = current_index
          })
        else
          -- If not cycling and sequence is exhausted, return nil or fallback value if set
          if stub_obj._sequence_exhausted_behavior == "fallback" and stub_obj._original_implementation then
            logger.debug("Using fallback implementation")
            return stub_obj._original_implementation(...)
          elseif stub_obj._sequence_exhausted_value ~= nil then
            logger.debug("Using custom exhausted value", {
              value_type = type(stub_obj._sequence_exhausted_value)
            })
            return stub_obj._sequence_exhausted_value
          else
            -- Default behavior: return nil when sequence exhausted
            logger.debug("Sequence exhausted, returning nil")
            stub_obj._sequence_index = current_index + 1
            return nil
          end
        end
      end
      
      -- Get the value
      local value = stub_obj._sequence_values[current_index]
      
      -- Advance to the next value in the sequence
      stub_obj._sequence_index = current_index + 1
      
      logger.debug("Returning sequence value", {
        index = current_index,
        value_type = type(value),
        next_index = stub_obj._sequence_index
      })
      
      -- If value is a function, call it with the arguments
      if type(value) == "function" then
        logger.debug("Executing function from sequence")
        return value(...)
      else
        return value
      end
    else
      -- Use the original implementation if no sequence values
      logger.debug("No sequence values, using original implementation")
      return stub_obj._original_implementation(...)
    end
  end
  
  return sequence_implementation
end

---@param return_value_or_implementation any Value to return when stub is called, or function to use as implementation
---@return stub_object stub A new stub function object
-- Create a standalone stub function that returns a specified value
-- or uses a custom implementation if a function is provided
function stub.new(return_value_or_implementation)
  logger.debug("Creating new stub", {
    value_type = type(return_value_or_implementation)
  })
  
  local implementation
  if type(return_value_or_implementation) == "function" then
    implementation = return_value_or_implementation
    logger.debug("Using provided function as implementation")
  else
    implementation = function() return return_value_or_implementation end
    logger.debug("Creating function to return provided value", {
      return_value_type = type(return_value_or_implementation)
    })
  end
  
  local stub_obj = spy.new(implementation)
  stub_obj._is_firmo_stub = true
  
  logger.debug("Created stub object based on spy")
  
  -- Add stub-specific methods
  function stub_obj:returns(value)
    logger.debug("Creating stub that returns fixed value", {
      value_type = type(value)
    })
    
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
    
    logger.debug("Created and configured returns stub")
    return new_stub
  end
  
  function stub_obj:throws(error_message)
    logger.debug("Creating stub that throws error", {
      error_message = error_message
    })
    
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
    
    logger.debug("Created and configured error-throwing stub")
    return new_stub
  end
  
  -- Add method for sequential return values
  function stub_obj:returns_in_sequence(values)
    logger.debug("Creating stub with sequence of return values", {
      is_table = type(values) == "table",
      values_count = type(values) == "table" and #values or 0
    })
    
    if type(values) ~= "table" then
      logger.error("Invalid argument type for returns_in_sequence", {
        expected = "table",
        received = type(values)
      })
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
    
    logger.debug("Created and configured sequence return stub", {
      sequence_length = #values
    })
    
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
    logger.debug("Resetting stub sequence to beginning")
    self._sequence_index = 1
    return self
  end
  
  return stub_obj
end

-- Create a stub for an object method
function stub.on(obj, method_name, return_value_or_implementation)
  logger.debug("Creating stub on object method", {
    obj_type = type(obj),
    method_name = method_name,
    return_value_type = type(return_value_or_implementation)
  })
  
  if type(obj) ~= "table" then
    logger.error("Invalid object type for stub.on", {
      expected = "table",
      actual = type(obj)
    })
    error("stub.on requires a table as its first argument")
  end
  
  if not obj[method_name] then
    logger.error("Method not found on target object", {
      method_name = method_name
    })
    error("stub.on requires a method name that exists on the object")
  end
  
  local original_fn = obj[method_name]
  logger.debug("Original method found", {
    method_name = method_name,
    original_type = type(original_fn)
  })
  
  -- Create the stub
  local implementation
  if type(return_value_or_implementation) == "function" then
    implementation = return_value_or_implementation
    logger.debug("Using provided function as implementation")
  else
    implementation = function() return return_value_or_implementation end
    logger.debug("Creating function to return provided value")
  end
  
  local stub_obj = spy.new(implementation)
  stub_obj._is_firmo_stub = true
  stub_obj.target = obj
  stub_obj.name = method_name
  stub_obj.original = original_fn
  
  -- Add restore method
  function stub_obj:restore()
    logger.debug("Restoring original method", {
      target_type = type(self.target),
      method_name = self.name
    })
    
    if self.target and self.name then
      self.target[self.name] = self.original
      logger.debug("Original method restored successfully")
    else
      logger.warn("Could not restore method - missing target or method name")
    end
  end
  
  -- Add stub-specific methods
  function stub_obj:returns(value)
    -- Create a new stub
    local new_stub = stub.on(obj, method_name, function() return value end)
    return new_stub
  end
  
  function stub_obj:throws(error_message)
    -- Create a new stub using structured error objects with TEST_EXPECTED category
    local new_stub = stub.on(obj, method_name, function() 
      local err
      if error_handler and type(error_handler.test_expected_error) == "function" then
        -- Create a structured test error if error_handler is available
        err = error_handler.test_expected_error(error_message, {
          stub_name = method_name,
          stub_type = "throws",
        })
        error(err, 2)
      else
        -- Fallback to simple error for backward compatibility
        error(error_message, 2) 
      end
    end)
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
