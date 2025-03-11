# Filesystem Migration Example

This document demonstrates the migration of one function from using standard Lua `io.*` functions to our robust filesystem module. This serves as a practical example of the migration approach described in the [migration guide](migrating_to_filesystem.md).

## Example: Log Search Function

We'll examine the `search_logs` function in `lib/tools/logging/search.lua`, which originally used `io.open` to read and process log files.

### Before Migration

```lua
function M.search_logs(options)
  options = options or {}
  
  local fs = get_fs()
  if not fs then
    return nil, "Filesystem module not available"
  end
  
  -- Validate options
  local log_file = options.log_file
  if not log_file then
    return nil, "Log file path is required"
  end
  
  -- Check if file exists
  if not fs.file_exists(log_file) then
    return nil, "Log file does not exist: " .. log_file
  end
  
  -- Determine log format (text or JSON)
  local is_json = log_file:match("%.json$") or options.format == "json"
  
  -- Open log file
  local file, err = io.open(log_file, "r")
  if not file then
    return nil, "Failed to open log file: " .. (err or "unknown error")
  end
  
  -- Set up filtering criteria
  local from_date = options.from_date
  local to_date = options.to_date
  local level = options.level and options.level:upper()
  local module = options.module
  local message_pattern = options.message_pattern
  local limit = options.limit or 1000  -- Default limit to prevent memory issues
  
  -- Initialize results
  local results = {}
  local count = 0
  
  -- Process log file line by line
  for line in file:lines() do
    local log_entry
    
    -- Parse based on format
    if is_json then
      log_entry = parse_json_log_line(line)
    else
      log_entry = parse_text_log_line(line)
    end
    
    -- Apply filters to parsed entry
    if log_entry then
      -- [filtering logic...]
      
      -- Add to results if passes all filters
      if include then
        count = count + 1
        results[count] = log_entry
        
        -- Check limit
        if count >= limit then
          break
        end
      end
    end
  end
  
  -- Close file
  file:close()
  
  -- Return results
  return {
    entries = results,
    count = count,
    truncated = count >= limit
  }
end
```

### After Migration

```lua
function M.search_logs(options)
  options = options or {}
  
  local fs = get_fs()
  if not fs then
    return nil, "Filesystem module not available"
  end
  
  -- Validate options
  local log_file = options.log_file
  if not log_file then
    return nil, "Log file path is required"
  end
  
  -- Check if file exists
  if not fs.file_exists(log_file) then
    return nil, "Log file does not exist: " .. log_file
  end
  
  -- Determine log format (text or JSON)
  local is_json = log_file:match("%.json$") or options.format == "json"
  
  -- Read log file
  local content, err = fs.read_file(log_file)
  if not content then
    return nil, "Failed to read log file: " .. (err or "unknown error")
  end
  
  -- Set up filtering criteria
  local from_date = options.from_date
  local to_date = options.to_date
  local level = options.level and options.level:upper()
  local module = options.module
  local message_pattern = options.message_pattern
  local limit = options.limit or 1000  -- Default limit to prevent memory issues
  
  -- Initialize results
  local results = {}
  local count = 0
  
  -- Process log file line by line (split content into lines)
  for line in content:gmatch("([^\r\n]+)[\r\n]*") do
    local log_entry
    
    -- Parse based on format
    if is_json then
      log_entry = parse_json_log_line(line)
    else
      log_entry = parse_text_log_line(line)
    end
    
    -- Apply filters to parsed entry
    if log_entry then
      -- [filtering logic...]
      
      -- Add to results if passes all filters
      if include then
        count = count + 1
        results[count] = log_entry
        
        -- Check limit
        if count >= limit then
          break
        end
      end
    end
  end
  
  -- Return results
  return {
    entries = results,
    count = count,
    truncated = count >= limit
  }
end
```

## Key Changes

1. Replaced `io.open(log_file, "r")` with `fs.read_file(log_file)`
2. Removed the need to explicitly close the file with `file:close()`
3. Changed from `file:lines()` to `content:gmatch("([^\r\n]+)[\r\n]*")` to iterate over lines
4. More consistent error handling that integrates with the existing error system

## Benefits of Migration

1. **Simpler Code**: The migration reduced the number of steps needed to read and process a file
2. **Better Error Handling**: The filesystem module provides more detailed error messages
3. **Cross-Platform Compatibility**: The filesystem module handles line endings consistently
4. **Automatic Integration**: The filesystem module automatically logs operations through the logging system
5. **Improved Security**: The filesystem module provides better handling of permissions and edge cases

## Additional Improvements

While migrating, we also:

1. Made sure error messages are consistent across the module
2. Improved the pattern for splitting lines to handle both Unix (LF) and Windows (CRLF) line endings
3. Made the code more concise by removing the explicit file close operation

## Testing the Migration

After making these changes, we should run the following tests:

1. Test with log files with different line endings (Unix, Windows)
2. Test with large log files to ensure performance remains acceptable
3. Test with various filtering options to ensure the functionality is preserved
4. Test error handling by providing invalid paths or permissions

## Next Steps

Now that the `search_logs` function is migrated, we can follow the same pattern to migrate the other I/O operations in this module, such as:

1. `get_log_stats` function
2. `export_logs` function
3. `get_log_processor` function

Each function should follow the same pattern:
1. Identify the `io.*` calls
2. Replace them with the equivalent filesystem module functions
3. Update the line-by-line processing
4. Test thoroughly to ensure no regressions