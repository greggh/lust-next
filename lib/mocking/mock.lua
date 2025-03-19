---@diagnostic disable: param-type-mismatch
-- mock.lua - Object mocking implementation for firmo

local spy = require("lib.mocking.spy")
local stub = require("lib.mocking.stub")
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Initialize module logger
local logger = logging.get_logger("mock")
logging.configure_from_config("mock")

local mock = {
  -- Module version
  _VERSION = "1.0.0",
}
local _mocks = {}

-- Helper function to check if a table is a mock
local function is_mock(obj)
  return type(obj) == "table" and obj._is_firmo_mock == true
end

-- Helper function to register a mock for cleanup
local function register_mock(mock_obj)
  -- Input validation
  if mock_obj == nil then
    local err = error_handler.validation_error("Cannot register nil mock object", {
      function_name = "register_mock",
      parameter_name = "mock_obj",
      provided_value = "nil",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  if not is_mock(mock_obj) then
    local err = error_handler.validation_error("Object is not a valid mock", {
      function_name = "register_mock",
      parameter_name = "mock_obj",
      provided_type = type(mock_obj),
      is_table = type(mock_obj) == "table",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  logger.debug("Registering mock for cleanup", {
    target_type = type(mock_obj.target),
    stubs_count = mock_obj._stubs and #mock_obj._stubs or 0,
  })

  -- Use try to safely insert the mock object
  local success, result, err = error_handler.try(function()
    table.insert(_mocks, mock_obj)
    return mock_obj
  end)

  if not success then
    local error_obj = error_handler.runtime_error(
      "Failed to register mock for cleanup",
      {
        function_name = "register_mock",
        target_type = type(mock_obj.target),
      },
      result -- On failure, result contains the error
    )
    logger.error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  return mock_obj
end

-- Helper function to restore all mocks
function mock.restore_all()
  logger.debug("Restoring all mocks", {
    count = #_mocks,
  })

  local errors = {}

  for i, mock_obj in ipairs(_mocks) do
    logger.debug("Restoring mock", {
      index = i,
      target_type = type(mock_obj.target),
    })

    -- Use protected call to ensure one failure doesn't prevent other mocks from being restored
    local success, result, err = error_handler.try(function()
      if type(mock_obj) == "table" and type(mock_obj.restore) == "function" then
        mock_obj:restore()
        return true
      else
        return false,
          error_handler.validation_error("Invalid mock object (missing restore method)", {
            function_name = "mock.restore_all",
            mock_index = i,
            mock_type = type(mock_obj),
            has_restore = type(mock_obj) == "table" and type(mock_obj.restore) == "function",
          })
      end
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to restore mock",
        {
          function_name = "mock.restore_all",
          mock_index = i,
          target_type = type(mock_obj) == "table" and type(mock_obj.target) or "unknown",
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      table.insert(errors, error_obj)
    elseif result == false then
      -- The try function succeeded but the restore validation failed
      table.insert(errors, err)
    end
  end

  -- Reset the mocks registry even if there were errors
  _mocks = {}

  -- If there were errors, report them but continue
  if #errors > 0 then
    logger.warn("Completed mock restoration with errors", {
      error_count = #errors,
    })

    -- Return a structured error summary
    return false,
      error_handler.runtime_error("Completed mock restoration with " .. #errors .. " errors", {
        function_name = "mock.restore_all",
        error_count = #errors,
        errors = errors,
      })
  end

  logger.debug("All mocks restored successfully")
  return true
end

-- Convert value to string representation for error messages
local function value_to_string(value, max_depth)
  -- Input validation with fallback
  if max_depth ~= nil and type(max_depth) ~= "number" then
    logger.warn("Invalid max_depth parameter type", {
      function_name = "value_to_string",
      parameter_name = "max_depth",
      provided_type = type(max_depth),
      provided_value = tostring(max_depth),
    })
    max_depth = 3 -- Default fallback
  end

  max_depth = max_depth or 3
  if max_depth < 0 then
    return "..."
  end

  -- Use protected call to catch errors during string conversion
  local success, result = error_handler.try(function()
    if value == nil then
      return "nil"
    elseif type(value) == "string" then
      return '"' .. value .. '"'
    elseif type(value) == "table" then
      if max_depth == 0 then
        return "{...}"
      end

      local parts = {}
      for k, v in pairs(value) do
        -- Check for special metatable-based formatting
        if k == "_is_matcher" and v == true and value.description then
          return value.description
        end

        local key_str = type(k) == "string" and k or "[" .. tostring(k) .. "]"
        table.insert(parts, key_str .. " = " .. value_to_string(v, max_depth - 1))
      end
      return "{ " .. table.concat(parts, ", ") .. " }"
    elseif type(value) == "function" then
      return "function(...)"
    else
      return tostring(value)
    end
  end)

  if not success then
    logger.warn("Error during string conversion", {
      function_name = "value_to_string",
      value_type = type(value),
      error = error_handler.format_error(result),
    })
    return "[Error during conversion: " .. error_handler.format_error(result) .. "]"
  end

  return result
end

-- Format args for error messages
local function format_args(args)
  -- Input validation with fallback
  if args == nil then
    logger.warn("Nil args parameter", {
      function_name = "format_args",
    })
    return "nil"
  end

  if type(args) ~= "table" then
    logger.warn("Invalid args parameter type", {
      function_name = "format_args",
      parameter_name = "args",
      provided_type = type(args),
      provided_value = tostring(args),
    })
    return tostring(args)
  end

  -- Use protected call to catch errors during args formatting
  local success, result = error_handler.try(function()
    local parts = {}
    for i, arg in ipairs(args) do
      if type(arg) == "table" and arg._is_matcher then
        table.insert(parts, arg.description)
      else
        table.insert(parts, value_to_string(arg))
      end
    end
    return table.concat(parts, ", ")
  end)

  if not success then
    logger.warn("Error during args formatting", {
      function_name = "format_args",
      args_count = #args,
      error = error_handler.format_error(result),
    })
    return "[Error during args formatting: " .. error_handler.format_error(result) .. "]"
  end

  return result
end

-- Create a mock object with verifiable behavior
function mock.create(target, options)
  -- Input validation
  if target == nil then
    local err = error_handler.validation_error("Cannot create mock with nil target", {
      function_name = "mock.create",
      parameter_name = "target",
      provided_value = "nil",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  if options ~= nil and type(options) ~= "table" then
    local err = error_handler.validation_error("Options must be a table or nil", {
      function_name = "mock.create",
      parameter_name = "options",
      provided_type = type(options),
      provided_value = tostring(options),
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  logger.debug("Creating mock object", {
    target_type = type(target),
    options = options or {},
  })

  options = options or {}

  -- Use protected call to create the mock object
  local success, mock_obj, err = error_handler.try(function()
    local obj = {
      _is_firmo_mock = true,
      target = target,
      _stubs = {},
      _originals = {},
      _expectations = {},
      _verify_all_expectations_called = options.verify_all_expectations_called ~= false,
    }

    logger.debug("Mock object initialized", {
      verify_all_expectations = obj._verify_all_expectations_called,
    })

    return obj
  end)

  if not success then
    local error_obj = error_handler.runtime_error(
      "Failed to create mock object",
      {
        function_name = "mock.create",
        target_type = type(target),
        options_provided = options ~= nil,
      },
      mock_obj -- On failure, mock_obj contains the error
    )
    logger.error(error_obj.message, error_obj.context)
    return nil, error_obj
  end

  -- Method to stub a function with a return value or implementation
  function mock_obj:stub(name, implementation_or_value)
    -- Input validation
    if name == nil then
      local err = error_handler.validation_error("Method name cannot be nil", {
        function_name = "mock_obj:stub",
        parameter_name = "name",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = error_handler.validation_error("Method name must be a string", {
        function_name = "mock_obj:stub",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    logger.debug("Stubbing method", {
      method_name = name,
      value_type = type(implementation_or_value),
    })

    -- Validate method existence
    if self.target[name] == nil then
      local err = error_handler.validation_error("Cannot stub non-existent method", {
        function_name = "mock_obj:stub",
        parameter_name = "name",
        method_name = name,
        target_type = type(self.target),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    logger.debug("Saving original method", {
      method_name = name,
      original_type = type(self.target[name]),
    })

    -- Use protected call to save the original method
    local success, result, err = error_handler.try(function()
      self._originals[name] = self.target[name]
      return true
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to save original method",
        {
          function_name = "mock_obj:stub",
          method_name = name,
          original_type = type(self.target[name]),
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Create the stub with error handling
    local stub_obj, stub_err

    if type(implementation_or_value) == "function" then
      logger.debug("Creating stub with function implementation")
      success, stub_obj, err = error_handler.try(function()
        return stub.on(self.target, name, implementation_or_value)
      end)
    else
      logger.debug("Creating stub with return value", {
        return_value_type = type(implementation_or_value),
      })
      success, stub_obj, err = error_handler.try(function()
        return stub.on(self.target, name, function()
          return implementation_or_value
        end)
      end)
    end

    if not success then
      -- Restore the original method since stub creation failed
      local restore_success, _ = error_handler.try(function()
        self.target[name] = self._originals[name]
        self._originals[name] = nil
        return true
      end)

      if not restore_success then
        logger.warn("Failed to restore original method after stub creation failure", {
          method_name = name,
        })
      end

      local error_obj = error_handler.runtime_error(
        "Failed to create stub",
        {
          function_name = "mock_obj:stub",
          method_name = name,
          implementation_type = type(implementation_or_value),
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Store the stub with error handling
    success, result, err = error_handler.try(function()
      self._stubs[name] = stub_obj
      return true
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to store stub in mock object",
        {
          function_name = "mock_obj:stub",
          method_name = name,
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    logger.debug("Method successfully stubbed", {
      method_name = name,
    })
    return self
  end

  -- Method to stub a function with sequential return values
  function mock_obj:stub_in_sequence(name, sequence_values)
    -- Input validation
    if name == nil then
      local err = error_handler.validation_error("Method name cannot be nil", {
        function_name = "mock_obj:stub_in_sequence",
        parameter_name = "name",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = error_handler.validation_error("Method name must be a string", {
        function_name = "mock_obj:stub_in_sequence",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    -- Validate method existence
    if self.target[name] == nil then
      local err = error_handler.validation_error("Cannot stub non-existent method", {
        function_name = "mock_obj:stub_in_sequence",
        parameter_name = "name",
        method_name = name,
        target_type = type(self.target),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    -- Validate sequence values
    if sequence_values == nil then
      local err = error_handler.validation_error("Sequence values cannot be nil", {
        function_name = "mock_obj:stub_in_sequence",
        parameter_name = "sequence_values",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    if type(sequence_values) ~= "table" then
      local err = error_handler.validation_error("stub_in_sequence requires a table of values", {
        function_name = "mock_obj:stub_in_sequence",
        parameter_name = "sequence_values",
        provided_type = type(sequence_values),
        provided_value = tostring(sequence_values),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    logger.debug("Creating sequence stub", {
      method_name = name,
      sequence_length = #sequence_values,
    })

    -- Use protected call to save the original method
    local success, result, err = error_handler.try(function()
      self._originals[name] = self.target[name]
      return true
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to save original method",
        {
          function_name = "mock_obj:stub_in_sequence",
          method_name = name,
          original_type = type(self.target[name]),
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Create the stub with error handling
    local stub_obj

    -- First create the basic stub
    success, stub_obj, err = error_handler.try(function()
      return stub.on(self.target, name, function() end)
    end)

    if not success then
      -- Restore the original method since stub creation failed
      local restore_success, _ = error_handler.try(function()
        self.target[name] = self._originals[name]
        self._originals[name] = nil
        return true
      end)

      if not restore_success then
        logger.warn("Failed to restore original method after stub creation failure", {
          method_name = name,
        })
      end

      local error_obj = error_handler.runtime_error(
        "Failed to create sequence stub",
        {
          function_name = "mock_obj:stub_in_sequence",
          method_name = name,
          sequence_length = #sequence_values,
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Now configure the sequence
    success, result, err = error_handler.try(function()
      return stub_obj:returns_in_sequence(sequence_values)
    end)

    if not success then
      -- Restore the original method since sequence configuration failed
      local restore_success, _ = error_handler.try(function()
        self.target[name] = self._originals[name]
        self._originals[name] = nil
        return true
      end)

      if not restore_success then
        logger.warn("Failed to restore original method after sequence configuration failure", {
          method_name = name,
        })
      end

      local error_obj = error_handler.runtime_error(
        "Failed to configure sequence returns",
        {
          function_name = "mock_obj:stub_in_sequence",
          method_name = name,
          sequence_length = #sequence_values,
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Update stub_obj with the configured sequence stub
    stub_obj = result

    -- Store the stub with error handling
    success, result, err = error_handler.try(function()
      self._stubs[name] = stub_obj
      return true
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to store sequence stub in mock object",
        {
          function_name = "mock_obj:stub_in_sequence",
          method_name = name,
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    logger.debug("Method successfully stubbed with sequence values", {
      method_name = name,
      sequence_length = #sequence_values,
    })

    return stub_obj -- Return the stub for method chaining
  end

  -- Restore a specific stub
  function mock_obj:restore_stub(name)
    -- Input validation
    if name == nil then
      local err = error_handler.validation_error("Method name cannot be nil", {
        function_name = "mock_obj:restore_stub",
        parameter_name = "name",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = error_handler.validation_error("Method name must be a string", {
        function_name = "mock_obj:restore_stub",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    logger.debug("Attempting to restore stub", {
      method_name = name,
      has_original = self._originals[name] ~= nil,
    })

    if not self._originals[name] then
      logger.warn("No original method found to restore", {
        function_name = "mock_obj:restore_stub",
        method_name = name,
      })
      return self
    end

    -- Use protected call to restore the original method
    local success, result, err = error_handler.try(function()
      self.target[name] = self._originals[name]
      return true
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to restore original method",
        {
          function_name = "mock_obj:restore_stub",
          method_name = name,
          target_type = type(self.target),
          original_type = type(self._originals[name]),
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Clean up references with error handling
    success, result, err = error_handler.try(function()
      self._originals[name] = nil
      self._stubs[name] = nil
      return true
    end)

    if not success then
      logger.warn("Failed to clean up references after restoration", {
        method_name = name,
        error = error_handler.format_error(result),
      })
      -- We continue despite this error because the restoration was successful
    end

    logger.debug("Successfully restored original method", {
      method_name = name,
    })

    return self
  end

  -- Restore all stubs for this mock
  function mock_obj:restore()
    logger.debug("Restoring all stubs for mock", {
      stub_count = self._stubs and #self._stubs or 0,
      original_count = self._originals and #self._originals or 0,
    })

    local errors = {}

    -- Use protected iteration for safety
    local success, originals = error_handler.try(function()
      -- Make a copy of the keys to allow modification during iteration
      local keys = {}
      for name, _ in pairs(self._originals) do
        table.insert(keys, name)
      end
      return keys
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to create list of methods to restore",
        {
          function_name = "mock_obj:restore",
          target_type = type(self.target),
        },
        originals -- On failure, originals contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Restore each method individually
    for _, name in ipairs(originals) do
      logger.debug("Restoring original method", {
        method_name = name,
        target_type = type(self.target),
      })

      -- Use protected call to restore the original method
      local restore_success, result, err = error_handler.try(function()
        if self._originals[name] ~= nil then
          self.target[name] = self._originals[name]
          return true
        else
          return false,
            error_handler.validation_error("Original method no longer exists", {
              function_name = "mock_obj:restore",
              method_name = name,
            })
        end
      end)

      if not restore_success then
        local error_obj = error_handler.runtime_error(
          "Failed to restore original method",
          {
            function_name = "mock_obj:restore",
            method_name = name,
            target_type = type(self.target),
          },
          result -- On failure, result contains the error
        )
        logger.error(error_obj.message, error_obj.context)
        table.insert(errors, error_obj)
      elseif result == false then
        -- The try function succeeded but the restoration validation failed
        table.insert(errors, err)
      end
    end

    -- Clean up all references with error handling
    ---@diagnostic disable-next-line: lowercase-global, unused-local
    success, result, err = error_handler.try(function()
      self._stubs = {}
      self._originals = {}
      return true
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to clean up references after restoration",
        {
          function_name = "mock_obj:restore",
          target_type = type(self.target),
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      table.insert(errors, error_obj)
    end

    -- If there were errors, report them but continue
    if #errors > 0 then
      logger.warn("Completed mock restoration with errors", {
        error_count = #errors,
      })

      -- We don't return an error here as we want to ensure the mock is available
      -- for reuse even if there were errors during cleanup
    else
      logger.debug("All stubs restored for mock")
    end

    return self
  end

  -- Verify all expected stubs were called
  function mock_obj:verify()
    logger.debug("Verifying mock expectations", {
      stub_count = self._stubs and #self._stubs or 0,
      verify_all = self._verify_all_expectations_called,
    })

    local failures = {}

    -- Use protected verification for safety
    local success, result, err = error_handler.try(function()
      if self._verify_all_expectations_called then
        for name, stub in pairs(self._stubs) do
          logger.debug("Checking if method was called", {
            method_name = name,
            was_called = stub and stub.called,
          })

          if not stub or not stub.called then
            -- Check if we're in test mode and should suppress logging
            if not (error_handler and 
                  type(error_handler.is_suppressing_test_logs) == "function" and 
                  error_handler.is_suppressing_test_logs()) then
              -- For verification failures, use warning level since this is potentially
              -- useful information in tests that are checking verification behavior
              logger.warn("Expected method was not called", {
                method_name = name,
              })
            else
              -- In test mode, only log at debug level
              logger.debug("Expected method was not called (test mode)", {
                method_name = name,
              })
            end
            table.insert(failures, "Expected '" .. name .. "' to be called, but it was not")
          end
        end
      end

      return failures
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Error during mock verification",
        {
          function_name = "mock_obj:verify",
          verify_all = self._verify_all_expectations_called,
          stub_count = self._stubs and #self._stubs or 0,
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    -- Check for verification failures
    if #failures > 0 then
      local error_message = "Mock verification failed:\n  " .. table.concat(failures, "\n  ")

      -- Check if we're in test mode and should suppress logging
      if not (error_handler and 
             type(error_handler.is_suppressing_test_logs) == "function" and 
             error_handler.is_suppressing_test_logs()) then
        -- For mock verification failures, use error level only if not in test mode
        logger.error("Mock verification failed", {
          failure_count = #failures,
          failures = table.concat(failures, "; "),
        })
      else
        -- In test mode, only log at debug level
        logger.debug("Mock verification failed (test mode)", {
          failure_count = #failures,
          failures = table.concat(failures, "; "),
        })
      end

      local error_obj = error_handler.validation_error(error_message, {
        function_name = "mock_obj:verify",
        failure_count = #failures,
        failures = failures,
      })

      -- We're returning the error object instead of throwing it
      -- This makes the API consistent with the rest of the error handling
      return false, error_obj
    end

    logger.debug("Mock verification passed")
    return true
  end

  -- Register for auto-cleanup
  register_mock(mock_obj)

  return mock_obj
end

-- Context manager for mocks that auto-restores
function mock.with_mocks(fn)
  -- Input validation
  if fn == nil then
    local err = error_handler.validation_error("Function argument cannot be nil", {
      function_name = "mock.with_mocks",
      parameter_name = "fn",
      provided_value = "nil",
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  if type(fn) ~= "function" then
    local err = error_handler.validation_error("Function argument must be a function", {
      function_name = "mock.with_mocks",
      parameter_name = "fn",
      provided_type = type(fn),
      provided_value = tostring(fn),
    })
    logger.error(err.message, err.context)
    return nil, err
  end

  logger.debug("Starting mock context manager")

  -- Keep a local registry of all mocks created within this context
  local context_mocks = {}

  -- Track function result and errors
  local ok, result, error_during_execution, errors_during_restore

  logger.debug("Initializing context-specific mock tracking")

  -- Create a mock function wrapper compatible with example usage
  local mock_fn = function(target, method_name, impl_or_value)
    -- Input validation with graceful degradation
    if target == nil then
      local err = error_handler.validation_error("Cannot create mock with nil target", {
        function_name = "mock_fn",
        parameter_name = "target",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      error(err.message)
    end

    -- Use protected calls for mock creation and manipulation
    local success, mock_obj, err = error_handler.try(function()
      if method_name then
        -- Called as mock_fn(obj, "method", impl)
        -- First create the mock object
        local mock_obj = mock.create(target)

        -- Then stub the method
        if type(method_name) == "string" then
          mock_obj:stub(method_name, impl_or_value)
        else
          logger.warn("Method name must be a string, skipping stubbing", {
            provided_type = type(method_name),
          })
        end

        table.insert(context_mocks, mock_obj)
        return mock_obj
      else
        -- Called as mock_fn(obj)
        local mock_obj = mock.create(target)
        table.insert(context_mocks, mock_obj)
        return mock_obj
      end
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to create or configure mock",
        {
          function_name = "mock_fn",
          target_type = type(target),
          method_name = method_name and tostring(method_name) or "nil",
          has_impl = impl_or_value ~= nil,
        },
        mock_obj -- On failure, mock_obj contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      error(error_obj.message)
    end

    return mock_obj
  end

  -- Run the function with mocking modules using error_handler.try
  local fn_success, fn_result, fn_err = error_handler.try(function()
    -- Create context-specific spy wrapper
    local context_spy = {
      new = function(...)
        local args = { ... }
        local success, spy_obj, err = error_handler.try(function()
          return spy.new(table.unpack(args))
        end)

        if not success then
          local error_obj = error_handler.runtime_error(
            "Failed to create spy",
            {
              function_name = "context_spy.new",
              arg_count = select("#", ...),
            },
            spy_obj -- On failure, spy_obj contains the error
          )
          logger.error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        table.insert(context_mocks, spy_obj)
        return spy_obj
      end,

      on = function(obj, method_name)
        -- Input validation
        if obj == nil then
          local err = error_handler.validation_error("Cannot spy on nil object", {
            function_name = "context_spy.on",
            parameter_name = "obj",
            provided_value = "nil",
          })
          logger.error(err.message, err.context)
          error(err.message)
        end

        if type(method_name) ~= "string" then
          local err = error_handler.validation_error("Method name must be a string", {
            function_name = "context_spy.on",
            parameter_name = "method_name",
            provided_type = type(method_name),
            provided_value = tostring(method_name),
          })
          logger.error(err.message, err.context)
          error(err.message)
        end

        -- Create spy with error handling
        local success, spy_obj, err = error_handler.try(function()
          return spy.on(obj, method_name)
        end)

        if not success then
          local error_obj = error_handler.runtime_error(
            "Failed to create spy on object method",
            {
              function_name = "context_spy.on",
              target_type = type(obj),
              method_name = method_name,
            },
            spy_obj -- On failure, spy_obj contains the error
          )
          logger.error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        table.insert(context_mocks, spy_obj)
        return spy_obj
      end,
    }

    -- Create context-specific stub wrapper
    local context_stub = {
      new = function(...)
        local args = { ... }
        local success, stub_obj, err = error_handler.try(function()
          return stub.new(table.unpack(args))
        end)

        if not success then
          local error_obj = error_handler.runtime_error(
            "Failed to create stub",
            {
              function_name = "context_stub.new",
              arg_count = select("#", ...),
            },
            stub_obj -- On failure, stub_obj contains the error
          )
          logger.error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        table.insert(context_mocks, stub_obj)
        return stub_obj
      end,

      on = function(obj, method_name, value_or_impl)
        -- Input validation
        if obj == nil then
          local err = error_handler.validation_error("Cannot stub nil object", {
            function_name = "context_stub.on",
            parameter_name = "obj",
            provided_value = "nil",
          })
          logger.error(err.message, err.context)
          error(err.message)
        end

        if type(method_name) ~= "string" then
          local err = error_handler.validation_error("Method name must be a string", {
            function_name = "context_stub.on",
            parameter_name = "method_name",
            provided_type = type(method_name),
            provided_value = tostring(method_name),
          })
          logger.error(err.message, err.context)
          error(err.message)
        end

        -- Create stub with error handling
        local success, stub_obj, err = error_handler.try(function()
          return stub.on(obj, method_name, value_or_impl)
        end)

        if not success then
          local error_obj = error_handler.runtime_error(
            "Failed to create stub on object method",
            {
              function_name = "context_stub.on",
              target_type = type(obj),
              method_name = method_name,
              value_type = type(value_or_impl),
            },
            stub_obj -- On failure, stub_obj contains the error
          )
          logger.error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        table.insert(context_mocks, stub_obj)
        return stub_obj
      end,
    }

    -- Create context-specific mock wrapper
    local context_mock = {
      create = function(target, options)
        -- Input validation
        if target == nil then
          local err = error_handler.validation_error("Cannot create mock with nil target", {
            function_name = "context_mock.create",
            parameter_name = "target",
            provided_value = "nil",
          })
          logger.error(err.message, err.context)
          error(err.message)
        end

        -- Create mock with error handling
        local success, mock_obj, err = error_handler.try(function()
          return mock.create(target, options)
        end)

        if not success then
          local error_obj = error_handler.runtime_error(
            "Failed to create mock object",
            {
              function_name = "context_mock.create",
              target_type = type(target),
              options_provided = options ~= nil,
            },
            mock_obj -- On failure, mock_obj contains the error
          )
          logger.error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        table.insert(context_mocks, mock_obj)
        return mock_obj
      end,

      restore_all = function()
        local success, result, err = error_handler.try(function()
          mock.restore_all()
          return true
        end)

        if not success then
          local error_obj = error_handler.runtime_error(
            "Failed to restore all mocks",
            {
              function_name = "context_mock.restore_all",
            },
            result -- On failure, result contains the error
          )
          logger.error(error_obj.message, error_obj.context)
          error(error_obj.message)
        end

        return true
      end,
    }

    -- Call the function with our wrappers
    -- Support both calling styles:
    -- with_mocks(function(mock_fn)) -- for old/example style
    -- with_mocks(function(mock, spy, stub)) -- for new style
    return fn(mock_fn, context_spy, context_stub)
  end)

  -- Set up results for proper error handling
  if fn_success then
    ok = true
    result = fn_result
  else
    ok = false
    error_during_execution = fn_result -- On failure, fn_result contains the error
  end

  -- Always restore mocks, even on failure
  logger.debug("Restoring context mocks", {
    mock_count = #context_mocks,
  })

  errors_during_restore = {}

  for i, mock_obj in ipairs(context_mocks) do
    -- Use error_handler.try to ensure we restore all mocks even if one fails
    logger.debug("Restoring context mock", {
      index = i,
      has_restore = mock_obj and type(mock_obj) == "table" and type(mock_obj.restore) == "function",
    })

    local restore_success, restore_result = error_handler.try(function()
      if mock_obj and type(mock_obj) == "table" and type(mock_obj.restore) == "function" then
        mock_obj:restore()
        return true
      else
        logger.debug("Cannot restore object (not a valid mock)", {
          index = i,
          obj_type = type(mock_obj),
        })
        return false,
          error_handler.validation_error("Cannot restore object (not a valid mock)", {
            function_name = "mock.with_mocks/restore",
            index = i,
            obj_type = type(mock_obj),
          })
      end
    end)

    -- If restoration fails, capture the error but continue
    if not restore_success then
      local error_obj = error_handler.runtime_error(
        "Failed to restore mock",
        {
          function_name = "mock.with_mocks/restore",
          index = i,
          mock_type = type(mock_obj),
        },
        restore_result -- On failure, restore_result contains the error
      )
      -- Use debug level instead of error to avoid confusing test output
      logger.debug("Failed to restore mock during test", error_obj.context)
      table.insert(errors_during_restore, error_obj)
    elseif restore_result == false then
      -- The try function succeeded but the validation failed
      logger.debug("Skipped restoration of invalid mock object", {
        index = i,
        error = "Not a valid mock with restore method",
      })
    end
  end

  logger.debug("Context mocks restoration complete", {
    success = #errors_during_restore == 0,
    error_count = #errors_during_restore,
  })

  -- If there was an error during the function execution
  if not ok then
    local error_message = "Error during mock context execution"
    
    -- Extract more information from the error if possible
    if error_during_execution then
      if type(error_during_execution) == "table" and error_during_execution.message then
        error_message = error_message .. ": " .. error_during_execution.message
      elseif type(error_during_execution) == "string" then
        error_message = error_message .. ": " .. error_during_execution
      end
    end
    
    local error_obj = error_handler.runtime_error(error_message, {
      function_name = "mock.with_mocks",
    }, error_during_execution)
    
    -- Properly detect test mode through the error handler
    local is_test_mode = error_handler and 
                         type(error_handler) == "table" and 
                         type(error_handler.is_test_mode) == "function" and
                         error_handler.is_test_mode()
    
    -- Check if this appears to be a test-related error based on structured error properties
    local is_expected_in_test = is_test_mode and 
                               error_during_execution and 
                               type(error_during_execution) == "table" and 
                               (error_during_execution.category == "VALIDATION" or
                                error_during_execution.category == "TEST_EXPECTED")
    
    if is_expected_in_test then
      -- If it's a validation error from an assertion, it's likely part of the test
      logger.debug("Test assertion failure in mock context", {
        error = error_message,
      })
    else
      -- For actual unexpected errors, check if we should log
      if not (error_handler and 
              type(error_handler.is_suppressing_test_logs) == "function" and 
              error_handler.is_suppressing_test_logs()) then
        logger.error("Error during mock context execution", {
          error = error_message,
        })
      end
    end

    -- If there were also errors during restoration, log them but prioritize the execution error
    if #errors_during_restore > 0 then
      logger.warn("Additional errors occurred during mock restoration", {
        error_count = #errors_during_restore,
      })
    end

    return nil, error_obj
  end

  -- If there were errors during mock restoration, report them
  if #errors_during_restore > 0 then
    local error_messages = {}
    for i, err in ipairs(errors_during_restore) do
      table.insert(error_messages, error_handler.format_error(err))
    end

    local error_obj = error_handler.runtime_error("Errors occurred during mock restoration", {
      function_name = "mock.with_mocks",
      error_count = #errors_during_restore,
      errors = error_messages,
    })
    -- Use debug level to avoid confusing test output
    logger.debug("Mock restoration issues during test", {
      error_count = #errors_during_restore
    })

    -- Since the main function executed successfully, we return both the result and the error
    return result, error_obj
  end

  logger.debug("Mock context completed successfully")

  -- Return the result from the function
  return result
end

return mock
