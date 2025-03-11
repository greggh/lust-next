# Filesystem Module

The filesystem module provides a comprehensive, platform-independent interface for file and directory operations in Lua. It is designed to work consistently across all operating systems while providing robust error handling and convenience functions.

## Overview

The filesystem module offers functions for:

- Reading, writing, and manipulating files
- Creating, listing, and managing directories
- Manipulating file paths in a platform-independent way
- Discovering and filtering files with glob patterns
- Retrieving file and directory information

## Importing the Module

```lua
local fs = require("lib.tools.filesystem")
```

## Core File Operations

### Reading Files

```lua
local content, err = fs.read_file(path)
```

Reads the entire contents of a file. Returns the file contents or `nil` and an error message if the file cannot be read.

**Replaces:** `io.open(path, "r"):read("*a")`

### Writing Files

```lua
local success, err = fs.write_file(path, content)
```

Writes content to a file, creating the file and any necessary parent directories. Returns `true` on success or `nil` and an error message on failure.

**Replaces:** `io.open(path, "w"):write(content)`

### Appending to Files

```lua
local success, err = fs.append_file(path, content)
```

Appends content to an existing file, creating the file if it doesn't exist. Returns `true` on success or `nil` and an error message on failure.

**Replaces:** `io.open(path, "a"):write(content)`

### Copying Files

```lua
local success, err = fs.copy_file(source, destination)
```

Copies a file from `source` to `destination`, creating any necessary parent directories. Returns `true` on success or `nil` and an error message on failure.

**Replaces:** Manual implementation with `io.open` for reading and writing

### Moving Files

```lua
local success, err = fs.move_file(source, destination)
```

Moves a file from `source` to `destination`, creating any necessary parent directories. Returns `true` on success or `nil` and an error message on failure.

**Replaces:** `os.rename(source, destination)` with better error handling and cross-filesystem support

### Deleting Files

```lua
local success, err = fs.delete_file(path)
```

Deletes a file. Returns `true` on success or `nil` and an error message on failure.

**Replaces:** `os.remove(path)` with better error handling

## Directory Operations

### Creating Directories

```lua
local success, err = fs.create_directory(path)
```

Creates a directory and any necessary parent directories. Returns `true` on success or `nil` and an error message on failure.

**Replaces:** `os.execute('mkdir -p "' .. path .. '"')` with cross-platform support

### Ensuring Directories Exist

```lua
local success, err = fs.ensure_directory_exists(path)
```

Creates a directory only if it doesn't already exist. Returns `true` if the directory exists or was created successfully, or `nil` and an error message on failure.

**Replaces:** Manual check and directory creation

### Getting Directory Contents

```lua
local contents, err = fs.get_directory_contents(path)
```

Lists the contents of a directory. Returns a table of file and directory names or `nil` and an error message on failure.

**Replaces:** `io.popen('ls -1 "' .. path .. '"')` or `io.popen('dir /b "' .. path .. '"')` with platform-independent implementation

### Deleting Directories

```lua
local success, err = fs.delete_directory(path, recursive)
```

Deletes a directory. If `recursive` is `true`, deletes all contents recursively. Returns `true` on success or `nil` and an error message on failure.

**Replaces:** `os.execute('rm -rf "' .. path .. '"')` or `os.execute('rmdir /s /q "' .. path .. '"')` with platform-independent implementation

## Path Manipulation

### Normalizing Paths

```lua
local normalized = fs.normalize_path(path)
```

Standardizes path separators and removes redundant elements. Always uses forward slashes `/` as the path separator, regardless of platform.

**Replaces:** Custom path normalization logic

### Joining Paths

```lua
local joined = fs.join_paths(path1, path2, ...)
```

Combines multiple path segments into a single path, handling separators appropriately.

**Replaces:** String concatenation with manual separator handling

### Getting Directory Name

```lua
local dir = fs.get_directory_name(path)
```

Extracts the directory component from a path.

**Replaces:** String manipulation with pattern matching

### Getting File Name

```lua
local name = fs.get_file_name(path)
```

Extracts the file name component from a path.

**Replaces:** String manipulation with pattern matching

### Getting File Extension

```lua
local ext = fs.get_extension(path)
```

Extracts the file extension from a path.

**Replaces:** String manipulation with pattern matching

### Getting Absolute Path

```lua
local abs_path = fs.get_absolute_path(path)
```

Converts a relative path to an absolute path.

**Replaces:** Various approaches using `os.getenv("PWD")` or `io.popen("cd"):read("*l")`

### Getting Relative Path

```lua
local rel_path = fs.get_relative_path(path, base)
```

Computes the relative path from `base` to `path`.

**Replaces:** Complex path manipulation logic

## File Discovery

### Converting Glob to Pattern

```lua
local pattern = fs.glob_to_pattern(glob)
```

Converts a glob pattern (like `*.lua`) to a Lua pattern string.

### Matching Patterns

```lua
local matches = fs.matches_pattern(path, pattern)
```

Tests if a path matches a glob pattern.

### Discovering Files

```lua
local files = fs.discover_files(directories, patterns, exclude_patterns)
```

Finds all files in the specified directories that match any pattern in `patterns` and don't match any pattern in `exclude_patterns`.

