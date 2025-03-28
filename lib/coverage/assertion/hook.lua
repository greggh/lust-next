---@class CoverageAssertionHook
---@field install fun() Install assertion hooks
---@field uninstall fun() Uninstall assertion hooks
---@field is_installed fun(): boolean Check if hooks are installed
---@field on_assertion fun(assertion_type: string, subject: any, expected: any, success: boolean, context: table) Handle assertion event
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local tracker = require("lib.coverage.runtime.tracker")
local analyzer = require("lib.coverage.assertion.analyzer")

-- Version
M._VERSION = "0.1.0"

-- Module state
local hooks_installed = false
local original_assertion_functions = {}

--- Install assertion hooks to track which assertions verify which lines of code
---@return boolean success Whether hooks were successfully installed
function M.install()
  if hooks_installed then
    logger.warn("Assertion hooks are already installed")
    return false
  end
  
  local firmo = require("firmo")
  
  -- Check if the assertion module is available
  if not firmo or not firmo.expect then
    logger.warn("Cannot install assertion hooks: firmo.expect not found")
    return false
  end
  
  -- Save original expect function
  local original_expect = firmo.expect
  
  -- Replace expect function with our hooked version
  firmo.expect = function(subject)
    -- Call the original expect function
    local result = original_expect(subject)
    
    -- Hook into the assertion methods
    for method_name, original_method in pairs(result) do
      if type(original_method) == "function" then
        original_assertion_functions[method_name] = original_method
        
        result[method_name] = function(...)
          -- Capture call stack before making the assertion
          local call_stack = debug.traceback("", 2):gsub("\t", "")
          
          -- Create context object
          local context = {
            call_stack = call_stack,
            assertion_type = method_name,
            timestamp = os.time()
          }
          
          -- Call the original method
          local success, value = pcall(original_method, ...)
          
          -- Process the assertion result
          if success then
            -- Handle successful assertion
            M.on_assertion(method_name, subject, value, true, context)
            return value
          else
            -- Handle failed assertion
            M.on_assertion(method_name, subject, value, false, context)
            error(value, 2)  -- Re-throw the error
          end
        end
      end
    end
    
    return result
  end
  
  hooks_installed = true
  logger.info("Installed assertion hooks")
  return true
end

--- Uninstall assertion hooks and restore original behavior
---@return boolean success Whether hooks were successfully uninstalled
function M.uninstall()
  if not hooks_installed then
    logger.warn("Assertion hooks are not installed")
    return false
  end
  
  local firmo = require("firmo")
  
  -- Restore original expect function
  if firmo._original_expect then
    firmo.expect = firmo._original_expect
    firmo._original_expect = nil
  end
  
  -- Clear saved functions
  original_assertion_functions = {}
  
  hooks_installed = false
  logger.info("Uninstalled assertion hooks")
  return true
end

-- Check if hooks are installed
---@return boolean is_installed Whether hooks are installed
function M.is_installed()
  return hooks_installed
end

-- Handle assertion event
---@param assertion_type string The type of assertion (e.g., "equal", "be_truthy")
---@param subject any The subject of the assertion
---@param expected any The expected value (if applicable)
---@param success boolean Whether the assertion succeeded
---@param context table Additional context information
function M.on_assertion(assertion_type, subject, expected, success, context)
  -- Skip if tracking is not active
  if not tracker.is_active() then
    return
  end
  
  -- Extract call stack information from context
  local call_stack = context.call_stack
  
  -- We don't need any special case handling here
  -- The analyzer.analyze_assertion will determine which lines should be covered
  -- in a general way that works for all files without special cases
  
  -- Analyze the call stack to determine which lines are verified by this assertion
  local verified_lines = analyzer.analyze_assertion(assertion_type, subject, expected, success, call_stack)
  
  -- Mark verified lines as covered
  for _, line_info in ipairs(verified_lines) do
    tracker.mark_covered(line_info.file_id, line_info.line_number)
    
    logger.debug("Marked line as covered due to assertion", {
      file_path = line_info.file_path,
      line_number = line_info.line_number,
      assertion_type = assertion_type
    })
  end
end

return M