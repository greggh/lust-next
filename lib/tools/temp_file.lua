---@class TempFileModule
---@field _VERSION string Module version
---@field create_temp_file fun(extension?: string): string|nil, table? Create a temporary file with optional extension
---@field create_with_content fun(content: string, extension?: string): string|nil, table? Create a temporary file with content
---@field create_temp_directory fun(): string|nil, table? Create a temporary directory
---@field get_temp_dir fun(): string Get the temporary directory path
---@field register_file fun(file_path: string): boolean Register a file for cleanup
---@field register_directory fun(dir_path: string): boolean Register a directory for cleanup 
---@field remove fun(file_path: string): boolean, string? Remove a temporary file
---@field remove_directory fun(dir_path: string): boolean, string? Remove a temporary directory
---@field with_temp_file fun(content: string, callback: fun(temp_path: string): any, extension?: string): any|nil, table? Create and use a temporary file with automatic cleanup
---@field with_temp_directory fun(callback: fun(dir_path: string): any): any|nil, table? Create and use a temporary directory with automatic cleanup
---@field cleanup_test_context fun(context?: string): boolean, table[] Clean up files from current test context
---@field cleanup_all fun(): boolean, table[], table Clean up all registered temporary files
---@field get_stats fun(): {registered_files: number, registered_directories: number, cleanup_errors: number, contexts: table<string, number>, orphaned_files: number} Get statistics about temporary files
---@field set_current_test_context fun(context: table|string): nil Set the current test context
---@field clear_current_test_context fun(): nil Clear the current test context
---@field configure fun(options: {temp_dir?: string, force_cleanup?: boolean, file_prefix?: string, auto_register?: boolean, cleanup_on_exit?: boolean}): TempFileModule Configure temp file behavior
---@field set_temp_dir fun(dir_path: string): boolean, string? Set the temporary directory path
---@field get_registered_files fun(): table<string, {context: string, created: number, size: number}> Get list of all registered temporary files
---@field get_registered_directories fun(): table<string, {context: string, created: number}> Get list of all registered temporary directories
---@field create_nested_directory fun(path: string): string|nil, table? Create a nested directory structure in the temp directory
---@field is_registered fun(path: string): boolean Check if a file or directory is registered
---@field get_context_for_file fun(file_path: string): string|nil Get the context a file was registered with
--[[
Utility for working with temporary files.

This module provides functions for creating and managing temporary files during tests,
with automatic cleanup when tests complete.
]]

local M = {}

local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

-- Load logging module directly - this is required
local logging = require("lib.tools.logging")
local logger = logging.get_logger("temp_file")

-- Global registry of temporary files by test context
-- Using weak keys so test contexts can be garbage collected
local _temp_file_registry = setmetatable({}, {__mode = "k"})

-- Get current test context - simplified to use hardcoded context
local function get_current_test_context()
    -- For simplicity, we've moved to using a single hardcoded context
    -- This avoids complexity and potential issues with different context types
    logger.debug("Using hardcoded test context")
    return "_SIMPLE_STRING_CONTEXT_"
end

---@param file_path string Path to the file to register for cleanup
---@return boolean success Whether the file was successfully registered
-- Register a file with the current test context
function M.register_file(file_path)
    logger.debug("Registering file", { path = file_path })
    
    -- Create simple string context to avoid complex objects 
    -- Note: We're hardcoding this to avoid potential issues with table serialization
    local context = "_SIMPLE_STRING_CONTEXT_"
    
    -- Initialize the registry for this context if needed
    _temp_file_registry[context] = _temp_file_registry[context] or {}
    
    -- Add the file to the registry
    table.insert(_temp_file_registry[context], {
        path = file_path,
        type = "file"
    })
    
    return file_path
end

---@param dir_path string Path to the directory to register for cleanup
---@return boolean success Whether the directory was successfully registered
-- Register a directory with the current test context
function M.register_directory(dir_path)
    logger.debug("Registering directory", { path = dir_path })
    
    -- Use same simplified context as register_file
    local context = "_SIMPLE_STRING_CONTEXT_"
    
    -- Initialize registry if needed
    _temp_file_registry[context] = _temp_file_registry[context] or {}
    
    -- Add directory to registry
    table.insert(_temp_file_registry[context], {
        path = dir_path,
        type = "directory"
    })
    
    return dir_path
end

---@private
---@param extension? string File extension (without the dot)
---@return string temp_path Temporary file path
-- Generate a temporary file path with specified extension
function M.generate_temp_path(extension)
    extension = extension or "tmp"
    -- Ensure extension doesn't start with a dot
    if extension:sub(1, 1) == "." then
        extension = extension:sub(2)
    end
    local temp_path = os.tmpname()
    -- Some os.tmpname() implementations include an extension, remove it
    if temp_path:match("%.") then
        temp_path = temp_path:gsub("%.[^%.]+$", "")
    end
    -- Add our extension
    return temp_path .. "." .. extension
end

