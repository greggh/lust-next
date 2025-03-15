-- Centralized configuration module for firmo
-- Provides a global configuration store with standardized access patterns

-- Directly require error_handler to ensure it's always available
local error_handler = require("lib.tools.error_handler")

-- Module table
local M = {}

-- Configuration storage
local config = {
  values = {}, -- Main configuration values
  schemas = {}, -- Registered schemas by module
  listeners = {}, -- Change listeners by path
  defaults = {} -- Default values by module
}

-- Initialize empty config storage
local function init_config()
  config.values = {}
  config.schemas = {}
  config.listeners = {}
  config.defaults = {}
end

-- Constants
M.DEFAULT_CONFIG_PATH = ".firmo-config.lua"

-- Error categories mapping to error_handler categories
M.ERROR_TYPES = {
  VALIDATION = error_handler.CATEGORY.VALIDATION, -- Schema validation errors
  ACCESS = error_handler.CATEGORY.VALIDATION,     -- Path access errors
  IO = error_handler.CATEGORY.IO,                 -- File I/O errors
  PARSE = error_handler.CATEGORY.PARSE            -- Config file parsing errors
}

-- Helper for generating pathed keys (a.b.c -> ["a"]["b"]["c"])
local function path_to_parts(path)
  if not path or path == "" then return {} end
  
  local parts = {}
  for part in string.gmatch(path, "[^.]+") do
    table.insert(parts, part)
  end
  
  return parts
end

-- Create value at path
local function ensure_path(t, parts)
  if not t or type(t) ~= "table" then
    return nil, error_handler.validation_error(
      "Target must be a table for ensure_path",
      {
        target_type = type(t),
        parts = parts
      }
    )
  end
  
  local current = t
  for i, part in ipairs(parts) do
    if i < #parts then
      current[part] = current[part] or {}
      if type(current[part]) ~= "table" then
        current[part] = {} -- Convert to table if it's not
      end
      current = current[part]
    end
  end
  return current
end

-- Lazy loading of dependencies to avoid circular references
local _logging, _fs

local function get_logging()
  if not _logging then
    local success, logging = pcall(require, "lib.tools.logging")
    _logging = success and logging or nil
  end
  return _logging
end

local function get_fs()
  if not _fs then
    local success, fs = pcall(require, "lib.tools.filesystem")
    _fs = success and fs or nil
  end
  return _fs
end

-- Log helper with structured logging
local function log(level, message, params)
  local logging = get_logging()
  if logging then
    local logger = logging.get_logger("central_config")
    logger[level](message, params or {})
  end
end

-- Deep merge helper (for merging configs)
local function deep_merge(target, source)
  -- Input validation
  if source ~= nil and type(source) ~= "table" then
    return nil, error_handler.validation_error(
      "Source must be a table or nil for deep_merge",
      {
        source_type = type(source),
        operation = "deep_merge"
      }
    )
  end
  
  if source == nil then
    return target
  end
  
  if target ~= nil and type(target) ~= "table" then
    return nil, error_handler.validation_error(
      "Target must be a table or nil for deep_merge",
      {
        target_type = type(target),
        operation = "deep_merge"
      }
    )
  end
  
  if target == nil then
    target = {}
  end
  
  for k, v in pairs(source) do
    if type(v) == "table" and type(target[k]) == "table" then
      local merged_value, err = deep_merge(target[k], v)
      if err then
        return nil, error_handler.validation_error(
          "Failed to merge nested table",
          {
            key = k,
            operation = "deep_merge",
            error = err.message
          }
        )
      end
      target[k] = merged_value
    else
      target[k] = v
    end
  end
  
  return target
end

-- Deep copy helper
local function deep_copy(obj)
  -- Input validation
  if obj ~= nil and type(obj) ~= "table" then
    -- For non-tables, just return the value
    return obj
  end
  
  if obj == nil then
    return nil
  end
  
  local result = {}
  for k, v in pairs(obj) do
    if type(v) == "table" then
      result[k] = deep_copy(v)
    else
      result[k] = v
    end
  end
  
  return result
end

-- Deep compare helper
local function deep_equals(a, b)
  -- Direct comparison for identical references or non-table values
  if a == b then return true end
  
  -- Type checking
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  
  -- Check all keys in a exist in b with equal values
  for k, v in pairs(a) do
    if not deep_equals(v, b[k]) then return false end
  end
  
  -- Check for extra keys in b that don't exist in a
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  
  return true
end

