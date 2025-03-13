-- DEPRECATED: Legacy configuration bridge module
-- This module is deprecated and will be removed in a future version
-- Please use lib.core.central_config directly instead

local function try_require(name)
  local ok, mod = pcall(require, name)
  if ok then
    return mod
  else
    return nil
  end
end

-- Attempt to load the centralized configuration system
local central_config = try_require("lib.core.central_config")
local logging = try_require("lib.tools.logging")
local logger

-- Initialize logger if possible
if logging then
  logger = logging.get_logger("config")
  logger.warn("DEPRECATED: lib.core.config module is deprecated and will be removed in a future version", {
    recommendation = "Use lib.core.central_config directly instead"
  })
else
  print("WARNING: lib.core.config module is deprecated and will be removed in a future version.")
  print("Please use lib.core.central_config directly instead.")
end

-- If central_config is not available, we can't do anything
if not central_config then
  if logger then
    logger.error("Cannot load central_config module - please ensure it exists", {
      file = "lib/core/central_config.lua"
    })
  else
    print("ERROR: Cannot load central_config module. Please ensure lib/core/central_config.lua exists.")
  end
  error("Failed to load central_config module")
end

-- Create a proxy that forwards all operations to central_config
local config = {}

-- Function to forward all calls to the central_config module
local function forward_to_central_config()
  -- Forward all methods from central_config to config
  for name, func in pairs(central_config) do
    if type(func) == "function" then
      config[name] = function(...)
        if logger then
          logger.debug("Forwarding deprecated call to central_config", {
            method = name
          })
        end
        return func(...)
      end
    else
      config[name] = func
    end
  end
end

-- Forward all operations
forward_to_central_config()

-- Add legacy function names for backward compatibility
config.load_from_file = central_config.load_from_file
config.apply_to_lust = function(lust_next)
  if logger then
    logger.warn("DEPRECATED: config.apply_to_lust is deprecated", {
      recommendation = "Update your code to use central_config directly"
    })
  end
  
  -- We still need to apply the configuration to maintain compatibility
  if not lust_next then
    error("Cannot apply configuration: lust_next is nil", 2)
  end
  
  -- Load config if not already loaded
  local cfg = config.get()
  if not cfg then
    return lust_next
  end
  
  -- Apply test discovery configuration
  if cfg.test_discovery then
    lust_next.test_discovery = lust_next.test_discovery or {}
    for k, v in pairs(cfg.test_discovery) do
      lust_next.test_discovery[k] = v
    end
  end
  
  -- Apply format options
  if cfg.format then
    if lust_next.format_options then
      for k, v in pairs(cfg.format) do
        if k ~= "default_format" then
          lust_next.format_options[k] = v
        end
      end
    end
    
    -- Apply default format if specified
    if cfg.format.default_format and lust_next.format then
      lust_next.format({
        dot_mode = cfg.format.default_format == "dot",
        compact = cfg.format.default_format == "compact",
        summary_only = cfg.format.default_format == "summary",
        show_success_detail = cfg.format.default_format == "detailed",
        show_trace = cfg.format.default_format == "detailed",
        use_color = cfg.format.default_format ~= "plain"
      })
    end
  end
  
  -- Apply async configuration
  if cfg.async and lust_next.async_options then
    for k, v in pairs(cfg.async) do
      lust_next.async_options[k] = v
    end
    
    -- Configure the async module with our options
    if lust_next.async_module and lust_next.async_module.set_timeout and cfg.async.timeout then
      lust_next.async_module.set_timeout(cfg.async.timeout)
    end
  end
  
  -- Apply parallel execution configuration
  if cfg.parallel and lust_next.parallel and lust_next.parallel.options then
    for k, v in pairs(cfg.parallel) do
      lust_next.parallel.options[k] = v
    end
  end
  
  -- Apply coverage configuration
  if cfg.coverage and lust_next.coverage_options then
    -- Handle coverage settings in a compatible way
    for k, v in pairs(cfg.coverage) do
      if k ~= "include" and k ~= "exclude" and k ~= "source_dirs" then
        lust_next.coverage_options[k] = v
      end
    end
    
    -- Handle special cases for arrays
    for _, key in ipairs({"include", "exclude", "source_dirs"}) do
      if cfg.coverage[key] then
        lust_next.coverage_options[key] = cfg.coverage[key]
      end
    end
    
    -- Update coverage module if available
    if lust_next.coverage_module and lust_next.coverage_module.init then
      lust_next.coverage_module.init(lust_next.coverage_options)
    end
  end
  
  -- Apply quality configuration
  if cfg.quality and lust_next.quality_options then
    for k, v in pairs(cfg.quality) do
      lust_next.quality_options[k] = v
    end
  end
  
  -- Apply other module configurations
  for module_name, module_config in pairs(cfg) do
    if module_name == "logging" and lust_next.logging and type(lust_next.logging.configure) == "function" then
      lust_next.logging.configure(module_config)
    elseif module_name == "codefix" and lust_next.codefix_options then
      for k, v in pairs(module_config) do
        lust_next.codefix_options[k] = v
      end
    elseif module_name == "reporting" and lust_next.report_config then
      for k, v in pairs(module_config) do
        lust_next.report_config[k] = v
      end
    elseif module_name == "watch" and lust_next.watcher then
      for k, v in pairs(module_config) do
        if k == "dirs" and #v > 0 then
          lust_next.watcher.dirs = v
        elseif k == "ignore" and #v > 0 then
          lust_next.watcher.ignore_patterns = v
        elseif k == "debounce" then
          lust_next.watcher.set_debounce_time(v)
        elseif k == "clear_console" then
          lust_next.watcher.clear_console = v
        end
      end
    elseif module_name == "interactive" and lust_next.interactive then
      for k, v in pairs(module_config) do
        lust_next.interactive[k] = v
      end
    elseif module_name == "formatters" then
      if module_config.coverage then
        lust_next.coverage_format = module_config.coverage
      end
      if module_config.quality then
        lust_next.quality_format = module_config.quality
      end
      if module_config.results then
        lust_next.results_format = module_config.results
      end
    elseif module_name == "module_reset" and lust_next.module_reset then
      for k, v in pairs(module_config) do
        if k ~= "protected_modules" and k ~= "exclude_patterns" then
          lust_next.module_reset[k] = v
        end
      end
      
      -- Handle arrays separately
      if module_config.protected_modules and #module_config.protected_modules > 0 then
        for _, mod in ipairs(module_config.protected_modules) do
          if lust_next.module_reset.add_protected_module then
            lust_next.module_reset.add_protected_module(mod)
          end
        end
      end
      
      if module_config.exclude_patterns and #module_config.exclude_patterns > 0 then
        for _, pattern in ipairs(module_config.exclude_patterns) do
          if lust_next.module_reset.add_exclude_pattern then
            lust_next.module_reset.add_exclude_pattern(pattern)
          end
        end
      end
    end
  end
  
  return lust_next
