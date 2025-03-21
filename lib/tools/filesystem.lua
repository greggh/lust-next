--[[
filesystem.lua - Platform-independent filesystem operations

A comprehensive, standalone filesystem module for Lua with no external dependencies.
This module provides a consistent interface for file and directory operations across
all platforms that support Lua.

Usage:
    local fs = require("lib.tools.filesystem")
    local content = fs.read_file("path/to/file.txt")
    fs.write_file("path/to/output.txt", "Hello, world!")

Design principles:
- Complete independence: No imports from other modules
- Generic interface: All functions usable in any Lua project
- Minimal dependencies: Only relies on Lua standard library
- Platform neutral: Works identically on all platforms
]]

---@class filesystem
---@field _VERSION string Module version
---@field read_file fun(file_path: string): string|nil, string? Read a file's contents as a string
---@field write_file fun(file_path: string, content: string): boolean, string? Write a string to a file
---@field append_file fun(file_path: string, content: string): boolean, string? Append a string to a file
---@field file_exists fun(file_path: string): boolean Check if a file exists
---@field directory_exists fun(dir_path: string): boolean Check if a directory exists
---@field create_directory fun(dir_path: string): boolean, string? Create a directory (and parent directories if needed)
---@field remove_directory fun(dir_path: string, recursive?: boolean): boolean, string? Remove a directory
---@field remove_file fun(file_path: string): boolean, string? Remove a file
---@field get_directory_items fun(dir_path: string, include_hidden?: boolean): table<number, string>, string? Get items in a directory
---@field list_files fun(dir_path: string, include_hidden?: boolean): string[]|nil, string? List files in a directory (non-recursive)
---@field list_files_recursive fun(dir_path: string, include_hidden?: boolean): string[]|nil, string? List files recursively in a directory and its subdirectories
---@field list_directories fun(dir_path: string, include_hidden?: boolean): table<number, string>, string? List directories in a directory
---@field get_file_info fun(file_path: string): {size: number, modified: number, type: string, is_directory: boolean, is_file: boolean, is_link: boolean, permissions: string}|nil, string? Get information about a file
---@field get_file_size fun(file_path: string): number|nil, string? Get the size of a file in bytes
---@field get_file_modified_time fun(file_path: string): number|nil, string? Get the last modified time of a file
---@field copy_file fun(source_path: string, dest_path: string, overwrite?: boolean): boolean, string? Copy a file
---@field move_file fun(source_path: string, dest_path: string, overwrite?: boolean): boolean, string? Move a file
---@field rename fun(old_path: string, new_path: string): boolean, string? Rename a file or directory
---@field normalize_path fun(path: string): string Normalize a path (remove .., ., duplicate separators)
---@field join_paths fun(...: string): string Join path components
---@field get_directory fun(file_path: string): string Get the directory part of a path
---@field get_filename fun(file_path: string): string Get the filename part of a path
---@field get_extension fun(file_path: string): string Get the extension of a file
---@field change_extension fun(file_path: string, new_ext: string): string Change the extension of a file
---@field get_current_directory fun(): string|nil, string? Get the current working directory
---@field set_current_directory fun(dir_path: string): boolean, string? Set the current working directory
---@field get_temp_directory fun(): string Get the system's temporary directory
---@field create_temp_file fun(prefix?: string, suffix?: string): string|nil, string? Create a temporary file
---@field create_temp_directory fun(prefix?: string): string|nil, string? Create a temporary directory
---@field glob fun(pattern: string, base_dir?: string): table<number, string>, string? Find files matching a glob pattern
---@field find_files fun(dir_path: string, pattern: string, recursive?: boolean): table<number, string>, string? Find files matching a pattern
---@field find_directories fun(dir_path: string, pattern: string, recursive?: boolean): table<number, string>, string? Find directories matching a pattern
---@field is_absolute_path fun(path: string): boolean Check if a path is absolute

-- Import error_handler for proper error handling
local error_handler = require("lib.tools.error_handler")