-- Get a value at a specific path
function M.get(path, default)
  -- Parameter validation
  if path ~= nil and type(path) ~= "string" then
    local err = error_handler.validation_error(
      "Path must be a string or nil",
      {
        parameter_name = "path",
        provided_type = type(path),
        operation = "get"
      }
    )
    log("warn", err.message, err.context)
    return nil, err
  end
  
  -- Return all config if no path specified
  if not path or path == "" then
    return deep_copy(config.values)
  end
  
  local parts = path_to_parts(path)
  if #parts == 0 then
    return deep_copy(config.values)
  end
  
  -- Navigate to value
  local current = config.values
  for i, part in ipairs(parts) do
    if type(current) ~= "table" then
      local context = {
        path = path,
        failed_at = table.concat(parts, ".", 1, i-1),
        expected = "table",
        got = type(current)
      }
      
      log("debug", "Path traversal failed at part", context)
      
      if default ~= nil then
        return default
      else
        local err = error_handler.validation_error(
          "Path traversal failed: expected table but got " .. type(current),
          context
        )
        return nil, err
      end
    end
    
    current = current[part]
    if current == nil then
      local context = {
        path = path,
        failed_at = table.concat(parts, ".", 1, i)
      }
      
      log("debug", "Path not found", context)
      
      if default ~= nil then
        return default
      else
        local err = error_handler.validation_error(
          "Path not found: " .. path,
          context
        )
        return nil, err
      end
    end
  end
  
  -- Return copy to prevent direct modification
  if type(current) == "table" then
    return deep_copy(current)
  end
  
  return current
end

