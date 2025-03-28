-- Assertion hook module for v3 coverage system
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local optimized_store = require("lib.coverage.v3.runtime.optimized_store")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.assertion.hook")

---@class coverage_v3_assertion_hook
---@field install fun(): boolean Install assertion hooks
---@field uninstall fun(): boolean Uninstall assertion hooks
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Original assertion functions
local original_functions = {}

-- Helper to find the actual assertion line by walking up the stack
local function find_assertion_location()
  local level = 2  -- Start above hook
  local max_level = 10  -- Don't go too far
  local locations = {}
  
  while level <= max_level do
    local info = debug.getinfo(level, "Sl")
    if not info then break end
    
    -- Look for a line in a Lua file
    if info.source:sub(1, 1) == "@" then
      -- Get the line's content if possible
      local file = io.open(info.source:sub(2))
      if file then
        -- Move to the line
        for _ = 1, info.currentline - 1 do
          file:read("*l")
        end
        local line = file:read("*l")
        file:close()
        
        -- Store this location
        table.insert(locations, {
          file = info.source:sub(2),
          line = info.currentline,
          content = line
        })
      end
    end
    
    level = level + 1
  end
  
  -- Look for the actual assertion
  for _, loc in ipairs(locations) do
    if loc.content and (loc.content:match("expect%(") or loc.content:match("assert%(")) then
      logger.debug("Found assertion", {
        file = loc.file,
        line = loc.line,
        content = loc.content
      })
      return loc.file, loc.line, locations
    end
  end
  
  -- Fallback to the first location
  if #locations > 0 then
    logger.debug("Using fallback location", {
      file = locations[1].file,
      line = locations[1].line
    })
    return locations[1].file, locations[1].line, locations
  end
  
  return nil, nil, locations
end

-- Hook function for assertions
local function assertion_hook(original_fn)
  -- Return a new function that wraps the original
  return function(...)
    -- Get current location
    local file, line, locations = find_assertion_location()
    if not file or not line then
      -- If we can't get location, just run original function
      return original_fn(...)
    end
    
    -- Run original assertion
    local success, result = error_handler.try(original_fn, ...)
    
    -- If assertion passed, mark lines as covered
    if success and result then
      -- Mark the assertion line itself
      optimized_store.record_coverage(file, line)
      
      -- If this is expect(), return a proxy that will track chained calls
      if original_fn == original_functions.expect then
        local proxy = {}
        local mt = {
          __index = function(t, k)
            -- Get the original method
            local orig = result[k]
            if type(orig) == "function" then
              -- Return a wrapped version that can handle varargs
              return function(self, ...)
                local success, result = error_handler.try(orig, result, ...)
                
                if success and result then
                  -- Mark the assertion line as covered
                  optimized_store.record_coverage(file, line)
                end
                
                if not success then
                  error(result)
                end
                
                -- Return proxy for chaining
                return proxy
              end
            end
            return orig
          end
        }
        setmetatable(proxy, mt)
        return proxy
      end
    end
    
    -- Re-throw error if assertion failed
    if not success then
      error(result)
    end
    
    return result
  end
end

-- Install assertion hooks
function M.install()
  -- Check if already installed
  if next(original_functions) then
    logger.warn("Assertion hooks already installed")
    return false
  end
  
  -- Get firmo module
  local firmo = package.loaded["firmo"]
  if not firmo then
    logger.error("Firmo module not loaded")
    return false
  end
  
  -- Hook assertion functions
  local assertion_functions = {
    "expect",
    "assert",
    "is_true",
    "is_false",
    "is_nil",
    "is_not_nil",
    "equals",
    "not_equals",
    "matches",
    "not_matches",
    "has_error",
    "has_no_error"
  }
  
  for _, name in ipairs(assertion_functions) do
    if type(firmo[name]) == "function" then
      original_functions[name] = firmo[name]
      firmo[name] = assertion_hook(original_functions[name])
    end
  end
  
  logger.debug("Installed assertion hooks", {
    hooked_functions = #assertion_functions
  })
  
  return true
end

-- Uninstall assertion hooks
function M.uninstall()
  -- Check if not installed
  if not next(original_functions) then
    logger.warn("Assertion hooks not installed")
    return false
  end
  
  -- Get firmo module
  local firmo = package.loaded["firmo"]
  if not firmo then
    logger.error("Firmo module not loaded")
    return false
  end
  
  -- Restore original functions
  for name, fn in pairs(original_functions) do
    firmo[name] = fn
  end
  
  -- Clear original functions
  original_functions = {}
  
  logger.debug("Uninstalled assertion hooks")
  
  return true
end

return M