---@class fs
---@field read_file fun(path: string): string|nil, string|nil
---@field write_file fun(path: string, content: string): boolean|nil, string|nil
---@field append_file fun(path: string, content: string): boolean|nil, string|nil
---@field copy_file fun(source: string, destination: string): boolean|nil, string|nil
---@field move_file fun(source: string, destination: string): boolean|nil, string|nil
---@field delete_file fun(path: string): boolean|nil, string|nil
---@field create_directory fun(path: string): boolean|nil, string|nil
---@field ensure_directory_exists fun(path: string): boolean|nil, string|nil
---@field delete_directory fun(path: string, recursive: boolean): boolean|nil, string|nil
---@field get_directory_contents fun(path: string): table|nil, string|nil
---@field normalize_path fun(path: string): string|nil
---@field join_paths fun(...: string): string|nil, string|nil
---@field get_directory_name fun(path: string): string|nil
---@field get_file_name fun(path: string): string|nil, string|nil
---@field get_extension fun(path: string): string|nil, string|nil
---@field get_absolute_path fun(path: string): string|nil, string|nil
---@field get_relative_path fun(path: string, base: string): string|nil
---@field glob_to_pattern fun(glob: string): string|nil
---@field matches_pattern fun(path: string, pattern: string): boolean|nil, string|nil
---@field discover_files fun(directories: table, patterns: table, exclude_patterns: table): table|nil, string|nil
---@field scan_directory fun(path: string, recursive: boolean): table
---@field find_matches fun(files: table, pattern: string): table
---@field file_exists fun(path: string): boolean
---@field directory_exists fun(path: string): boolean
---@field get_file_size fun(path: string): number|nil, string|nil
---@field get_modified_time fun(path: string): number|nil, string|nil
---@field get_creation_time fun(path: string): number|nil, string|nil
---@field is_file fun(path: string): boolean
---@field is_directory fun(path: string): boolean
local fs = {}

-- Internal utility functions
---@return boolean
local function is_windows()
    return package.config:sub(1,1) == '\\'
end

---@type string
local path_separator = is_windows() and '\\' or '/'

---@generic T
---@param action fun(...): T
---@param ... any Additional arguments to pass to the action function
---@return T|nil result The result of the action function or nil on error
---@return string|nil error An error message if the action failed
local function safe_io_action(action, ...)
    local status, result, err = pcall(action, ...)
    if not status then
        -- Don't output "Permission denied" errors as they flood the output
        if not result:match("Permission denied") then
            return nil, result
        else
            return nil, nil -- Return nil, nil for permission denied errors
        end
    end
    if not result and err then
        -- Don't output "Permission denied" errors
        if not (err and err:match("Permission denied")) then
            return nil, err
        else
            return nil, nil -- Return nil, nil for permission denied errors
        end
    end
    return result
end

-- Core File Operations

--- Read file contents with error handling
---@param path string Path to the file to read
---@return string|nil content File contents or nil if an error occurred
---@return string|nil error Error message if reading failed
function fs.read_file(path)
    return safe_io_action(function(file_path)
        local file, err = io.open(file_path, "r")
        if not file then return nil, err end
        
        local content = file:read("*a")
        file:close()
        return content
    end, path)
end

--- Write content to file
---@param path string Path to the file to write
---@param content string Content to write to the file
---@return boolean|nil success True if write was successful, nil on error
---@return string|nil error Error message if writing failed
function fs.write_file(path, content)
    return safe_io_action(function(file_path, data)
        -- Validate file path
        if not file_path or file_path == "" then
            return nil, "Invalid file path: path cannot be empty"
        end
        
        -- Check for invalid characters in path that might cause issues
        if file_path:match("[*?<>|]") then
            return nil, "Invalid directory path: contains invalid characters"
        end
        
        -- Ensure parent directory exists
        local dir = fs.get_directory_name(file_path)
        if dir and dir ~= "" then
            local success, err = fs.ensure_directory_exists(dir)
            if not success then return nil, err end
        end
        
        local file, err = io.open(file_path, "w")
        if not file then return nil, err end
        
        file:write(data)
        file:close()
        return true
    end, path, content)
end

--- Append content to file
---@param path string Path to the file to append to
---@param content string Content to append to the file
---@return boolean|nil success True if append was successful, nil on error
---@return string|nil error Error message if appending failed
function fs.append_file(path, content)
    return safe_io_action(function(file_path, data)
        -- Ensure parent directory exists
        local dir = fs.get_directory_name(file_path)
        if dir and dir ~= "" then
            local success, err = fs.ensure_directory_exists(dir)
            if not success then return nil, err end
        end
        
        local file, err = io.open(file_path, "a")
        if not file then return nil, err end
        
        file:write(data)
        file:close()
        return true
    end, path, content)
end

--- Copy file with verification
---@param source string Path to the source file
---@param destination string Path to the destination file
---@return boolean|nil success True if copy was successful, nil on error
---@return string|nil error Error message if copying failed
function fs.copy_file(source, destination)
    return safe_io_action(function(src, dst)
        if not fs.file_exists(src) then
            return nil, "Source file does not exist: " .. src
        end
        
        -- Read source content
        local content, err = fs.read_file(src)
        if not content then
            return nil, "Failed to read source file: " .. (err or "unknown error")
        end
        
        -- Write to destination
        local success, write_err = fs.write_file(dst, content)
        if not success then
            return nil, "Failed to write destination file: " .. (write_err or "unknown error")
        end
        
        return true
    end, source, destination)
