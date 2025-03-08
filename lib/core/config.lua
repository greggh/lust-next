-- Configuration management module for lust-next
-- Handles loading configuration from .lust-next-config.lua and applying it to the framework

local config = {}

-- Default configuration file path
config.default_config_path = ".lust-next-config.lua"

-- Store loaded configuration
config.loaded = nil

-- Deep merge two tables
local function deep_merge(target, source)
  for k, v in pairs(source) do
    if type(v) == "table" and type(target[k]) == "table" then
      deep_merge(target[k], v)
    else
      target[k] = v
    end
  end
  return target
end

-- Attempt to load a configuration file from the given path
function config.load_from_file(path)
  path = path or config.default_config_path
  
  local file_stat, err = io.open(path, "r")
  if not file_stat then
    return nil, "Config file not found: " .. path
  end
  file_stat:close()
  
  -- Try to load the configuration file
  local ok, user_config = pcall(dofile, path)
  if not ok then
    return nil, "Error loading config file: " .. tostring(user_config)
  end
  
  if type(user_config) ~= "table" then
    return nil, "Invalid config format: expected a table, got " .. type(user_config)
  end
  
  -- Store the loaded configuration
  config.loaded = user_config
  
  return user_config
end

-- Get the loaded config or load it from the default path
function config.get()
  if not config.loaded then
    local user_config, err = config.load_from_file()
    if not user_config then
      -- No config file found, use empty table
      config.loaded = {}
    end
  end
  
  return config.loaded
end

-- Apply configuration to a lust-next instance
function config.apply_to_lust(lust_next)
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
    if cfg.format.default_format then
      if cfg.format.default_format == "dot" then
        lust_next.format({ dot_mode = true })
      elseif cfg.format.default_format == "compact" then
        lust_next.format({ compact = true, show_success_detail = false })
      elseif cfg.format.default_format == "summary" then
        lust_next.format({ summary_only = true })
      elseif cfg.format.default_format == "detailed" then
        lust_next.format({ show_success_detail = true, show_trace = true })
      elseif cfg.format.default_format == "plain" then
        lust_next.format({ use_color = false })
      end
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
    -- Handle special cases for include/exclude patterns and source_dirs
    if cfg.coverage.include then
      if cfg.coverage.use_default_patterns == false then
        -- Replace entire include array
        lust_next.coverage_options.include = cfg.coverage.include
      else
        -- Append to existing include patterns
        lust_next.coverage_options.include = lust_next.coverage_options.include or {}
        for _, pattern in ipairs(cfg.coverage.include) do
          table.insert(lust_next.coverage_options.include, pattern)
        end
      end
    end
    
    if cfg.coverage.exclude then
      if cfg.coverage.use_default_patterns == false then
        -- Replace entire exclude array
        lust_next.coverage_options.exclude = cfg.coverage.exclude
      else
        -- Append to existing exclude patterns
        lust_next.coverage_options.exclude = lust_next.coverage_options.exclude or {}
        for _, pattern in ipairs(cfg.coverage.exclude) do
          table.insert(lust_next.coverage_options.exclude, pattern)
        end
      end
    end
    
    if cfg.coverage.source_dirs then
      -- Always replace source_dirs array
      lust_next.coverage_options.source_dirs = cfg.coverage.source_dirs
    end
    
    -- Copy other options directly
    for k, v in pairs(cfg.coverage) do
      if k ~= "include" and k ~= "exclude" and k ~= "source_dirs" then
        lust_next.coverage_options[k] = v
      end
    end
  end
  
  -- Apply quality configuration
  if cfg.quality and lust_next.quality_options then
    for k, v in pairs(cfg.quality) do
      lust_next.quality_options[k] = v
    end
  end
  
  -- Apply codefix configuration
  if cfg.codefix and lust_next.codefix_options then
    -- Handle top-level options
    for k, v in pairs(cfg.codefix) do
      if k ~= "custom_fixers" then
        lust_next.codefix_options[k] = v
      end
    end
    
    -- Handle custom fixers sub-table
    if cfg.codefix.custom_fixers and lust_next.codefix_options.custom_fixers then
      for k, v in pairs(cfg.codefix.custom_fixers) do
        lust_next.codefix_options.custom_fixers[k] = v
      end
    end
  end
  
  -- Apply reporting configuration
  if cfg.reporting then
    -- Store the configuration for later use
    lust_next.report_config = lust_next.report_config or {}
    
    if cfg.reporting.report_dir then
      lust_next.report_config.report_dir = cfg.reporting.report_dir
    end
    
    if cfg.reporting.report_suffix ~= nil then
      lust_next.report_config.report_suffix = cfg.reporting.report_suffix
    end
    
    if cfg.reporting.timestamp_format then
      lust_next.report_config.timestamp_format = cfg.reporting.timestamp_format
    end
    
    if cfg.reporting.verbose ~= nil then
      lust_next.report_config.verbose = cfg.reporting.verbose
    end
    
    -- Apply templates
    if cfg.reporting.templates then
      if cfg.reporting.templates.coverage then
        lust_next.report_config.coverage_path_template = cfg.reporting.templates.coverage
      end
      
      if cfg.reporting.templates.quality then
        lust_next.report_config.quality_path_template = cfg.reporting.templates.quality
      end
      
      if cfg.reporting.templates.results then
        lust_next.report_config.results_path_template = cfg.reporting.templates.results
      end
    end
  end
  
  -- Apply watch mode configuration
  if cfg.watch and lust_next.watcher then
    if cfg.watch.dirs and #cfg.watch.dirs > 0 then
      lust_next.watcher.dirs = cfg.watch.dirs
    end
    
    if cfg.watch.ignore and #cfg.watch.ignore > 0 then
      lust_next.watcher.ignore_patterns = cfg.watch.ignore
    end
    
    if cfg.watch.debounce then
      lust_next.watcher.set_debounce_time(cfg.watch.debounce)
    end
    
    if cfg.watch.clear_console ~= nil then
      lust_next.watcher.clear_console = cfg.watch.clear_console
    end
  end
  
  -- Apply interactive CLI configuration
  if cfg.interactive and lust_next.interactive then
    if cfg.interactive.history_size then
      lust_next.interactive.history_size = cfg.interactive.history_size
    end
    
    if cfg.interactive.prompt then
      lust_next.interactive.prompt = cfg.interactive.prompt
    end
    
    if cfg.interactive.default_dir then
      lust_next.interactive.default_dir = cfg.interactive.default_dir
    end
    
    if cfg.interactive.default_pattern then
      lust_next.interactive.default_pattern = cfg.interactive.default_pattern
    end
  end
  
  -- Apply custom formatters configuration
  if cfg.formatters then
    if cfg.formatters.coverage then
      lust_next.coverage_format = cfg.formatters.coverage
    end
    
    if cfg.formatters.quality then
      lust_next.quality_format = cfg.formatters.quality
    end
    
    if cfg.formatters.results then
      lust_next.results_format = cfg.formatters.results
    end
    
    -- Load custom formatter module if specified
    if cfg.formatters.module and lust_next.reporting then
      local ok, custom_formatters = pcall(require, cfg.formatters.module)
      if ok and custom_formatters then
        lust_next.reporting.load_formatters(custom_formatters)
      end
    end
  end
  
  -- Apply module reset configuration
  if cfg.module_reset and lust_next.module_reset then
    if cfg.module_reset.enabled ~= nil then
      lust_next.module_reset.enabled = cfg.module_reset.enabled
    end
    
    if cfg.module_reset.track_memory ~= nil then
      lust_next.module_reset.track_memory = cfg.module_reset.track_memory
    end
    
    if cfg.module_reset.protected_modules and #cfg.module_reset.protected_modules > 0 then
      -- Merge with existing protected modules
      for _, mod in ipairs(cfg.module_reset.protected_modules) do
        if not lust_next.module_reset.is_protected(mod) then
          lust_next.module_reset.add_protected_module(mod)
        end
      end
    end
    
    if cfg.module_reset.exclude_patterns and #cfg.module_reset.exclude_patterns > 0 then
      -- Merge with existing exclude patterns
      for _, pattern in ipairs(cfg.module_reset.exclude_patterns) do
        lust_next.module_reset.add_exclude_pattern(pattern)
      end
    end
  end
  
  return lust_next
