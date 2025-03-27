# Filesystem Module Examples

This document provides comprehensive examples for using the Firmo filesystem module in various scenarios, from basic file operations to complex file discovery and temporary file management.

## Basic File Operations

### Reading and Writing Files

```lua
local fs = require("lib.tools.filesystem")

-- Writing a file
local success, err = fs.write_file("/tmp/example.txt", "Hello, world!")
if not success then
    print("Error writing file: " .. (err or "unknown error"))
    return
end

-- Reading a file
local content, err = fs.read_file("/tmp/example.txt")
if not content then
    print("Error reading file: " .. (err or "unknown error"))
    return
end
print(content)  -- Outputs: Hello, world!

-- Appending to a file
success, err = fs.append_file("/tmp/example.txt", "\nThis is a new line.")
if not success then
    print("Error appending to file: " .. (err or "unknown error"))
    return
end

-- Reading the updated file
content, err = fs.read_file("/tmp/example.txt")
if content then
    print(content)  -- Outputs: Hello, world!\nThis is a new line.
end
```

### Copying and Moving Files

```lua
local fs = require("lib.tools.filesystem")

-- Create a source file
fs.write_file("/tmp/source.txt", "This is the source file.")

-- Copy the file
local success, err = fs.copy_file("/tmp/source.txt", "/tmp/destination.txt")
if not success then
    print("Error copying file: " .. (err or "unknown error"))
    return
end

-- Verify the copy worked
local content = fs.read_file("/tmp/destination.txt")
print(content)  -- Outputs: This is the source file.

-- Move the file to a new location
success, err = fs.move_file("/tmp/destination.txt", "/tmp/moved.txt")
if not success then
    print("Error moving file: " .. (err or "unknown error"))
    return
end

-- Verify the original file no longer exists and the new one does
print(fs.file_exists("/tmp/destination.txt"))  -- Outputs: false
print(fs.file_exists("/tmp/moved.txt"))        -- Outputs: true
```

### Checking If Files Exist and Deleting Files

```lua
local fs = require("lib.tools.filesystem")

-- Create a test file
fs.write_file("/tmp/delete_me.txt", "This file will be deleted.")

-- Check if the file exists
if fs.file_exists("/tmp/delete_me.txt") then
    print("File exists!")
else
    print("File does not exist.")
end

-- Delete the file
local success, err = fs.delete_file("/tmp/delete_me.txt")
if not success then
    print("Error deleting file: " .. (err or "unknown error"))
    return
end

-- Verify the file was deleted
if not fs.file_exists("/tmp/delete_me.txt") then
    print("File was successfully deleted!")
end
```

## Directory Operations

### Creating and Ensuring Directories

```lua
local fs = require("lib.tools.filesystem")

-- Create a nested directory structure
local success, err = fs.create_directory("/tmp/parent/child/grandchild")
if not success then
    print("Error creating directories: " .. (err or "unknown error"))
    return
end

-- Check if a directory exists
if fs.directory_exists("/tmp/parent/child") then
    print("Directory exists!")
end

-- Ensure a directory exists (creates it only if it doesn't exist)
success, err = fs.ensure_directory_exists("/tmp/parent/another_child")
if success then
    print("Directory exists or was created!")
end
```

### Listing Directory Contents

```lua
local fs = require("lib.tools.filesystem")

-- Create a directory with some files for the example
fs.create_directory("/tmp/test_dir")
fs.write_file("/tmp/test_dir/file1.txt", "Content 1")
fs.write_file("/tmp/test_dir/file2.lua", "Content 2")
fs.create_directory("/tmp/test_dir/subdir")

-- Get all contents (files and directories)
local contents, err = fs.get_directory_contents("/tmp/test_dir")
if not contents then
    print("Error listing directory: " .. (err or "unknown error"))
    return
end

print("All contents:")
for _, item in ipairs(contents) do
    print("- " .. item)
end

-- List only files
local files, err = fs.list_files("/tmp/test_dir")
if not files then
    print("Error listing files: " .. (err or "unknown error"))
    return
end

print("Files only:")
for _, file in ipairs(files) do
    print("- " .. fs.get_file_name(file))
end

-- List files recursively (including subdirectories)
local all_files, err = fs.list_files_recursive("/tmp/test_dir")
if not all_files then
    print("Error listing files recursively: " .. (err or "unknown error"))
    return
end

print("All files recursively:")
for _, file in ipairs(all_files) do
    print("- " .. file)
end
```

### Deleting Directories

```lua
local fs = require("lib.tools.filesystem")

-- Create a directory with contents
fs.create_directory("/tmp/to_delete")
fs.write_file("/tmp/to_delete/file.txt", "Content")
fs.create_directory("/tmp/to_delete/subdir")

-- Try to delete non-recursively (will fail because directory is not empty)
local success, err = fs.delete_directory("/tmp/to_delete", false)
if not success then
    print("Non-recursive delete failed as expected: " .. (err or ""))
end

-- Delete recursively
success, err = fs.delete_directory("/tmp/to_delete", true)
if success then
    print("Directory deleted recursively!")
end

-- Verify the directory no longer exists
if not fs.directory_exists("/tmp/to_delete") then
    print("Confirmed: Directory no longer exists")
end
```

## Path Manipulation

### Normalizing and Joining Paths

