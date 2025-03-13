-- Module reset functionality for lust-next
-- Provides better isolation between test files by cleaning up module state

local error_handler = require("lib.tools.error_handler")
local module_reset = {}
module_reset._VERSION = "1.2.0"

-- Enhanced validation functions using error_handler
local function validate_not_nil(value, name)
  if value == nil then
    error_handler.throw(
      name .. " must not be nil",
      error_handler.CATEGORY.VALIDATION,
      error_handler.SEVERITY.ERROR,
      { parameter_name = name }
    )
  end
  return true
end

local function validate_type(value, expected_type, name)
  if type(value) ~= expected_type then
    error_handler.throw(
      name .. " must be of type '" .. expected_type .. "', got '" .. type(value) .. "'",
      error_handler.CATEGORY.VALIDATION,
      error_handler.SEVERITY.ERROR,
      { 
        parameter_name = name,
        expected_type = expected_type,
        actual_type = type(value)
      }
    )
  end
  return true
end

local function validate_type_or_nil(value, expected_type, name)
  if value ~= nil and type(value) ~= expected_type then
    error_handler.throw(
      name .. " must be of type '" .. expected_type .. "' or nil, got '" .. type(value) .. "'",
      error_handler.CATEGORY.VALIDATION,
      error_handler.SEVERITY.ERROR,
      { 
        parameter_name = name,
        expected_type = expected_type,
        actual_type = type(value)
      }
    )
  end
  return true
end

-- Import logging with enhanced error handling
local logging, logger
local function get_logger()
  if not logger then
    local success, log_module, err = error_handler.try(function()
      return require("lib.tools.logging")
    end)
    
    if success and log_module then
      logging = log_module
      logger = logging.get_logger("core.module_reset")
      
      local config_success, config_err = error_handler.try(function()
        logging.configure_from_config("core.module_reset")
        return true
      end)
      
      if not config_success then
        -- Use fallback logging if configuration fails
        print("[WARNING] Failed to configure module_reset logger: " .. 
              (config_err and error_handler.format_error(config_err) or "unknown error"))
      end
      
      if logger then
        logger.debug("Module reset system initialized", {
          version = module_reset._VERSION
        })
      end
    end
  end
  return logger
end

-- Initialize logger
get_logger()

-- Store original package.loaded state
module_reset.initial_state = nil

-- Store modules that should never be reset
module_reset.protected_modules = {
  -- Core Lua modules that should never be reset
  ["_G"] = true,
  ["package"] = true,
  ["coroutine"] = true,
  ["table"] = true,
  ["io"] = true,
  ["os"] = true,
  ["string"] = true,
  ["math"] = true,
  ["debug"] = true,
  ["bit32"] = true,
  ["utf8"] = true,
  
  -- Essential testing modules
  ["lust-next"] = true,
  ["lust"] = true
}

-- Configure additional modules that should be protected
function module_reset.protect(modules)
  local log = get_logger()
  
  if type(modules) == "string" then
    if log then
      log.debug("Protecting single module", {
        module = modules
      })
    end
    module_reset.protected_modules[modules] = true
  elseif type(modules) == "table" then
    if log then
      log.debug("Protecting multiple modules", {
        count = #modules
      })
    end
    for _, module_name in ipairs(modules) do
      module_reset.protected_modules[module_name] = true
      if log and log.is_debug_enabled() then
        log.debug("Added module to protected list", {
          module = module_name
        })
      end
    end
  end
  
  if log then
    log.info("Module protection updated", {
      protected_count = module_reset.count_protected_modules()
    })
  end
end

-- Helper function to count protected modules
function module_reset.count_protected_modules()
  local count = 0
  for _ in pairs(module_reset.protected_modules) do
    count = count + 1
  end
  return count
end

-- Take a snapshot of the current module state
function module_reset.snapshot()
  local log = get_logger()
  
  local success, result = error_handler.try(function()
    local snapshot = {}
    local count = 0
    
    for module_name, _ in pairs(package.loaded) do
      snapshot[module_name] = true
      count = count + 1
    end
    
    if log then
      log.debug("Created module state snapshot", {
        module_count = count
      })
    end
    
    return snapshot, count
  end)
  
  if not success then
    if log then
      local loaded_modules_count = 0
      if package and package.loaded and type(package.loaded) == "table" then
        for _ in pairs(package.loaded) do loaded_modules_count = loaded_modules_count + 1 end
      end
      
      log.error("Failed to create module state snapshot", {
        error = error_handler.format_error(result),
        loaded_modules_count = loaded_modules_count,
        protected_modules_count = module_reset.count_protected_modules()
      })
    end
    
    error_handler.rethrow(result, {
      operation = "module_reset.snapshot",
      module_version = module_reset._VERSION
    })
  end
  
  return result
