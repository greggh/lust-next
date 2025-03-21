-- Version module for firmo
-- Single source of truth for the project version

-- This file is used by other components like documentation generators,
-- package managers, and release scripts to determine the current version.

-- Should follow semantic versioning: MAJOR.MINOR.PATCH
-- See https://semver.org/ for more details

---@class version
---@field MAJOR number Major version component
---@field MINOR number Minor version component
---@field PATCH number Patch version component
---@field _VERSION string Combined version string
---@field parse fun(version_string: string): {major: number, minor: number, patch: number, prerelease?: string, buildmetadata?: string}|nil, table? Parse a version string into components
---@field compare fun(version1: string|table, version2: string|table): number|nil, table? Compare two versions (-1, 0, 1)
---@field satisfies_requirement fun(version: string|table, required_version: string|table): boolean|nil, table? Check if version satisfies requirement
---@field get_version fun(): string Get full version string
---@field get_version_table fun(): {major: number, minor: number, patch: number, prerelease?: string, buildmetadata?: string} Get version as table
---@field check_version fun(min_version: string|table): boolean|nil, table? Check if current version meets minimum required
---@field is_compatible fun(other_version: string|table): boolean|nil, table? Check compatibility with another version
---@field compare_versions fun(version_a: string|table, version_b: string|table): number|nil, table? Compare two version strings (-1, 0, 1)
---@field format fun(version_table: table): string Format a version table as a string
---@field has_breaking_changes fun(version1: string|table, version2: string|table): boolean|nil, table? Check if versions have breaking changes
---@field LUA_VERSION {major: number, minor: number, is_luajit: boolean, is_51_compatible: boolean} Information about the Lua runtime version

-- Require error handler for comprehensive error handling
local error_handler = require("lib.tools.error_handler")

-- Initialize logging
local logging = require("lib.tools.logging")
local log = logging.get_logger("core.version")

---@type version
local M = {}

-- Individual version components
M.major = 0
M.minor = 7
M.patch = 3

-- Combined semantic version
M.string = string.format("%d.%d.%d", M.major, M.minor, M.patch)

---@param version_string string Version string to parse in format "MAJOR.MINOR.PATCH"
---@return table|nil parsed_version Table with major, minor, patch components or nil on error
---@return table|nil error Error object if operation failed
-- Version parsing function with error handling
function M.parse(version_string)
  -- Parameter validation
  if version_string == nil then
    local err = error_handler.validation_error(
      "Version string cannot be nil",
      { function_name = "version.parse" }
    )
    log.debug("version.parse validation failed", {
      error = error_handler.format_error(err)
    })
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
    log.debug("version.parse validation failed", {
      error = error_handler.format_error(err),
      provided_type = type(version_string)
    })
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
    log.debug("version.parse invalid format", {
      error = error_handler.format_error(err),
      version_string = version_string
    })
    return nil, err
  end
  
  -- Convert to numbers
  local result = {
    major = tonumber(major),
    minor = tonumber(minor),
    patch = tonumber(patch),
    string = version_string
  }
  
  log.debug("Parsed version string", {
    version_string = version_string,
    major = result.major,
    minor = result.minor,
    patch = result.patch
  })
  
  return result
end

---@param version1 string|table First version to compare (string or version table)
---@param version2 string|table Second version to compare (string or version table)
---@return number|nil comparison -1 if v1 < v2, 0 if equal, 1 if v1 > v2, nil on error
---@return table|nil error Error object if operation failed
-- Version comparison function with error handling
function M.compare(version1, version2)
  -- Parameter validation
  if version1 == nil then
    local err = error_handler.validation_error(
      "First version cannot be nil",
      { function_name = "version.compare" }
    )
    log.debug("version.compare validation failed", {
      error = error_handler.format_error(err)
    })
    return nil, err
  end
  
  if version2 == nil then
    local err = error_handler.validation_error(
      "Second version cannot be nil",
      { function_name = "version.compare" }
    )
    log.debug("version.compare validation failed", {
      error = error_handler.format_error(err)
    })
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
    log.debug("version.compare validation failed", {
      error = error_handler.format_error(err),
      version1 = version1
    })
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
    log.debug("version.compare validation failed", {
      error = error_handler.format_error(err),
      version2 = version2
    })
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

---@param required_version string|table Minimum required version (string or version table)
---@return boolean|nil satisfies True if current version satisfies requirement, nil on error
---@return table|nil error Error object if operation failed
-- Check if current version satisfies a minimum required version
function M.satisfies_requirement(required_version)
  -- Parameter validation
  if required_version == nil then
    local err = error_handler.validation_error(
      "Required version cannot be nil",
      { function_name = "version.satisfies_requirement" }
    )
    log.debug("version.satisfies_requirement validation failed", {
      error = error_handler.format_error(err)
    })
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