```lua
local fs = require("lib.tools.filesystem")

-- Normalize paths
print(fs.normalize_path("/home/user/./documents/../downloads/"))  
-- Outputs: /home/user/downloads

print(fs.normalize_path("C:\\Windows\\System32\\..\\Users"))
-- Outputs: C:/Windows/Users

-- Join paths
local path = fs.join_paths("/home/user", "documents", "file.txt")
print(path)  -- Outputs: /home/user/documents/file.txt

-- Handles trailing slashes correctly
path = fs.join_paths("/home/user/", "/documents/", "file.txt")
print(path)  -- Outputs: /home/user/documents/file.txt
```

### Working with Path Components

```lua
local fs = require("lib.tools.filesystem")

local file_path = "/home/user/documents/report.pdf"

-- Get directory name
print(fs.get_directory_name(file_path))  -- Outputs: /home/user/documents

-- Get file name
print(fs.get_file_name(file_path))  -- Outputs: report.pdf

-- Get file extension
print(fs.get_extension(file_path))  -- Outputs: pdf

-- Handle paths without extensions
print(fs.get_extension("/etc/hosts"))  -- Outputs: "" (empty string)

-- Get absolute path from relative
local abs_path = fs.get_absolute_path("../relative/path")
print(abs_path)  -- Outputs depends on current directory

-- Get relative path
local rel_path = fs.get_relative_path("/home/user/projects/app/src", "/home/user/projects")
print(rel_path)  -- Outputs: app/src
```

## File Discovery

### Finding Files by Pattern

```lua
local fs = require("lib.tools.filesystem")

-- Setup example directory structure
fs.create_directory("/tmp/find_examples/src")
fs.create_directory("/tmp/find_examples/tests")
fs.write_file("/tmp/find_examples/src/main.lua", "print('Hello')")
fs.write_file("/tmp/find_examples/src/utils.lua", "-- Utils")
fs.write_file("/tmp/find_examples/tests/main_test.lua", "-- Test")
fs.write_file("/tmp/find_examples/README.md", "# Example")

-- Use discover_files to find all Lua files
local lua_files, err = fs.discover_files(
    {"/tmp/find_examples"},  -- Directories to search
    {"*.lua"},              -- Include patterns
    {}                      -- Exclude patterns
)

if not lua_files then
    print("Error discovering files: " .. (err or "unknown error"))
    return
end

print("All Lua files:")
for _, file in ipairs(lua_files) do
    print("- " .. file)
end

-- Find only test files
local test_files, err = fs.discover_files(
    {"/tmp/find_examples"},
    {"*_test.lua"},
    {}
)

print("Test files:")
for _, file in ipairs(test_files) do
    print("- " .. file)
end

-- Find all files except tests
local non_test_files, err = fs.discover_files(
    {"/tmp/find_examples"},
    {"*"},
    {"*_test.lua"}
)

print("Non-test files:")
for _, file in ipairs(non_test_files) do
    print("- " .. file)
end
```

### Using Glob Patterns

```lua
local fs = require("lib.tools.filesystem")

-- Convert a glob pattern to a Lua pattern
local pattern = fs.glob_to_pattern("*.lua")
print(pattern)  -- Outputs the Lua equivalent pattern

-- Check if a file matches a pattern
local matches = fs.matches_pattern("script.lua", "*.lua")
print(matches)  -- Outputs: true

-- Check a complex pattern
matches = fs.matches_pattern("src/components/Button.jsx", "src/**/*.jsx")
print(matches)  -- Outputs: true

-- Scan a directory and then filter results
local all_files = fs.scan_directory("/tmp/find_examples", true)
local md_files = fs.find_matches(all_files, "*.md")

print("Markdown files:")
for _, file in ipairs(md_files) do
    print("- " .. file)
end
```

### Working with Recursive Searches

```lua
local fs = require("lib.tools.filesystem")

-- Create a nested directory structure
fs.create_directory("/tmp/recursive_example/src/components/ui")
fs.create_directory("/tmp/recursive_example/src/utils")
fs.write_file("/tmp/recursive_example/src/components/ui/Button.jsx", "// Button component")
fs.write_file("/tmp/recursive_example/src/components/ui/Card.jsx", "// Card component")
fs.write_file("/tmp/recursive_example/src/utils/format.js", "// Format utilities")
fs.write_file("/tmp/recursive_example/src/index.js", "// Entry point")

-- Find all JS and JSX files recursively
local js_files, err = fs.discover_files(
    {"/tmp/recursive_example"},
    {"*.js", "*.jsx"},
    {}
)

print("All JS and JSX files:")
for _, file in ipairs(js_files) do
    print("- " .. file)
end

-- Find specifically UI components
local ui_components, err = fs.discover_files(
    {"/tmp/recursive_example/src/components/ui"},
    {"*.jsx"},
    {}
)

print("UI Components:")
for _, file in ipairs(ui_components) do
    print("- " .. fs.get_file_name(file))
end
```

## File Information

### Getting File Metadata

