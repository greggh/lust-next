-- File watcher module for lust-next
local watcher = {}
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("watcher")
logging.configure_from_config("watcher")

-- List of file patterns to watch
local watch_patterns = {
  "%.lua$",           -- Lua source files
  "%.txt$",           -- Text files
  "%.json$",          -- JSON files
}

-- Variables to track file state
local file_timestamps = {}
local last_check_time = 0
local check_interval = 1.0 -- seconds

-- Function to check if a file matches any of the watch patterns
local function should_watch_file(filename)
  for _, pattern in ipairs(watch_patterns) do
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
  local cmd = string.format('stat -c "%%Y" "%s" 2>/dev/null || stat -f "%%m" "%s" 2>/dev/null', path, path)
  local file = io.popen(cmd)
  if not file then
    logger.warn("Failed to get modification time", {path = path})
    return nil 
  end
  
  local mtime = file:read("*n")
  file:close()
  
  if not mtime then
    logger.warn("Could not read modification time", {path = path})
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
    
    -- Use find to get all files (Linux/macOS compatible)
    local cmd = 'find "' .. dir .. '" -type f 2>/dev/null'
    logger.debug("Executing find command", {command = cmd})
    local pipe = io.popen(cmd)
    
    if pipe then
      local file_count = 0
      local exclude_count = 0
      local watch_count = 0
      
      for path in pipe:lines() do
        file_count = file_count + 1
        
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
      
      pipe:close()
    else
      logger.error("Failed to open pipe for directory scan", {directory = dir})
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
  if current_time - last_check_time < check_interval then
    logger.verbose("Skipping file check", {
      elapsed = current_time - last_check_time,
      required_interval = check_interval
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
  for _, dir in ipairs({"."}) do  -- Default to current directory
    local cmd = 'find "' .. dir .. '" -type f -name "*.lua" 2>/dev/null'
    logger.debug("Checking for new files", {command = cmd})
    local pipe = io.popen(cmd)
    
    if pipe then
      for path in pipe:lines() do
        if should_watch_file(path) and not file_timestamps[path] then
          local mtime = get_file_mtime(path)
          if mtime then
            logger.info("New file detected", {path = path})
            table.insert(changed_files, path)
            file_timestamps[path] = mtime
          end
        end
      end
      pipe:close()
    else
      logger.warn("Failed to execute find command", {purpose = "new file check"})
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
    table.insert(watch_patterns, pattern)
  end
end

-- Set check interval
function watcher.set_check_interval(interval)
  logger.info("Setting check interval", {seconds = interval})
  check_interval = interval
end

return watcher