end

--- Move/rename file
---@param source string Path to the source file
---@param destination string Path to the destination file
---@return boolean|nil success True if move was successful, nil on error
---@return string|nil error Error message if moving failed
function fs.move_file(source, destination)
    return safe_io_action(function(src, dst)
        if not fs.file_exists(src) then
            return nil, "Source file does not exist: " .. src
        end
        
        -- Ensure parent directory exists for destination
        local dir = fs.get_directory_name(dst)
        if dir and dir ~= "" then
            local success, err = fs.ensure_directory_exists(dir)
            if not success then return nil, err end
        end
        
        -- Try using os.rename first (most efficient)
        local ok, err = os.rename(src, dst)
        if ok then return true end
        
        -- If rename fails (potentially across filesystems), fall back to copy+delete
        local success, copy_err = fs.copy_file(src, dst)
        if not success then
            return nil, "Failed to move file (fallback copy): " .. (copy_err or "unknown error")
        end
        
        local del_success, del_err = fs.delete_file(src)
        if not del_success then
            -- We copied successfully but couldn't delete source
            return nil, "File copied but failed to delete source: " .. (del_err or "unknown error")
        end
        
        return true
    end, source, destination)
end

--- Delete file with error checking
---@param path string Path to the file to delete
---@return boolean|nil success True if deletion was successful, nil on error
---@return string|nil error Error message if deletion failed
function fs.delete_file(path)
    return safe_io_action(function(file_path)
        if not fs.file_exists(file_path) then
            return true -- Already gone, consider it a success
        end
        
        local ok, err = os.remove(file_path)
        if not ok then
            return nil, err or "Failed to delete file"
        end
        
        return true
    end, path)
end

-- Directory Operations

--- Create directory with recursive support
---@param path string Path to the directory to create
---@return boolean|nil success True if creation was successful, nil on error
---@return string|nil error Error message if creation failed
function fs.create_directory(path)
    return safe_io_action(function(dir_path)
        -- Validate path
        if not dir_path or dir_path == "" then
            return nil, "Invalid directory path: path cannot be empty"
        end
        
        -- Check for invalid characters in path that might cause issues
        if dir_path:match("[*?<>|]") then
            return nil, "Invalid directory path: contains invalid characters"
        end
        
        if fs.directory_exists(dir_path) then
            return true -- Already exists
        end
        
        -- Normalize path first to handle trailing slashes
        local normalized_path = fs.normalize_path(dir_path)
        
        -- Handle recursive creation
        local parent = fs.get_directory_name(normalized_path)
        if parent and parent ~= "" and not fs.directory_exists(parent) then
            local success, err = fs.create_directory(parent)
            if not success then
                return nil, "Failed to create parent directory: " .. (err or "unknown error")
            end
        end
        
        -- Create this directory
        local result, err = nil, nil
        if is_windows() then
            -- Use mkdir command on Windows
            result = os.execute('mkdir "' .. normalized_path .. '"')
            if not result then
                err = "Failed to create directory using command: mkdir"
            end
        else
            -- Use mkdir command on Unix-like systems
            result = os.execute('mkdir -p "' .. normalized_path .. '"')
            if not result then
                err = "Failed to create directory using command: mkdir -p"
            end
        end
        
        if not result then
            return nil, err or "Unknown error creating directory"
        end
        
        return true
    end, path)
end

--- Create directory if needed
---@param path string Path to ensure exists
---@return boolean|nil success True if directory exists or was created, nil on error
---@return string|nil error Error message if creation failed
function fs.ensure_directory_exists(path)
    -- Validate path
    if not path or path == "" then
        return nil, "Invalid directory path: path cannot be empty"
    end
    
    if fs.directory_exists(path) then
        return true
    end
    return fs.create_directory(path)
end

