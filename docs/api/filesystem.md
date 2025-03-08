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

### Writing Files

```lua
local success, err = fs.write_file(path, content)
```

Writes content to a file, creating the file and any necessary parent directories. Returns `true` on success or `nil` and an error message on failure.

### Appending to Files

```lua
local success, err = fs.append_file(path, content)
```

Appends content to an existing file, creating the file if it doesn't exist. Returns `true` on success or `nil` and an error message on failure.

### Copying Files

```lua
local success, err = fs.copy_file(source, destination)
```

Copies a file from `source` to `destination`, creating any necessary parent directories. Returns `true` on success or `nil` and an error message on failure.

### Moving Files

```lua
local success, err = fs.move_file(source, destination)
```

Moves a file from `source` to `destination`, creating any necessary parent directories. Returns `true` on success or `nil` and an error message on failure.

### Deleting Files

```lua
local success, err = fs.delete_file(path)
```

Deletes a file. Returns `true` on success or `nil` and an error message on failure.

## Directory Operations

### Creating Directories

```lua
local success, err = fs.create_directory(path)
```

Creates a directory and any necessary parent directories. Returns `true` on success or `nil` and an error message on failure.

### Ensuring Directories Exist

```lua
local success, err = fs.ensure_directory_exists(path)
```

Creates a directory only if it doesn't already exist. Returns `true` if the directory exists or was created successfully, or `nil` and an error message on failure.

### Getting Directory Contents

```lua
local contents, err = fs.get_directory_contents(path)
```

Lists the contents of a directory. Returns a table of file and directory names or `nil` and an error message on failure.

### Deleting Directories

```lua
local success, err = fs.delete_directory(path, recursive)
```

Deletes a directory. If `recursive` is `true`, deletes all contents recursively. Returns `true` on success or `nil` and an error message on failure.

## Path Manipulation

### Normalizing Paths

```lua
local normalized = fs.normalize_path(path)
```

Standardizes path separators and removes redundant elements. Always uses forward slashes `/` as the path separator, regardless of platform.

### Joining Paths

```lua
local joined = fs.join_paths(path1, path2, ...)
```

Combines multiple path segments into a single path, handling separators appropriately.

### Getting Directory Name

```lua
local dir = fs.get_directory_name(path)
```

Extracts the directory component from a path.

### Getting File Name

```lua
local name = fs.get_file_name(path)
```

Extracts the file name component from a path.

### Getting File Extension

```lua
local ext = fs.get_extension(path)
```

Extracts the file extension from a path.

### Getting Absolute Path

```lua
local abs_path = fs.get_absolute_path(path)
```

Converts a relative path to an absolute path.

### Getting Relative Path

```lua
local rel_path = fs.get_relative_path(path, base)
```

Computes the relative path from `base` to `path`.

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

### Scanning Directories

```lua
local files = fs.scan_directory(path, recursive)
```

Lists all files in a directory. If `recursive` is `true`, includes files in subdirectories.

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

### Checking if Directory Exists

```lua
local exists = fs.directory_exists(path)
```

Tests if a directory exists.

### Getting File Size

```lua
local size, err = fs.get_file_size(path)
```

Gets the size of a file in bytes.

### Getting Modified Time

```lua
local time, err = fs.get_modified_time(path)
```

Gets the modification timestamp of a file or directory.

### Getting Creation Time

```lua
local time, err = fs.get_creation_time(path)
```

Gets the creation timestamp of a file or directory.

### Testing if Path is a File

```lua
local is_file = fs.is_file(path)
```

Tests if a path points to a file.

### Testing if Path is a Directory

```lua
local is_dir = fs.is_directory(path)
```

Tests if a path points to a directory.

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

## Platform Compatibility

The filesystem module works consistently across all platforms, including:
- Linux
- macOS
- Windows

It handles platform-specific differences internally, providing a consistent API regardless of the underlying operating system.