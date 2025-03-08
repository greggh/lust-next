-- Module reset functionality for lust-next
-- Provides better isolation between test files by cleaning up module state

local module_reset = {}

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
  if type(modules) == "string" then
    module_reset.protected_modules[modules] = true
  elseif type(modules) == "table" then
    for _, module_name in ipairs(modules) do
      module_reset.protected_modules[module_name] = true
    end
  end
end

-- Take a snapshot of the current module state
function module_reset.snapshot()
  local snapshot = {}
  for module_name, _ in pairs(package.loaded) do
    snapshot[module_name] = true
  end
  return snapshot
end

-- Initialize the module system (capture initial state)
function module_reset.init()
  module_reset.initial_state = module_reset.snapshot()
  
  -- Also protect all modules already loaded at init time
  for module_name, _ in pairs(module_reset.initial_state) do
    module_reset.protected_modules[module_name] = true
  end
  
  return module_reset
end

-- Reset modules to initial state, excluding protected modules
function module_reset.reset_all(options)
  options = options or {}
  local verbose = options.verbose
  
  -- If we haven't initialized, do so now
  if not module_reset.initial_state then
    module_reset.init()
    return
  end
  
  local reset_count = 0
  local modules_to_reset = {}
  
  -- Collect modules that need to be reset
  for module_name, _ in pairs(package.loaded) do
    if not module_reset.protected_modules[module_name] then
      modules_to_reset[#modules_to_reset + 1] = module_name
    end
  end
  
  -- Actually reset the modules
  for _, module_name in ipairs(modules_to_reset) do
    package.loaded[module_name] = nil
    reset_count = reset_count + 1
    
    if verbose then
      print("Reset module: " .. module_name)
    end
  end
  
  -- Force garbage collection after resetting modules
  collectgarbage("collect")
  
  return reset_count
end

-- Reset specific modules by pattern
function module_reset.reset_pattern(pattern, options)
  options = options or {}
  local verbose = options.verbose
  
  local reset_count = 0
  local modules_to_reset = {}
  
  -- Collect matching modules
  for module_name, _ in pairs(package.loaded) do
    if module_name:match(pattern) and not module_reset.protected_modules[module_name] then
      modules_to_reset[#modules_to_reset + 1] = module_name
    end
  end
  
  -- Actually reset the modules
  for _, module_name in ipairs(modules_to_reset) do
    package.loaded[module_name] = nil
    reset_count = reset_count + 1
    
    if verbose then
      print("Reset module: " .. module_name)
    end
  end
  
  -- Conditional garbage collection
  if reset_count > 0 then
    collectgarbage("collect")
  end
  
  return reset_count
end

-- Get list of currently loaded modules
function module_reset.get_loaded_modules()
  local modules = {}
  for module_name, _ in pairs(package.loaded) do
    if not module_reset.protected_modules[module_name] then
      table.insert(modules, module_name)
    end
  end
  
  table.sort(modules)
  return modules
end

-- Get memory usage information
function module_reset.get_memory_usage()
  return {
    current = collectgarbage("count"), -- Current memory in KB
    count = 0 -- Will be calculated below
  }
end

-- Calculate memory usage per module (approximately)
function module_reset.analyze_memory_usage(options)
  options = options or {}
  local baseline = collectgarbage("count")
  local results = {}
  
  -- Get the starting memory usage
  collectgarbage("collect")
  local start_mem = collectgarbage("count")
  
  -- Check memory usage of each module by removing and re-requiring
  local modules = module_reset.get_loaded_modules()
  for _, module_name in ipairs(modules) do
    -- Skip protected modules
    if not module_reset.protected_modules[module_name] then
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
      
      if memory_used > 0 then
        results[module_name] = memory_used
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
  
  return sorted_results
end

-- Register the module with lust-next
function module_reset.register_with_lust(lust_next)
  -- Store reference to lust-next
  module_reset.lust_next = lust_next
  
  -- Add module reset capabilities to lust_next
  lust_next.module_reset = module_reset
  
  -- Enhance the reset function to also reset modules
  local original_reset = lust_next.reset
  lust_next.reset = function()
    -- First call the original reset function
    original_reset()
    
    -- Then reset modules as needed
    if lust_next.isolation_options and lust_next.isolation_options.reset_modules then
      module_reset.reset_all({
        verbose = lust_next.isolation_options.verbose
      })
    end
    
    -- Return lust_next to allow chaining
    return lust_next
  end
  
  -- Initialize module tracking
  module_reset.init()
  
  return lust_next
end

-- Configure isolation options for lust-next
function module_reset.configure(options)
  local lust_next = module_reset.lust_next
  if not lust_next then
    error("Module reset not registered with lust-next")
  end
  
  lust_next.isolation_options = options or {}
  
  return lust_next
end

return module_reset