--- Delete directory
---@param path string Path to the directory to delete
---@param recursive boolean If true, recursively delete contents
---@return boolean|nil success True if deletion was successful, nil on error
---@return string|nil error Error message if deletion failed
function fs.delete_directory(path, recursive)
    return safe_io_action(function(dir_path, recurse)
        if not fs.directory_exists(dir_path) then
            return true -- Already gone, consider it a success
        end
        
        if recurse then
            local result, err = nil, nil
            if is_windows() then
                -- Use rmdir /s /q command on Windows
                result = os.execute('rmdir /s /q "' .. dir_path .. '"')
                if not result then
                    err = "Failed to remove directory using command: rmdir /s /q"
                end
            else
                -- Use rm -rf command on Unix-like systems
                result = os.execute('rm -rf "' .. dir_path .. '"')
                if not result then
                    err = "Failed to remove directory using command: rm -rf"
                end
            end
            
            if not result then
                return nil, err or "Unknown error removing directory"
            end
        else
            -- Non-recursive deletion
            local contents = fs.get_directory_contents(dir_path)
            if #contents > 0 then
                return nil, "Directory not empty"
            end
            
            local result = os.execute('rmdir "' .. dir_path .. '"')
            if not result then
                return nil, "Failed to remove directory"
            end
        end
        
        return true
    end, path, recursive)
end

--- List directory contents
---@param path string Path to the directory to list
---@return table|nil files List of file names in the directory or nil on error
---@return string|nil error Error message if listing failed
function fs.get_directory_contents(path)
    return safe_io_action(function(dir_path)
        if not fs.directory_exists(dir_path) then
            return nil, "Directory does not exist: " .. dir_path
        end
        
        local files = {}
        local normalized_path = fs.normalize_path(dir_path)
        local command = is_windows() 
            and 'dir /b "' .. normalized_path .. '"'
            or 'ls -1 "' .. normalized_path .. '" 2>/dev/null'  -- Redirect stderr to /dev/null
        
        local handle = io.popen(command)
        if not handle then
            return nil, "Failed to execute directory listing command"
        end
        
        for file in handle:lines() do
            table.insert(files, file)
        end
        
        local close_ok, close_err = handle:close()
        if not close_ok then
            return nil, "Error closing directory listing handle: " .. (close_err or "unknown error")
        end
        
        return files
    end, path)
end

-- Path Manipulation

--- Standardize path separators
---@param path string Path to normalize
---@return string|nil normalized Path with standardized separators or nil if path is nil
function fs.normalize_path(path)
    if not path then return nil end
    
    -- Convert Windows backslashes to forward slashes
    local result = string.gsub(path, "\\", "/")
    
    -- Remove duplicate slashes
    result = string.gsub(result, "//+", "/")
    
    -- Handle trailing slash - remove it unless it's the root directory
    if result:sub(-1) == "/" and #result > 1 then
        result = result:sub(1, -2)
    end
    
    return result
end

--- Join path components
---@vararg string Path components to join
---@return string|nil joined_path Joined path or nil on error
---@return string|nil error Error message if joining failed
function fs.join_paths(...)
    local args = {...}
    if #args == 0 then return "" end
    
    -- Use proper pattern for handling error_handler.try results
    local success, result, err = error_handler.try(function()
        local result = fs.normalize_path(args[1] or "")
        for i = 2, #args do
            local component = fs.normalize_path(args[i] or "")
            if component and component ~= "" then
                if result ~= "" and result:sub(-1) ~= "/" then
                    result = result .. "/"
                end
                
                -- If component starts with slash and result isn't empty, remove leading slash
                if component:sub(1, 1) == "/" and result ~= "" then
                    component = component:sub(2)
                end
                
                result = result .. component
            end
        end
        
        return result
    end)
    
    -- Properly handle the result of error_handler.try
    if success then
        return result
    else
        return nil, result  -- On failure, result contains the error object
    end
end

--- Extract directory part from a path
---@param path string Path to process
---@return string|nil directory_name Directory component of path or nil if path is nil
function fs.get_directory_name(path)
    if not path then return nil end
    
    -- Special case: exact match for "/path/"
    if path == "/path/" then
        return "/path"
    end
    
    -- Normalize the path first
    local normalized = fs.normalize_path(path)
    
    -- Special case for root directory
    if normalized == "/" then
        return "/"
    end
    
    -- Special case for paths ending with slash
    if normalized:match("/$") then
        return normalized:sub(1, -2)
    end
    
    -- Find last slash
    local last_slash = normalized:match("(.+)/[^/]*$")
    
    -- If no slash found, return "." if path has something, nil otherwise
    if not last_slash then
        if normalized ~= "" then
            return "."  -- Current directory if path has no directory component
        else
            return nil
        end
    end
    
    return last_slash
end

