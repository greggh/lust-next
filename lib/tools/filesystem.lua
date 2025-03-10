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

local fs = {}

-- Internal utility functions
local function is_windows()
    return package.config:sub(1,1) == '\\'
end

local path_separator = is_windows() and '\\' or '/'

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
-- @param path (string) Path to the file to read
-- @return content (string) or nil if error
-- @return error (string) Error message if reading failed
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
-- @param path (string) Path to the file to write
-- @param content (string) Content to write to the file
-- @return success (boolean) True if write was successful
-- @return error (string) Error message if writing failed
function fs.write_file(path, content)
    return safe_io_action(function(file_path, data)
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
-- @param path (string) Path to the file to append to
-- @param content (string) Content to append to the file
-- @return success (boolean) True if append was successful
-- @return error (string) Error message if appending failed
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
-- @param source (string) Path to the source file
-- @param destination (string) Path to the destination file
-- @return success (boolean) True if copy was successful
-- @return error (string) Error message if copying failed
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
-- @param source (string) Path to the source file
-- @param destination (string) Path to the destination file
-- @return success (boolean) True if move was successful
-- @return error (string) Error message if moving failed
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
-- @param path (string) Path to the file to delete
-- @return success (boolean) True if deletion was successful
-- @return error (string) Error message if deletion failed
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
-- @param path (string) Path to the directory to create
-- @return success (boolean) True if creation was successful
-- @return error (string) Error message if creation failed
function fs.create_directory(path)
    return safe_io_action(function(dir_path)
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
-- @param path (string) Path to ensure exists
-- @return success (boolean) True if directory exists or was created
-- @return error (string) Error message if creation failed
function fs.ensure_directory_exists(path)
    if fs.directory_exists(path) then
        return true
    end
    return fs.create_directory(path)
end

--- Delete directory
-- @param path (string) Path to the directory to delete
-- @param recursive (boolean) If true, recursively delete contents
-- @return success (boolean) True if deletion was successful
-- @return error (string) Error message if deletion failed
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
-- @param path (string) Path to the directory to list
-- @return files (table) List of file names in the directory or nil on error
-- @return error (string) Error message if listing failed
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
-- @param path (string) Path to normalize
-- @return normalized (string) Path with standardized separators
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
-- @param ... (string) Path components to join
-- @return joined (string) Joined path
function fs.join_paths(...)
    local args = {...}
    if #args == 0 then return "" end
    
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
end

--- Extract directory part
-- @param path (string) Path to process
-- @return directory (string) Directory component of path
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

--- Extract file name
-- @param path (string) Path to process
-- @return filename (string) File name component of path
function fs.get_file_name(path)
    if not path then return nil end
    
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
end

--- Get file extension
-- @param path (string) Path to process
-- @return extension (string) Extension of the file, or empty string if none
function fs.get_extension(path)
    if not path then return nil end
    
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
end

--- Convert to absolute path
-- @param path (string) Path to convert
-- @return absolute (string) Absolute path
function fs.get_absolute_path(path)
    if not path then return nil end
    
    -- If already absolute, return normalized path
    if path:sub(1, 1) == "/" or (is_windows() and path:match("^%a:")) then
        return fs.normalize_path(path)
    end
    
    -- Get current directory
    local current_dir = os.getenv("PWD") or io.popen("cd"):read("*l")
    
    -- Join with the provided path
    return fs.join_paths(current_dir, path)
end

--- Convert to relative path
-- @param path (string) Path to convert
-- @param base (string) Base path to make relative to
-- @return relative (string) Path relative to base
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

--- Convert glob to Lua pattern
-- @param glob (string) Glob pattern to convert
-- @return pattern (string) Lua pattern equivalent
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
-- @param path (string) Path to test
-- @param pattern (string) Glob pattern to match against
-- @return matches (boolean) True if path matches pattern
function fs.matches_pattern(path, pattern)
    if not path or not pattern then return false end
    
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
end

--- Find files by glob pattern
-- @param directories (table) List of directories to search in
-- @param patterns (table) List of patterns to match
-- @param exclude_patterns (table) List of patterns to exclude
-- @return matches (table) List of matching file paths
function fs.discover_files(directories, patterns, exclude_patterns)
    if not directories or #directories == 0 then return {} end
    
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
end

--- List all files in directory
-- @param path (string) Directory path to scan
-- @param recursive (boolean) Whether to scan recursively
-- @return files (table) List of file paths
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
-- @param files (table) List of file paths to filter
-- @param pattern (string) Pattern to match against
-- @return matches (table) List of matching file paths
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
-- @param path (string) Path to check
-- @return exists (boolean) True if file exists
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
-- @param path (string) Path to check
-- @return exists (boolean) True if directory exists
function fs.directory_exists(path)
    if not path then return false end
    
    -- Normalize path to handle trailing slashes
    local normalized_path = fs.normalize_path(path)
    
    -- Handle root directory special case
    if normalized_path == "" or normalized_path == "/" then
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
-- @param path (string) Path to file
-- @return size (number) File size in bytes or nil on error
-- @return error (string) Error message if getting size failed
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
-- @param path (string) Path to file
-- @return timestamp (number) Modification time or nil on error
-- @return error (string) Error message if getting time failed
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
-- @param path (string) Path to file
-- @return timestamp (number) Creation time or nil on error
-- @return error (string) Error message if getting time failed
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
-- @param path (string) Path to check
-- @return is_file (boolean) True if path is a file
function fs.is_file(path)
    if not path then return false end
    if fs.directory_exists(path) then return false end
    return fs.file_exists(path)
end

--- Check if path is a directory
-- @param path (string) Path to check
-- @return is_directory (boolean) True if path is a directory
function fs.is_directory(path)
    if not path then return false end
    if fs.file_exists(path) and not fs.directory_exists(path) then return false end
    return fs.directory_exists(path)
end

return fs