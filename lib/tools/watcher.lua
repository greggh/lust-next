-- File watcher module for lust-next
local watcher = {}
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")

-- Initialize module logger
local logger = logging.get_logger("watcher")

-- Default configuration
local DEFAULT_CONFIG = {
  check_interval = 1.0, -- seconds
  watch_patterns = {
    "%.lua$",           -- Lua source files
    "%.txt$",           -- Text files
    "%.json$",          -- JSON files
  },
  default_directory = ".",
  debug = false,
  verbose = false
}

-- Current configuration
local config = {
  check_interval = DEFAULT_CONFIG.check_interval,
  watch_patterns = {},
  default_directory = DEFAULT_CONFIG.default_directory,
  debug = DEFAULT_CONFIG.debug,
  verbose = DEFAULT_CONFIG.verbose
}

-- Copy default watch patterns
for _, pattern in ipairs(DEFAULT_CONFIG.watch_patterns) do
  table.insert(config.watch_patterns, pattern)
end

-- Variables to track file state
local file_timestamps = {}
local last_check_time = 0

-- Lazy loading of central_config to avoid circular dependencies
local _central_config

local function get_central_config()
  if not _central_config then
    -- Use pcall to safely attempt loading central_config
    local success, central_config = pcall(require, "lib.core.central_config")
    if success then
      _central_config = central_config
      
      -- Register this module with central_config
      _central_config.register_module("watcher", {
        -- Schema
        field_types = {
          check_interval = "number",
          watch_patterns = "table",
          default_directory = "string",
          debug = "boolean",
          verbose = "boolean"
        },
        field_ranges = {
          check_interval = {min = 0.1, max = 60}
        }
      }, DEFAULT_CONFIG)
      
      logger.debug("Successfully loaded central_config", {
        module = "watcher"
      })
    else
      logger.debug("Failed to load central_config", {
        error = tostring(central_config)
      })
    end
  end
  
  return _central_config
end

-- Set up change listener for central configuration
local function register_change_listener()
  local central_config = get_central_config()
  if not central_config then
    logger.debug("Cannot register change listener - central_config not available")
    return false
  end
  
  -- Register change listener for watcher configuration
  central_config.on_change("watcher", function(path, old_value, new_value)
    logger.debug("Configuration change detected", {
      path = path,
      changed_by = "central_config"
    })
    
    -- Update local configuration from central_config
    local watcher_config = central_config.get("watcher")
    if watcher_config then
      -- Update check_interval
      if watcher_config.check_interval ~= nil and watcher_config.check_interval ~= config.check_interval then
        config.check_interval = watcher_config.check_interval
        logger.debug("Updated check_interval from central_config", {
          check_interval = config.check_interval
        })
      end
      
      -- Update watch_patterns
      if watcher_config.watch_patterns ~= nil then
        -- Clear existing patterns and copy new ones
        config.watch_patterns = {}
        for _, pattern in ipairs(watcher_config.watch_patterns) do
          table.insert(config.watch_patterns, pattern)
        end
        logger.debug("Updated watch_patterns from central_config", {
          pattern_count = #config.watch_patterns
        })
      end
      
      -- Update default_directory
      if watcher_config.default_directory ~= nil and watcher_config.default_directory ~= config.default_directory then
        config.default_directory = watcher_config.default_directory
        logger.debug("Updated default_directory from central_config", {
          default_directory = config.default_directory
        })
      end
      
      -- Update debug setting
      if watcher_config.debug ~= nil and watcher_config.debug ~= config.debug then
        config.debug = watcher_config.debug
        logger.debug("Updated debug setting from central_config", {
          debug = config.debug
        })
      end
      
      -- Update verbose setting
      if watcher_config.verbose ~= nil and watcher_config.verbose ~= config.verbose then
        config.verbose = watcher_config.verbose
        logger.debug("Updated verbose setting from central_config", {
          verbose = config.verbose
        })
      end
      
      -- Update logging configuration
      logging.configure_from_options("watcher", {
        debug = config.debug,
        verbose = config.verbose
      })
      
      logger.debug("Applied configuration changes from central_config")
    end
  end)
  
  logger.debug("Registered change listener for central configuration")
  return true
