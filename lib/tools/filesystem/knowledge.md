# Filesystem Knowledge

## Purpose
Safe and consistent file operations across platforms.

## File Operations
```lua
-- Safe file operations
local fs = require("lib.tools.filesystem")

-- Read file with error handling
local content, err = fs.read_file("config.json")
if not content then
  logger.error("Failed to read config", {
    error = err,
    category = err.category
  })
  return nil, err
end

-- Write with directory creation
local success, err = fs.write_file("path/to/new/file.txt", content, {
  create_dirs = true,
  mode = "644"
})

-- Directory operations
local files = fs.list_files("dir", {
  pattern = "*.lua",
  recursive = true
})

-- Complex file operations
local function process_large_file(path)
  -- Open file for streaming
  local file, err = fs.open_file(path, "r")
  if not file then return nil, err end
  
  local result = {}
  local chunk_size = 1024 * 1024 -- 1MB chunks
  
  while true do
    local chunk = file:read(chunk_size)
    if not chunk then break end
    -- Process chunk
    table.insert(result, process_chunk(chunk))
  end
  
  file:close()
  return table.concat(result)
end

-- Safe temporary files
local function with_temp_file(callback)
  local path = fs.temp_file()
  local result, err = error_handler.try(function()
    return callback(path)
  end)
  
  fs.delete_file(path)
  return result, err
end
```

## Path Operations
```lua
-- Path normalization
local path = fs.normalize_path("dir/../file.txt")
expect(path).to.equal("file.txt")

-- Path joining
local full_path = fs.join_paths("dir", "subdir", "file.txt")

-- Directory creation
local success = fs.create_directory("path/to/dir", {
  recursive = true,
  mode = "755"
})

-- Path checking
if fs.is_directory(path) then
  for file in fs.iterate_directory(path) do
    -- Process file
  end
end
```

## Error Handling
```lua
-- Standard error pattern
local function safe_file_operation(path)
  -- Check existence
  if not fs.file_exists(path) then
    return nil, error_handler.io_error(
      "File not found",
      { path = path }
    )
  end
  
  -- Check permissions
  local accessible, err = fs.check_access(path, "r")
  if not accessible then
    return nil, err
  end
  
  -- Perform operation
  local result, op_err = error_handler.try(function()
    return fs.read_file(path)
  end)
  
  if not result then
    return nil, op_err
  end
  
  return result
end

-- Resource cleanup
local function with_open_file(path, mode, callback)
  local file, err = fs.open_file(path, mode)
  if not file then return nil, err end
  
  local result, cb_err = error_handler.try(function()
    return callback(file)
  end)
  
  file:close()
  
  if not result then
    return nil, cb_err
  end
  return result
end
```

## Critical Rules
- NEVER use io.* functions
- ALWAYS handle errors
- ALWAYS clean up resources
- CHECK permissions first
- VALIDATE paths
- USE proper modes
- HANDLE large files
- CLEAN UP temp files

## Best Practices
- Use normalized paths
- Handle platform differences
- Clean up resources
- Check permissions
- Validate paths
- Handle symlinks
- Use streaming
- Monitor space
- Handle timeouts
- Document patterns

## Performance Tips
- Use appropriate chunks
- Stream large files
- Cache stats
- Clean up promptly
- Monitor space
- Handle timeouts
- Batch operations
- Buffer writes