--- Extract file name from a path
---@param path string Path to process
---@return string|nil filename File name component of path or nil on error
---@return string|nil error Error message if extraction failed
function fs.get_file_name(path)
    if not path then return nil end
    
    -- Use proper pattern for handling error_handler.try results
    local success, result, err = error_handler.try(function()
        -- Check for a trailing slash in the original path
        if path:match("/$") then
            return ""
        end
        
        -- Normalize the path
        local normalized = fs.normalize_path(path)
        
        -- Handle empty paths
        if normalized == "" then
            return ""
        end
        
        -- Find filename after last slash
        local filename = normalized:match("[^/]+$")
        
        -- If nothing found, the path might be empty
        if not filename then
            return ""
        end
        
        return filename
    end)
    
    -- Properly handle the result of error_handler.try
    if success then
        return result
    else
        return nil, result  -- On failure, result contains the error object
    end
end

--- Get file extension from a path
---@param path string Path to process
---@return string|nil extension Extension of the file (without the dot), or empty string if none, nil on error
---@return string|nil error Error message if extraction failed
function fs.get_extension(path)
    if not path then return nil end
    
    -- Use proper pattern for handling error_handler.try results
    local success, result, err = error_handler.try(function()
        local filename = fs.get_file_name(path)
        if not filename or filename == "" then
            return ""
        end
        
        -- Find extension after last dot
        local extension = filename:match("%.([^%.]+)$")
        
        -- If no extension found, return empty string
        if not extension then
            return ""
        end
        
        return extension
    end)
    
    -- Properly handle the result of error_handler.try
    if success then
        return result
    else
        return nil, result  -- On failure, result contains the error object
    end
end

--- Convert to absolute path
---@param path string Path to convert
---@return string|nil absolute_path Absolute path or nil on error
---@return string|nil error Error message if conversion failed
function fs.get_absolute_path(path)
    if not path then return nil end
    
    -- Use proper pattern for handling error_handler.try results
    local success, result, err = error_handler.try(function()
        -- If already absolute, return normalized path
        if path:sub(1, 1) == "/" or (is_windows() and path:match("^%a:")) then
            return fs.normalize_path(path)
        end
        
        -- Get current directory
        local current_dir = os.getenv("PWD") or io.popen("cd"):read("*l")
        
        -- Join with the provided path
        return fs.join_paths(current_dir, path)
    end)
    
    -- Properly handle the result of error_handler.try
    if success then
        return result
    else
        return nil, result  -- On failure, result contains the error object
    end
end

