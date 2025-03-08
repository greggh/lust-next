-- mocking.lua - Mocking system integration for lust-next

local spy = require("src.spy")
local stub = require("src.stub")
local mock = require("src.mock")

local mocking = {}

-- Export the spy module with compatibility for both object-oriented and functional API
mocking.spy = setmetatable({
  on = spy.on,
  new = spy.new
}, {
  __call = function(_, target, name)
    if type(target) == 'table' then
      return spy.on(target, name)
    else
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
  __call = function(_, target, options)
    return mock.create(target, options)
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

return mocking