```lua
local fs = require("lib.tools.filesystem")

-- Create a test file
fs.write_file("/tmp/metadata_test.txt", "This is test content.")

-- Get file size
local size, err = fs.get_file_size("/tmp/metadata_test.txt")
if size then
    print("File size: " .. size .. " bytes")
end

-- Get modified time
local mod_time, err = fs.get_modified_time("/tmp/metadata_test.txt")
if mod_time then
    print("Last modified: " .. os.date("%Y-%m-%d %H:%M:%S", mod_time))
end

-- Get creation time (may not be available on all systems)
local create_time, err = fs.get_creation_time("/tmp/metadata_test.txt")
if create_time then
    print("Created on: " .. os.date("%Y-%m-%d %H:%M:%S", create_time))
end

-- Check if path is a file or directory
print("Is file: " .. tostring(fs.is_file("/tmp/metadata_test.txt")))
print("Is directory: " .. tostring(fs.is_directory("/tmp/metadata_test.txt")))
```

## Working with Temporary Files

### Using the Temp File Module

```lua
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")

-- Create a temporary file with content
local temp_path, err = temp_file.create_with_content("This is temporary content", "txt")
if not temp_path then
    print("Error creating temp file: " .. tostring(err))
    return
end

print("Created temporary file at: " .. temp_path)

-- Read the content back
local content, read_err = fs.read_file(temp_path)
if content then
    print("Content: " .. content)
end

-- Create a temporary directory
local temp_dir, err = temp_file.create_temp_directory()
if not temp_dir then
    print("Error creating temp directory: " .. tostring(err))
    return
end

print("Created temporary directory at: " .. temp_dir)

-- Create a file in the temp directory
local file_in_temp_dir = fs.join_paths(temp_dir, "example.txt")
fs.write_file(file_in_temp_dir, "File in temp directory")

-- Automatically cleanup when the test is done
local success, errors = temp_file.cleanup_test_context()
if not success then
    print("Some resources could not be cleaned up:")
    for _, resource in ipairs(errors) do
        print("Failed to clean up: " .. resource.path)
    end
end
```

### Using Temporary Files with Callbacks

```lua
local temp_file = require("lib.tools.temp_file")

-- Create and use a temporary file with automatic cleanup
local result, err = temp_file.with_temp_file("Temporary content", function(temp_path)
    print("Working with temporary file at: " .. temp_path)
    
    -- Do something with the file
    local fs = require("lib.tools.filesystem")
    local content = fs.read_file(temp_path)
    
    -- Return a result from the callback
    return content .. " (processed)"
end, "txt")

if result then
    print("Result: " .. result)
end

-- Create and use a temporary directory with automatic cleanup
local dir_result, dir_err = temp_file.with_temp_directory(function(dir_path)
    print("Working with temporary directory at: " .. dir_path)
    
    -- Create some files in the directory
    local fs = require("lib.tools.filesystem")
    fs.write_file(fs.join_paths(dir_path, "file1.txt"), "Content 1")
    fs.write_file(fs.join_paths(dir_path, "file2.txt"), "Content 2")
    
    -- Return some result
    return "Created 2 files in temporary directory"
end)

if dir_result then
    print(dir_result)
end
```

## Advanced Examples

### Processing Multiple Files in a Directory

```lua
local fs = require("lib.tools.filesystem")

-- Create sample files
fs.create_directory("/tmp/data_processing")
fs.write_file("/tmp/data_processing/data1.csv", "id,name\n1,Alice\n2,Bob")
fs.write_file("/tmp/data_processing/data2.csv", "id,name\n3,Charlie\n4,Dave")
fs.write_file("/tmp/data_processing/notes.txt", "This is not a CSV file")

-- Function to process a CSV file
local function process_csv(file_path)
    local content, err = fs.read_file(file_path)
    if not content then
        return nil, "Failed to read file: " .. (err or "unknown error")
    end
    
    local results = {}
    local lines = {}
    
    -- Split content into lines
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    -- Parse header
    local header = lines[1]
    local columns = {}
    for col in header:gmatch("[^,]+") do
        table.insert(columns, col)
    end
    
    -- Parse data rows
    for i = 2, #lines do
        local row = {}
        local col_index = 1
        for value in lines[i]:gmatch("[^,]+") do
            row[columns[col_index]] = value
            col_index = col_index + 1
        end
        table.insert(results, row)
    end
    
    return results
end

-- Process all CSV files in the directory
local csv_files, err = fs.find_files("/tmp/data_processing", "%.csv$", false)
if not csv_files then
    print("Error finding CSV files: " .. (err or "unknown error"))
    return
end

local all_data = {}
for _, file_path in ipairs(csv_files) do
    print("Processing: " .. file_path)
    
    local data, err = process_csv(file_path)
    if data then
        for _, row in ipairs(data) do
            table.insert(all_data, row)
        end
    else
        print("Error processing file: " .. (err or "unknown error"))
    end
end

-- Print the combined data
print("\nCombined data:")
for i, row in ipairs(all_data) do
    print(string.format("Row %d: ID=%s, Name=%s", i, row.id, row.name))
end
```

### Creating a File Backup System

