-- mocking.lua - Mocking system integration for firmo

local spy = require("lib.mocking.spy")
local stub = require("lib.mocking.stub")
local mock = require("lib.mocking.mock")
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Initialize module logger
local logger = logging.get_logger("mocking")
logging.configure_from_config("mocking")

local mocking = {
  -- Module version
  _VERSION = "1.0.0"
}

-- Export the spy module with compatibility for both object-oriented and functional API
mocking.spy = setmetatable({
  on = spy.on,
  new = spy.new
}, {
  __call = function(_, target, name)
    -- Input validation with error handling
    if target == nil then
      local err = error_handler.validation_error(
        "Cannot create spy on nil target",
        {
          function_name = "mocking.spy",
          parameter_name = "target",
          provided_value = "nil"
        }
      )
      logger.error(err.message, err.context)
      return nil, err
    end
    
    if type(target) == 'table' and name ~= nil then
      -- Called as spy(obj, "method") - spy on an object method
      
      -- Validate method name
      if type(name) ~= "string" then
        local err = error_handler.validation_error(
          "Method name must be a string",
          {
            function_name = "mocking.spy",
            parameter_name = "name",
            provided_type = type(name),
            provided_value = tostring(name)
          }
        )
        logger.error(err.message, err.context)
        return nil, err
      end
      
      -- Validate method exists on target
      if target[name] == nil then
        local err = error_handler.validation_error(
          "Method does not exist on target object",
          {
            function_name = "mocking.spy",
            parameter_name = "name",
            method_name = name,
            target_type = type(target)
          }
        )
        logger.error(err.message, err.context)
        return nil, err
      end
      
      logger.debug("Creating spy on object method", {
        target_type = type(target),
        method_name = name
      })
      
      -- Use error handling to safely create the spy
      local success, spy_obj, err = error_handler.try(function()
        return spy.on(target, name)
      end)
      
      if not success then
        local error_obj = error_handler.runtime_error(
          "Failed to create spy on object method",
          {
            function_name = "mocking.spy",
            target_type = type(target),
            method_name = name
          },
          spy_obj -- On failure, spy_obj contains the error
        )
        logger.error(error_obj.message, error_obj.context)
        return nil, error_obj
      end
      
      -- Make sure the wrapper gets all properties from the spy with error handling
      local success, _, err = error_handler.try(function()
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
        local error_obj = error_handler.runtime_error(
          "Failed to set properties on spied method",
          {
            function_name = "mocking.spy",
            target_type = type(target),
            method_name = name
          },
          err
        )
        logger.error(error_obj.message, error_obj.context)
        -- We continue anyway - this is a non-critical error
        logger.warn("Continuing with partially configured spy")
      end
      
      logger.debug("Spy created successfully on object method", {
        target_type = type(target),
        method_name = name
      })
      
      return target[name] -- Return the method wrapper
    else
      -- Called as spy(fn) - spy on a function
      
      -- Validate function
      if type(target) ~= "function" then
        local err = error_handler.validation_error(
          "Target must be a function when creating standalone spy",
          {
            function_name = "mocking.spy",
            parameter_name = "target",
            provided_type = type(target)
          }
        )
        logger.error(err.message, err.context)
        return nil, err
      end
      
      logger.debug("Creating spy on function", {
        target_type = type(target)
      })
      
      -- Use error handling to safely create the spy
      local success, spy_obj, err = error_handler.try(function()
        return spy.new(target)
      end)
      
      if not success then
        local error_obj = error_handler.runtime_error(
          "Failed to create spy on function",
          {
            function_name = "mocking.spy",
            target_type = type(target)
          },
          spy_obj -- On failure, spy_obj contains the error
        )
        logger.error(error_obj.message, error_obj.context)
        return nil, error_obj
      end
      
      return spy_obj
    end
  end
})

-- Export the stub module with compatibility for both object-oriented and functional API
mocking.stub = setmetatable({
  on = function(target, name, value_or_impl)
    -- Input validation
    if target == nil then
      local err = error_handler.validation_error(
        "Cannot create stub on nil target",
        {
          function_name = "mocking.stub.on",
          parameter_name = "target",
          provided_value = "nil"
        }
      )
      logger.error(err.message, err.context)
      return nil, err
    end
    
    if type(name) ~= "string" then
      local err = error_handler.validation_error(
        "Method name must be a string",
        {
          function_name = "mocking.stub.on",
          parameter_name = "name",
          provided_type = type(name),
          provided_value = tostring(name)
        }
      )
      logger.error(err.message, err.context)
      return nil, err
    end
    
    logger.debug("Creating stub on object method", {
      target_type = type(target),
      method_name = name,
      value_type = type(value_or_impl)
    })
    
    -- Use error handling to safely create the stub
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
          value_type = type(value_or_impl)
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end
    
    logger.debug("Stub created successfully on object method", {
      target_type = type(target),
      method_name = name
    })
    
    return stub_obj
  end,
  
  new = function(value_or_fn)
    logger.debug("Creating new stub function", {
      value_type = type(value_or_fn)
    })
    
    -- Use error handling to safely create the stub
    local success, stub_obj, err = error_handler.try(function()
      return stub.new(value_or_fn)
    end)
    
    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to create new stub function",
        {
          function_name = "mocking.stub.new",
          value_type = type(value_or_fn)
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end
    
    return stub_obj
  end
}, {
  __call = function(_, value_or_fn)
    -- Input validation (optional, as stub can be called without arguments)
    if value_or_fn ~= nil and type(value_or_fn) ~= "function" and type(value_or_fn) ~= "table" and
       type(value_or_fn) ~= "string" and type(value_or_fn) ~= "number" and type(value_or_fn) ~= "boolean" then
      local err = error_handler.validation_error(
        "Stub value must be a function, table, string, number, boolean or nil",
        {
          function_name = "mocking.stub",
          parameter_name = "value_or_fn",
          provided_type = type(value_or_fn),
          provided_value = tostring(value_or_fn)
        }
      )
      logger.error(err.message, err.context)
      return nil, err
    end
    
    logger.debug("Creating new stub", {
      value_type = value_or_fn and type(value_or_fn) or "nil"
    })
    
    -- Use error handling to safely create the stub
    local success, stub_obj, err = error_handler.try(function()
      return stub.new(value_or_fn)
    end)
    
    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to create stub",
        {
          function_name = "mocking.stub",
          value_type = value_or_fn and type(value_or_fn) or "nil"
        },
        stub_obj -- On failure, stub_obj contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end
    
    return stub_obj
  end
})

-- Export the mock module with compatibility for functional API
mocking.mock = setmetatable({
  create = function(target, options)
    -- Input validation
    if target == nil then
      local err = error_handler.validation_error(
        "Cannot create mock on nil target",
        {
          function_name = "mocking.mock.create",
          parameter_name = "target",
          provided_value = "nil"
        }
      )
      logger.error(err.message, err.context)
      return nil, err
    end
    
    if options ~= nil and type(options) ~= "table" then
      local err = error_handler.validation_error(
        "Options must be a table or nil",
        {
          function_name = "mocking.mock.create",
          parameter_name = "options",
          provided_type = type(options)
        }
      )
      logger.error(err.message, err.context)
      return nil, err
    end
    
    logger.debug("Creating mock object", {
      target_type = type(target),
      options = options or {}
    })
    
    -- Use error handling to safely create the mock
    local success, mock_obj, err = error_handler.try(function()
      return mock.create(target, options)
    end)
    
    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to create mock object",
        {
          function_name = "mocking.mock.create",
          target_type = type(target),
          options_type = options and type(options) or "nil"
        },
        mock_obj -- On failure, mock_obj contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end
    
    logger.debug("Mock object created successfully", {
      target_type = type(target),
      verify_all = mock_obj._verify_all_expectations_called
    })
    
    return mock_obj
  end,
  
  restore_all = function()
    logger.debug("Restoring all mocks")
    
    -- Use error handling to safely restore all mocks
    local success, err = error_handler.try(function()
      mock.restore_all()
      return true
    end)
    
    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to restore all mocks",
        {
          function_name = "mocking.mock.restore_all"
        },
        err
      )
      logger.error(error_obj.message, error_obj.context)
      return false, error_obj
    end
    
    logger.debug("All mocks restored successfully")
    return true
  end,
  
  with_mocks = function(fn)
    -- Input validation
    if type(fn) ~= "function" then
      local err = error_handler.validation_error(
        "with_mocks requires a function argument",
        {
          function_name = "mocking.mock.with_mocks",
          parameter_name = "fn",
          provided_type = type(fn)
        }
      )
      logger.error(err.message, err.context)
      return nil, err
    end
    
    logger.debug("Starting with_mocks context manager")
    
    -- Use error handling to safely execute the with_mocks function
    local success, result, err = error_handler.try(function()
      return mock.with_mocks(fn)
    end)
    
    if not success then
      local error_obj = error_handler.runtime_error(
        "Failed to execute with_mocks context manager",
        {
          function_name = "mocking.mock.with_mocks"
        },
        result -- On failure, result contains the error
      )
      logger.error(error_obj.message, error_obj.context)
      return nil, error_obj
    end
    
    logger.debug("with_mocks context manager completed successfully")
    return result
  end
}, {
  __call = function(_, target, method_or_options, impl_or_value)
    -- Input validation
    if target == nil then
      local err = error_handler.validation_error(
        "Cannot create mock on nil target",
        {
          function_name = "mocking.mock",
          parameter_name = "target",
          provided_value = "nil"
        }
      )
      logger.error(err.message, err.context)
      return nil, err
    end
    
    if type(method_or_options) == "string" then
      -- Called as mock(obj, "method", value_or_function)
      -- Validate method name
      if method_or_options == "" then
        local err = error_handler.validation_error(
          "Method name cannot be empty",
          {
            function_name = "mocking.mock",
            parameter_name = "method_or_options",
            provided_value = method_or_options
          }
        )
        logger.error(err.message, err.context)
        return nil, err
      end
      
      logger.debug("Creating mock with method stub", {
        target_type = type(target),
        method = method_or_options,
        implementation_type = type(impl_or_value)
      })
      
      -- Use error handling to safely create the mock
      local success, mock_obj, err = error_handler.try(function()
        local m = mock.create(target)
        return m, m:stub(method_or_options, impl_or_value)
      end)
      
      if not success then
        local error_obj = error_handler.runtime_error(
          "Failed to create mock with method stub",
          {
            function_name = "mocking.mock",
            target_type = type(target),
            method = method_or_options,
            implementation_type = type(impl_or_value)
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
        local err = error_handler.validation_error(
          "Options must be a table or nil",
          {
            function_name = "mocking.mock",
            parameter_name = "method_or_options",
            provided_type = type(method_or_options)
          }
        )
        logger.error(err.message, err.context)
        return nil, err
      end
      
      logger.debug("Creating mock with options", {
        target_type = type(target),
        options_type = type(method_or_options)
      })
      
      -- Use error handling to safely create the mock
      local success, mock_obj, err = error_handler.try(function()
        return mock.create(target, method_or_options)
      end)
      
      if not success then
        local error_obj = error_handler.runtime_error(
          "Failed to create mock with options",
          {
            function_name = "mocking.mock",
            target_type = type(target),
            options_type = method_or_options and type(method_or_options) or "nil"
          },
          mock_obj -- On failure, mock_obj contains the error
        )
        logger.error(error_obj.message, error_obj.context)
        return nil, error_obj
      end
      
      return mock_obj
    end
  end
})

-- Export the with_mocks context manager through our enhanced version
mocking.with_mocks = mocking.mock.with_mocks

-- Register cleanup hook for mocks after tests
function mocking.register_cleanup_hook(after_test_fn)
  logger.debug("Registering mock cleanup hook")
  
  -- Use empty function as fallback
  local original_fn
  
  if after_test_fn ~= nil and type(after_test_fn) ~= "function" then
    local err = error_handler.validation_error(
      "Cleanup hook must be a function or nil",
      {
        function_name = "mocking.register_cleanup_hook",
        parameter_name = "after_test_fn",
        provided_type = type(after_test_fn)
      }
    )
    logger.error(err.message, err.context)
    
    -- Use fallback empty function
    original_fn = function() end
  else
    original_fn = after_test_fn or function() end
  end
  
  -- Return the cleanup hook function with error handling
  return function(name)
    logger.debug("Running test cleanup hook", {
      test_name = name
    })
    
    -- Call the original after function first with error handling
    local success, result, err = error_handler.try(function()
      return original_fn(name)
    end)
    
    if not success then
      logger.error("Original test cleanup hook failed", {
        test_name = name,
        error = error_handler.format_error(result)
      })
      -- We continue with mock restoration despite the error
    end
    
    -- Then restore all mocks with error handling
    logger.debug("Restoring all mocks")
    local mock_success, mock_err = error_handler.try(function()
      mock.restore_all()
      return true
    end)
    
    if not mock_success then
      logger.error("Failed to restore mocks in cleanup hook", {
        test_name = name,
        error = error_handler.format_error(mock_success)
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

-- Function to add be_truthy/be_falsy assertions to firmo
function mocking.ensure_assertions(firmo_module)
  logger.debug("Ensuring mocking assertions are registered")
  
  -- Input validation
  if firmo_module == nil then
    local err = error_handler.validation_error(
      "Cannot register assertions on nil module",
      {
        function_name = "mocking.ensure_assertions",
        parameter_name = "firmo_module",
        provided_value = "nil"
      }
    )
    logger.error(err.message, err.context)
    return false, err
  end
  
  -- Use error handling to safely access the paths
  local success, paths, err = error_handler.try(function()
    return firmo_module.paths
  end)
  
  if not success or not paths then
    local error_obj = error_handler.validation_error(
      "Failed to register assertions - paths not found or accessible",
      {
        function_name = "mocking.ensure_assertions",
        module_name = "firmo_module",
        error = success and "paths is nil" or error_handler.format_error(paths)
      }
    )
    logger.warn(error_obj.message, error_obj.context)
    return false, error_obj
  end
  
  -- Add assertions to the path chains with error handling
  local assertions_to_add = {"be_truthy", "be_falsy", "be_falsey"}
  logger.debug("Adding mocking assertions to path chains", {
    assertions = table.concat(assertions_to_add, ", ")
  })
  
  -- Use error handling for the entire assertions addition process
  local success, _, err = error_handler.try(function()
    for _, assertion in ipairs(assertions_to_add) do
      -- Check if present in 'to' chain
      local found_in_to = false
      for _, v in ipairs(paths.to) do
        if v == assertion then found_in_to = true; break end
      end
      
      if not found_in_to then 
        table.insert(paths.to, assertion)
        logger.debug("Added assertion to 'to' chain", {
          assertion = assertion
        })
      end
      
      -- Check if present in 'to_not' chain
      local found_in_to_not = false
      for _, v in ipairs(paths.to_not) do
        if v == assertion then found_in_to_not = true; break end
      end
      
      if not found_in_to_not then 
        -- Special handling for to_not since it has a chain function
        local chain_fn = paths.to_not.chain
        local to_not_temp = {}
        for i, v in ipairs(paths.to_not) do
          to_not_temp[i] = v
        end
        table.insert(to_not_temp, assertion)
        paths.to_not = to_not_temp
        paths.to_not.chain = chain_fn
        
        logger.debug("Added assertion to 'to_not' chain", {
          assertion = assertion
        })
      end
    end
    
    -- Add assertion implementations if not present
    if not paths.be_truthy then
      logger.debug("Adding be_truthy assertion implementation")
      paths.be_truthy = {
        test = function(v)
          return v and true or false,
            'expected ' .. tostring(v) .. ' to be truthy',
            'expected ' .. tostring(v) .. ' to not be truthy'
        end
      }
    end
    
    if not paths.be_falsy then
      logger.debug("Adding be_falsy assertion implementation")
      paths.be_falsy = {
        test = function(v)
          return not v,
            'expected ' .. tostring(v) .. ' to be falsy',
            'expected ' .. tostring(v) .. ' to not be falsy'
        end
      }
    end
    
    if not paths.be_falsey then
      logger.debug("Adding be_falsey assertion implementation")
      paths.be_falsey = {
        test = function(v)
          return not v,
            'expected ' .. tostring(v) .. ' to be falsey',
            'expected ' .. tostring(v) .. ' to not be falsey'
        end
      }
    end
    
    return true
  end)
  
  if not success then
    local error_obj = error_handler.runtime_error(
      "Failed to register mocking assertions",
      {
        function_name = "mocking.ensure_assertions",
        assertions = table.concat(assertions_to_add, ", ")
      },
      err
    )
    logger.error(error_obj.message, error_obj.context)
    return false, error_obj
  end
  
  logger.info("Mocking assertions registered successfully")
  return true
end

return mocking
