-- mocking.lua - Mocking system integration for lust-next

local spy = require("lib.mocking.spy")
local stub = require("lib.mocking.stub")
local mock = require("lib.mocking.mock")

local mocking = {}

-- Export the spy module with compatibility for both object-oriented and functional API
mocking.spy = setmetatable({
  on = spy.on,
  new = spy.new
}, {
  __call = function(_, target, name)
    if type(target) == 'table' and name ~= nil then
      -- Called as spy(obj, "method") - spy on an object method
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
      
      return target[name] -- Return the method wrapper
    else
      -- Called as spy(fn) - spy on a function
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
      local mock_obj = mock.create(target)
      mock_obj:stub(method_or_options, impl_or_value)
      return mock_obj
    else
      -- Called as mock(obj, options)
      return mock.create(target, method_or_options)
    end
  end
})

-- Export the with_mocks context manager
mocking.with_mocks = mock.with_mocks

-- Register cleanup hook for mocks after tests
function mocking.register_cleanup_hook(after_test_fn)
  local original_fn = after_test_fn or function() end
  
  return function(name)
    -- Call the original after function first
    local result = original_fn(name)
    
    -- Then restore all mocks
    mock.restore_all()
    
    return result
  end
end

-- Function to add be_truthy/be_falsy assertions to lust-next
function mocking.ensure_assertions(lust_next_module)
  local paths = lust_next_module.paths
  if paths then
    -- Add assertions to the path chains
    for _, assertion in ipairs({"be_truthy", "be_falsy", "be_falsey"}) do
      -- Check if present in 'to' chain
      local found_in_to = false
      for _, v in ipairs(paths.to) do
        if v == assertion then found_in_to = true; break end
      end
      if not found_in_to then table.insert(paths.to, assertion) end
      
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
      end
    end
    
    -- Add assertion implementations if not present
    if not paths.be_truthy then
      paths.be_truthy = {
        test = function(v)
          return v and true or false,
            'expected ' .. tostring(v) .. ' to be truthy',
            'expected ' .. tostring(v) .. ' to not be truthy'
        end
      }
    end
    
    if not paths.be_falsy then
      paths.be_falsy = {
        test = function(v)
          return not v,
            'expected ' .. tostring(v) .. ' to be falsy',
            'expected ' .. tostring(v) .. ' to not be falsy'
        end
      }
    end
    
    if not paths.be_falsey then
      paths.be_falsey = {
        test = function(v)
          return not v,
            'expected ' .. tostring(v) .. ' to be falsey',
            'expected ' .. tostring(v) .. ' to not be falsey'
        end
      }
    end
  end
end

return mocking