```lua
local fs = require("lib.tools.filesystem")

-- Setup a backup function
local function backup_file(file_path, backup_dir)
    -- Ensure the backup directory exists
    local success, err = fs.ensure_directory_exists(backup_dir)
    if not success then
        return nil, "Failed to create backup directory: " .. (err or "unknown error")
    end
    
    -- Get the filename for the backup
    local filename = fs.get_file_name(file_path)
    local timestamp = os.date("%Y%m%d%H%M%S")
    local backup_path = fs.join_paths(backup_dir, filename .. "." .. timestamp .. ".bak")
    
    -- Copy the file to the backup location
    success, err = fs.copy_file(file_path, backup_path)
    if not success then
        return nil, "Failed to create backup: " .. (err or "unknown error")
    end
    
    return backup_path
end

-- Create a test file
fs.write_file("/tmp/important_data.txt", "This is important data!")

-- Create a backup
local backup_path, err = backup_file("/tmp/important_data.txt", "/tmp/backups")
if not backup_path then
    print("Backup failed: " .. (err or "unknown error"))
    return
end

print("Backup created: " .. backup_path)

-- Modify the original file
fs.write_file("/tmp/important_data.txt", "This is updated important data!")

-- Create another backup
local second_backup, err = backup_file("/tmp/important_data.txt", "/tmp/backups")
if second_backup then
    print("Second backup created: " .. second_backup)
end

-- List all backups
local backups, err = fs.find_files("/tmp/backups", "important_data.txt.%d+.bak")
if backups then
    print("\nAll backups:")
    for _, backup in ipairs(backups) do
        print("- " .. backup)
    end
end
```

### Watching for File Changes

```lua
-- Note: This example requires the watch module, which may not be available
-- in all environments. It's provided as a conceptual example.

local fs = require("lib.tools.filesystem")

-- Create a test file to monitor
fs.write_file("/tmp/watched_file.txt", "Initial content")

-- For the file watching example, we'll simulate it with a timer
-- In a real application, you might use a proper file watching library
print("Watching /tmp/watched_file.txt for changes...")
print("(Simulating file changes every few seconds)")

local function process_file_change(file_path)
    local content, err = fs.read_file(file_path)
    if not content then
        print("Error reading changed file: " .. (err or "unknown error"))
        return
    end
    
    print("File changed! New content length: " .. #content)
    
    -- Process the content (in a real app)
    -- For example, you might update a database, trigger a notification, etc.
end

-- Simulate file changes and watching
local function simulate_file_watch()
    -- In a real application, this would be an event-driven system
    local iterations = 3
    
    for i = 1, iterations do
        -- Simulate a file change
        fs.write_file("/tmp/watched_file.txt", "Updated content " .. i)
        
        -- Simulate detecting the change and processing it
        print("\nChange detected iteration " .. i)
        process_file_change("/tmp/watched_file.txt")
        
        -- Wait between changes
        if i < iterations then
            print("Waiting for next change simulation...")
        end
    end
    
    print("\nFile watch simulation complete!")
end

-- Run the simulation
simulate_file_watch()
```

### Working with Binary Files

```lua
local fs = require("lib.tools.filesystem")

-- Create a binary file (simple example)
local binary_data = string.char(0x00, 0x01, 0xFF, 0xFE, 0x7F)
fs.write_file("/tmp/binary_file.bin", binary_data)

-- Read binary file back
local content, err = fs.read_file("/tmp/binary_file.bin")
if not content then
    print("Error reading binary file: " .. (err or "unknown error"))
    return
end

-- Print the binary content as hex
print("Binary content (hex):")
for i = 1, #content do
    local byte = string.byte(content, i)
    io.write(string.format("%02X ", byte))
end
print("\n")

-- Work with a more complex binary format (simplified example)
local function create_binary_record(id, name, age)
    -- Create a simple binary record format:
    -- 4 bytes: ID (as a 32-bit integer)
    -- 1 byte: name length
    -- N bytes: name characters
    -- 1 byte: age
    
    local result = ""
    
    -- Add ID (as 4 bytes, big-endian)
    result = result .. string.char(
        bit.band(bit.rshift(id, 24), 0xFF),
        bit.band(bit.rshift(id, 16), 0xFF),
        bit.band(bit.rshift(id, 8), 0xFF),
        bit.band(id, 0xFF)
    )
    
    -- Add name length and name
    result = result .. string.char(#name) .. name
    
    -- Add age
    result = result .. string.char(age)
    
    return result
end

-- Note: The above function requires the bit library, which might not be available
-- in all Lua environments. If you're running this code and get an error,
-- you can replace it with a simpler binary format or use a different approach.

-- For demonstration purposes, let's create a simpler binary record format:
local function create_simple_binary_record(id, name, age)
    -- Format: id:name:age with colons as separators
    return id .. ":" .. name .. ":" .. age
end

-- Create multiple records
local records = {
    create_simple_binary_record(1, "Alice", 30),
    create_simple_binary_record(2, "Bob", 25),
    create_simple_binary_record(3, "Charlie", 35)
}

-- Combine records into a single file
fs.write_file("/tmp/records.bin", table.concat(records, "\n"))

-- Read and parse records
local records_data, err = fs.read_file("/tmp/records.bin")
if not records_data then
    print("Error reading records: " .. (err or "unknown error"))
    return
end

print("Parsed records:")
for line in records_data:gmatch("[^\r\n]+") do
    local id, name, age = line:match("(%d+):([^:]+):(%d+)")
    print(string.format("ID: %s, Name: %s, Age: %s", id, name, age))
end
```

### Searching for Content in Files