**Replaces:** Complex implementations using `io.popen` with `find` or other commands

### Scanning Directories

```lua
local files = fs.scan_directory(path, recursive)
```

Lists all files in a directory. If `recursive` is `true`, includes files in subdirectories.

**Replaces:** Recursive directory traversal with `io.popen`

### Finding Matches

```lua
local matches = fs.find_matches(files, pattern)
```

Filters a list of files to those matching a glob pattern.

## Information Functions

### Checking if File Exists

```lua
local exists = fs.file_exists(path)
```

Tests if a file exists.

**Replaces:** Opening and closing a file to check existence

### Checking if Directory Exists

```lua
local exists = fs.directory_exists(path)
```

Tests if a directory exists.

**Replaces:** Platform-specific checks using `os.execute`

### Getting File Size

```lua
local size, err = fs.get_file_size(path)
```

Gets the size of a file in bytes.

**Replaces:** Opening file, seeking to end, and getting position

### Getting Modified Time

```lua
local time, err = fs.get_modified_time(path)
```

Gets the modification timestamp of a file or directory.

**Replaces:** Platform-specific approaches using `io.popen` with `stat` or other commands

### Getting Creation Time

```lua
local time, err = fs.get_creation_time(path)
```

Gets the creation timestamp of a file or directory.

**Replaces:** Platform-specific approaches using `io.popen`

### Testing if Path is a File

```lua
local is_file = fs.is_file(path)
```

Tests if a path points to a file.

**Replaces:** Combination of existence checks

### Testing if Path is a Directory

```lua
local is_dir = fs.is_directory(path)
```

Tests if a path points to a directory.

**Replaces:** Platform-specific checks

## Example Usage

```lua
local fs = require("lib.tools.filesystem")

-- Basic file operations
local content = "Hello, world!"
fs.write_file("/tmp/example.txt", content)
local read_content = fs.read_file("/tmp/example.txt")
print(read_content)  -- "Hello, world!"

-- Directory operations
fs.create_directory("/tmp/test/nested")
local files = fs.get_directory_contents("/tmp/test")
for _, file in ipairs(files) do
    print(file)
end

-- Path manipulation
local path = fs.join_paths("/tmp", "test", "file.txt")
print(path)  -- "/tmp/test/file.txt"
print(fs.get_directory_name(path))  -- "/tmp/test"
print(fs.get_file_name(path))       -- "file.txt"
print(fs.get_extension(path))       -- "txt"

-- File discovery
local lua_files = fs.discover_files({"/src"}, {"*.lua"}, {"test/*"})
for _, file in ipairs(lua_files) do
    print(file)
end
```

## Migrating from io.* functions

The filesystem module provides a robust replacement for standard Lua I/O functions with better error handling, cross-platform compatibility, and higher-level operations. Here's how to replace common io.* patterns:

### Reading a file

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
local content, err = fs.read_file("data.txt")
if not content then
    print("Error reading file: " .. (err or ""))
    return
end
return content
```

### Writing a file

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
local success, err = fs.write_file("output.txt", "Hello, world!")
if not success then
    print("Error writing file: " .. (err or ""))
    return false
end
return true
```

### Checking if a file exists

**Before:**
```lua
local file = io.open("data.txt", "r")
if file then
    file:close()
    return true
end
return false
```

**After:**
```lua
return fs.file_exists("data.txt")
```

### Creating a directory

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
local success, err = fs.create_directory("new_dir")
if not success then
    print("Failed to create directory: " .. (err or ""))
    return false
end
return true
```

### Listing directory contents

**Before:**
```lua
local handle = io.popen('ls -1 "directory"')
if not handle then
    return {}
end
local result = {}
for file in handle:lines() do
    table.insert(result, file)
end
handle:close()
return result
```

**After:**
```lua
local contents, err = fs.get_directory_contents("directory")
if not contents then
    print("Error listing directory: " .. (err or ""))
    return {}
end
return contents
```

## Error Handling

All functions that can fail return two values:
1. The result value (or `nil` if an error occurred)
2. An error message (only present if an error occurred)

This allows for robust error handling:

```lua
local content, err = fs.read_file("/path/to/file.txt")
if not content then
    print("Error reading file: " .. (err or "unknown error"))
    return
end
```

The filesystem module provides detailed error messages and handles "Permission denied" errors gracefully, avoiding excessive error output when traversing system directories.

## Platform Compatibility

The filesystem module works consistently across all platforms, including:
- Linux
- macOS
- Windows

It handles platform-specific differences internally, providing a consistent API regardless of the underlying operating system.

## Performance Considerations

- The module includes internal caching to avoid redundant operations
- Path normalization is optimized for frequent use
- Operations are designed to minimize system calls where possible
- For high-volume operations, consider batching changes to minimize I/O overhead

## Logging Integration

The filesystem module integrates with the logging system for detailed diagnostics:

```lua
-- Configure verbose logging for filesystem operations
local logging = require("lib.tools.logging")
logging.configure_module("filesystem", {
  level = logging.LEVELS.DEBUG
})

-- Filesystem operations will now produce detailed logs
local fs = require("lib.tools.filesystem")
fs.read_file("config.json")  -- Will log detailed information about the operation
```

This is particularly useful for debugging file access issues in complex applications.