end

-- Configure the module
function watcher.configure(options)
  options = options or {}
  
  logger.debug("Configuring watcher module", {
    options = options
  })
  
  -- Check for central configuration first
  local central_config = get_central_config()
  if central_config then
    -- Get existing central config values
    local watcher_config = central_config.get("watcher")
    
    -- Apply central configuration (with defaults as fallback)
    if watcher_config then
      logger.debug("Using central_config values for initialization", {
        check_interval = watcher_config.check_interval,
        has_watch_patterns = watcher_config.watch_patterns ~= nil
      })
      
      -- Apply check_interval
      config.check_interval = watcher_config.check_interval ~= nil
                           and watcher_config.check_interval
                           or DEFAULT_CONFIG.check_interval
      
      -- Apply default_directory
      config.default_directory = watcher_config.default_directory ~= nil
                              and watcher_config.default_directory
                              or DEFAULT_CONFIG.default_directory
      
      -- Apply debug and verbose settings
      config.debug = watcher_config.debug ~= nil
                    and watcher_config.debug
                    or DEFAULT_CONFIG.debug
                    
      config.verbose = watcher_config.verbose ~= nil
                      and watcher_config.verbose
                      or DEFAULT_CONFIG.verbose
      
      -- Apply watch_patterns if available
      if watcher_config.watch_patterns then
        config.watch_patterns = {}
        for _, pattern in ipairs(watcher_config.watch_patterns) do
          table.insert(config.watch_patterns, pattern)
        end
      else
        -- Reset to defaults
        config.watch_patterns = {}
        for _, pattern in ipairs(DEFAULT_CONFIG.watch_patterns) do
          table.insert(config.watch_patterns, pattern)
        end
      end
    else
      logger.debug("No central_config values found, using defaults")
      -- Reset to defaults
      config.check_interval = DEFAULT_CONFIG.check_interval
      config.default_directory = DEFAULT_CONFIG.default_directory
      config.debug = DEFAULT_CONFIG.debug
      config.verbose = DEFAULT_CONFIG.verbose
      
      config.watch_patterns = {}
      for _, pattern in ipairs(DEFAULT_CONFIG.watch_patterns) do
        table.insert(config.watch_patterns, pattern)
      end
    end
    
    -- Register change listener if not already done
    register_change_listener()
  else
    logger.debug("central_config not available, using defaults")
    -- Apply defaults
    config.check_interval = DEFAULT_CONFIG.check_interval
    config.default_directory = DEFAULT_CONFIG.default_directory
    config.debug = DEFAULT_CONFIG.debug
    config.verbose = DEFAULT_CONFIG.verbose
    
    config.watch_patterns = {}
    for _, pattern in ipairs(DEFAULT_CONFIG.watch_patterns) do
      table.insert(config.watch_patterns, pattern)
    end
  end
  
  -- Apply user options (highest priority) and update central config
  if options.check_interval ~= nil then
    config.check_interval = options.check_interval
    
    -- Update central_config if available
    if central_config then
      central_config.set("watcher.check_interval", options.check_interval)
    end
  end
  
  if options.default_directory ~= nil then
    config.default_directory = options.default_directory
    
    -- Update central_config if available
    if central_config then
      central_config.set("watcher.default_directory", options.default_directory)
    end
  end
  
  if options.debug ~= nil then
    config.debug = options.debug
    
    -- Update central_config if available
    if central_config then
      central_config.set("watcher.debug", options.debug)
    end
  end
  
  if options.verbose ~= nil then
    config.verbose = options.verbose
    
    -- Update central_config if available
    if central_config then
      central_config.set("watcher.verbose", options.verbose)
    end
  end
  
  if options.watch_patterns ~= nil then
    -- Replace watch patterns
    config.watch_patterns = {}
    for _, pattern in ipairs(options.watch_patterns) do
      table.insert(config.watch_patterns, pattern)
    end
    
    -- Update central_config if available
    if central_config then
      central_config.set("watcher.watch_patterns", options.watch_patterns)
    end
  end
  
  -- Configure logging
  logging.configure_from_options("watcher", {
    debug = config.debug,
    verbose = config.verbose
  })
  
  logger.debug("Watcher module configuration complete", {
    check_interval = config.check_interval,
    watch_patterns_count = #config.watch_patterns,
    default_directory = config.default_directory,
    debug = config.debug,
    verbose = config.verbose,
    using_central_config = central_config ~= nil
  })
  
  return watcher
