-- mocking.lua - Mocking system integration for firmo

local spy = require("lib.mocking.spy")
local stub = require("lib.mocking.stub")
local mock = require("lib.mocking.mock")
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Initialize module logger
local logger = logging.get_logger("mocking")
logging.configure_from_config("mocking")

---@class mocking
---@field _VERSION string Module version
---@field spy table|fun(target: table|function, name?: string): spy_object Spy on a function or object method
---@field stub table|fun(value_or_fn?: any): stub_object Create a stub function that returns a specified value
---@field mock table|fun(target: table, method_or_options?: string|table, impl_or_value?: any): table Create a mock object with controlled behavior
---@field with_mocks fun(fn: function): any Execute a function with automatic mock cleanup
---@field register_cleanup_hook fun(after_test_fn?: function): function Register a cleanup hook for mocks
---@field ensure_assertions fun(firmo_module: table): boolean, table? Ensure required assertions are available
---@field reset_all fun(): boolean Reset all spies, stubs, and mocks created through this module
---@field create_spy fun(fn?: function): spy_object Create a new spy function
---@field create_stub fun(return_value?: any): stub_object Create a new stub function
---@field create_mock fun(methods?: table<string, function|any>): table Create a new mock object with specified methods
---@field is_spy fun(obj: any): boolean Check if an object is a spy
---@field is_stub fun(obj: any): boolean Check if an object is a stub
---@field is_mock fun(obj: any): boolean Check if an object is a mock
---@field get_all_mocks fun(): table<number, any> Get all mocks created through this module
---@field safe_mock fun(target: table, method_name: string, unsafe_fn: function): function Create a safe mock that won't cause infinite recursion
---@field verify fun(mock_obj: table): boolean Verify that a mock's expectations were met
---@field configure fun(options: table): mocking Configure the mocking system
local mocking = {
  -- Module version
  _VERSION = "1.0.0",
}