```lua
local fs = require("lib.tools.filesystem")

-- Create sample files with content
fs.create_directory("/tmp/search_examples")
fs.write_file("/tmp/search_examples/file1.txt", "This file contains the word apple in it.")
fs.write_file("/tmp/search_examples/file2.txt", "This file contains the word banana in it.")
fs.write_file("/tmp/search_examples/file3.txt", "This file contains both apple and banana.")

-- Function to search for text in files
local function search_files_for_text(directory, text)
    -- Get all files in the directory
    local files, err = fs.list_files_recursive(directory)
    if not files then
        return nil, "Failed to list files: " .. (err or "unknown error")
    end
    
    local matches = {}
    
    for _, file_path in ipairs(files) do
        local content, err = fs.read_file(file_path)
        if content then
            -- Check if the file contains the search text
            if content:find(text, 1, true) then
                table.insert(matches, {
                    path = file_path,
                    name = fs.get_file_name(file_path)
                })
            end
        end
    end
    
    return matches
end

-- Search for files containing "apple"
local apple_matches, err = search_files_for_text("/tmp/search_examples", "apple")
if not apple_matches then
    print("Search failed: " .. (err or "unknown error"))
    return
end

print("Files containing 'apple':")
for _, match in ipairs(apple_matches) do
    print("- " .. match.path)
end

-- Search for files containing "banana"
local banana_matches, err = search_files_for_text("/tmp/search_examples", "banana")
if banana_matches then
    print("\nFiles containing 'banana':")
    for _, match in ipairs(banana_matches) do
        print("- " .. match.path)
    end
end

-- Count occurrences of a word in files
local function count_word_occurrences(directory, word)
    local files, err = fs.list_files_recursive(directory)
    if not files then
        return nil, "Failed to list files: " .. (err or "unknown error")
    end
    
    local results = {}
    local total_count = 0
    
    for _, file_path in ipairs(files) do
        local content, err = fs.read_file(file_path)
        if content then
            -- Count occurrences of the word
            local count = 0
            local pos = 1
            while true do
                pos = content:find(word, pos, true)
                if not pos then break end
                count = count + 1
                pos = pos + #word
            end
            
            if count > 0 then
                results[file_path] = count
                total_count = total_count + count
            end
        end
    end
    
    return results, total_count
end

-- Count occurrences of "apple" and "banana"
local apple_counts, apple_total = count_word_occurrences("/tmp/search_examples", "apple")
local banana_counts, banana_total = count_word_occurrences("/tmp/search_examples", "banana")

print("\nOccurrence counts:")
print("'apple' appears " .. apple_total .. " times")
print("'banana' appears " .. banana_total .. " times")

print("\nDetailed counts:")
for file_path, count in pairs(apple_counts) do
    print("- " .. fs.get_file_name(file_path) .. ": " .. count .. " occurrences of 'apple'")
end
```

## Integration with Error Handling

### Using Filesystem Module with Error Handler

```lua
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

-- Safe file read with error handler
local function safe_read_file(file_path)
    local success, result, err = error_handler.try(function()
        local content, read_err = fs.read_file(file_path)
        if not content then
            error(error_handler.io_error(
                "Failed to read file",
                {file_path = file_path, original_error = read_err}
            ))
        end
        return content
    end)
    
    if not success then
        return nil, result  -- result contains the error object in failure case
    end
    
    return result  -- result contains the content in success case
end

-- Safe file write with error handler
local function safe_write_file(file_path, content)
    local success, result, err = error_handler.try(function()
        local ok, write_err = fs.write_file(file_path, content)
        if not ok then
            error(error_handler.io_error(
                "Failed to write file",
                {file_path = file_path, original_error = write_err}
            ))
        end
        return true
    end)
    
    if not success then
        return nil, result  -- result contains the error object in failure case
    end
    
    return true
end

-- Example using the safe functions
local content, err = safe_read_file("/non/existent/file.txt")
if not content then
    print("Error category: " .. err.category)
    print("Error message: " .. err.message)
    print("Error context: " .. require("lib.tools.json").encode(err.context))
end

-- Write content safely
local success, err = safe_write_file("/tmp/safe_write_example.txt", "Safely written content")
if success then
    print("File written safely!")
else
    print("Write error: " .. err.message)
end
```

## Logging Integration

### Using Filesystem Module with Logging

```lua
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")

-- Configure logging for filesystem operations
logging.configure_module("filesystem", {
    level = logging.LEVELS.DEBUG
})

local logger = logging.get_logger("filesystem_example")

-- Perform file operations with logging
logger.info("Starting file operations example")

-- Create a directory
local success, err = fs.create_directory("/tmp/logging_example")
if not success then
    logger.error("Failed to create directory", {
        path = "/tmp/logging_example",
        error = err
    })
else
    logger.debug("Created directory successfully", {
        path = "/tmp/logging_example"
    })
    
    -- Write a file
    success, err = fs.write_file("/tmp/logging_example/test.txt", "Test content")
    if not success then
        logger.error("Failed to write file", {
            path = "/tmp/logging_example/test.txt",
            error = err
        })
    else
        logger.info("Wrote file successfully", {
            path = "/tmp/logging_example/test.txt",
            size = #"Test content"
        })
        
        -- Read the file
        local content, read_err = fs.read_file("/tmp/logging_example/test.txt")
        if not content then
            logger.error("Failed to read file", {
                path = "/tmp/logging_example/test.txt",
                error = read_err
            })
        else
            logger.debug("Read file successfully", {
                path = "/tmp/logging_example/test.txt",
                content_length = #content
            })
        end
    end
end

logger.info("File operations example complete")
```

