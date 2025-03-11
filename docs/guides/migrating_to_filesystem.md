# Migrating to the Filesystem Module

This guide provides a step-by-step approach to replacing standard Lua `io.*` functions with our robust filesystem module. The filesystem module offers improved error handling, cross-platform compatibility, and higher-level operations.

## Why Migrate?

The standard Lua I/O functions have several limitations:

1. **Poor Error Handling**: Error information is often limited and inconsistent
2. **Lack of Cross-Platform Compatibility**: Path handling and directory operations differ across operating systems
3. **Limited Higher-Level Operations**: Common tasks like creating nested directories or copying files require multiple operations
4. **No Integration with Logging**: Error reporting is disconnected from the application's logging system
5. **No Permission Handling**: "Permission denied" errors can flood logs when traversing system directories

The filesystem module addresses these issues and provides a consistent, robust API for file and directory operations.

## Migration Approach

We recommend a gradual, file-by-file approach to migration:

1. Identify files that use `io.*` functions
2. Prioritize modules with the most file operations
3. Replace operations one by one, testing after each change
4. Update error handling to make use of the improved error messages

## Common Replacements

### Reading Files

**Before:**
```lua
local file, err = io.open("data.txt", "r")
if not file then
    print("Error opening file: " .. (err or ""))
    return
end
local content = file:read("*a")
file:close()
return content
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local content, err = fs.read_file("data.txt")
if not content then
    print("Error reading file: " .. (err or ""))
    return
end
return content
```

### Writing Files

**Before:**
```lua
local file, err = io.open("output.txt", "w")
if not file then
    print("Error opening file: " .. (err or ""))
    return false
end
file:write("Hello, world!")
file:close()
return true
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.write_file("output.txt", "Hello, world!")
if not success then
    print("Error writing file: " .. (err or ""))
    return false
end
return true
```

### Appending to Files

**Before:**
```lua
local file, err = io.open("log.txt", "a")
if not file then
    print("Error opening file: " .. (err or ""))
    return false
end
file:write("New log entry\n")
file:close()
return true
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.append_file("log.txt", "New log entry\n")
if not success then
    print("Error appending to file: " .. (err or ""))
    return false
end
return true
```

### Reading Files Line by Line

**Before:**
```lua
local file, err = io.open("data.txt", "r")
if not file then
    print("Error opening file: " .. (err or ""))
    return
end
local lines = {}
for line in file:lines() do
    table.insert(lines, line)
end
file:close()
return lines
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local content, err = fs.read_file("data.txt")
if not content then
    print("Error reading file: " .. (err or ""))
    return
end
local lines = {}
for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
end
return lines
```

### Checking if a File Exists

**Before:**
```lua
local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local exists = fs.file_exists(path)
```

### Creating a Directory

**Before:**
```lua
local success = os.execute('mkdir "new_dir"')
if not success then
    print("Failed to create directory")
    return false
end
return true
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.create_directory("new_dir")
if not success then
    print("Failed to create directory: " .. (err or ""))
    return false
end
return true
```

### Creating Nested Directories

**Before:**
```lua
local function create_recursive(path)
    local sep = package.config:sub(1,1)
    local current = ""
    for dir in path:gmatch("[^" .. sep .. "]+") do
        current = current .. dir .. sep
        os.execute('mkdir "' .. current .. '" 2>/dev/null')
    end
end
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.create_directory("path/to/nested/directory")
```

### Listing Directory Contents

**Before:**
```lua
local function list_directory(path)
    local handle
    if package.config:sub(1,1) == '\\' then
        -- Windows
        handle = io.popen('dir /b "' .. path .. '"')
    else
        -- Unix
        handle = io.popen('ls -1 "' .. path .. '"')
    end
    if not handle then
        return {}
    end
    local result = {}
    for file in handle:lines() do
        table.insert(result, file)
    end
    handle:close()
    return result
end
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local contents, err = fs.get_directory_contents(path)
if not contents then
    return {}
end
return contents
```

### Copying a File

**Before:**
```lua
local function copy_file(source, destination)
    local input = io.open(source, "rb")
    if not input then return false end
    
    local output = io.open(destination, "wb")
    if not output then 
        input:close()
        return false 
    end
    
    local content = input:read("*a")
    output:write(content)
    
    input:close()
    output:close()
    return true
end
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.copy_file(source, destination)
```

