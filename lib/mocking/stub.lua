--[[
    stub.lua - Function stubbing implementation for the Firmo testing framework
    
    This module provides robust function stubbing capabilities for test isolation and behavior verification.
    Stubs replace real functions with test doubles that have pre-programmed behavior.
    
    Features:
    - Create standalone stub functions that return specified values
    - Replace object methods with stubs that can be restored later
    - Configure stubs to throw errors for testing error handling
    - Return values in sequence to simulate changing behavior over time
    - Advanced sequence control with cycling and exhaustion handling
    - Integration with the spy system for call tracking and verification
    - Automatic restoration of original methods
    
    @module stub
    @author Firmo Team
    @license MIT
    @copyright 2023-2025
]]

---@class stub_module
---@field _VERSION string Module version
---@field new fun(value_or_fn?: any): stub_object Create a new stub function that returns a specified value or uses custom implementation
---@field on fun(obj: table, method_name: string, return_value_or_implementation: any): stub_object Replace an object's method with a stub
---@field create fun(implementation?: function): stub_object Create a new stub with a custom implementation (alias for new)
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
---@field returns_in_sequence fun(values: table): stub_object Configure stub to return values from a sequence
---@field cycle_sequence fun(enable?: boolean): stub_object Configure whether sequence cycles when exhausted
---@field when_exhausted fun(behavior: string, custom_value?: any): stub_object Configure sequence exhaustion behavior
---@field reset_sequence fun(): stub_object Reset sequence to the beginning
---@field returns_async fun(value: any, delay?: number): stub_object Configure stub to return a value asynchronously
---@field set_sequence_behavior fun(options: {cycles?: boolean, exhausted_behavior?: string, exhausted_value?: any}): stub_object Configure sequence behavior
---@field restore fun(): void Restore the original method (for stubs created with stub.on)
---@field target table|nil The object that contains the stubbed method
---@field name string|nil Name of the method being stubbed
---@field original function|nil Original method implementation before stubbing
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
--- Helper function to add sequential return values implementation
--- Creates a function that returns values from sequence_table one by one.
--- This sophisticated sequence handler provides:
--- - Returns values from the sequence in order
--- - Configurable cycling behavior (restart from beginning when exhausted)
--- - Custom exhaustion behavior (nil, fallback to original, custom value)
--- - Support for function values in the sequence (called with arguments)
--- - Error handling and detailed logging
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

--- Create a standalone stub function that returns a specified value or uses a custom implementation
--- This is the primary function for creating stubs that aren't attached to existing objects.
--- The created stub inherits all spy functionality and adds stub-specific methods.
---
--- @param return_value_or_implementation any Value to return when stub is called, or function to use as implementation
--- @return stub_object stub A new stub function object that can be called like a normal function
--- 
--- @usage
--- -- Create a stub that returns a fixed value
--- local my_stub = stub.new("fixed value")
--- 
--- -- Create a stub with custom implementation
--- local custom_stub = stub.new(function(arg1, arg2)
---   return arg1 * arg2
--- end)
--- 
--- -- Configure further with chaining
--- local advanced_stub = stub.new()
---   :returns_in_sequence({1, 2, 3})
---   :cycle_sequence(true)
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
  
  --- Configure the stub to return a specific fixed value
  --- Creates a new stub that returns the specified value regardless of arguments
  --- 
  --- @param value any The value to return when the stub is called
  --- @return stub_object A new stub configured to return the specified value
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
  
  --- Configure the stub to throw an error when called
  --- Creates a new stub that throws the specified error message or object
  --- Used for testing error handling code paths
  ---
  --- @param error_message string|table The error message or error object to throw
  --- @return stub_object A new stub configured to throw the specified error
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
  
  --- Configure the stub to return values from a sequence in order
  --- Creates a new stub that returns each value from the provided table in sequence,
  --- one value per call. Useful for simulating changing behavior over time.
  ---
  --- @param values table An array of values to return in sequence
  --- @return stub_object A new stub configured with sequence behavior
  --- 
  --- @usage
  --- -- Create a stub that returns values in sequence
  --- local seq_stub = stub.new():returns_in_sequence({"first", "second", "third"})
  --- 
  --- -- By default, returns nil after the sequence is exhausted
  --- print(seq_stub()) -- "first"
  --- print(seq_stub()) -- "second"
  --- print(seq_stub()) -- "third"
  --- print(seq_stub()) -- nil (sequence exhausted)
  --- 
  --- -- Can be combined with other sequence options:
  --- local cycling_stub = stub.new()
  ---   :returns_in_sequence({1, 2, 3})
  ---   :cycle_sequence(true)
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
  
  --- Configure whether the sequence of return values should cycle
  --- When enabled, after the last value in the sequence is returned,
  --- the stub will start again from the first value. When disabled,
  --- the exhausted behavior determines what happens when the sequence ends.
  ---
  --- @param enable boolean Whether to enable cycling (defaults to true)
  --- @return stub_object The same stub object for method chaining
  function stub_obj:cycle_sequence(enable)
    if enable == nil then enable = true end
    self._sequence_cycles = enable
    return self
  end
  
  --- Specify behavior when a sequence is exhausted (no more values to return)
  --- Controls what the stub returns after all sequence values have been used
  --- and cycling is disabled. Three options are available:
  --- - "nil": Return nil (default behavior)
  --- - "fallback": Use the original implementation
  --- - "custom": Return a custom value
  ---
  --- @param behavior string The behavior when sequence is exhausted: "nil", "fallback", or "custom"
  --- @param custom_value any The value to return when behavior is "custom"
  --- @return stub_object The same stub object for method chaining
  --- 
  --- @usage
  --- -- Return nil when sequence is exhausted (default)
  --- stub:when_exhausted("nil")
  --- 
  --- -- Fall back to original implementation
  --- stub:when_exhausted("fallback")
  --- 
  --- -- Return a custom value
  --- stub:when_exhausted("custom", "sequence complete")
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
  
  --- Reset sequence to the beginning
  --- Sets the sequence index back to 1, so the next call will return
  --- the first value in the sequence again.
  ---
  --- @return stub_object The same stub object for method chaining
  function stub_obj:reset_sequence()
    logger.debug("Resetting stub sequence to beginning")
    self._sequence_index = 1
    return self
  end
  
  return stub_obj