end

config.register_with_lust = function(lust_next)
  if logger then
    logger.warn("DEPRECATED: config.register_with_lust is deprecated", {
      recommendation = "Update your code to use central_config directly"
    })
  end
  
  -- Store reference to lust-next
  config.lust_next = lust_next
  
  -- Register lust-next version with central_config
  central_config.register_module("lust-next", {
    field_types = {
      version = "string"
    }
  }, {
    version = lust_next.version
  })
  
  -- Add config functionality to lust-next
  lust_next.config = config
  
  -- Apply configuration from .lust-next-config.lua if exists
  config.apply_to_lust(lust_next)
  
  -- Add CLI options for configuration
  local original_parse_args = lust_next.parse_args
  if original_parse_args then
    lust_next.parse_args = function(args)
      local options = original_parse_args(args)
      
      -- Check for config file option
      local i = 1
      while i <= #args do
        local arg = args[i]
        if arg == "--config" and args[i+1] then
          -- Load the specified config file
          local config_path = args[i+1]
          local user_config, err = central_config.load_from_file(config_path)
          
          if not user_config then
            if logger then
              logger.warn("Failed to load config file", {
                path = config_path,
                error = err and err.message or "unknown error"
              })
            else
              print("Warning: Failed to load config file: " .. config_path)
            end
          else
            -- Apply the configuration
            config.apply_to_lust(lust_next)
          end
          i = i + 2
        else
          i = i + 1
        end
      end
      
      -- Process CLI args as config options
      central_config.configure_from_options(options)
      
      return options
    end
  end
  
  -- Extend help text to include config options
  local original_show_help = lust_next.show_help
  if original_show_help then
    lust_next.show_help = function()
      original_show_help()
      
      print("\nConfiguration Options:")
      print("  --config FILE             Use the specified configuration file instead of .lust-next-config.lua")
      print("  --create-config           Create a default configuration file at .lust-next-config.lua")
    end
  end
  
  -- Add CLI command to create a default config file
  local original_cli_run = lust_next.cli_run
  if original_cli_run then
    lust_next.cli_run = function(args)
      -- Check for create-config option
      for i, arg in ipairs(args) do
        if arg == "--create-config" then
          -- Create a default config file
          central_config.save_to_file()
          return true
        end
      end
      
      -- Call the original cli_run
      return original_cli_run(args)
    end
  end
  
  return lust_next
end

config.create_default_config = function()
  if logger then
    logger.warn("DEPRECATED: config.create_default_config is deprecated", {
      recommendation = "Use central_config.save_to_file() instead"
    })
  end
  return central_config.save_to_file()
end

return config