end

-- Initialize the module
watcher.configure()

-- Function to check if a file matches any of the watch patterns
local function should_watch_file(filename)
  for _, pattern in ipairs(config.watch_patterns) do
    if filename:match(pattern) then
      logger.debug("File matches watch pattern", {
        filename = filename,
        pattern = pattern
      })
      return true
    end
  end
  logger.debug("File does not match watch patterns", {filename = filename})
  return false
end

-- Get file modification time
local function get_file_mtime(path)
  local mtime, err = fs.get_modified_time(path)
  if not mtime then
    logger.warn("Failed to get modification time", {path = path, error = err})
    return nil 
  end
  
  logger.debug("File modification time", {path = path, mtime = mtime})
  return mtime
end

-- Initialize the watcher by scanning all files in the given directories
function watcher.init(directories, exclude_patterns)
  directories = type(directories) == "table" and directories or {directories or "."}
  exclude_patterns = exclude_patterns or {}
  
  file_timestamps = {}
  last_check_time = os.time()
  
  -- Create list of exclusion patterns as functions
  local excludes = {}
  for _, pattern in ipairs(exclude_patterns) do
    logger.info("Adding exclusion pattern", {pattern = pattern})
    table.insert(excludes, function(path) return path:match(pattern) end)
  end
  
  -- Scan all files in directories
  for _, dir in ipairs(directories) do
    logger.info("Watching directory", {directory = dir})
    
    -- Use filesystem module to scan directory recursively
    logger.debug("Scanning directory recursively", {directory = dir})
    local files = fs.scan_directory(dir, true)
    
    if files then
      local file_count = #files
      local exclude_count = 0
      local watch_count = 0
      
      for _, path in ipairs(files) do
        -- Check if file should be excluded
        local exclude = false
        for _, exclude_func in ipairs(excludes) do
          if exclude_func(path) then
            exclude = true
            exclude_count = exclude_count + 1
            logger.debug("Excluding file", {path = path})
            break
          end
        end
        
        -- If not excluded and matches patterns to watch, add to timestamp list
        if not exclude and should_watch_file(path) then
          local mtime = get_file_mtime(path)
          if mtime then
            file_timestamps[path] = mtime
            watch_count = watch_count + 1
          end
        end
      end
      
      logger.info("Directory scan results", {
        directory = dir,
        files_found = file_count,
        files_excluded = exclude_count,
        files_watched = watch_count
      })
    else
      logger.error("Failed to scan directory", {directory = dir})
    end
  end
  
  local file_count = 0
  for _ in pairs(file_timestamps) do
    file_count = file_count + 1
  end
  logger.info("Watch initialization complete", {monitored_files = file_count})
  return true
end

