-- Re-export the new mocking system from the modular implementation
package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path
local mocking = require("mocking")

-- Add backward compatibility
function mocking.register_with_lust_next(lust_next)
  -- Export the spy functionality
  lust_next.spy = mocking.spy
  lust_next.stub = mocking.stub
  lust_next.mock = mocking.mock
  lust_next.with_mocks = mocking.with_mocks
  lust_next.arg_matcher = mocking.arg_matcher or {}
  
  -- Ensure truthy/falsy assertions are available
  if mocking.ensure_assertions then
    mocking.ensure_assertions(lust_next)
  end
  
  -- Register cleanup hook if available
  if mocking.register_cleanup_hook then
    local original_after = lust_next.after
    lust_next.after = mocking.register_cleanup_hook(original_after)
  end
end

return mocking