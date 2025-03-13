-- Version module for lust-next
-- Single source of truth for the project version

-- This file is used by other components like documentation generators,
-- package managers, and release scripts to determine the current version.

-- Should follow semantic versioning: MAJOR.MINOR.PATCH
-- See https://semver.org/ for more details

-- Require error handler for comprehensive error handling
local error_handler
local error_handler_loaded, error_handler_module = pcall(require, "lib.tools.error_handler")
if error_handler_loaded then
  error_handler = error_handler_module
else
  -- Simple fallback in case error_handler can't be loaded (should never happen in normal operation)
  error_handler = {
    validation_error = function(msg) error(msg) end,
    format_error = function(err) return tostring(err) end
  }
end

-- Initialize logging (optional, will be nil if not available)
local logging
local log
pcall(function()
  logging = require("lib.tools.logging")
  if logging then
    log = logging.get_logger("core.version")
  end
end)

local M = {}

-- Individual version components
M.major = 0
M.minor = 7
M.patch = 3

-- Combined semantic version
M.string = string.format("%d.%d.%d", M.major, M.minor, M.patch)

-- Version parsing function with error handling
-- @param version_string (string) Version string to parse
-- @return parsed_version (table|nil) Table with major, minor, patch components or nil on error
-- @return error (table|nil) Error object if operation failed
function M.parse(version_string)
  -- Parameter validation
  if version_string == nil then
    local err = error_handler.validation_error(
      "Version string cannot be nil",
      { function_name = "version.parse" }
    )
    if log then
      log.debug("version.parse validation failed", {
        error = error_handler.format_error(err)
      })
    end
    return nil, err
  end
  
  if type(version_string) ~= "string" then
    local err = error_handler.validation_error(
      "Version string must be a string",
      { 
        function_name = "version.parse",
        provided_type = type(version_string)
      }
    )
    if log then
      log.debug("version.parse validation failed", {
        error = error_handler.format_error(err),
        provided_type = type(version_string)
      })
    end
    return nil, err
  end
  
  -- Parse semantic version
  local major, minor, patch = version_string:match("^(%d+)%.(%d+)%.(%d+)$")
  if not (major and minor and patch) then
    local err = error_handler.validation_error(
      "Invalid version format, must be MAJOR.MINOR.PATCH",
      { 
        function_name = "version.parse",
        provided_version = version_string,
        expected_format = "MAJOR.MINOR.PATCH"
      }
    )
    if log then
      log.debug("version.parse invalid format", {
        error = error_handler.format_error(err),
        version_string = version_string
      })
    end
    return nil, err
  end
  
  -- Convert to numbers
  local result = {
    major = tonumber(major),
    minor = tonumber(minor),
    patch = tonumber(patch),
    string = version_string
  }
  
  if log and log.is_debug_enabled() then
    log.debug("Parsed version string", {
      version_string = version_string,
      major = result.major,
      minor = result.minor,
      patch = result.patch
    })
  end
  
  return result
end

-- Version comparison function with error handling
-- @param version1 (string|table) First version to compare
-- @param version2 (string|table) Second version to compare
-- @return comparison (number|nil) -1 if v1 < v2, 0 if equal, 1 if v1 > v2, nil on error
-- @return error (table|nil) Error object if operation failed
function M.compare(version1, version2)
  -- Parameter validation
  if version1 == nil then
    local err = error_handler.validation_error(
      "First version cannot be nil",
      { function_name = "version.compare" }
    )
    if log then
      log.debug("version.compare validation failed", {
        error = error_handler.format_error(err)
      })
    end
    return nil, err
  end
  
  if version2 == nil then
    local err = error_handler.validation_error(
      "Second version cannot be nil",
      { function_name = "version.compare" }
    )
    if log then
      log.debug("version.compare validation failed", {
        error = error_handler.format_error(err)
      })
    end
    return nil, err
  end
  
  -- Parse versions if they're strings
  local v1, v1_err
  local v2, v2_err
  
  if type(version1) == "string" then
    v1, v1_err = M.parse(version1)
    if not v1 then
      return nil, v1_err
    end
  elseif type(version1) == "table" and version1.major and version1.minor and version1.patch then
    v1 = version1
  else
    local err = error_handler.validation_error(
      "First version must be a string or a properly formatted version table",
      { 
        function_name = "version.compare",
        provided_type = type(version1)
      }
    )
    if log then
      log.debug("version.compare validation failed", {
        error = error_handler.format_error(err),
        version1 = version1
      })
    end
    return nil, err
  end
  
  if type(version2) == "string" then
    v2, v2_err = M.parse(version2)
    if not v2 then
      return nil, v2_err
    end
  elseif type(version2) == "table" and version2.major and version2.minor and version2.patch then
    v2 = version2
  else
    local err = error_handler.validation_error(
      "Second version must be a string or a properly formatted version table",
      { 
        function_name = "version.compare",
        provided_type = type(version2)
      }
    )
    if log then
      log.debug("version.compare validation failed", {
        error = error_handler.format_error(err),
        version2 = version2
      })
    end
    return nil, err
  end
  
  -- Compare major version
  if v1.major > v2.major then
    return 1
  elseif v1.major < v2.major then
    return -1
  end
  
  -- Compare minor version (if major versions are equal)
  if v1.minor > v2.minor then
    return 1
  elseif v1.minor < v2.minor then
    return -1
  end
  
  -- Compare patch version (if major and minor versions are equal)
  if v1.patch > v2.patch then
    return 1
  elseif v1.patch < v2.patch then
    return -1
  end
  
  -- Versions are equal
  return 0
end

-- Check if current version satisfies a minimum required version
-- @param required_version (string|table) Minimum required version
-- @return satisfies (boolean|nil) True if current version satisfies requirement, nil on error
-- @return error (table|nil) Error object if operation failed
function M.satisfies_requirement(required_version)
  -- Parameter validation
  if required_version == nil then
    local err = error_handler.validation_error(
      "Required version cannot be nil",
      { function_name = "version.satisfies_requirement" }
    )
    if log then
      log.debug("version.satisfies_requirement validation failed", {
        error = error_handler.format_error(err)
      })
    end
    return nil, err
  end
  
  local comparison, err = M.compare(M, required_version)
  if not comparison then
    return nil, err
  end
  
  -- Current version is greater or equal to required version
  return comparison >= 0
end

-- For compatibility with direct require
return M.string