## Working with Cross-Platform Paths

### Path Normalization Across Platforms

```lua
local fs = require("lib.tools.filesystem")

-- Show how the same paths are normalized on different platforms
print("Path normalization examples:\n")

-- Windows-style paths normalized to cross-platform format
local win_paths = {
    "C:\\Users\\name\\Documents\\file.txt",
    "..\\relative\\path",
    "C:\\Program Files\\App\\",
    "\\\\server\\share\\file.txt"  -- UNC path
}

print("Windows-style paths normalized:")
for _, path in ipairs(win_paths) do
    print(path .. " -> " .. fs.normalize_path(path))
end

-- Unix-style paths normalized
local unix_paths = {
    "/home/user/documents/file.txt",
    "../relative/path",
    "/usr/local//bin/",      -- with double slashes
    "/home/user/./downloads" -- with current directory
}

print("\nUnix-style paths normalized:")
for _, path in ipairs(unix_paths) do
    print(path .. " -> " .. fs.normalize_path(path))
end

-- Path joining across platforms
print("\nPath joining examples:")

local base_paths = {
    "/home/user",
    "C:\\Users\\name",
    "/var/log/"
}

local sub_paths = {
    "documents/file.txt",
    "pictures",
    "../downloads/file.zip"
}

for _, base in ipairs(base_paths) do
    for _, sub in ipairs(sub_paths) do
        local joined = fs.join_paths(base, sub)
        print(base .. " + " .. sub .. " -> " .. joined)
    end
end
```

## Implementing a Simple Config System

### Reading and Writing Configuration Files

```lua
local fs = require("lib.tools.filesystem")
local json = require("lib.tools.json") -- Assuming a JSON module is available

-- Simple configuration system
local config_system = {}

-- Get the config directory
function config_system.get_config_dir()
    -- Use platform-specific locations
    if package.config:sub(1,1) == '\\' then
        -- Windows
        return fs.join_paths(os.getenv("APPDATA"), "MyApp")
    else
        -- Unix-like
        return fs.join_paths(os.getenv("HOME"), ".config", "myapp")
    end
end

-- Load configuration
function config_system.load_config(config_name)
    local config_dir = config_system.get_config_dir()
    local config_path = fs.join_paths(config_dir, config_name .. ".json")
    
    -- Check if the config file exists
    if not fs.file_exists(config_path) then
        return nil, "Config file does not exist: " .. config_path
    end
    
    -- Read the config file
    local content, err = fs.read_file(config_path)
    if not content then
        return nil, "Failed to read config: " .. (err or "unknown error")
    end
    
    -- Parse the JSON content
    local success, result = pcall(json.decode, content)
    if not success then
        return nil, "Failed to parse config: " .. tostring(result)
    end
    
    return result
end

-- Save configuration
function config_system.save_config(config_name, config_data)
    local config_dir = config_system.get_config_dir()
    
    -- Ensure the config directory exists
    local success, err = fs.ensure_directory_exists(config_dir)
    if not success then
        return nil, "Failed to create config directory: " .. (err or "unknown error")
    end
    
    -- Convert data to JSON
    local success, json_str = pcall(json.encode, config_data)
    if not success then
        return nil, "Failed to encode config: " .. tostring(json_str)
    end
    
    -- Save the config file
    local config_path = fs.join_paths(config_dir, config_name .. ".json")
    success, err = fs.write_file(config_path, json_str)
    if not success then
        return nil, "Failed to write config: " .. (err or "unknown error")
    end
    
    return true
end

-- Example usage
local app_config = {
    username = "user123",
    theme = "dark",
    recent_files = {
        "/path/to/file1.txt",
        "/path/to/file2.txt"
    },
    window = {
        width = 800,
        height = 600
    }
}

-- Save the config
local success, err = config_system.save_config("settings", app_config)
if not success then
    print("Failed to save config: " .. (err or "unknown error"))
else
    print("Config saved successfully!")
    
    -- Load the config back
    local loaded_config, load_err = config_system.load_config("settings")
    if not loaded_config then
        print("Failed to load config: " .. (load_err or "unknown error"))
    else
        print("Config loaded successfully!")
        print("Username: " .. loaded_config.username)
        print("Theme: " .. loaded_config.theme)
        print("Recent files count: " .. #loaded_config.recent_files)
        print("Window dimensions: " .. loaded_config.window.width .. "x" .. loaded_config.window.height)
    end
end
```

## Advanced Uses in Testing Contexts

### Creating Test Directory Structures