-- Set a value at a specific path
function M.set(path, value)
  -- Parameter validation
  if path ~= nil and type(path) ~= "string" then
    local err = error_handler.validation_error(
      "Path must be a string or nil",
      {
        parameter_name = "path",
        provided_type = type(path),
        operation = "set"
      }
    )
    log("warn", err.message, err.context)
    return M
  end
  
  -- Handle root config
  if not path or path == "" then
    -- Root config must be a table
    if type(value) ~= "table" then
      local err = error_handler.validation_error(
        "Cannot set root config to non-table value",
        {
          type = type(value),
          operation = "set"
        }
      )
      log("warn", err.message, err.context)
      return M
    end
    
    -- Set the root config (with deep copy)
    config.values = deep_copy(value)
    log("debug", "Set complete configuration", {keys = table.concat({},"," )})
    return M
  end
  
  local parts = path_to_parts(path)
  if #parts == 0 then
    -- Empty path parts (shouldn't normally happen with non-empty path)
    if type(value) == "table" then
      config.values = deep_copy(value)
      log("debug", "Set complete configuration (empty parts)", {path = path})
    else
      local err = error_handler.validation_error(
        "Cannot set root config to non-table value",
        {
          type = type(value),
          operation = "set"
        }
      )
      log("warn", err.message, err.context)
    end
    return M
  end
  
  -- Get the last part (key to set)
  local last_key = parts[#parts]
  table.remove(parts, #parts)
  
  -- Ensure path exists by creating parent tables as needed
  local parent
  if #parts == 0 then
    -- If no parent path (direct child of root), use root config
    parent = config.values
  else
    -- Create the parent path structure if needed
    parent = config.values
    for i, part in ipairs(parts) do
      if type(parent[part]) ~= "table" then
        parent[part] = {}
      end
      parent = parent[part]
    end
  end
  
  -- Store old value for change detection
  local old_value = parent[last_key]
  
  -- Set the value (deep copy if it's a table)
  if type(value) == "table" then
    parent[last_key] = deep_copy(value)
  else
    parent[last_key] = value
  end
  
  -- Log the operation with detailed information for debugging
  log("debug", "Set configuration value", {
    path = path,
    old_value_type = type(old_value),
    new_value_type = type(value),
    complete_path = path
  })
  
  -- Notify listeners if value changed
  if not deep_equals(old_value, value) then
    M.notify_change(path, old_value, value)
  end
  
  return M
end

-- Delete a value at a specific path
function M.delete(path)
  -- Parameter validation
  if path == nil or type(path) ~= "string" then
    local err = error_handler.validation_error(
      "Path must be a non-empty string",
      {
        parameter_name = "path",
        provided_type = type(path),
        operation = "delete"
      }
    )
    log("warn", err.message, err.context)
    return false, err
  end
  
  if path == "" then
    local err = error_handler.validation_error(
      "Cannot delete root configuration",
      {
        operation = "delete"
      }
    )
    log("warn", err.message, err.context)
    return false, err
  end
  
  local parts = path_to_parts(path)
  if #parts == 0 then
    local err = error_handler.validation_error(
      "Cannot delete root configuration",
      {
        operation = "delete",
        path = path
      }
    )
    log("warn", err.message, err.context)
    return false, err
  end
  
  -- Get the last part (key to delete)
  local last_key = parts[#parts]
  table.remove(parts, #parts)
  
  -- Navigate to parent
  local current = config.values
  for i, part in ipairs(parts) do
    if type(current) ~= "table" then
      local context = {
        path = path,
        failed_at = table.concat(parts, ".", 1, i),
        operation = "delete"
      }
      
      local err = error_handler.validation_error(
        "Delete failed: path not found",
        context
      )
      log("debug", err.message, context)
      return false, err
    end
    
    current = current[part]
    if current == nil then
      local context = {
        path = path,
        failed_at = table.concat(parts, ".", 1, i),
        operation = "delete"
      }
      
      local err = error_handler.validation_error(
        "Delete failed: path not found",
        context
      )
      log("debug", err.message, context)
      return false, err
    end
  end
  
  -- Delete the key if parent exists
  if type(current) == "table" then
    -- Store old value for change detection
    local old_value = current[last_key]
    
    -- Check if the key exists
    if old_value == nil then
      local context = {
        path = path,
        key = last_key,
        operation = "delete"
      }
      
      local err = error_handler.validation_error(
        "Delete failed: key does not exist",
        context
      )
      log("debug", err.message, context)
      return false, err
    end
    
    -- Remove the key
    current[last_key] = nil
    
    -- Notify listeners
    M.notify_change(path, old_value, nil)
    
    log("debug", "Deleted configuration value", {path = path})
    return true
  end
  
  -- Parent isn't a table
  local context = {
    path = path,
    parent_type = type(current),
    operation = "delete"
  }
  
  local err = error_handler.validation_error(
    "Delete failed: parent is not a table",
    context
  )
  log("debug", err.message, context)
  return false, err
end

-- Register change listener
function M.on_change(path, callback)
  -- Parameter validation
  if path ~= nil and type(path) ~= "string" then
    local err = error_handler.validation_error(
      "Path must be a string or nil",
      {
        parameter_name = "path",
        provided_type = type(path),
        operation = "on_change"
      }
    )
    log("warn", err.message, err.context)
    return M
  end
  
  if type(callback) ~= "function" then
    local err = error_handler.validation_error(
      "Callback must be a function",
      {
        parameter_name = "callback",
        provided_type = type(callback),
        operation = "on_change"
      }
    )
    log("warn", err.message, err.context)
    return M
  end
  
  -- Initialize the listener array if needed
  path = path or "" -- Convert nil to empty string for root listeners
  config.listeners[path] = config.listeners[path] or {}
  
  -- Register the listener
  table.insert(config.listeners[path], callback)
  log("debug", "Registered change listener", {path = path})
  
  return M
end

-- Notify change listeners
function M.notify_change(path, old_value, new_value)
  -- Parameter validation
  if path == nil or type(path) ~= "string" then
    local err = error_handler.validation_error(
      "Path must be a string",
      {
        parameter_name = "path",
        provided_type = type(path),
        operation = "notify_change"
      }
    )
    log("warn", err.message, err.context)
    return
  end
  
  -- Log the notification for debugging
  log("debug", "Notifying change listeners", {
    path = path,
    old_value_type = type(old_value),
    new_value_type = type(new_value),
    has_exact_listeners = config.listeners[path] ~= nil and #(config.listeners[path] or {}) > 0
  })
  
  -- Notify exact path listeners using error_handler.try for safety
  if config.listeners[path] and #config.listeners[path] > 0 then
    for i, callback in ipairs(config.listeners[path]) do
      if type(callback) == "function" then
        local success, err = error_handler.try(function()
          return callback(path, old_value, new_value)
        end)
        
        if not success then
          log("error", "Error in change listener callback", {
            path = path,
            error = err.message,
            traceback = err.traceback,
            listener_index = i
          })
        else
          log("debug", "Successfully called exact path listener", {
            path = path,
            listener_index = i
          })
        end
      else
        log("warn", "Non-function callback found in listeners", {
          path = path,
          callback_type = type(callback),
          listener_index = i
        })
      end
    end
  end
  
  -- Notify parent path listeners
  local parts = path_to_parts(path)
  while #parts > 0 do
    table.remove(parts, #parts)
    local parent_path = table.concat(parts, ".")
    
    if config.listeners[parent_path] and #config.listeners[parent_path] > 0 then
      for i, callback in ipairs(config.listeners[parent_path]) do
        if type(callback) == "function" then
          local success, err = error_handler.try(function()
            return callback(path, old_value, new_value)
          end)
          
          if not success then
            log("error", "Error in parent change listener callback", {
              parent_path = parent_path,
              changed_path = path,
              error = err.message,
              traceback = err.traceback,
              listener_index = i
            })
          else
            log("debug", "Successfully called parent path listener", {
              parent_path = parent_path,
              changed_path = path,
              listener_index = i
            })
          end
        else
          log("warn", "Non-function callback found in parent listeners", {
            parent_path = parent_path,
            callback_type = type(callback),
            listener_index = i
          })
        end
      end
    end
  end
  
  -- Notify root listeners (empty path)
  if config.listeners[""] and #config.listeners[""] > 0 then
    for i, callback in ipairs(config.listeners[""]) do
      if type(callback) == "function" then
        local success, err = error_handler.try(function()
          return callback(path, old_value, new_value)
        end)
        
        if not success then
          log("error", "Error in root change listener callback", {
            changed_path = path,
            error = err.message,
            traceback = err.traceback,
            listener_index = i
          })
        else
          log("debug", "Successfully called root listener", {
            changed_path = path,
            listener_index = i
          })
        end
      else
        log("warn", "Non-function callback found in root listeners", {
          callback_type = type(callback),
          listener_index = i
        })
      end
    end
  end
end

-- Register a module's configuration schema and defaults
function M.register_module(module_name, schema, defaults)
  -- Parameter validation
  if type(module_name) ~= "string" then
    local err = error_handler.validation_error(
      "Module name must be a string",
      {
        parameter_name = "module_name",
        provided_type = type(module_name),
        operation = "register_module"
      }
    )
    log("error", err.message, err.context)
    return M
  end
  
  if module_name == "" then
    local err = error_handler.validation_error(
      "Module name cannot be empty",
      {
        parameter_name = "module_name",
        operation = "register_module"
      }
    )
    log("error", err.message, err.context)
    return M
  end
  
  -- Log the registration operation
  log("debug", "Registering module configuration", {
    module = module_name,
    has_schema = schema ~= nil,
    has_defaults = defaults ~= nil
  })
  
  -- Store schema if provided
  if schema ~= nil then
    if type(schema) ~= "table" then
      local err = error_handler.validation_error(
        "Schema must be a table or nil",
        {
          parameter_name = "schema",
          provided_type = type(schema),
          module = module_name,
          operation = "register_module"
        }
      )
      log("warn", err.message, err.context)
    else
      config.schemas[module_name] = deep_copy(schema)  -- Use deep_copy to prevent modification
      log("debug", "Registered schema for module", {
        module = module_name,
        schema_keys = table.concat(
          (function()
            local keys = {}
            for k, _ in pairs(schema) do table.insert(keys, k) end
            return keys
          end)(),
          ", "
        )
      })
    end
  end
  
  -- Apply defaults if provided
  if defaults ~= nil then
    if type(defaults) ~= "table" then
      local err = error_handler.validation_error(
        "Defaults must be a table or nil",
        {
          parameter_name = "defaults",
          provided_type = type(defaults),
          module = module_name,
          operation = "register_module"
        }
      )
      log("warn", err.message, err.context)
    else
      -- Store defaults (with deep copy to prevent modification)
      config.defaults[module_name] = deep_copy(defaults)
      
      -- Make sure the module's config section exists
      config.values[module_name] = config.values[module_name] or {}
      
      -- Simplified and more robust default application function
      local function apply_defaults(target, source)
        for k, v in pairs(source) do
          if target[k] == nil then
            -- No value exists, so copy from defaults
            if type(v) == "table" then
              target[k] = deep_copy(v)  -- Use deep_copy for tables
            else
              target[k] = v  -- Direct assignment for simple values
            end
            log("debug", "Applied default value for key", {
              module = module_name,
              key = k,
              value_type = type(v)
            })
          elseif type(target[k]) == "table" and type(v) == "table" then
            -- Both are tables, so merge recursively
            apply_defaults(target[k], v)
          end
          -- If value exists and is not a table, keep the existing value
        end
      end
      
      -- Apply defaults to the module's configuration
      apply_defaults(config.values[module_name], defaults)
      
      log("debug", "Applied defaults for module", {
        module = module_name,
        default_keys = table.concat(
          (function()
            local keys = {}
            for k, _ in pairs(defaults) do table.insert(keys, k) end
            return keys
          end)(),
          ", "
        )
      })
    end
  end
  
  return M
end

-- Validate configuration against registered schemas
function M.validate(module_name)
  -- Parameter validation
  if module_name ~= nil and type(module_name) ~= "string" then
    local err = error_handler.validation_error(
      "Module name must be a string or nil",
      {
        parameter_name = "module_name",
        provided_type = type(module_name),
        operation = "validate"
      }
    )
    log("warn", err.message, err.context)
    return false, err
  end
  
  local errors = {}
  
  local function validate_module(name)
    -- Verify the module exists in the schema registry
    local schema = config.schemas[name]
    if not schema then
      log("debug", "No schema registered for module", {module = name})
      return true
    end
    
    -- Get the current configuration for this module
    local module_config = M.get(name)
    if not module_config then
      -- No configuration for this module, which is valid
      return true
    end
    
    local module_errors = {}
    
    -- Basic structural validation (check required fields)
    if schema.required_fields then
      if type(schema.required_fields) ~= "table" then
        log("warn", "Invalid schema.required_fields format", {
          module = name,
          type = type(schema.required_fields)
        })
      else
        for _, field in ipairs(schema.required_fields) do
          if module_config[field] == nil then
            table.insert(module_errors, {
              field = field,
              message = "Required field missing"
            })
          end
        end
      end
    end
    
    -- Type validation
    if schema.field_types then
      if type(schema.field_types) ~= "table" then
        log("warn", "Invalid schema.field_types format", {
          module = name,
          type = type(schema.field_types)
        })
      else
        for field, expected_type in pairs(schema.field_types) do
          if module_config[field] ~= nil and type(module_config[field]) ~= expected_type then
            table.insert(module_errors, {
              field = field,
              message = "Field has wrong type",
              expected = expected_type,
              got = type(module_config[field])
            })
          end
        end
      end
    end
    
    -- Range validation
    if schema.field_ranges then
      if type(schema.field_ranges) ~= "table" then
        log("warn", "Invalid schema.field_ranges format", {
          module = name,
          type = type(schema.field_ranges)
        })
      else
        for field, range in pairs(schema.field_ranges) do
          if type(range) ~= "table" then
            log("warn", "Invalid range specification", {
              module = name,
              field = field,
              range_type = type(range)
            })
          else
            local value = module_config[field]
            if value ~= nil and type(value) == "number" then
              if (range.min and value < range.min) or (range.max and value > range.max) then
                table.insert(module_errors, {
                  field = field,
                  message = "Field value out of range",
                  min = range.min,
                  max = range.max,
                  value = value
                })
              end
            end
          end
        end
      end
    end
    
    -- Pattern validation
    if schema.field_patterns then
      if type(schema.field_patterns) ~= "table" then
        log("warn", "Invalid schema.field_patterns format", {
          module = name,
          type = type(schema.field_patterns)
        })
      else
        for field, pattern in pairs(schema.field_patterns) do
          if type(pattern) ~= "string" then
            log("warn", "Invalid pattern specification", {
              module = name,
              field = field,
              pattern_type = type(pattern)
            })
          else
            local value = module_config[field]
            if value ~= nil and type(value) == "string" then
              local success, result = error_handler.try(function()
                return string.match(value, pattern) ~= nil
              end)
              
              if not success then
                table.insert(module_errors, {
                  field = field,
                  message = "Invalid pattern: " .. result.message,
                  pattern = pattern
                })
              elseif not result then
                table.insert(module_errors, {
                  field = field,
                  message = "Field value does not match pattern",
                  pattern = pattern,
                  value = value
                })
              end
            end
          end
        end
      end
    end
    
    -- Value validation (enum-like)
    if schema.field_values then
      if type(schema.field_values) ~= "table" then
        log("warn", "Invalid schema.field_values format", {
          module = name,
          type = type(schema.field_values)
        })
      else
        for field, valid_values in pairs(schema.field_values) do
          if type(valid_values) ~= "table" then
            log("warn", "Invalid valid_values specification", {
              module = name,
              field = field,
              values_type = type(valid_values)
            })
          else
            local value = module_config[field]
            if value ~= nil then
              local valid = false
              for _, valid_value in ipairs(valid_values) do
                if value == valid_value then
                  valid = true
                  break
                end
              end
              
              if not valid then
                table.insert(module_errors, {
                  field = field,
                  message = "Field has invalid value",
                  valid_values = valid_values,
                  value = value
                })
              end
            end
          end
        end
      end
    end
    
    -- Custom validators
    if schema.validators then
      if type(schema.validators) ~= "table" then
        log("warn", "Invalid schema.validators format", {
          module = name,
          type = type(schema.validators)
        })
      else
        for field, validator in pairs(schema.validators) do
          if type(validator) ~= "function" then
            log("warn", "Invalid validator specification", {
              module = name,
              field = field,
              validator_type = type(validator)
            })
          else
            local value = module_config[field]
            if value ~= nil then
              local success, result, message = error_handler.try(function()
                return validator(value, module_config)
              end)
              
              if not success then
                table.insert(module_errors, {
                  field = field,
                  message = "Validator error: " .. result.message,
                  value = value
                })
              elseif not result then
                table.insert(module_errors, {
                  field = field,
                  message = message or "Failed custom validation",
                  value = value
                })
              end
            end
          end
        end
      end
    end
    
    -- Store errors if any
    if #module_errors > 0 then
      errors[name] = module_errors
      return false
    end
    
    return true
  end
  
  -- Validate specific module if provided
  if module_name then
    local result = validate_module(module_name)
    if result then
      return true
    else
      local validation_error = error_handler.validation_error(
        "Configuration validation failed for module: " .. module_name,
        {
          module = module_name,
          errors = errors[module_name]
        }
      )
      return false, validation_error
    end
  end
  
  -- Validate all registered modules
  local all_valid = true
  for name in pairs(config.schemas) do
    if not validate_module(name) then
      all_valid = false
    end
  end
  
  -- Return validation result
  if all_valid then
    return true
  else
    -- Create error object
    local validation_error = error_handler.validation_error(
      "Configuration validation failed for multiple modules",
      {
        modules = errors
      }
    )
    return false, validation_error
  end
end

-- Load configuration from a file
function M.load_from_file(path)
  -- Parameter validation
  if path ~= nil and type(path) ~= "string" then
    local err = error_handler.validation_error(
      "Path must be a string or nil",
      {
        parameter_name = "path",
        provided_type = type(path),
        operation = "load_from_file"
      }
    )
    log("warn", err.message, err.context)
    return nil, err
  end
  
  path = path or M.DEFAULT_CONFIG_PATH
  local fs = get_fs()
  
  -- Check if filesystem module is available
  if not fs then
    local err = error_handler.io_error(
      "Filesystem module not available for loading config",
      {
        path = path,
        operation = "load_from_file"
      }
    )
    log("error", err.message, err.context)
    return nil, err
  end
  
  -- Use safe_io_operation for checking if file exists
  local exists, err = error_handler.safe_io_operation(
    function() return fs.file_exists(path) end,
    path,
    {operation = "check_file_exists"}
  )
  
  if err then
    log("error", "Error checking if config file exists", {
      path = path,
      error = err.message
    })
    return nil, err
  end
  
  if not exists then
    -- This is a normal case - config file is optional
    log("info", "Config file not found, using defaults", {
      path = path,
      operation = "load_from_file"
    })
    -- Create a proper error object for tests
    local err = error_handler.io_error(
      "Config file not found",
      {
        path = path,
        operation = "load_from_file"
      }
    )
    return nil, err  -- Return nil, err to indicate file not found
  end
  
  -- Try to load the configuration file
  local success, user_config, err = error_handler.try(function()
    return dofile(path)
  end)
  
  if not success then
    -- Handle the case where err might not be a structured error
    local error_message = error_handler.is_error(err) and err.message or tostring(err)
    local parse_err = error_handler.parse_error(
      "Error loading config file: " .. error_message,
      {
        path = path,
        operation = "load_from_file"
      },
      error_handler.is_error(err) and err or nil
    )
    log("warn", parse_err.message, parse_err.context)
    return nil, parse_err
  end
  
  if type(user_config) ~= "table" then
    local format_err = error_handler.validation_error(
      "Invalid config format: expected a table, got " .. type(user_config),
      {
        path = path,
        expected = "table",
        got = type(user_config),
        operation = "load_from_file"
      }
    )
    log("error", format_err.message, format_err.context)
    return nil, format_err
  end
  
  -- Apply loaded configuration
  local old_config = deep_copy(config.values)
  
  -- Store and apply the loaded configuration
  local merged_config, err = deep_merge(config.values, user_config)
  if err then
    log("error", "Failed to merge configuration", {
      path = path,
      error = err.message
    })
    return nil, err
  end
  
  config.values = merged_config
  log("debug", "Config file loaded successfully", {path = path})
  
  -- Notify listeners of all changed paths
  local function notify_changes(prefix, old, new)
    if type(old) ~= "table" or type(new) ~= "table" then
      if not deep_equals(old, new) then
        M.notify_change(prefix, old, new)
      end
      return
    end
    
    -- Notify about changed or added keys
    for k, v in pairs(new) do
      local new_prefix = prefix == "" and k or (prefix .. "." .. k)
      notify_changes(new_prefix, old[k], v)
    end
    
    -- Notify about removed keys
    for k, v in pairs(old) do
      if new[k] == nil then
        local new_prefix = prefix == "" and k or (prefix .. "." .. k)
        M.notify_change(new_prefix, v, nil)
      end
    end
  end
  
  notify_changes("", old_config, config.values)
  
  return user_config
end

-- Save current configuration to a file
function M.save_to_file(path)
  -- Parameter validation
  if path ~= nil and type(path) ~= "string" then
    local err = error_handler.validation_error(
      "Path must be a string or nil",
      {
        parameter_name = "path",
        provided_type = type(path),
        operation = "save_to_file"
      }
    )
    log("warn", err.message, err.context)
    return false, err
  end
  
  path = path or M.DEFAULT_CONFIG_PATH
  local fs = get_fs()
  
  -- Check if filesystem module is available
  if not fs then
    local err = error_handler.io_error(
      "Filesystem module not available for saving config",
      {
        path = path,
        operation = "save_to_file"
      }
    )
    log("error", err.message, err.context)
    return false, err
  end
  
  -- Generate Lua code for the configuration
  local function serialize(tbl, indent)
    -- Validate input
    if type(tbl) ~= "table" then
      return nil, error_handler.validation_error(
        "Cannot serialize non-table value",
        {
          provided_type = type(tbl),
          operation = "serialize"
        }
      )
    end
    
    indent = indent or ""
    local result = "{\n"
    
    -- Sort keys for deterministic output
    local keys = {}
    for k in pairs(tbl) do
      table.insert(keys, k)
    end
    table.sort(keys)
    
    for _, k in ipairs(keys) do
      local v = tbl[k]
      local key_str
      
      -- Format key based on type
      if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
        key_str = k
      elseif type(k) == "string" then
        key_str = string.format("[%q]", k)
      elseif type(k) == "number" then
        key_str = string.format("[%d]", k)
      else
        -- Skip non-string/non-number keys
        log("warn", "Skipping unsupported key type in serialization", {
          key_type = type(k),
          operation = "serialize"
        })
        goto continue
      end
      
      -- Format value based on type
      if type(v) == "table" then
        local serialized_value, err = serialize(v, indent .. "  ")
        if err then
          return nil, err
        end
        result = result .. indent .. "  " .. key_str .. " = " .. serialized_value .. ",\n"
      elseif type(v) == "string" then
        result = result .. indent .. "  " .. key_str .. " = " .. string.format("%q", v) .. ",\n"
      elseif type(v) == "number" or type(v) == "boolean" then
        result = result .. indent .. "  " .. key_str .. " = " .. tostring(v) .. ",\n"
      elseif type(v) == "nil" then
        result = result .. indent .. "  " .. key_str .. " = nil,\n"
      else
        -- Skip unsupported types (function, userdata, thread)
        log("warn", "Skipping unsupported value type in serialization", {
          key = tostring(k),
          value_type = type(v),
          operation = "serialize"
        })
      end
      
      ::continue::
    end
    
    result = result .. indent .. "}"
    return result
  end
  
  -- Create a copy of the config to serialize
  local config_to_save = deep_copy(config.values)
  
  -- Generate Lua code
  local serialized_config, err = serialize(config_to_save)
  if not serialized_config then
    log("error", "Failed to serialize configuration", {
      path = path,
      error = err.message
    })
    return false, err
  end
  
  local content = "-- firmo configuration file\n"
  content = content .. "-- This file was automatically generated\n\n"
  content = content .. "return " .. serialized_config .. "\n"
  
  -- Write to file using safe_io_operation
  local success, err = error_handler.safe_io_operation(
    function() return fs.write_file(path, content) end,
    path,
    {operation = "write_config_file"}
  )
  
  if not success then
    log("error", "Failed to save config file", {
      path = path,
      error = err.message
    })
    return false, err
  end
  
  log("info", "Configuration saved to file", {path = path})
  return true
end

-- Reset configuration to defaults
function M.reset(module_name)
  -- Parameter validation
  if module_name ~= nil and type(module_name) ~= "string" then
    local err = error_handler.validation_error(
      "Module name must be a string or nil",
      {
        parameter_name = "module_name",
        provided_type = type(module_name),
        operation = "reset"
      }
    )
    log("warn", err.message, err.context)
    return M
  end
  
  -- If module_name is nil, completely reset everything
  if module_name == nil then
    -- Reset everything for testing
    local old_values = deep_copy(config.values)
    
    -- Clear all configuration data structures
    init_config()
    
    log("info", "Reset entire configuration system for testing")
    
    -- No listeners to notify after full reset since they were cleared too
    return M
  end
  
  -- Reset specific module
  if not config.defaults[module_name] then
    -- If there are no defaults, just clear the module's configuration
    if config.values[module_name] then
      -- Store old config for change notifications
      local old_config = deep_copy(config.values[module_name])
      
      -- Clear the module's config
      config.values[module_name] = {}
      
      log("info", "Cleared configuration for module (no defaults)", {module = module_name})
      
      -- Notify listeners
      M.notify_change(module_name, old_config, config.values[module_name])
    else
      log("debug", "No configuration or defaults to reset for module", {module = module_name})
    end
    
    return M
  end
  
  -- Copy the old configuration for change detection
  local old_config = deep_copy(config.values[module_name])
  
  -- Reset to defaults (with deep copy to prevent modification of defaults)
  config.values[module_name] = deep_copy(config.defaults[module_name])
  
  log("info", "Reset configuration for module to defaults", {
    module = module_name,
    default_count = (function()
      local count = 0
      for _, _ in pairs(config.defaults[module_name]) do count = count + 1 end
      return count
    end)()
  })
  
  -- Notify listeners of change
  M.notify_change(module_name, old_config, config.values[module_name])
  
  return M
end

-- Configure from options table (typically from CLI)
function M.configure_from_options(options)
  -- Parameter validation
  if options == nil then
    log("debug", "No options provided to configure_from_options")
    return M
  end
  
  if type(options) ~= "table" then
    local err = error_handler.validation_error(
      "Options must be a table",
      {
        parameter_name = "options",
        provided_type = type(options),
        operation = "configure_from_options"
      }
    )
    log("warn", err.message, err.context)
    return M
  end
  
  -- Process options using error_handler.try to catch any errors
  for k, v in pairs(options) do
    -- Only handle options with module.option format
    if type(k) == "string" and string.find(k, "%.") then
      local success, err = error_handler.try(function()
        M.set(k, v)
      end)
      
      if not success then
        log("warn", "Failed to set option", {
          key = k,
          value_type = type(v),
          error = err.message
        })
      end
    end
  end
  
  log("debug", "Applied configuration from options")
  return M
end

-- Configure from global config
function M.configure_from_config(global_config)
  -- Parameter validation
  if global_config == nil then
    log("debug", "No global config provided to configure_from_config")
    return M
  end
  
  if type(global_config) ~= "table" then
    local err = error_handler.validation_error(
      "Global config must be a table",
      {
        parameter_name = "global_config",
        provided_type = type(global_config),
        operation = "configure_from_config"
      }
    )
    log("warn", err.message, err.context)
    return M
  end
  
  -- Merge global config into our config with error handling
  local merged_config, err = deep_merge(config.values, global_config)
  if err then
    log("error", "Failed to merge global configuration", {
      error = err.message
    })
    return M
  end
  
  config.values = merged_config
  log("debug", "Applied configuration from global config")
  
  return M
end

-- Export public interface with error handling wrappers
M.serialize = function(obj)
  local result = deep_copy(obj)
  if type(result) ~= "table" and obj ~= nil then
    log("warn", "serialize was called on a non-table value", {
      value_type = type(obj)
    })
  end
  return result
end

M.merge = function(target, source)
  local result, err = deep_merge(target, source)
  if err then
    log("error", "Error in merge operation", {
      error = err.message,
      target_type = type(target),
      source_type = type(source)
    })
    return target
  end
  return result
end

-- Module initialization with error handling
local function init()
  -- Initialize with proper error handling
  local success, err = error_handler.try(function()
    -- Register this module's defaults
    M.register_module("central_config", {
      -- Schema
      required_fields = {},
      field_types = {
        auto_save = "boolean",
        config_path = "string"
      }
    }, {
      -- Defaults
      auto_save = false,
      config_path = M.DEFAULT_CONFIG_PATH
    })
    
    log("debug", "Centralized configuration module initialized")
    
    return M
  end)
  
  if not success then
    log("error", "Failed to initialize central_config module", {
      error = err.message,
      traceback = err.traceback
    })
    -- Return module anyway to prevent crashes
  end
  
  return M
end

return init()
