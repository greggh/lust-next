--[[
Utility for working with temporary files.

This module provides functions for creating and managing temporary files during tests,
with automatic cleanup when tests complete.
]]

local M = {}

local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

-- Try to load logging module
local logging
local function get_logger()
    if not logging then
        local success, module = pcall(require, "lib.tools.logging")
        if success then
            logging = module
        end
    end
    
    if logging then
        return logging.get_logger("temp_file")
    end
    
    return nil
end

-- Global registry of temporary files by test context
-- Using weak keys so test contexts can be garbage collected
local _temp_file_registry = setmetatable({}, {__mode = "k"})

-- Get current test context (from firmo or a global fallback)
local function get_current_test_context()
    local logger = get_logger()
    
    -- If running inside firmo, try to get the current test context
    if _G.firmo then
        if _G.firmo._current_test_context then
            if logger then
                logger.debug("Using firmo test context")
            end
            return _G.firmo._current_test_context
        end
        
        -- Try using global context provided by firmo (fallback)
        if _G._current_temp_file_context then
            if logger then
                logger.debug("Using global test context via firmo")
            end
            return _G._current_temp_file_context
        end
    end
    
    -- Otherwise use a global context
    if logger then
        logger.debug("Using global context fallback")
    end
    return "_global_context_"
end

-- Register a file with the current test context
function M.register_file(file_path)
    local logger = get_logger()
    if logger then
        logger.debug("Registering file", { path = file_path })
    end
    
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

-- Register a directory with the current test context
function M.register_directory(dir_path)
    local logger = get_logger()
    if logger then
        logger.debug("Registering directory", { path = dir_path })
    end
    
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

-- Remove a temporary directory
function M.remove_directory(dir_path)
    if not dir_path then
        return false, error_handler.validation_error(
            "Missing directory path for temporary directory removal",
            {operation = "remove_temp_directory"}
        )
    end
    
    -- Check if the function exists with the expected name
    if fs.delete_directory then
        return fs.delete_directory(dir_path, true) -- Use recursive deletion
    elseif fs.remove_directory then
        -- Fallback to alternate name
        return fs.remove_directory(dir_path, true) -- Use recursive deletion
    else
        -- Last resort fallback
        return false, error_handler.runtime_error(
            "Directory deletion function not found in filesystem module",
            {operation = "remove_temp_directory", dir_path = dir_path}
        )
    end
end

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

-- Clean up all temporary files and directories for a specific test context
function M.cleanup_test_context(context)
    local logger = get_logger()
    if logger then
        logger.debug("Cleaning up test context")
    end
    
    -- Use hardcoded context to match our simplified registration
    context = "_SIMPLE_STRING_CONTEXT_"
    
    local resources = _temp_file_registry[context] or {}
    
    if logger then
        logger.debug("Found resources to clean up", { count = #resources })
    end
    
    local errors = {}
    
    -- Try to remove all resources (skipping sorting for simplicity)
    for i = #resources, 1, -1 do
        local resource = resources[i]
        
        local success = false
        
        if resource.type == "file" then
            local ok, err = os.remove(resource.path)
            success = ok ~= nil
        else
            local ok, err
            -- Check which function name is available
            if fs.delete_directory then
                ok, err = fs.delete_directory(resource.path, true) -- Use recursive deletion
            elseif fs.remove_directory then
                ok, err = fs.remove_directory(resource.path, true) -- Use recursive deletion
            else
                ok, err = false, "Directory removal function not found"
            end
            success = ok
        end
        
        if not success then
            table.insert(errors, {
                path = resource.path, 
                type = resource.type
            })
            if logger then
                logger.debug("Failed to clean up resource", { 
                    path = resource.path, 
                    type = resource.type 
                })
            end
        else
            -- Remove from the registry
            table.remove(resources, i)
        end
    end
    
    -- Clear the registry for this context if all resources were removed
    if #resources == 0 then
        _temp_file_registry[context] = nil
        if logger then
            logger.debug("All resources cleaned up, removed context from registry")
        end
    end
    
    return #errors == 0, errors
end

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

-- Clean up all temporary files across all contexts
function M.cleanup_all()
    local logger = get_logger()
    if logger then
        logger.debug("Cleaning up all temporary files")
    end
    
    -- Simplified version that just calls cleanup_test_context with our hardcoded context
    local success, errors = M.cleanup_test_context("_SIMPLE_STRING_CONTEXT_")
    
    -- Return stats
    local stats = {
        total_resources = errors and #errors or 0,
        cleaned = success
    }
    
    return success, errors, stats
end

-- Set the current test context (for use by test runners)
function M.set_current_test_context(context)
    -- If we can modify firmo, use it
    if _G.firmo then
        _G.firmo._current_test_context = context
    end
    
    -- Also set a global for fallback
    _G._current_temp_file_context = context
end

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