-- Check for file changes since the last check
function watcher.check_for_changes()
  -- Don't check too frequently
  local current_time = os.time()
  if current_time - last_check_time < config.check_interval then
    logger.verbose("Skipping file check", {
      elapsed = current_time - last_check_time,
      required_interval = config.check_interval
    })
    return nil
  end
  
  logger.debug("Checking for file changes", {timestamp = os.date("%Y-%m-%d %H:%M:%S")})
  last_check_time = current_time
  local changed_files = {}
  
  -- Check each watched file for changes
  for path, old_mtime in pairs(file_timestamps) do
    local new_mtime = get_file_mtime(path)
    
    -- If file exists and has changed
    if new_mtime and new_mtime > old_mtime then
      logger.info("File changed", {
        path = path,
        old_mtime = old_mtime,
        new_mtime = new_mtime
      })
      table.insert(changed_files, path)
      file_timestamps[path] = new_mtime
    -- If file no longer exists
    elseif not new_mtime then
      logger.info("File removed", {path = path})
      table.insert(changed_files, path)
      file_timestamps[path] = nil
    end
  end
  
  -- Check for new files
  local dirs = {config.default_directory}
  for _, dir in ipairs(dirs) do
    logger.debug("Checking for new files", {directory = dir})
    local files = fs.scan_directory(dir, true)
    
    if files then
      for _, path in ipairs(files) do
        if should_watch_file(path) and not file_timestamps[path] then
          local mtime = get_file_mtime(path)
          if mtime then
            logger.info("New file detected", {path = path})
            table.insert(changed_files, path)
            file_timestamps[path] = mtime
          end
        end
      end
    else
      logger.warn("Failed to scan directory for new files", {directory = dir})
    end
  end
  
  if #changed_files > 0 then
    logger.info("Detected changed files", {count = #changed_files})
    return changed_files
  else
    logger.debug("No file changes detected", {check_time = os.time() - last_check_time})
    return nil
  end
end

-- Add patterns to watch
function watcher.add_patterns(patterns)
  for _, pattern in ipairs(patterns) do
    logger.info("Adding watch pattern", {pattern = pattern})
    table.insert(config.watch_patterns, pattern)
    
    -- Update central_config if available
    local central_config = get_central_config()
    if central_config then
      -- Get current patterns
      local current_patterns = central_config.get("watcher.watch_patterns") or {}
      -- Add new pattern
      table.insert(current_patterns, pattern)
      -- Update central config
      central_config.set("watcher.watch_patterns", current_patterns)
      
      logger.debug("Updated watch_patterns in central_config", {
        pattern_count = #current_patterns
      })
    end
  end
  
  return watcher
end

-- Set check interval
function watcher.set_check_interval(interval)
  logger.info("Setting check interval", {seconds = interval})
  config.check_interval = interval
  
  -- Update central_config if available
  local central_config = get_central_config()
  if central_config then
    central_config.set("watcher.check_interval", interval)
    logger.debug("Updated check_interval in central_config", {
      check_interval = interval
    })
  end
  
  return watcher
end

-- Reset the module configuration to defaults
function watcher.reset()
  logger.debug("Resetting watcher module configuration to defaults")
  
  -- Reset check_interval and default_directory
  config.check_interval = DEFAULT_CONFIG.check_interval
  config.default_directory = DEFAULT_CONFIG.default_directory
  config.debug = DEFAULT_CONFIG.debug
  config.verbose = DEFAULT_CONFIG.verbose
  
  -- Reset watch_patterns
  config.watch_patterns = {}
  for _, pattern in ipairs(DEFAULT_CONFIG.watch_patterns) do
    table.insert(config.watch_patterns, pattern)
  end
  
  return watcher
end

-- Fully reset both local and central configuration
function watcher.full_reset()
  -- Reset local configuration
  watcher.reset()
  
  -- Reset central configuration if available
  local central_config = get_central_config()
  if central_config then
    central_config.reset("watcher")
    logger.debug("Reset central configuration for watcher module")
  end
  
  return watcher
end

-- Debug helper to show current configuration
function watcher.debug_config()
  local debug_info = {
    local_config = {
      check_interval = config.check_interval,
      default_directory = config.default_directory,
      debug = config.debug,
      verbose = config.verbose,
      watch_patterns = config.watch_patterns
    },
    using_central_config = false,
    central_config = nil,
    file_count = 0
  }
  
  -- Count monitored files
  for _ in pairs(file_timestamps) do
    debug_info.file_count = debug_info.file_count + 1
  end
  
  -- Check for central_config
  local central_config = get_central_config()
  if central_config then
    debug_info.using_central_config = true
    debug_info.central_config = central_config.get("watcher")
  end
  
  -- Display configuration
  logger.info("Watcher module configuration", debug_info)
  
  return debug_info
end

return watcher