```lua
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")

-- Helper to create a test directory structure with files
local function create_test_directory_structure(base_dir, structure)
    -- Ensure base directory exists
    fs.ensure_directory_exists(base_dir)
    
    -- Create directories and files based on the structure
    for path, content in pairs(structure) do
        local full_path = fs.join_paths(base_dir, path)
        
        -- If content is a table, it represents a directory with nested items
        if type(content) == "table" then
            fs.ensure_directory_exists(full_path)
            create_test_directory_structure(full_path, content)
        else
            -- Ensure parent directory exists
            local parent_dir = fs.get_directory_name(full_path)
            fs.ensure_directory_exists(parent_dir)
            
            -- Write file with content
            fs.write_file(full_path, content)
        end
    end
    
    return base_dir
end

-- Create a temporary test directory
local test_dir, err = temp_file.create_temp_directory()
if not test_dir then
    print("Failed to create test directory: " .. tostring(err))
    return
end

-- Define a test project structure
local test_structure = {
    ["README.md"] = "# Test Project",
    ["src"] = {
        ["main.lua"] = "print('Hello, World!')",
        ["utils"] = {
            ["string.lua"] = "local M = {}\nfunction M.trim(s)\n  return s:match('^%s*(.-)%s*$')\nend\nreturn M",
            ["math.lua"] = "local M = {}\nfunction M.add(a, b)\n  return a + b\nend\nreturn M"
        }
    },
    ["tests"] = {
        ["main_test.lua"] = "describe('Main', function()\n  it('works', function()\n    expect(true).to.be_truthy()\n  end)\nend)",
        ["utils"] = {
            ["string_test.lua"] = "describe('String utils', function()\n  it('trims whitespace', function()\n    local string = require('src.utils.string')\n    expect(string.trim(' test ')).to.equal('test')\n  end)\nend)"
        }
    },
    [".firmo-config.lua"] = "return {\n  coverage = {\n    include = {'src/**/*.lua'},\n    exclude = {}\n  }\n}"
}

-- Create the test structure
create_test_directory_structure(test_dir, test_structure)

-- Now let's list what we created
local function list_directory_tree(dir, indent)
    indent = indent or 0
    local indent_str = string.rep("  ", indent)
    
    local items = fs.get_directory_contents(dir)
    for _, item in ipairs(items) do
        local full_path = fs.join_paths(dir, item)
        if fs.is_directory(full_path) then
            print(indent_str .. "+ " .. item .. "/")
            list_directory_tree(full_path, indent + 1)
        else
            local size = fs.get_file_size(full_path) or 0
            print(indent_str .. "- " .. item .. " (" .. size .. " bytes)")
        end
    end
end

print("Created test project structure at: " .. test_dir)
print("Directory structure:")
list_directory_tree(test_dir)

-- Clean up when done
temp_file.cleanup_test_context()
```

### Using a Test Directory Context in Testing

```lua
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")

-- Create a test helper to manage test directories
local test_helper = {}

-- Create a temporary test directory with files
function test_helper.with_temp_dir(structure, callback)
    local test_dir, err = temp_file.create_temp_directory()
    if not test_dir then
        error("Failed to create test directory: " .. tostring(err))
    end
    
    -- Register the directory for cleanup
    temp_file.register_directory(test_dir)
    
    -- Keep track of files we create
    local created_files = {}
    
    -- Create files from the structure
    for path, content in pairs(structure) do
        local full_path = fs.join_paths(test_dir, path)
        
        -- Ensure parent directory exists
        local parent_dir = fs.get_directory_name(full_path)
        fs.ensure_directory_exists(parent_dir)
        
        -- Write the file
        local success, err = fs.write_file(full_path, content)
        if not success then
            error("Failed to create test file " .. path .. ": " .. (err or "unknown error"))
        end
        
        created_files[path] = full_path
    end
    
    -- Call the callback with the test directory context
    local success, result = pcall(callback, test_dir, created_files)
    
    -- Clean up will happen automatically thanks to temp_file registration
    
    -- Re-throw any errors from the callback
    if not success then
        error(result)
    end
    
    return result
end

-- Example test
print("Running test with temporary directory context...")

test_helper.with_temp_dir({
    ["config.json"] = '{"setting": "value"}',
    ["data/input.txt"] = "Input data for test",
    ["data/expected.txt"] = "Expected output"
}, function(dir_path, files)
    print("Test running in directory: " .. dir_path)
    
    -- Access the config file
    local config_content = fs.read_file(files["config.json"])
    print("Config content: " .. config_content)
    
    -- Access the data files
    local input_content = fs.read_file(files["data/input.txt"])
    local expected_content = fs.read_file(files["data/expected.txt"])
    
    print("Input: " .. input_content)
    print("Expected: " .. expected_content)
    
    -- In a real test, we would process the input and compare with expected
    local actual_output = input_content .. " (processed)"
    
    -- Create an output file
    local output_path = fs.join_paths(dir_path, "data/output.txt")
    fs.write_file(output_path, actual_output)
    
    print("Output written to: " .. output_path)
    
    -- Test cleanup happens automatically
    print("Test completed, directory will be cleaned up automatically")
    
    return true -- Test result
end)
```

## Working with File Systems in CI/CD Pipelines

### Detecting and Operating in CI Environments

