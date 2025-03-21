-- Enhanced type checking for firmo
-- Implements advanced type and class validation features

---@class type_checking
---@field is_exact_type fun(value: any, expected_type: string, message?: string): boolean
---@field is_instance_of fun(object: table, class: table, message?: string): boolean
---@field implements fun(object: table, interface: table, message?: string): boolean
---@field contains fun(container: table|string, item: any, message?: string): boolean
---@field has_error fun(fn: function, message?: string): string|table
local type_checking = {}

---@param value any The value to check the type of
---@param expected_type string The expected type name (e.g., 'string', 'number', 'table')
---@param message? string Optional custom error message
---@return boolean true If the type matches (otherwise throws an error)
---@error if type doesn't match the expected_type
-- Checks if an object is exactly of the specified primitive type
function type_checking.is_exact_type(value, expected_type, message)
  local actual_type = type(value)

  if actual_type ~= expected_type then
    local default_message =
      string.format("Expected value to be exactly of type '%s', but got '%s'", expected_type, actual_type)
    error(message or default_message, 2)
  end

  return true
end

---@param object table The object to check
---@param class table The class/metatable to check against
---@param message? string Optional custom error message
---@return boolean true If object is an instance of class (otherwise throws an error)
---@error if object is not an instance of class
-- Check if an object is an instance of a class (metatable-based)
function type_checking.is_instance_of(object, class, message)
  -- Validate arguments
  if type(object) ~= "table" then
    ---@diagnostic disable-next-line: ambiguity-1
    error(message or "Expected object to be a table (got " .. type(object) .. ")", 2)
  end

  if type(class) ~= "table" then
    ---@diagnostic disable-next-line: ambiguity-1
    error(message or "Expected class to be a metatable (got " .. type(class) .. ")", 2)
  end

  -- Get object's metatable
  local mt = getmetatable(object)

  -- No metatable means it's not an instance of anything
  if not mt then
    local default_message =
      string.format("Expected object to be an instance of %s, but it has no metatable", class.__name or tostring(class))
    error(message or default_message, 2)
    return false
  end

  -- Check if object's metatable matches the class directly
  if mt == class then
    return true
  end

    -- Handle inheritance: Check if any metatable in the hierarchy is the class
  -- Check both metatable.__index (for inheritance) and getmetatable(metatable) for inheritance
  ---@param meta table The metatable to check
  ---@param target_class table The target class to compare against
  ---@param seen? table Table to track already seen metatables (prevents infinite recursion)
  ---@return boolean true if meta is or inherits from target_class
  local function check_inheritance_chain(meta, target_class, seen)
    seen = seen or {}
    if not meta or seen[meta] then
      return false
    end
    seen[meta] = true

    -- Check direct match
    if meta == target_class then
      return true
    end

    -- Check __index (for inheritance via __index)
    if type(meta.__index) == "table" then
      if meta.__index == target_class then
        return true
      end
      if check_inheritance_chain(meta.__index, target_class, seen) then
        return true
      end
    end

    -- Check parent metatable (for meta-inheritance)
    local parent_mt = getmetatable(meta)
    if parent_mt then
      if parent_mt == target_class then
        return true
      end
      if check_inheritance_chain(parent_mt, target_class, seen) then
        return true
      end
    end

    return false
  end

  -- Check all inheritance paths
  if check_inheritance_chain(mt, class) then
    return true
  end

  -- If we got here, the object is not an instance of the class
  local class_name = class.__name or tostring(class)
  local object_class = mt.__name or tostring(mt)
  local default_message =
    string.format("Expected object to be an instance of %s, but it is an instance of %s", class_name, object_class)

  error(message or default_message, 2)
end

---@param object table The object to check
---@param interface table Table defining the required methods and properties
---@param message? string Optional custom error message
---@return boolean true If object implements all interface requirements (otherwise throws an error)
---@error if object doesn't implement interface requirements
-- Check if an object implements all the required interface methods and properties
function type_checking.implements(object, interface, message)
  -- Validate arguments
  if type(object) ~= "table" then
    ---@diagnostic disable-next-line: ambiguity-1
    error(message or "Expected object to be a table (got " .. type(object) .. ")", 2)
  end

  if type(interface) ~= "table" then
    ---@diagnostic disable-next-line: ambiguity-1
    error(message or "Expected interface to be a table (got " .. type(interface) .. ")", 2)
  end

  local missing_keys = {}
  local wrong_types = {}

  -- Check all interface requirements
  for key, expected in pairs(interface) do
    local actual = object[key]

    if actual == nil then
      table.insert(missing_keys, key)
    elseif type(expected) ~= type(actual) then
      table.insert(wrong_types, key)
    end
  end

  -- If we found any issues, report them
  if #missing_keys > 0 or #wrong_types > 0 then
    local default_message = "Object does not implement interface: "

    if #missing_keys > 0 then
      default_message = default_message .. "missing: " .. table.concat(missing_keys, ", ")
    end

    if #wrong_types > 0 then
      if #missing_keys > 0 then
        default_message = default_message .. "; "
      end
      default_message = default_message .. "wrong types: " .. table.concat(wrong_types, ", ")
    end

    error(message or default_message, 2)
  end

  return true
end

---@param container table|string The container to check (either a table or string)
---@param item any The item to look for in the container
---@param message? string Optional custom error message
---@return boolean true If container contains item (otherwise throws an error)
---@error if container doesn't contain item
-- Enhanced contains implementation that works with both tables and strings
function type_checking.contains(container, item, message)
  -- For tables, check if the item exists as a value
  if type(container) == "table" then
    for _, value in pairs(container) do
      if value == item then
        return true
      end
    end

    -- If we got here, the item wasn't found
    local default_message = string.format("Expected table to contain %s", tostring(item))
    error(message or default_message, 2)

  -- For strings, check substring containment
  elseif type(container) == "string" then
    -- Convert item to string if needed
    local item_str = tostring(item)

    if not string.find(container, item_str, 1, true) then
      local default_message = string.format("Expected string '%s' to contain '%s'", container, item_str)
      error(message or default_message, 2)
    end

    return true
  else
    error("Cannot check containment in a " .. type(container), 2)
  end
end

---@param fn function The function to test (should throw an error when called)
---@param message? string Optional custom error message if function doesn't throw
---@return string|table error The error value returned by the function
---@error if function doesn't throw an error
-- Helper function to check if a function throws an error
function type_checking.has_error(fn, message)
  if type(fn) ~= "function" then
    error("Expected a function to test for errors", 2)
  end

  local ok, err = pcall(fn)

  if ok then
    error(message or "Expected function to throw an error, but it did not", 2)
  end

  return err
end

return type_checking