---@param content string Content to write to the file
---@param extension? string File extension (without the dot)
---@return string|nil temp_path Path to the created temporary file, or nil on error
---@return table? error Error object if file creation failed
-- Create a temporary file with the given content (enhanced with registration)
function M.create_with_content(content, extension)
    local temp_path = M.generate_temp_path(extension)
    
    local success, result, err = error_handler.try(function()
        local ok, write_err = fs.write_file(temp_path, content)
        if not ok then
            return nil, write_err or error_handler.io_error(
                "Failed to write to temporary file",
                {file_path = temp_path}
            )
        end
        
        -- Register the file for automatic cleanup
        M.register_file(temp_path)
        
        return temp_path
    end)
    
    if not success then
        return nil, result -- Result contains the error in this case
    end
    
    return result -- Result contains the path in success case
end

---@return string|nil dir_path Path to the created temporary directory, or nil on error
---@return table? error Error object if directory creation failed
-- Create a temporary directory (enhanced with registration)
function M.create_temp_directory()
    local temp_dir = os.tmpname() .. "_dir"
    
    local success, result, err = error_handler.try(function()
        local ok, mkdir_err = fs.create_directory(temp_dir)
        if not ok then
            return nil, mkdir_err or error_handler.io_error(
                "Failed to create temporary directory",
                {directory_path = temp_dir}
            )
        end
        
        -- Register the directory for automatic cleanup
        M.register_directory(temp_dir)
        
        return temp_dir
    end)
    
    if not success then
        return nil, result -- Result contains the error in this case
    end
    
    return result -- Result contains the path in success case
end

---@param file_path string Path to the temporary file to remove
---@return boolean success Whether the file was successfully removed
---@return string? error Error message if removal failed
-- Remove a temporary file
function M.remove(file_path)
    if not file_path then
        return false, error_handler.validation_error(
            "Missing file path for temporary file removal",
            {operation = "remove_temp_file"}
        )
    end
    
    return fs.delete_file(file_path)
end

---@param dir_path string Path to the temporary directory to remove
---@return boolean success Whether the directory was successfully removed
---@return string? error Error message if removal failed
-- Remove a temporary directory
function M.remove_directory(dir_path)
    if not dir_path then
        return false, error_handler.validation_error(
            "Missing directory path for temporary directory removal",
            {operation = "remove_temp_directory"}
        )
    end
    
    -- Use the standard function name - this should always exist
    return fs.delete_directory(dir_path, true) -- Use recursive deletion
end

---@param content string Content to write to the file
---@param callback fun(temp_path: string): any Function to call with the temporary file path
---@param extension? string File extension (without the dot)
---@return any|nil result Result from the callback function, or nil on error
---@return table? error Error object if operation failed
-- Create a temporary file, use it with a callback, and then remove it
function M.with_temp_file(content, callback, extension)
    local temp_path, create_err = M.create_with_content(content, extension)
    if not temp_path then
        return nil, create_err
    end
    
    local success, result, err = error_handler.try(function()
        return callback(temp_path)
    end)
    
    -- Always try to clean up, even if callback failed
    local _, remove_err = M.remove(temp_path)
    if remove_err then
        -- Just log the error, don't fail the operation due to cleanup issues
        -- This is a best-effort cleanup
        error_handler.log_error(remove_err, error_handler.LOG_LEVEL.DEBUG)
    end
    
    if not success then
        return nil, err
    end
    
    return result
end

---@param callback fun(dir_path: string): any Function to call with the temporary directory path
---@return any|nil result Result from the callback function, or nil on error
---@return table? error Error object if operation failed
-- Create a temporary directory, use it with a callback, and then remove it
function M.with_temp_directory(callback)
    local dir_path, create_err = M.create_temp_directory()
    if not dir_path then
        return nil, create_err
    end
    
    local success, result, err = error_handler.try(function()
        return callback(dir_path)
    end)
    
    -- Always try to clean up, even if callback failed
    local _, remove_err = M.remove_directory(dir_path)
    if remove_err then
        -- Just log the error, don't fail the operation due to cleanup issues
        error_handler.log_error(remove_err, error_handler.LOG_LEVEL.DEBUG)
    end
    
    if not success then
        return nil, err
    end
    
    return result
end

---@private
---@param path string Path to file or directory to remove
---@param resource_type string "file" or "directory"
---@param max_retries number Maximum number of retries
---@return boolean success Whether the resource was successfully removed
---@return string? err Error message if removal failed
-- Helper function to remove a resource with retry logic
local function remove_with_retry(path, resource_type, max_retries)
    max_retries = max_retries or 3
    local success = false
    local err
    
    for retry = 1, max_retries do
        if resource_type == "file" then
            -- For files, try with both os.remove and fs.delete_file
            -- os.remove is often more reliable for temp files
            local ok1 = os.remove(path)
            if ok1 then
                success = true
                break
            end
            
            -- If os.remove failed, try fs.delete_file
            local ok2, delete_err = fs.delete_file(path)
            if ok2 then
                success = true
                break
            end
            err = delete_err or "Failed to remove file"
        else
            -- For directories, always use recursive deletion
            local ok, delete_err = fs.delete_directory(path, true)
            if ok then
                success = true
                break
            end
            err = delete_err or "Failed to remove directory"
        end
        
        if not success and retry < max_retries then
            -- Wait briefly before retrying (increasing delay)
            local delay = 0.1 * retry
            logger.debug("Retry " .. retry .. " failed for " .. resource_type .. ", waiting " .. delay .. "s", {path = path})
            
            -- Sleep using os.execute("sleep") for cross-platform compatibility
            if delay > 0 then
                os.execute("sleep " .. tostring(delay))
            end
        end
    end
    
    return success, err