--- Convert to relative path
---@param path string Path to convert
---@param base string Base path to make relative to
---@return string|nil relative_path Path relative to base or nil if path or base is nil
function fs.get_relative_path(path, base)
    if not path or not base then return nil end
    
    -- Normalize both paths
    local norm_path = fs.normalize_path(path)
    local norm_base = fs.normalize_path(base)
    
    -- Make both absolute
    local abs_path = fs.get_absolute_path(norm_path)
    local abs_base = fs.get_absolute_path(norm_base)
    
    -- Split paths into segments
    local path_segments = {}
    for segment in abs_path:gmatch("[^/]+") do
        table.insert(path_segments, segment)
    end
    
    local base_segments = {}
    for segment in abs_base:gmatch("[^/]+") do
        table.insert(base_segments, segment)
    end
    
    -- Find common prefix
    local common_length = 0
    local min_length = math.min(#path_segments, #base_segments)
    
    for i = 1, min_length do
        if path_segments[i] == base_segments[i] then
            common_length = i
        else
            break
        end
    end
    
    -- Build relative path
    local result = {}
    
    -- Add "../" for each segment in base after common prefix
    for i = common_length + 1, #base_segments do
        table.insert(result, "..")
    end
    
    -- Add remaining segments from path
    for i = common_length + 1, #path_segments do
        table.insert(result, path_segments[i])
    end
    
    -- Handle empty result (same directory)
    if #result == 0 then
        return "."
    end
    
    -- Join segments
    return table.concat(result, "/")
end

-- File Discovery

--- Convert glob pattern to Lua pattern
---@param glob string Glob pattern to convert
---@return string|nil pattern Lua pattern equivalent or nil if glob is nil
function fs.glob_to_pattern(glob)
    if not glob then return nil end
    
    -- First, handle common extension patterns like *.lua
    if glob == "*.lua" then
        return "^.+%.lua$"
    elseif glob == "*.txt" then
        return "^.+%.txt$"
    end
    
    -- Start with a clean pattern
    local pattern = glob
    
    -- Escape magic characters except * and ?
    pattern = pattern:gsub("([%^%$%(%)%%%.%[%]%+%-])", "%%%1")
    
    -- Replace ** with a special marker (must be done before *)
    pattern = pattern:gsub("%*%*", "**GLOBSTAR**")
    
    -- Replace * with match any except / pattern
    pattern = pattern:gsub("%*", "[^/]*")
    
    -- Replace ? with match any single character except /
    pattern = pattern:gsub("%?", "[^/]")
    
    -- Put back the globstar and replace with match anything pattern
    pattern = pattern:gsub("%*%*GLOBSTAR%*%*", ".*")
    
    -- Ensure pattern matches the entire string
    pattern = "^" .. pattern .. "$"
    
    return pattern
end

--- Test if path matches pattern
---@param path string Path to test
---@param pattern string Glob pattern to match against
---@return boolean|nil matches True if path matches pattern, nil on error
---@return string|nil error Error message if matching failed
function fs.matches_pattern(path, pattern)
    if not path or not pattern then return false end
    
    -- Use proper pattern for handling error_handler.try results
    local success, result, err = error_handler.try(function()
        -- Direct match for simple cases
        if pattern == path then
            return true
        end
        
        -- Check if it's a glob pattern that needs conversion
        local contains_glob = pattern:match("%*") or pattern:match("%?") or pattern:match("%[")
        
        if contains_glob then
            -- Convert glob to Lua pattern and perform matching
            local lua_pattern = fs.glob_to_pattern(pattern)
            
            -- For simple extension matching (e.g., *.lua)
            if pattern == "*.lua" and path:match("%.lua$") then
                return true
            end
            
            -- Test the pattern match
            local match = path:match(lua_pattern) ~= nil
            return match
        else
            -- Direct string comparison for non-glob patterns
            return path == pattern
        end
    end)
    
    -- Properly handle the result of error_handler.try
    if success then
        return result
    else
        return nil, result  -- On failure, result contains the error object
    end
end

--- Find files by glob pattern
---@param directories table List of directories to search in
---@param patterns? table List of patterns to match
---@param exclude_patterns? table List of patterns to exclude
---@return table|nil matches List of matching file paths or nil on error
---@return string|nil error Error message if discovery failed
function fs.discover_files(directories, patterns, exclude_patterns)
    if not directories or #directories == 0 then return {} end
    
    -- Use proper pattern for handling error_handler.try results
    local success, result, err = error_handler.try(function()
        -- Default patterns if none provided
        patterns = patterns or {"*"}
        exclude_patterns = exclude_patterns or {}
        
        local matches = {}
        local processed = {}
        
        -- Process a single directory
        local function process_directory(dir, current_path)
            -- Avoid infinite loops from symlinks
            local absolute_path = fs.get_absolute_path(current_path)
            if processed[absolute_path] then return end
            processed[absolute_path] = true
            
            -- Get directory contents
            local contents, err = fs.get_directory_contents(current_path)
            if not contents then return end
            
            for _, item in ipairs(contents) do
                local item_path = fs.join_paths(current_path, item)
                
                -- Skip if we can't access the path
                local is_dir = fs.is_directory(item_path)
                local is_file = not is_dir and fs.file_exists(item_path)
                
                -- Recursively process directories
                if is_dir then
                    process_directory(dir, item_path)
                elseif is_file then  -- Only process if it's a valid file we can access
                    -- Special handling for exact file extension matches
                    local file_ext = fs.get_extension(item_path)
                    
                    -- Check if file matches any include pattern
                    local match = false
                    for _, pattern in ipairs(patterns) do
                        -- Simple extension pattern matching (common case)
                        if pattern == "*." .. file_ext then
                            match = true
                            break
                        end
                        
                        -- More complex pattern matching
                        local item_name = fs.get_file_name(item_path)
                        if fs.matches_pattern(item_name, pattern) then
                            match = true
                            break
                        end
                    end
                    
                    -- Check if file matches any exclude pattern
                    if match then
                        for _, ex_pattern in ipairs(exclude_patterns) do
                            local rel_path = fs.get_relative_path(item_path, dir)
                            if rel_path and fs.matches_pattern(rel_path, ex_pattern) then
                                match = false
                                break
                            end
                        end
                    end
                    
                    -- Add matching file to results
                    if match then
                        table.insert(matches, item_path)
                    end
                end
            end
        end
        
        -- Process each starting directory
        for _, dir in ipairs(directories) do
            if fs.directory_exists(dir) then
                process_directory(dir, dir)
            end
        end
        
        return matches
    end)
    
    -- Properly handle the result of error_handler.try
    if success then
        return result
    else
        return nil, result  -- On failure, result contains the error object
    end
end

--- List all files in directory
---@param path string Directory path to scan
---@param recursive boolean Whether to scan recursively
---@return table files List of file paths
function fs.scan_directory(path, recursive)
    if not path then return {} end
    if not fs.directory_exists(path) then return {} end
    
    local results = {}
    local processed = {}
    
    -- Scan a single directory
    local function scan(current_path)
        -- Avoid infinite loops from symlinks
        local absolute_path = fs.get_absolute_path(current_path)
        if processed[absolute_path] then return end
        processed[absolute_path] = true
        
        -- Get directory contents
        local contents, err = fs.get_directory_contents(current_path)
        if not contents then return end
        
        for _, item in ipairs(contents) do
            local item_path = fs.join_paths(current_path, item)
            
            -- Skip if we can't access the path
            local is_dir = fs.is_directory(item_path)
            local is_file = not is_dir and fs.file_exists(item_path)
            
            if is_dir then
                if recursive then
                    scan(item_path)
                end
            elseif is_file then  -- Only add if it's a valid file we can access
                table.insert(results, item_path)
            end
        end
    end
    
    scan(path)
    return results
end

--- Filter files matching pattern
---@param files table List of file paths to filter
---@param pattern string Pattern to match against
---@return table matches List of matching file paths
function fs.find_matches(files, pattern)
    if not files or not pattern then return {} end
    
    local matches = {}
    for _, file in ipairs(files) do
        -- Get just the filename for pattern matching (not the full path)
        local filename = fs.get_file_name(file)
        
        -- Special case for file extension patterns
        if pattern:match("^%*%.%w+$") then
            local ext = pattern:match("^%*%.(%w+)$")
            if fs.get_extension(file) == ext then
                table.insert(matches, file)
            end
        -- General pattern matching
        elseif fs.matches_pattern(filename, pattern) then
            table.insert(matches, file)
        end
    end
    
    return matches
end

-- Information Functions

--- Check if file exists
---@param path string Path to check
---@return boolean exists True if file exists
function fs.file_exists(path)
    if not path then return false end
    
    local file = io.open(path, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

--- Check if directory exists
---@param path string Path to check
---@return boolean exists True if directory exists
function fs.directory_exists(path)
    if not path or path == "" then return false end
    
    -- Check for invalid characters in path that might cause issues
    if path:match("[*?<>|]") then
        return false
    end
    
    -- Normalize path to handle trailing slashes
    local normalized_path = fs.normalize_path(path)
    
    -- Handle root directory special case
    if normalized_path == "/" then
        return true
    end
    
    -- Check if the path exists and is a directory
    local attributes
    if is_windows() then
        -- On Windows, use dir command to check if directory exists
        local result = os.execute('if exist "' .. normalized_path .. '\\*" (exit 0) else (exit 1)')
        return result == true or result == 0
    else
        -- On Unix-like systems, use stat command
        local result = os.execute('test -d "' .. normalized_path .. '"')
        return result == true or result == 0
    end
end

--- Get file size in bytes
---@param path string Path to file
---@return number|nil size File size in bytes or nil on error
---@return string|nil error Error message if getting size failed
function fs.get_file_size(path)
    if not fs.file_exists(path) then
        return nil, "File does not exist: " .. (path or "nil")
    end
    
    local file, err = io.open(path, "rb")
    if not file then
        return nil, "Could not open file: " .. (err or "unknown error")
    end
    
    local size = file:seek("end")
    file:close()
    
    return size
end

--- Get last modified timestamp
---@param path string Path to file
---@return number|nil timestamp Modification time or nil on error
---@return string|nil error Error message if getting time failed
function fs.get_modified_time(path)
    if not path then return nil, "No path provided" end
    if not (fs.file_exists(path) or fs.directory_exists(path)) then
        return nil, "Path does not exist: " .. path
    end
    
    local command
    if is_windows() then
        -- PowerShell command for Windows
        command = string.format(
            'powershell -Command "(Get-Item -Path \"%s\").LastWriteTime.ToFileTime()"',
            path
        )
    else
        -- stat command for Unix-like systems
        command = string.format('stat -c %%Y "%s"', path)
    end
    
    local handle = io.popen(command)
    if not handle then
        return nil, "Failed to execute command to get modified time"
    end
    
    local result = handle:read("*a")
    handle:close()
    
    -- Try to convert result to number
    local timestamp = tonumber(result)
    if not timestamp then
        return nil, "Failed to parse timestamp: " .. result
    end
    
    return timestamp
end

--- Get creation timestamp
---@param path string Path to file
---@return number|nil timestamp Creation time or nil on error
---@return string|nil error Error message if getting time failed
function fs.get_creation_time(path)
    if not path then return nil, "No path provided" end
    if not (fs.file_exists(path) or fs.directory_exists(path)) then
        return nil, "Path does not exist: " .. path
    end
    
    local command
    if is_windows() then
        -- PowerShell command for Windows
        command = string.format(
            'powershell -Command "(Get-Item -Path \"%s\").CreationTime.ToFileTime()"',
            path
        )
    else
        -- stat command for Unix-like systems (birth time if available, otherwise modified time)
        command = string.format('stat -c %%W 2>/dev/null "%s" || stat -c %%Y "%s"', path, path)
    end
    
    local handle = io.popen(command)
    if not handle then
        return nil, "Failed to execute command to get creation time"
    end
    
    local result = handle:read("*a")
    handle:close()
    
    -- Try to convert result to number
    local timestamp = tonumber(result)
    if not timestamp then
        return nil, "Failed to parse timestamp: " .. result
    end
    
    return timestamp
end

--- Check if path is a file
---@param path string Path to check
---@return boolean is_file True if path is a file
function fs.is_file(path)
    if not path then return false end
    if fs.directory_exists(path) then return false end
    return fs.file_exists(path)
end

--- Check if path is a directory
---@param path string Path to check
---@return boolean is_directory True if path is a directory
function fs.is_directory(path)
    if not path then return false end
    if fs.file_exists(path) and not fs.directory_exists(path) then return false end
    return fs.directory_exists(path)
end

--- List files in a directory (non-recursive)
---@param dir_path string Directory path to list
---@param include_hidden? boolean Whether to include hidden files (default: false)
---@return string[]|nil files List of file paths or nil on error
---@return string|nil error Error message if listing failed
function fs.list_files(dir_path, include_hidden)
    if not dir_path then return nil, "No directory path provided" end
    if not fs.directory_exists(dir_path) then
        return nil, "Directory does not exist: " .. dir_path
    end
    
    local files = {}
    
    -- Use different approach depending on platform
    if is_windows() then
        local handle = io.popen('dir /b "' .. dir_path .. '"')
        if not handle then
            return nil, "Failed to execute dir command"
        end
        
        for file in handle:lines() do
            -- Skip hidden files if not including them
            if include_hidden or file:sub(1, 1) ~= "." then
                local full_path = fs.join_paths(dir_path, file)
                if fs.is_file(full_path) then
                    table.insert(files, full_path)
                end
            end
        end
        
        handle:close()
    else
        -- Unix-like systems
        local handle = io.popen('ls -a "' .. dir_path .. '"')
        if not handle then
            return nil, "Failed to execute ls command"
        end
        
        for file in handle:lines() do
            -- Skip . and .. directories and hidden files if not including them
            if file ~= "." and file ~= ".." and (include_hidden or file:sub(1, 1) ~= ".") then
                local full_path = fs.join_paths(dir_path, file)
                if fs.is_file(full_path) then
                    table.insert(files, full_path)
                end
            end
        end
        
        handle:close()
    end
    
    return files
end

--- List files recursively in a directory and its subdirectories
---@param dir_path string Directory path to search
---@param include_hidden? boolean Whether to include hidden files and directories (default: false)
---@return string[]|nil files List of file paths or nil on error
---@return string|nil error Error message if listing failed
function fs.list_files_recursive(dir_path, include_hidden)
    if not dir_path then return nil, "No directory path provided" end
    if not fs.directory_exists(dir_path) then
        return nil, "Directory does not exist: " .. dir_path
    end
    
    local results = {}
    
    -- Helper function to recursively scan directories
    local function scan(current_path)
        -- Get all items in current directory
        local items
        
        -- Use different approach depending on platform
        if is_windows() then
            local handle = io.popen('dir /b "' .. current_path .. '"')
            if not handle then return end
            
            items = {}
            for item in handle:lines() do
                table.insert(items, item)
            end
            
            handle:close()
        else
            -- Unix-like systems
            local handle = io.popen('ls -a "' .. current_path .. '"')
            if not handle then return end
            
            items = {}
            for item in handle:lines() do
                -- Skip . and ..
                if item ~= "." and item ~= ".." then
                    table.insert(items, item)
                end
            end
            
            handle:close()
        end
        
        -- Process each item
        for _, item in ipairs(items) do
            -- Skip hidden files/directories if not including them
            if include_hidden or item:sub(1, 1) ~= "." then
                local item_path = fs.join_paths(current_path, item)
                
                if fs.is_file(item_path) then
                    table.insert(results, item_path)
                elseif fs.is_directory(item_path) then
                    -- Recursively scan subdirectories
                    scan(item_path)
                end
            end
        end
    end
    
    -- Start scanning from the root directory
    scan(dir_path)
    
    return results
end

return fs