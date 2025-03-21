-- lib/core/init.lua - Core module for firmo

---@class core
---@field type_checking type_checking Type checking utilities
---@field fix_expect boolean Whether expect system was fixed successfully
---@field version string Version string
---@field is_exact_type fun(value: any, expected_type: string, message?: string): boolean
---@field is_instance_of fun(object: table, class: table, message?: string): boolean
---@field implements fun(object: table, interface: table, message?: string): boolean
local M = {}

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