end

-- Register the config module with lust-next
function config.register_with_lust(lust_next)
  -- Store reference to lust-next
  config.lust_next = lust_next
  
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
          local user_config, err = config.load_from_file(args[i+1])
          if not user_config then
            print("Warning: " .. err)
          else
            -- Apply the configuration
            config.apply_to_lust(lust_next)
          end
          i = i + 2
        else
          i = i + 1
        end
      end
      
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
          config.create_default_config()
          return true
        end
      end
      
      -- Call the original cli_run
      return original_cli_run(args)
    end
  end
  
  return lust_next
end

-- Create a default config file by copying the template
function config.create_default_config()
  -- Try to find the template file
  local template_path = ".lust-next-config.lua.template"
  local template_file = io.open(template_path, "r")
  
  if not template_file then
    -- Try to find the template in the package path
    local function find_in_path(path)
      for dir in string.gmatch(package.path, "[^;]+") do
        local file_path = dir:gsub("?", path)
        local file = io.open(file_path, "r")
        if file then
          file:close()
          return file_path
        end
      end
      return nil
    end
    
    template_path = find_in_path("lust-next-config.lua.template")
    template_file = template_path and io.open(template_path, "r")
  end
  
  if not template_file then
    print("Error: Config template file not found")
    return false
  end
  
  -- Read the template content
  local content = template_file:read("*a")
  template_file:close()
  
  -- Write to the config file
  local config_file = io.open(config.default_config_path, "w")
  if not config_file then
    print("Error: Could not create config file at " .. config.default_config_path)
    return false
  end
  
  config_file:write(content)
  config_file:close()
  
  print("Default configuration file created at " .. config.default_config_path)
  return true
end

return config