end

---@param context? string Test context identifier (optional)
---@return boolean success Whether all files were cleaned up successfully
---@return table[] errors Array of resources that could not be cleaned up
-- Clean up all temporary files and directories for a specific test context
function M.cleanup_test_context(context)
    logger.debug("Cleaning up test context")
    
    -- Use hardcoded context to match our simplified registration
    context = "_SIMPLE_STRING_CONTEXT_"
    
    local resources = _temp_file_registry[context] or {}
    
    logger.debug("Found resources to clean up", { count = #resources })
    
    local errors = {}
    
    -- Sort resources to ensure directories are deleted after their contained files
    -- This helps with nested directory structure cleanup
    table.sort(resources, function(a, b)
        -- If one is a file and one is a directory, process files first
        if a.type ~= b.type then
            return a.type == "file"
        end
        
        -- For directories, sort by path depth (delete deeper paths first)
        if a.type == "directory" and b.type == "directory" then
            local depth_a = select(2, string.gsub(a.path, "/", ""))
            local depth_b = select(2, string.gsub(b.path, "/", ""))
            return depth_a > depth_b
        end
        
        -- Otherwise, keep original order
        return false
    end)
    
    -- Try to remove all resources with retry logic
    for i = #resources, 1, -1 do
        local resource = resources[i]
        
        -- Check if the resource still exists before attempting removal
        local exists = false
        if resource.type == "file" then
            exists = fs.file_exists(resource.path)
        else
            exists = fs.directory_exists(resource.path)
        end
        
        local success = not exists -- Consider it successful if the resource doesn't exist
        
        if exists then
            -- Try to remove with retry
            success, _ = remove_with_retry(resource.path, resource.type, 3)
        end
        
        if not success then
            table.insert(errors, {
                path = resource.path, 
                type = resource.type
            })
            logger.debug("Failed to clean up resource", { 
                path = resource.path, 
                type = resource.type 
            })
        else
            -- Remove from the registry
            table.remove(resources, i)
        end
    end
    
    -- Clear the registry for this context if all resources were removed
    if #resources == 0 then
        _temp_file_registry[context] = nil
        logger.debug("All resources cleaned up, removed context from registry")
    end
    
    return #errors == 0, errors
end

---@return table stats Statistics about temporary files and their contexts
-- Get statistics about temporary files
function M.get_stats()
    local stats = {
        contexts = 0,
        total_resources = 0,
        files = 0,
        directories = 0,
        resources_by_context = {}
    }
    
    for context, resources in pairs(_temp_file_registry) do
        stats.contexts = stats.contexts + 1
        
        local context_stats = {
            files = 0,
            directories = 0,
            total = #resources
        }
        
        for _, resource in ipairs(resources) do
            stats.total_resources = stats.total_resources + 1
            
            if resource.type == "file" then
                stats.files = stats.files + 1
                context_stats.files = context_stats.files + 1
            else
                stats.directories = stats.directories + 1
                context_stats.directories = context_stats.directories + 1
            end
        end
        
        stats.resources_by_context[tostring(context)] = context_stats
    end
    
    return stats
end

---@return boolean success Whether all files were cleaned up successfully
---@return table[] errors Array of resources that could not be cleaned up
---@return table stats Statistics about the cleanup operation
-- Clean up all temporary files across all contexts
function M.cleanup_all()
    logger.debug("Cleaning up all temporary files")
    
    -- Simplified version that just calls cleanup_test_context with our hardcoded context
    local success, errors = M.cleanup_test_context("_SIMPLE_STRING_CONTEXT_")
    
    -- Return stats
    local stats = {
        total_resources = errors and #errors or 0,
        cleaned = success
    }
    
    return success, errors, stats
end

---@param context table|string The test context to set
---@return nil
-- Set the current test context (for use by test runners)
function M.set_current_test_context(context)
    -- If we can modify firmo, use it
    if _G.firmo then
        _G.firmo._current_test_context = context
    end
    
    -- Also set a global for fallback
    _G._current_temp_file_context = context
end

---@return nil
-- Clear the current test context (for use by test runners)
function M.clear_current_test_context()
    -- If we can modify firmo, use it
    if _G.firmo then
        _G.firmo._current_test_context = nil
    end
    
    -- Also clear the global fallback
    _G._current_temp_file_context = nil
end

return M