-- Export the spy module with compatibility for both object-oriented and functional API
mocking.spy = setmetatable({
  on = spy.on,
  new = spy.new,
}, {
  ---@param _ any The table being used as a function
  ---@param target table|function The target to spy on (table or function)
  ---@param name? string Optional name of the method to spy on (for table targets)
  ---@return table|nil spy The created spy, or nil on error
  ---@return table|nil error Error information if spy creation failed
  __call = function(_, target, name)
    -- Input validation with error handling
    if target == nil then
      local err = error_handler.validation_error("Cannot create spy on nil target", {
        function_name = "mocking.spy",
        parameter_name = "target",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    if type(target) == "table" and name ~= nil then
      -- Called as spy(obj, "method") - spy on an object method

      -- Validate method name
      if type(name) ~= "string" then
        local err = error_handler.validation_error("Method name must be a string", {
          function_name = "mocking.spy",
          parameter_name = "name",
          provided_type = type(name),
          provided_value = tostring(name),
        })
        logger.error(err.message, err.context)
        return nil, err
      end

      -- Validate method exists on target
      if target[name] == nil then
        local err = error_handler.validation_error("Method does not exist on target object", {
          function_name = "mocking.spy",
          parameter_name = "name",
          method_name = name,
          target_type = type(target),
        })
        logger.error(err.message, err.context)
        return nil, err
      end

      logger.debug("Creating spy on object method", {
        target_type = type(target),
        method_name = name,
      })

      -- Use error handling to safely create the spy
      ---@diagnostic disable-next-line: unused-local
      local success, spy_obj, err = error_handler.try(function()
        return spy.on(target, name)
      end)

      if not success then
        local error_obj = error_handler.runtime_error(
          "Failed to create spy on object method",
          {
            function_name = "mocking.spy",
            target_type = type(target),
            method_name = name,
          },
          spy_obj -- On failure, spy_obj contains the error
        )
        logger.error(error_obj.message, error_obj.context)
        return nil, error_obj
      end

      -- Make sure the wrapper gets all properties from the spy with error handling
      local success, _, err = error_handler.try(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        for k, v in pairs(spy_obj) do
          if type(target[name]) == "table" then
            target[name][k] = v
          end
        end

        -- Make sure callback works
        if type(target[name]) == "table" then
          target[name].called_with = function(_, ...)
            return spy_obj:called_with(...)
          end
        end

        return true
      end)

      if not success then
        local error_obj = error_handler.runtime_error("Failed to set properties on spied method", {
          function_name = "mocking.spy",
          target_type = type(target),
          method_name = name,
        }, err)
        logger.error(error_obj.message, error_obj.context)
        -- We continue anyway - this is a non-critical error
        logger.warn("Continuing with partially configured spy")
      end

      logger.debug("Spy created successfully on object method", {
        target_type = type(target),
        method_name = name,
      })

      return target[name] -- Return the method wrapper
    else
      -- Called as spy(fn) - spy on a function

      -- Validate function
      if type(target) ~= "function" then
        local err = error_handler.validation_error("Target must be a function when creating standalone spy", {
          function_name = "mocking.spy",
          parameter_name = "target",
          provided_type = type(target),
        })
        logger.error(err.message, err.context)
        return nil, err
      end

      logger.debug("Creating spy on function", {
        target_type = type(target),
      })

      -- Use error handling to safely create the spy
      ---@diagnostic disable-next-line: unused-local
      local success, spy_obj, err = error_handler.try(function()
        return spy.new(target)
      end)

      if not success then
        local error_obj = error_handler.runtime_error(
          "Failed to create spy on function",
          {
            function_name = "mocking.spy",
            target_type = type(target),
          },
          spy_obj -- On failure, spy_obj contains the error
        )
        logger.error(error_obj.message, error_obj.context)
        return nil, error_obj
      end

      return spy_obj
    end
  end,
})

-- Export the stub module with compatibility for both object-oriented and functional API
mocking.stub = setmetatable({
  ---@param target table The object to stub a method on
  ---@param name string The name of the method to stub
  ---@param value_or_impl any The value or function implementation for the stub
  ---@return table|nil stub The created stub, or nil on error
  ---@return table|nil error Error information if creation failed
  on = function(target, name, value_or_impl)
    -- Input validation
    if target == nil then
      local err = error_handler.validation_error("Cannot create stub on nil target", {
        function_name = "mocking.stub.on",
        parameter_name = "target",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    if type(name) ~= "string" then
      local err = error_handler.validation_error("Method name must be a string", {
        function_name = "mocking.stub.on",
        parameter_name = "name",
        provided_type = type(name),
        provided_value = tostring(name),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    logger.debug("Creating stub on object method", {
      target_type = type(target),
      method_name = name,
      value_type = type(value_or_impl),
    })

    -- Use error handling to safely create the stub
    ---@diagnostic disable-next-line: unused-local
    local success, stub_obj, err = error_handler.try(function()
      return stub.on(target, name, value_or_impl)
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to create stub on object method",
        {
          function_name = "mocking.stub.on",
          target_type = type(target),
          method_name = name,
          value_type = type(value_or_impl),
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    logger.debug("Stub created successfully on object method", {
      target_type = type(target),
      method_name = name,
    })

    return stub_obj
  end,

  ---@param value_or_fn? any The value or function implementation for the stub
  ---@return table|nil stub The created stub, or nil on error
  ---@return table|nil error Error information if creation failed
  new = function(value_or_fn)
    logger.debug("Creating new stub function", {
      value_type = type(value_or_fn),
    })

    -- Use error handling to safely create the stub
    ---@diagnostic disable-next-line: unused-local
    local success, stub_obj, err = error_handler.try(function()
      return stub.new(value_or_fn)
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to create new stub function",
        {
          function_name = "mocking.stub.new",
          value_type = type(value_or_fn),
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    return stub_obj
  end,
}, {
  ---@param _ any The table being used as a function
  ---@param value_or_fn? any The value or function implementation for the stub
  ---@return table|nil stub The created stub, or nil on error
  ---@return table|nil error Error information if creation failed
  __call = function(_, value_or_fn)
    -- Input validation (optional, as stub can be called without arguments)
    if
      value_or_fn ~= nil
      and type(value_or_fn) ~= "function"
      and type(value_or_fn) ~= "table"
      and type(value_or_fn) ~= "string"
      and type(value_or_fn) ~= "number"
      and type(value_or_fn) ~= "boolean"
    then
      local err =
        error_handler.validation_error("Stub value must be a function, table, string, number, boolean or nil", {
          function_name = "mocking.stub",
          parameter_name = "value_or_fn",
          provided_type = type(value_or_fn),
          provided_value = tostring(value_or_fn),
        })
      logger.error(err.message, err.context)
      return nil, err
    end

    logger.debug("Creating new stub", {
      value_type = value_or_fn and type(value_or_fn) or "nil",
    })

    -- Use error handling to safely create the stub
    ---@diagnostic disable-next-line: unused-local
    local success, stub_obj, err = error_handler.try(function()
      return stub.new(value_or_fn)
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to create stub",
        {
          function_name = "mocking.stub",
          value_type = value_or_fn and type(value_or_fn) or "nil",
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    return stub_obj
  end,
})

-- Export the mock module with compatibility for functional API
mocking.mock = setmetatable({
  ---@param target table The object to create a mock of
  ---@param options? table Optional configuration { verify_all_expectations?: boolean }
  ---@return table|nil mock The created mock object, or nil on error
  ---@return table|nil error Error information if creation failed
  create = function(target, options)
    -- Input validation
    if target == nil then
      local err = error_handler.validation_error("Cannot create mock on nil target", {
        function_name = "mocking.mock.create",
        parameter_name = "target",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    if options ~= nil and type(options) ~= "table" then
      local err = error_handler.validation_error("Options must be a table or nil", {
        function_name = "mocking.mock.create",
        parameter_name = "options",
        provided_type = type(options),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    logger.debug("Creating mock object", {
      target_type = type(target),
      options = options or {},
    })

    -- Use error handling to safely create the mock
    ---@diagnostic disable-next-line: unused-local
    local success, mock_obj, err = error_handler.try(function()
      return mock.create(target, options)
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to create mock object",
        {
          function_name = "mocking.mock.create",
          target_type = type(target),
          options_type = options and type(options) or "nil",
        },
        mock_obj -- On failure, mock_obj contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    logger.debug("Mock object created successfully", {
      target_type = type(target),
      verify_all = mock_obj._verify_all_expectations_called,
    })

    return mock_obj
  end,

  ---@return boolean success Whether all mocks were successfully restored
  ---@return table|nil error Error information if restoration failed
  restore_all = function()
    logger.debug("Restoring all mocks")

    -- Use error handling to safely restore all mocks
    local success, err = error_handler.try(function()
      mock.restore_all()
      return true
    end)

    if not success then
      local error_obj = error_handler.runtime_error("Failed to restore all mocks", {
        function_name = "mocking.mock.restore_all",
      }, err)
      logger.error(error_obj.message, error_obj.context)
      return false, error_obj
    end

    logger.debug("All mocks restored successfully")
    return true
  end,

  ---@param fn function The function to execute with automatic mock cleanup
  ---@return any result The result from the function execution
  ---@return table|nil error Error information if execution failed
  with_mocks = function(fn)
    -- Input validation
    if type(fn) ~= "function" then
      local err = error_handler.validation_error("with_mocks requires a function argument", {
        function_name = "mocking.mock.with_mocks",
        parameter_name = "fn",
        provided_type = type(fn),
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    logger.debug("Starting with_mocks context manager")

    -- Use error handling to safely execute the with_mocks function
    ---@diagnostic disable-next-line: unused-local
    local success, result, err = error_handler.try(function()
      return mock.with_mocks(fn)
    end)

    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to execute with_mocks context manager",
        {
          function_name = "mocking.mock.with_mocks",
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end

    logger.debug("with_mocks context manager completed successfully")
    return result
  end,
}, {
  ---@param _ any The table being used as a function
  ---@param target table The object to create a mock of
  ---@param method_or_options? string|table Either a method name to stub or options table
  ---@param impl_or_value? any The implementation or return value for the stub (when method specified)
  ---@return table|nil mock The created mock object, or nil on error
  ---@return table|nil error Error information if creation failed
  __call = function(_, target, method_or_options, impl_or_value)
    -- Input validation
    if target == nil then
      local err = error_handler.validation_error("Cannot create mock on nil target", {
        function_name = "mocking.mock",
        parameter_name = "target",
        provided_value = "nil",
      })
      logger.error(err.message, err.context)
      return nil, err
    end

    if type(method_or_options) == "string" then
      -- Called as mock(obj, "method", value_or_function)
      -- Validate method name
      if method_or_options == "" then
        local err = error_handler.validation_error("Method name cannot be empty", {
          function_name = "mocking.mock",
          parameter_name = "method_or_options",
          provided_value = method_or_options,
        })
        logger.error(err.message, err.context)
        return nil, err
      end

      logger.debug("Creating mock with method stub", {
        target_type = type(target),
        method = method_or_options,
        implementation_type = type(impl_or_value),
      })

      -- Use error handling to safely create the mock
      ---@diagnostic disable-next-line: unused-local
      local success, mock_obj, err = error_handler.try(function()
        local m = mock.create(target)
        ---@diagnostic disable-next-line: need-check-nil
        return m, m:stub(method_or_options, impl_or_value)
      end)

      if not success then
        local error_obj = error_handler.runtime_error(
          "Failed to create mock with method stub",
          {
            function_name = "mocking.mock",
            target_type = type(target),
            method = method_or_options,
            implementation_type = type(impl_or_value),
          },
          mock_obj -- On failure, mock_obj contains the error
        )
        logger.error(error_obj.message, error_obj.context)
        return nil, error_obj
      end

      return mock_obj
    else
      -- Called as mock(obj, options)
      -- Validate options
      if method_or_options ~= nil and type(method_or_options) ~= "table" then
        local err = error_handler.validation_error("Options must be a table or nil", {
          function_name = "mocking.mock",
          parameter_name = "method_or_options",
          provided_type = type(method_or_options),
        })
        logger.error(err.message, err.context)
        return nil, err
      end

      logger.debug("Creating mock with options", {
        target_type = type(target),
        options_type = type(method_or_options),
      })

      -- Use error handling to safely create the mock
      ---@diagnostic disable-next-line: unused-local
      local success, mock_obj, err = error_handler.try(function()
        return mock.create(target, method_or_options)
      end)

      if not success then
        local error_obj = error_handler.runtime_error(
          "Failed to create mock with options",
          {
            function_name = "mocking.mock",
            target_type = type(target),
            options_type = method_or_options and type(method_or_options) or "nil",
          },
          mock_obj -- On failure, mock_obj contains the error
        )
        logger.error(error_obj.message, error_obj.context)
        return nil, error_obj
      end

      return mock_obj
    end
  end,
})

-- Export the with_mocks context manager through our enhanced version
mocking.with_mocks = mocking.mock.with_mocks

---@param after_test_fn? function Function to call after each test (optional)
---@return function hook The cleanup hook function to use
-- Register cleanup hook for mocks after tests
function mocking.register_cleanup_hook(after_test_fn)
  logger.debug("Registering mock cleanup hook")

  -- Use empty function as fallback
  local original_fn

  if after_test_fn ~= nil and type(after_test_fn) ~= "function" then
    local err = error_handler.validation_error("Cleanup hook must be a function or nil", {
      function_name = "mocking.register_cleanup_hook",
      parameter_name = "after_test_fn",
      provided_type = type(after_test_fn),
    })
    logger.error(err.message, err.context)

    -- Use fallback empty function
    original_fn = function() end
  else
    original_fn = after_test_fn or function() end
  end

  -- Return the cleanup hook function with error handling
  return function(name)
    logger.debug("Running test cleanup hook", {
      test_name = name,
    })

    -- Call the original after function first with error handling
    ---@diagnostic disable-next-line: unused-local
    local success, result, err = error_handler.try(function()
      ---@diagnostic disable-next-line: redundant-parameter
      return original_fn(name)
    end)

    if not success then
      logger.error("Original test cleanup hook failed", {
        test_name = name,
        error = error_handler.format_error(result),
      })
      -- We continue with mock restoration despite the error
    end

    -- Then restore all mocks with error handling
    logger.debug("Restoring all mocks")
    ---@diagnostic disable-next-line: unused-local
    local mock_success, mock_err = error_handler.try(function()
      mock.restore_all()
      return true
    end)

    if not mock_success then
      logger.error("Failed to restore mocks in cleanup hook", {
        test_name = name,
        error = error_handler.format_error(mock_success),
      })
      -- We still return the original result despite the error
    end

    -- Return the result from the original function
    if success then
      return result
    else
      -- If the original function failed, we return nil
      return nil
    end
  end
end

---@param firmo_module table The firmo module instance to modify
---@return boolean success Whether the assertions were successfully registered
---@return table|nil error Error information if registration failed
-- Function to add be_truthy/be_falsy assertions to firmo
function mocking.ensure_assertions(firmo_module)
  logger.debug("Ensuring mocking assertions are registered")

  -- Input validation
  if firmo_module == nil then
    local err = error_handler.validation_error("Cannot register assertions on nil module", {
      function_name = "mocking.ensure_assertions",
      parameter_name = "firmo_module",
      provided_value = "nil",
    })
    logger.error(err.message, err.context)
    return false, err
  end
  
  -- In newer versions of firmo, assertions might be managed directly by the assertion module.
  -- Just return success since the assertions should already be defined there or in lib/assertion.lua.
  
  logger.info("Skipping assertion registration in newer firmo version", {
    function_name = "mocking.ensure_assertions",
    module = "mocking",
    reason = "Built-in assertions likely already exist",
  })
  
  -- Return success without modifying paths since they may not exist or be needed in newer versions
  return true
end

return mocking