### Moving/Renaming a File

**Before:**
```lua
local success = os.rename(source, destination)
if not success then
    print("Failed to move file")
    return false
end
return true
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local success, err = fs.move_file(source, destination)
if not success then
    print("Failed to move file: " .. (err or ""))
    return false
end
return true
```

## Working with Paths

### Joining Paths

**Before:**
```lua
local sep = package.config:sub(1,1)
local path = dir .. sep .. filename
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local path = fs.join_paths(dir, filename)
```

### Normalizing Paths

**Before:**
```lua
local function normalize_path(path)
    local sep = package.config:sub(1,1)
    path = path:gsub("\\", "/"):gsub("//+", "/")
    if path:sub(-1) == "/" and #path > 1 then
        path = path:sub(1, -2)
    end
    return path
end
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local normalized = fs.normalize_path(path)
```

### Getting File Name and Extension

**Before:**
```lua
local function get_filename(path)
    return path:match("([^/\\]+)$")
end

local function get_extension(path)
    return path:match("%.([^.]+)$")
end
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local filename = fs.get_file_name(path)
local extension = fs.get_extension(path)
```

## Integrating with Logging

One major advantage of the filesystem module is its integration with the logging system:

```lua
-- Configure logging for filesystem operations
local logging = require("lib.tools.logging")
logging.configure_module("filesystem", {
  level = logging.LEVELS.INFO  -- Adjust level as needed
})

-- Now filesystem operations will log through the central logging system
local fs = require("lib.tools.filesystem")
fs.write_file("output.txt", "Hello, world!")
```

This integration provides:
- Consistent error reporting
- Detailed operation logging at debug/trace levels
- Centralized control over filesystem logging verbosity

## Migration Strategy for Large Codebases

For larger codebases, follow these steps:

1. **Audit**: Use grep to identify all `io.*` usages:
   ```bash
   grep -r "io\." --include="*.lua" .
   ```

2. **Prioritize**: Focus first on:
   - Core utilities and libraries
   - Modules with the most file operations
   - Code that runs on multiple platforms

3. **Create Helper Functions**: If the same patterns are used repeatedly, create wrapper functions:
   ```lua
   local fs = require("lib.tools.filesystem")
   
   function read_config_file(filename)
       local content, err = fs.read_file(filename)
       if not content then
           log.error("Failed to read config file: " .. (err or ""))
           return nil
       end
       return content
   end
   ```

4. **Test Thoroughly**: File operations are critical, so test each replacement carefully

5. **Update Diagnostics**: Enhance error handling to take advantage of the more detailed error messages

## Handling Specific Migration Challenges

### Working with Temporary Files

**Before:**
```lua
local temp_file = os.tmpname()
local file = io.open(temp_file, "w")
file:write(data)
file:close()
-- Use temp_file...
os.remove(temp_file)
```

**After:**
```lua
local fs = require("lib.tools.filesystem")
local temp_dir = os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
local temp_file = fs.join_paths(temp_dir, "temp_" .. os.time() .. "_" .. math.random(1000))
fs.write_file(temp_file, data)
-- Use temp_file...
fs.delete_file(temp_file)
```

### Handling Binary Files

The filesystem module handles binary files correctly:

```lua
local fs = require("lib.tools.filesystem")
local binary_data = fs.read_file("image.jpg")  -- Works with binary data
fs.write_file("copy.jpg", binary_data)
```

### Reading Parts of Large Files

For very large files where you don't want to read the entire content:

```lua
local file, err = io.open("large_file.txt", "r")
if not file then
    print("Error opening file: " .. (err or ""))
    return
end

-- Read the first 1000 bytes
file:seek("set", 0)
local data = file:read(1000)
file:close()
```

Currently, the filesystem module does not directly support partial reads, so continue using `io.open` for these cases until this feature is added.

## Conclusion

Migrating from standard Lua I/O functions to the filesystem module provides numerous benefits, including:

- Better error handling and reporting
- Cross-platform compatibility
- Higher-level operations (copying files, creating nested directories)
- Integration with the logging system
- Permission error handling

Take a gradual approach to migration, focusing on one file or module at a time, and test thoroughly after each change.