end

-- Initialize the module system (capture initial state)
function module_reset.init()
  local log = get_logger()
  
  local success, err = error_handler.try(function()
    if log then
      log.debug("Initializing module reset system")
    end
    
    module_reset.initial_state = module_reset.snapshot()
    local initial_count = 0
    
    -- Also protect all modules already loaded at init time
    for module_name, _ in pairs(module_reset.initial_state) do
      module_reset.protected_modules[module_name] = true
      initial_count = initial_count + 1
    end
    
    if log then
      log.info("Module reset system initialized", {
        initial_modules = initial_count,
        protected_modules = module_reset.count_protected_modules()
      })
    end
  end)
  
  if not success then
    if log then
      log.error("Failed to initialize module reset system", {
        error = error_handler.format_error(err),
        protected_modules_count = module_reset.count_protected_modules(),
        state = module_reset.initial_state ~= nil and "created" or "missing"
      })
    end
    
    error_handler.rethrow(err, {
      operation = "module_reset.init",
      module_version = module_reset._VERSION
    })
  end
  
  return module_reset
end

-- Reset modules to initial state, excluding protected modules
function module_reset.reset_all(options)
  local log = get_logger()
  
  -- Validate options
  options = options or {}
  validate_type_or_nil(options, "table", "options")
  
  local verbose = options.verbose
  
  if log then
    log.debug("Resetting all modules", {
      verbose = verbose and true or false
    })
  end
  
  local success, result, err = error_handler.try(function()
    -- If we haven't initialized, do so now
    if not module_reset.initial_state then
      if log then
        log.debug("Module reset system not initialized, initializing now")
      end
      module_reset.init()
      return 0
    end
    
    local reset_count = 0
    local modules_to_reset = {}
    local total_modules = 0
    local protected_count = 0
    
    -- Collect modules that need to be reset
    for module_name, _ in pairs(package.loaded) do
      total_modules = total_modules + 1
      if not module_reset.protected_modules[module_name] then
        modules_to_reset[#modules_to_reset + 1] = module_name
      else
        protected_count = protected_count + 1
      end
    end
    
    if log then
      log.debug("Collected modules for reset", {
        total_loaded = total_modules,
        to_reset = #modules_to_reset,
        protected = protected_count
      })
    end
    
    -- Actually reset the modules
    for _, module_name in ipairs(modules_to_reset) do
      package.loaded[module_name] = nil
      reset_count = reset_count + 1
      
      if verbose then
        if log then
          log.info("Reset module", {
            module = module_name
          })
        else
          -- Safe printing with try/catch
          local print_success, _ = error_handler.try(function()
            print("Reset module: " .. module_name)
            return true
          end)
          
          if not print_success then
            -- Cannot log if log is nil here, just silently fail
          end
        end
      end
    end
    
    -- Force garbage collection after resetting modules
    local before_gc = collectgarbage("count")
    collectgarbage("collect")
    local after_gc = collectgarbage("count")
    local memory_freed = before_gc - after_gc
    
    if log then
      log.info("Module reset completed", {
        reset_count = reset_count,
        memory_freed_kb = memory_freed > 0 and memory_freed or 0
      })
    end
    
    return reset_count
  end)
  
  if not success then
    if log then
      local loaded_modules_count = 0
      if package and package.loaded and type(package.loaded) == "table" then
        for _ in pairs(package.loaded) do loaded_modules_count = loaded_modules_count + 1 end
      end
      
      log.error("Failed to reset modules", {
        error = error_handler.format_error(result),
        loaded_modules_count = loaded_modules_count,
        protected_modules_count = module_reset.count_protected_modules(),
        options = options ~= nil and type(options) == "table" and "provided" or "default"
      })
    end
    
    error_handler.rethrow(result, {
      operation = "module_reset.reset_all",
      options = options or "default"
    })
  end
  
  return result
end

-- Reset specific modules by pattern
function module_reset.reset_pattern(pattern, options)
  local log = get_logger()
  
  -- Validate parameters
  validate_not_nil(pattern, "pattern")
  validate_type(pattern, "string", "pattern")
  
  options = options or {}
  validate_type_or_nil(options, "table", "options")
  
  local verbose = options.verbose
  
  if log then
    log.debug("Resetting modules by pattern", {
      pattern = pattern,
      verbose = verbose and true or false
    })
  end
  
  local success, result = error_handler.try(function()
    local reset_count = 0
    local modules_to_reset = {}
    local total_checked = 0
    local match_count = 0
    
    -- Collect matching modules
    for module_name, _ in pairs(package.loaded) do
      total_checked = total_checked + 1
      
      -- Safely check for pattern match
      local match_success, matches = error_handler.try(function()
        return module_name:match(pattern) ~= nil
      end)
      
      if not match_success then
        error_handler.throw(
          "Invalid pattern for module matching", 
          error_handler.CATEGORY.VALIDATION, 
          error_handler.SEVERITY.ERROR,
          { pattern = pattern, module = module_name }
        )
      end
      
      if matches then
        match_count = match_count + 1
        if not module_reset.protected_modules[module_name] then
          modules_to_reset[#modules_to_reset + 1] = module_name
        else
          if log and log.is_debug_enabled() then
            log.debug("Skipping protected module", {
              module = module_name,
              pattern = pattern
            })
          end
        end
      end
    end
    
    if log then
      log.debug("Collected modules for pattern reset", {
        pattern = pattern,
        total_checked = total_checked,
        matches = match_count,
        to_reset = #modules_to_reset
      })
    end
    
    -- Actually reset the modules
    for _, module_name in ipairs(modules_to_reset) do
      package.loaded[module_name] = nil
      reset_count = reset_count + 1
      
      if verbose then
        if log then
          log.info("Reset module", {
            module = module_name,
            pattern = pattern
          })
        else
          -- Safe printing with try/catch
          local print_success, _ = error_handler.try(function()
            print("Reset module: " .. module_name)
            return true
          end)
          
          if not print_success then
            -- Cannot log if log is nil here, just silently fail
          end
        end
      end
    end
    
    -- Conditional garbage collection
    if reset_count > 0 then
      local before_gc = collectgarbage("count")
      collectgarbage("collect")
      local after_gc = collectgarbage("count")
      local memory_freed = before_gc - after_gc
      
      if log then
        log.info("Pattern reset completed", {
          pattern = pattern,
          reset_count = reset_count,
          memory_freed_kb = memory_freed > 0 and memory_freed or 0
        })
      end
    else if log then
        log.debug("No modules reset for pattern", {
          pattern = pattern
        })
      end
    end
    
    return reset_count
  end)
  
  if not success then
    if log then
      local loaded_modules_count = 0
      if package and package.loaded and type(package.loaded) == "table" then
        for _ in pairs(package.loaded) do loaded_modules_count = loaded_modules_count + 1 end
      end
      
      log.error("Failed to reset modules by pattern", {
        pattern = pattern,
        error = error_handler.format_error(result),
        loaded_modules_count = loaded_modules_count,
        protected_modules_count = module_reset.count_protected_modules(),
        options = options ~= nil and type(options) == "table" and "provided" or "default"
      })
    end
    
    error_handler.rethrow(result, {
      operation = "module_reset.reset_pattern",
      pattern = pattern,
      options = options or "default"
    })
  end
  
  return result
end

-- Get list of currently loaded modules
function module_reset.get_loaded_modules()
  local log = get_logger()
  
  local success, result = error_handler.try(function()
    local modules = {}
    local total_loaded = 0
    local non_protected = 0
    
    for module_name, _ in pairs(package.loaded) do
      total_loaded = total_loaded + 1
      if not module_reset.protected_modules[module_name] then
        table.insert(modules, module_name)
        non_protected = non_protected + 1
      end
    end
    
    table.sort(modules)
    
    if log then
      log.debug("Retrieved loaded modules list", {
        total_loaded = total_loaded,
        non_protected = non_protected
      })
    end
    
    return modules
  end)
  
  if not success then
    if log then
      log.error("Failed to retrieve loaded modules list", {
        error = error_handler.format_error(result),
        protected_modules_count = module_reset.count_protected_modules()
      })
    end
    
    error_handler.rethrow(result, {
      operation = "module_reset.get_loaded_modules",
      module_version = module_reset._VERSION
    })
  end
  
  return result
end

-- Get memory usage information
function module_reset.get_memory_usage()
  local log = get_logger()
  
  local success, result = error_handler.try(function()
    local current_mem = collectgarbage("count")
    
    if log then
      log.debug("Retrieved memory usage", {
        current_kb = current_mem
      })
    end
    
    return {
      current = current_mem, -- Current memory in KB
      count = 0 -- Will be calculated below
    }
  end)
  
  if not success then
    if log then
      log.error("Failed to retrieve memory usage", {
        error = error_handler.format_error(result),
        operation = "get_memory_usage"
      })
    end
    
    error_handler.rethrow(result, {
      operation = "module_reset.get_memory_usage",
      module_version = module_reset._VERSION
    })
  end
  
  return result
end

-- Calculate memory usage per module (approximately)
function module_reset.analyze_memory_usage(options)
  local log = get_logger()
  
  -- Validate options
  options = options or {}
  validate_type_or_nil(options, "table", "options")
  
  if log then
    log.debug("Starting memory usage analysis", {
      track_level = options.track_level or "basic"
    })
  end
  
  local success, result = error_handler.try(function()
    local baseline = collectgarbage("count")
    local results = {}
    
    -- Get the starting memory usage
    collectgarbage("collect")
    local start_mem = collectgarbage("count")
    
    if log then
      log.debug("Memory baseline established", {
        before_gc = baseline,
        after_gc = start_mem,
        freed_kb = baseline - start_mem
      })
    end
    
    -- Check memory usage of each module by removing and re-requiring
    local modules = module_reset.get_loaded_modules()
    local analyzed_count = 0
    local total_memory = 0
    
    if log then
      log.debug("Analyzing modules", {
        module_count = #modules
      })
    end
    
    for _, module_name in ipairs(modules) do
      -- Skip protected modules
      if not module_reset.protected_modules[module_name] then
        -- Safely measure memory difference
        local module_success, module_memory = error_handler.try(function()
          -- Save the loaded module
          local loaded_module = package.loaded[module_name]
          
          -- Unload it
          package.loaded[module_name] = nil
          collectgarbage("collect")
          local after_unload = collectgarbage("count")
          
          -- Measure memory difference
          local memory_used = start_mem - after_unload
          
          -- Re-load the module to preserve state
          package.loaded[module_name] = loaded_module
          
          return memory_used
        end)
        
        if not module_success then
          if log then
            log.warn("Failed to analyze memory for module", {
              module = module_name,
              error = error_handler.format_error(module_memory)
            })
          end
          -- Continue with the next module
        else
          local memory_used = module_memory
          
          if memory_used > 0 then
            results[module_name] = memory_used
            total_memory = total_memory + memory_used
            analyzed_count = analyzed_count + 1
            
            if log and log.is_debug_enabled() then
              log.debug("Module memory usage measured", {
                module = module_name,
                memory_kb = memory_used
              })
            end
          end
        end
      end
    end
    
    -- Sort modules by memory usage
    local sorted_results = {}
    for module_name, mem in pairs(results) do
      table.insert(sorted_results, {
        name = module_name,
        memory = mem
      })
    end
    
    table.sort(sorted_results, function(a, b)
      return a.memory > b.memory
    end)
    
    if log then
      log.info("Memory usage analysis completed", {
        total_modules = #modules,
        analyzed_modules = analyzed_count,
        total_memory_kb = total_memory,
        top_module = sorted_results[1] and sorted_results[1].name or "none",
        top_module_memory = sorted_results[1] and sorted_results[1].memory or 0
      })
    end
    
    return sorted_results
  end)
  
  if not success then
    if log then
      log.error("Failed to analyze memory usage", {
        error = error_handler.format_error(result),
        track_level = options and options.track_level or "basic",
        modules_count = module_reset.get_loaded_modules() and #module_reset.get_loaded_modules() or 0,
        protected_modules_count = module_reset.count_protected_modules()
      })
    end
    
    error_handler.rethrow(result, {
      operation = "module_reset.analyze_memory_usage",
      module_version = module_reset._VERSION,
      options = options or "default"
    })
  end
  
  return result
end

-- Check if a module is protected
function module_reset.is_protected(module_name)
  validate_not_nil(module_name, "module_name")
  validate_type(module_name, "string", "module_name")
  
  return module_reset.protected_modules[module_name] or false
end

-- Add a module to the protected list
function module_reset.add_protected_module(module_name)
  local log = get_logger()
  
  -- Validate input
  validate_not_nil(module_name, "module_name")
  validate_type(module_name, "string", "module_name")
  
  local success, result = error_handler.try(function()
    if not module_reset.protected_modules[module_name] then
      module_reset.protected_modules[module_name] = true
      
      if log then
        log.debug("Added module to protected list", {
          module = module_name,
          protected_count = module_reset.count_protected_modules()
        })
      end
      
      return true
    end
    
    return false
  end)
  
  if not success then
    if log then
      log.error("Failed to add module to protected list", {
        module = module_name,
        error = error_handler.format_error(result),
        protected_modules_count = module_reset.count_protected_modules(),
        is_already_protected = module_reset.protected_modules[module_name] and true or false
      })
    end
    
    error_handler.rethrow(result, {
      operation = "module_reset.add_protected_module",
      module_name = module_name,
      module_version = module_reset._VERSION
    })
  end
  
  return result
end

-- Register the module with lust-next
function module_reset.register_with_lust(lust_next)
  local log = get_logger()
  
  -- Validate input
  validate_not_nil(lust_next, "lust_next")
  validate_type(lust_next, "table", "lust_next")
  
  local success, err = error_handler.try(function()
    if log then
      log.debug("Registering module reset with lust-next")
    end
    
    -- Store reference to lust-next
    module_reset.lust_next = lust_next
    
    -- Add module reset capabilities to lust_next
    lust_next.module_reset = module_reset
    
    -- Verify that lust_next.reset exists and is a function
    if type(lust_next.reset) ~= "function" then
      error_handler.throw(
        "Expected lust_next.reset to be a function, but it was " .. 
        (lust_next.reset == nil and "nil" or type(lust_next.reset)),
        error_handler.CATEGORY.VALIDATION,
        error_handler.SEVERITY.ERROR,
        {
          required_function = "lust_next.reset",
          actual_type = lust_next.reset == nil and "nil" or type(lust_next.reset),
          operation = "register_with_lust"
        }
      )
    end
    
    -- Enhance the reset function
    local original_reset = lust_next.reset
    
    lust_next.reset = function()
      local reset_success, reset_result = error_handler.try(function()
        if log then
          log.debug("Enhanced reset function called")
        end
        
        -- First call the original reset function
        original_reset()
        
        -- Then reset modules as needed
        if lust_next.isolation_options and lust_next.isolation_options.reset_modules then
          if log then
            log.debug("Automatic module reset triggered", {
              verbose = lust_next.isolation_options.verbose and true or false
            })
          end
          
          module_reset.reset_all({
            verbose = lust_next.isolation_options.verbose
          })
        end
        
        -- Return lust_next to allow chaining
        return lust_next
      end)
      
      if not reset_success then
        if log then
          log.error("Enhanced reset function failed", {
            error = error_handler.format_error(reset_result)
          })
        end
        error_handler.rethrow(reset_result)
      end
      
      return reset_result
    end
    
    -- Initialize module tracking
    module_reset.init()
    
    if log then
      log.info("Module reset system registered with lust-next", {
        protected_modules = module_reset.count_protected_modules(),
        initial_modules = module_reset.initial_state and
          (type(module_reset.initial_state) == "table" and #module_reset.initial_state or 0) or 0
      })
    end
  end)
  
  if not success then
    if log then
      log.error("Failed to register module reset with lust-next", {
        error = error_handler.format_error(err),
        protected_modules_count = module_reset.count_protected_modules(),
        initial_state = module_reset.initial_state ~= nil and "created" or "missing"
      })
    end
    
    error_handler.rethrow(err, {
      operation = "module_reset.register_with_lust",
      module_version = module_reset._VERSION
    })
  end
  
  return lust_next
end

-- Configure isolation options for lust-next
function module_reset.configure(options)
  local log = get_logger()
  
  -- Validate options
  options = options or {}
  validate_type_or_nil(options, "table", "options")
  
  local success, result = error_handler.try(function()
    local lust_next = module_reset.lust_next
    
    if not lust_next then
      error_handler.throw(
        "Module reset not registered with lust-next", 
        error_handler.CATEGORY.CONFIGURATION, 
        error_handler.SEVERITY.ERROR
      )
    end
    
    if log then
      log.debug("Configuring isolation options", {
        reset_modules = options.reset_modules and true or false,
        verbose = options.verbose and true or false,
        track_memory = options.track_memory and true or false
      })
    end
    
    lust_next.isolation_options = options
    
    if log then
      log.info("Isolation options configured", {
        reset_enabled = options.reset_modules and true or false
      })
    end
    
    return lust_next
  end)
  
  if not success then
    if log then
      log.error("Failed to configure isolation options", {
        error = error_handler.format_error(result),
        options_type = type(options),
        has_lust_next = module_reset.lust_next ~= nil,
        reset_modules = options and options.reset_modules,
        verbose = options and options.verbose,
        track_memory = options and options.track_memory
      })
    end
    
    error_handler.rethrow(result, {
      operation = "module_reset.configure",
      module_version = module_reset._VERSION,
      options = options or "default"
    })
  end
  
  return result
end

return module_reset