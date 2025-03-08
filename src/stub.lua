-- stub.lua - Function stubbing implementation for lust-next

local spy = require("src.spy")
local stub = {}

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
  
  -- Replace the method with our stub
  obj[method_name] = stub_obj
  
  return stub_obj
end

return stub