end

--- Create a stub for an object method, replacing the original method temporarily
--- This function replaces a method on an object with a stub that tracks calls and provides
--- pre-programmed behavior. The original method is preserved and can be restored later.
---
--- @param obj table The object containing the method to stub
--- @param method_name string The name of the method to stub
--- @param return_value_or_implementation any Value to return when stub is called, or function to use as implementation
--- @return stub_object stub A stub object that tracks calls and controls method behavior
---
--- @usage
--- -- Replace a method with a stub that returns 42
--- local my_obj = { calculate = function() return 10 end }
--- local calc_stub = stub.on(my_obj, "calculate", 42)
--- 
--- -- Replace with custom implementation
--- stub.on(logger, "warn", function(msg) print("STUBBED: " .. msg) end)
--- 
--- -- Create a stub that throws an error
--- local error_stub = stub.on(file_system, "read", function() 
---   error("Simulated IO error") 
--- end)
--- 
--- -- Restore the original method
--- calc_stub:restore()
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
  
  --- Restore the original method that was replaced by the stub
  --- This undoes the stubbing, replacing the stub with the original method
  --- implementation that existed before stubbing. After restoration, calling
  --- the method will execute the original behavior.
  ---
  --- @return nil
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
  
  --- Configure the stub to return a specific fixed value
  --- Creates a new stub that returns the specified value regardless of arguments
  --- 
  --- @param value any The value to return when the stub is called
  --- @return stub_object A new stub configured to return the specified value
  function stub_obj:returns(value)
    -- Create a new stub
    local new_stub = stub.on(obj, method_name, function() return value end)
    return new_stub
  end
  
  --- Configure the stub to throw an error when called
  --- Creates a new stub that throws the specified error message or object
  --- Uses structured error objects with TEST_EXPECTED category when error_handler is available
  ---
  --- @param error_message string|table The error message or error object to throw
  --- @return stub_object A new stub configured to throw the specified error
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
  
  --- Configure the stub to return values from a sequence in order
  --- Creates a new stub that returns each value from the provided table in sequence,
  --- one value per call. Useful for simulating changing behavior over time.
  ---
  --- @param values table An array of values to return in sequence
  --- @return stub_object A new stub configured with sequence behavior
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
  
  --- Configure whether the sequence of return values should cycle
  --- When enabled, after the last value in the sequence is returned,
  --- the stub will start again from the first value. When disabled,
  --- the exhausted behavior determines what happens when the sequence ends.
  ---
  --- @param enable boolean Whether to enable cycling (defaults to true)
  --- @return stub_object The same stub object for method chaining
  function stub_obj:cycle_sequence(enable)
    if enable == nil then enable = true end
    self._sequence_cycles = enable
    return self
  end
  
  --- Specify behavior when a sequence is exhausted (no more values to return)
  --- Controls what the stub returns after all sequence values have been used
  --- and cycling is disabled. Three options are available:
  --- - "nil": Return nil (default behavior)
  --- - "fallback": Use the original implementation
  --- - "custom": Return a custom value
  ---
  --- @param behavior string The behavior when sequence is exhausted: "nil", "fallback", or "custom"
  --- @param custom_value any The value to return when behavior is "custom"
  --- @return stub_object The same stub object for method chaining
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
  
  --- Reset sequence to the beginning
  --- Sets the sequence index back to 1, so the next call will return
  --- the first value in the sequence again.
  ---
  --- @return stub_object The same stub object for method chaining
  function stub_obj:reset_sequence()
    self._sequence_index = 1
    return self
  end
  
  -- Replace the method with our stub
  obj[method_name] = stub_obj
  
  return stub_obj
end

return stub
