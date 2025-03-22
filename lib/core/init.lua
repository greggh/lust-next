--- Core module for firmo
--- 
--- Central module that aggregates core functionality from submodules:
--- - Type checking utilities for advanced type validation
--- - Expect system enhancements for improved assertion handling
--- - Version information for tracking framework version
---
--- This module acts as a convenience wrapper around these core submodules,
--- providing direct access to commonly used functions while maintaining
--- the option to access the full submodules when needed.
---
--- @version 0.3.0
--- @author Firmo Team

---@class core
---@field type_checking type_checking Type checking utilities for advanced validation
---@field fix_expect boolean Whether expect system was fixed successfully
---@field version string Version string of the framework
---@field is_exact_type fun(value: any, expected_type: string, message?: string): boolean Checks if a value is exactly of the specified primitive type
---@field is_instance_of fun(object: table, class: table, message?: string): boolean Checks if an object is an instance of a class
---@field implements fun(object: table, interface: table, message?: string): boolean Checks if an object implements all interface methods
---@field _VERSION string Module version identifier
local M = {}

-- Module version
M._VERSION = "0.3.0"

---@private
---@param module_name string Name of the module to require
---@return table|nil The required module or nil if not found
-- Try to load a module without failing
local function try_require(module_name)
  local success, module = pcall(require, module_name)
  if success then
    return module
  else
    return nil
  end
end

-- Load submodules
local type_checking = try_require("lib.core.type_checking")
local fix_expect = try_require("lib.core.fix_expect")
local version = try_require("lib.core.version")

-- Export submodules if available
if type_checking then
  M.type_checking = type_checking
end

if fix_expect then
  M.fix_expect = fix_expect
end

if version then
  M.version = version
end

-- Direct exports for convenience
if type_checking then
  M.is_exact_type = type_checking.is_exact_type
  M.is_instance_of = type_checking.is_instance_of
  M.implements = type_checking.implements
end

return M
