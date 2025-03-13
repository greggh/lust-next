-- mocking.lua - Mocking system integration for lust-next

local spy = require("lib.mocking.spy")
local stub = require("lib.mocking.stub")
local mock = require("lib.mocking.mock")
local logging = require("lib.tools.logging")

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
    if type(target) == 'table' and name ~= nil then
      -- Called as spy(obj, "method") - spy on an object method
      logger.debug("Creating spy on object method", {
        target_type = type(target),
        method_name = name
      })
      
      local spy_obj = spy.on(target, name)
      
      -- Make sure the wrapper gets all properties from the spy
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
      
      logger.debug("Spy created successfully on object method", {
        target_type = type(target),
        method_name = name
      })
      
      return target[name] -- Return the method wrapper
    else
      -- Called as spy(fn) - spy on a function
      logger.debug("Creating spy on function", {
        target_type = type(target)
      })
      
      return spy.new(target)
    end
  end
})

-- Export the stub module with compatibility for both object-oriented and functional API
mocking.stub = setmetatable({
  on = stub.on,
  new = stub.new
}, {
  __call = function(_, value_or_fn)
    logger.debug("Creating new stub", {
      value_type = type(value_or_fn)
    })
    return stub.new(value_or_fn)
  end
})

-- Export the mock module with compatibility for functional API
mocking.mock = setmetatable({
  create = mock.create
}, {
  __call = function(_, target, method_or_options, impl_or_value)
    if type(method_or_options) == "string" then
      -- Called as mock(obj, "method", value_or_function)
      logger.debug("Creating mock with method stub", {
        target_type = type(target),
        method = method_or_options,
        implementation_type = type(impl_or_value)
      })
      
      local mock_obj = mock.create(target)
      mock_obj:stub(method_or_options, impl_or_value)
      return mock_obj
    else
      -- Called as mock(obj, options)
      logger.debug("Creating mock with options", {
        target_type = type(target),
        options_type = type(method_or_options)
      })
      
      return mock.create(target, method_or_options)
    end
  end
})

-- Export the with_mocks context manager
mocking.with_mocks = mock.with_mocks

-- Register cleanup hook for mocks after tests
function mocking.register_cleanup_hook(after_test_fn)
  logger.debug("Registering mock cleanup hook")
  
  local original_fn = after_test_fn or function() end
  
  return function(name)
    logger.debug("Running test cleanup hook", {
      test_name = name
    })
    
    -- Call the original after function first
    local result = original_fn(name)
    
    -- Then restore all mocks
    logger.debug("Restoring all mocks")
    mock.restore_all()
    
    return result
  end
end

-- Function to add be_truthy/be_falsy assertions to lust-next
function mocking.ensure_assertions(lust_next_module)
  logger.debug("Ensuring mocking assertions are registered")
  
  local paths = lust_next_module.paths
  if not paths then
    logger.warn("Failed to register assertions - paths not found", {
      module_name = "lust_next_module"
    })
    return
  end
  
  -- Add assertions to the path chains
  local assertions_to_add = {"be_truthy", "be_falsy", "be_falsey"}
  logger.debug("Adding mocking assertions to path chains", {
    assertions = table.concat(assertions_to_add, ", ")
  })
  
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
  
  logger.info("Mocking assertions registered successfully")
end

return mocking