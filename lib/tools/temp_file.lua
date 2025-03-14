--[[
Utility for working with temporary files.
]]

local M = {}

local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

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

-- Create a temporary file with the given content
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
        return temp_path
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

return M