```lua
local fs = require("lib.tools.filesystem")

-- Helper to detect if running in a CI environment
local function is_ci_environment()
    -- Check common CI environment variables
    return os.getenv("CI") == "true" or
           os.getenv("GITHUB_ACTIONS") or
           os.getenv("GITLAB_CI") or
           os.getenv("TRAVIS") or
           os.getenv("JENKINS_URL")
end

-- Get appropriate paths based on environment
local function get_environment_paths()
    local paths = {}
    
    if is_ci_environment() then
        -- In CI environment, use absolute paths
        paths.output_dir = "/tmp/ci-output"
        paths.cache_dir = "/tmp/ci-cache"
        paths.report_dir = "/tmp/ci-reports"
    else
        -- In development environment, use relative paths
        paths.output_dir = "./build"
        paths.cache_dir = "./.cache"
        paths.report_dir = "./reports"
    end
    
    return paths
end

-- Ensure CI directories exist
local function setup_ci_directories()
    local paths = get_environment_paths()
    
    -- Create directories
    for name, path in pairs(paths) do
        local success, err = fs.ensure_directory_exists(path)
        if not success then
            print("Failed to create " .. name .. " directory: " .. (err or "unknown error"))
            return false
        end
    end
    
    return true, paths
end

-- Example CI/CD pipeline function
local function run_pipeline_task(task_name, artifacts)
    print("Running task: " .. task_name)
    
    -- Set up directories
    local success, paths = setup_ci_directories()
    if not success then
        print("Failed to set up CI directories")
        return false
    end
    
    -- Generate an artifact file
    local artifact_path = fs.join_paths(paths.output_dir, task_name .. "-output.txt")
    local success, err = fs.write_file(artifact_path, "Task result: " .. task_name .. "\n" .. 
                                                    "Generated: " .. os.date() .. "\n" ..
                                                    "Artifacts: " .. table.concat(artifacts, ", "))
    if not success then
        print("Failed to write artifact: " .. (err or "unknown error"))
        return false
    end
    
    -- Generate a report
    local report_path = fs.join_paths(paths.report_dir, task_name .. "-report.json")
    local report_content = string.format([[
    {
        "task": "%s",
        "status": "success",
        "timestamp": %d,
        "artifacts": ["%s"]
    }
    ]], task_name, os.time(), artifact_path)
    
    success, err = fs.write_file(report_path, report_content)
    if not success then
        print("Failed to write report: " .. (err or "unknown error"))
        return false
    end
    
    print("Task completed successfully")
    print("Artifact: " .. artifact_path)
    print("Report: " .. report_path)
    
    return true
end

-- Simulate running a CI/CD pipeline
print("Detecting environment: " .. (is_ci_environment() and "CI" or "Development"))
run_pipeline_task("build", {"app.exe", "lib.dll"})
run_pipeline_task("test", {"test-results.xml"})
```

## Performance Optimization Techniques

### Smart File Operations for Large Files

```lua
local fs = require("lib.tools.filesystem")

-- Create a large file for demonstration
local function create_large_file(path, size_mb)
    print("Creating a " .. size_mb .. "MB file at " .. path)
    
    -- Open file for writing
    local file, err = io.open(path, "wb")
    if not file then
        print("Failed to create file: " .. (err or "unknown error"))
        return false
    end
    
    -- Write data in chunks to avoid memory issues
    local chunk_size = 1024 * 1024  -- 1MB chunks
    local chunk = string.rep("X", chunk_size)
    
    for i = 1, size_mb do
        file:write(chunk)
        if i % 10 == 0 then
            print("  Wrote " .. i .. "MB...")
        end
    end
    
    file:close()
    print("File created successfully")
    return true
end

-- Process a large file line by line (memory efficient)
local function process_large_file_by_line(path, callback)
    print("Processing file line by line: " .. path)
    
    local file, err = io.open(path, "r")
    if not file then
        print("Failed to open file: " .. (err or "unknown error"))
        return false
    end
    
    local line_count = 0
    for line in file:lines() do
        line_count = line_count + 1
        callback(line, line_count)
    end
    
    file:close()
    print("Processed " .. line_count .. " lines")
    return true
end

-- Process a large file in chunks (memory efficient)
local function process_large_file_by_chunks(path, chunk_size, callback)
    print("Processing file in chunks: " .. path)
    
    local file, err = io.open(path, "rb")
    if not file then
        print("Failed to open file: " .. (err or "unknown error"))
        return false
    end
    
    local total_bytes = 0
    while true do
        local chunk = file:read(chunk_size)
        if not chunk then break end
        
        total_bytes = total_bytes + #chunk
        callback(chunk, total_bytes)
    end
    
    file:close()
    print("Processed " .. total_bytes .. " bytes")
    return true
end

-- Create a smaller test file (1MB) for the example
local test_file = "/tmp/large_file_test.txt"
create_large_file(test_file, 1)  -- 1MB

-- Get file size
local size, err = fs.get_file_size(test_file)
if size then
    print("File size: " .. size .. " bytes")
end

-- Process the file line by line (good for text files)
process_large_file_by_line(test_file, function(line, line_number)
    -- In a real application, you would process each line
    -- For this example, we'll just count lines
    if line_number % 10000 == 0 then
        print("  Processed " .. line_number .. " lines...")
    end
end)

-- Process the file in chunks (good for binary files)
process_large_file_by_chunks(test_file, 1024 * 1024, function(chunk, total_bytes)
    -- In a real application, you would process each chunk
    -- For this example, we'll just count bytes
    print("  Processed chunk, total bytes: " .. total_bytes)
end)

-- Clean up
fs.delete_file(test_file)
```

This comprehensive set of examples demonstrates the wide range of capabilities provided by the Firmo filesystem module, from basic file operations to advanced use cases in testing, CI/CD, and performance optimization scenarios.