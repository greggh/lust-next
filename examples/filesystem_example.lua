--[[
    filesystem_example.lua - Example usage of the filesystem module

    This example demonstrates the key features of the filesystem module,
    including file operations, directory management, path manipulation,
    and file discovery.

    Run this example with:
    lua examples/filesystem_example.lua
]]

local fs = require("lib.tools.filesystem")

print("Filesystem Module Example")
print("-----------------------\n")

-- Set up a test directory structure
local base_dir = "/tmp/fs-example"
local nested_dir = fs.join_paths(base_dir, "nested/deep")
local example_file = fs.join_paths(base_dir, "example.txt")
local example_content = "This is example content for testing the filesystem module."

-- Clean up previous runs
if fs.directory_exists(base_dir) then
    print("Cleaning up previous test directory...")
    fs.delete_directory(base_dir, true)
end

-- 1. Directory Operations
print("1. Directory Operations")
print("----------------------")

print("Creating directory: " .. nested_dir)
local success = fs.create_directory(nested_dir)
print("Directory created: " .. tostring(success))

print("Directory exists: " .. tostring(fs.directory_exists(nested_dir)))
print("")

-- 2. File Operations
print("2. File Operations")
print("-----------------")

-- Write a file
print("Writing file: " .. example_file)
success = fs.write_file(example_file, example_content)
print("File written: " .. tostring(success))

-- Read a file
print("\nReading file: " .. example_file)
local content = fs.read_file(example_file)
print("File content: " .. content)

-- Copy a file
local copy_file = fs.join_paths(nested_dir, "copy.txt")
print("\nCopying file to: " .. copy_file)
success = fs.copy_file(example_file, copy_file)
print("File copied: " .. tostring(success))

-- Append to a file
print("\nAppending to file: " .. example_file)
local append_text = "\nThis text was appended."
success = fs.append_file(example_file, append_text)
print("Content appended: " .. tostring(success))

-- Read the modified file
content = fs.read_file(example_file)
print("Updated content: " .. content)

-- Move a file
local moved_file = fs.join_paths(base_dir, "moved.txt")
print("\nMoving copy to: " .. moved_file)
success = fs.move_file(copy_file, moved_file)
print("File moved: " .. tostring(success))
print("")

-- 3. Path Manipulation
print("3. Path Manipulation")
print("-------------------")

-- Normalize paths
print("Original path: /path//to/./file/../target/")
local normalized = fs.normalize_path("/path//to/./file/../target/")
print("Normalized: " .. normalized)

-- Join paths
print("\nJoining paths: '/base' + 'sub/dir' + './file.txt'")
local joined = fs.join_paths("/base", "sub/dir", "./file.txt")
print("Joined: " .. joined)

-- Extract components
print("\nPath components for: " .. example_file)
print("Directory: " .. fs.get_directory_name(example_file))
print("Filename: " .. fs.get_file_name(example_file))
print("Extension: " .. fs.get_extension(example_file))

-- Relative paths
print("\nRelative path from '" .. base_dir .. "' to '" .. nested_dir .. "'")
local rel_path = fs.get_relative_path(nested_dir, base_dir)
print("Relative: " .. rel_path)
print("")

-- 4. File Discovery
print("4. File Discovery")
print("-----------------")

-- Create some additional files for discovery testing
fs.write_file(fs.join_paths(base_dir, "file1.lua"), "-- Test file 1")
fs.write_file(fs.join_paths(base_dir, "file2.lua"), "-- Test file 2")
fs.write_file(fs.join_paths(nested_dir, "file3.lua"), "-- Test file 3")
fs.write_file(fs.join_paths(nested_dir, "other.txt"), "Other file")

-- Scan directory
print("Scanning base directory (non-recursive):")
local files = fs.scan_directory(base_dir, false)
for i, file in ipairs(files) do
    print("  " .. i .. ". " .. file)
end

-- Recursive scan
print("\nScanning base directory (recursive):")
files = fs.scan_directory(base_dir, true)
for i, file in ipairs(files) do
    print("  " .. i .. ". " .. file)
end

-- Discover specific files
print("\nDiscovering Lua files:")
local lua_files = fs.discover_files({base_dir}, {"*.lua"})
for i, file in ipairs(lua_files) do
    print("  " .. i .. ". " .. file)
end

-- 5. File Information
print("\n5. File Information")
print("------------------")

-- File size
local size = fs.get_file_size(example_file)
print("Size of " .. example_file .. ": " .. size .. " bytes")

-- Modification time
local mod_time = fs.get_modified_time(example_file)
print("Last modified: " .. os.date("%Y-%m-%d %H:%M:%S", mod_time))

print("\nCleaning up example files...")
fs.delete_directory(base_dir, true)
print("Done!")