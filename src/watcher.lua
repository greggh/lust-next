-- File watcher module for lust-next
local watcher = {}

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
      return true
    end
  end
  return false
end

-- Get file modification time
local function get_file_mtime(path)
  local cmd = string.format('stat -c "%%Y" "%s" 2>/dev/null || stat -f "%%m" "%s" 2>/dev/null', path, path)
  local file = io.popen(cmd)
  if not file then return nil end
  
  local mtime = file:read("*n")
  file:close()
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
    table.insert(excludes, function(path) return path:match(pattern) end)
  end
  
  -- Scan all files in directories
  for _, dir in ipairs(directories) do
    print("Watching directory: " .. dir)
    
    -- Use find to get all files (Linux/macOS compatible)
    local cmd = 'find "' .. dir .. '" -type f 2>/dev/null'
    local pipe = io.popen(cmd)
    
    if pipe then
      for path in pipe:lines() do
        -- Check if file should be excluded
        local exclude = false
        for _, exclude_func in ipairs(excludes) do
          if exclude_func(path) then
            exclude = true
            break
          end
        end
        
        -- If not excluded and matches patterns to watch, add to timestamp list
        if not exclude and should_watch_file(path) then
          local mtime = get_file_mtime(path)
          if mtime then
            file_timestamps[path] = mtime
          end
        end
      end
      pipe:close()
    end
  end
  
  print("Watching " .. #file_timestamps .. " files for changes")
  return true
end

-- Check for file changes since the last check
function watcher.check_for_changes()
  -- Don't check too frequently
  local current_time = os.time()
  if current_time - last_check_time < check_interval then
    return nil
  end
  
  last_check_time = current_time
  local changed_files = {}
  
  -- Check each watched file for changes
  for path, old_mtime in pairs(file_timestamps) do
    local new_mtime = get_file_mtime(path)
    
    -- If file exists and has changed
    if new_mtime and new_mtime > old_mtime then
      table.insert(changed_files, path)
      file_timestamps[path] = new_mtime
    -- If file no longer exists
    elseif not new_mtime then
      table.insert(changed_files, path)
      file_timestamps[path] = nil
    end
  end
  
  -- Check for new files
  for _, dir in ipairs({"."}) do  -- Default to current directory
    local cmd = 'find "' .. dir .. '" -type f -name "*.lua" 2>/dev/null'
    local pipe = io.popen(cmd)
    
    if pipe then
      for path in pipe:lines() do
        if should_watch_file(path) and not file_timestamps[path] then
          local mtime = get_file_mtime(path)
          if mtime then
            table.insert(changed_files, path)
            file_timestamps[path] = mtime
          end
        end
      end
      pipe:close()
    end
  end
  
  return #changed_files > 0 and changed_files or nil
end

-- Add patterns to watch
function watcher.add_patterns(patterns)
  for _, pattern in ipairs(patterns) do
    table.insert(watch_patterns, pattern)
  end
end

-- Set check interval
function watcher.set_check_interval(interval)
  check_interval = interval
end

return watcher