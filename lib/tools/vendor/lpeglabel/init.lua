-- LPegLabel loader for lust-next
-- This module attempts to load or compile the LPegLabel C module
-- Original source: https://github.com/sqmedeiros/lpeglabel
-- MIT License

---@class lpeglabel
---@field _VERSION string Module version
---@field match fun(pattern: table, subject: string, init?: number): any, ... Match a string against a pattern
---@field type fun(v: any): string Return the type of the pattern
---@field P fun(p: string|table|number|boolean|function): table Create a pattern
---@field S fun(set: string): table Create a set pattern
---@field R fun(range: string, ...): table Create a range pattern
---@field V fun(v: string|number): table Create a variable pattern
---@field C fun(p: table): table Create a capture pattern
---@field Cc fun(...): table Create a constant capture pattern
---@field Cp fun(): table Create a position capture pattern
---@field Cmt fun(p: table, f: function): table Create a match-time capture pattern
---@field Ct fun(p: table): table Create a table capture pattern
---@field T fun(l: string): table Create a labeled failure pattern
---@field B fun(p: table): table Create a back reference pattern
---@field Carg fun(n: number): table Create an argument capture pattern
---@field Cb fun(name: string): table Create a back capture pattern
---@field Cf fun(p: table, f: function): table Create a fold capture pattern
---@field Cg fun(p: table, name?: string): table Create a group capture pattern
---@field Cs fun(p: table): table Create a substitution capture pattern
---@field Lc fun(p: table): table Create a labeled failure capture pattern
---@field setlabels fun(labels: table): table Set failure labels for patterns
---@field locale fun(t: table): table Set locale for patterns
---@field version fun(): string Get the module version
---@field setmaxstack fun(n: number): boolean Set the maximum stack size for the VM
---@field getcaptures fun(subject: string, init: number, caps: table): ... Get captures from a match result
---@field ispatterntable fun(p: any): boolean Check if a value is a pattern table

local M = {}
local fs = require("lib.tools.filesystem")

-- Detect operating system
local is_windows = package.config:sub(1,1) == '\\'
local extension = is_windows and "dll" or "so"

-- Define paths
local script_path = debug.getinfo(1, "S").source:sub(2):match("(.+/)[^/]+$") or "./"
local vendor_dir = script_path
-- Ensure paths are strings
if type(vendor_dir) ~= "string" then
  vendor_dir = "./"
  print("Warning: vendor_dir is not a string, using './' instead")
end
-- Use direct string concatenation instead of fs.join_paths
local module_path = vendor_dir .. "lpeglabel." .. extension
local build_log_path = vendor_dir .. "build.log"

-- Debug paths
print("LPegLabel paths:")
print("- script_path: " .. tostring(script_path))
print("- vendor_dir: " .. tostring(vendor_dir))
print("- module_path: " .. tostring(module_path) .. " (type: " .. type(module_path) .. ")")
print("- build_log_path: " .. tostring(build_log_path) .. " (type: " .. type(build_log_path) .. ")")

---@private
---@return boolean needs_build Whether the module needs to be built
-- Check if we need to build the module
local function needs_build()
  return not fs.file_exists(module_path)
end

---@private
---@return string platform The platform string: "windows", "macosx", or "linux"
-- Helper function to get platform
local function get_platform()
  if is_windows then
    return "windows"
  end
  
  -- Check if we're on macOS
  local success, result = pcall(function()
    local handle = io.popen("uname")
    if not handle then return "linux" end
    
    local output = handle:read("*a")
    handle:close()
    return output:match("Darwin") and "macosx" or "linux"
  end)
  
  return success and result or "linux"
end

---@private
---@return boolean success Whether the build was successful
---@return string? error Error message if build failed
-- Build the module from source
local function build_module()
  -- Create or empty the log file
  local log_content = "Building LPegLabel module at " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
  
  -- Ensure we have a valid path before writing
  if type(build_log_path) ~= "string" then
    print("Error: build_log_path is not a string: " .. tostring(build_log_path))
    return false, "Invalid build log path (not a string)"
  end
  
  local write_success = fs.write_file(build_log_path, log_content)
  
  if not write_success then
    return false, "Could not create build log file"
  end
  
  -- Get current directory
  local current_dir = fs.get_absolute_path(".")
  
  -- Get platform (windows, linux, macosx)
  local platform = get_platform()
  log_content = log_content .. "Detected platform: " .. platform .. "\n"
  fs.append_file(build_log_path, "Detected platform: " .. platform .. "\n")
  
  -- Change to the vendor directory
  local original_dir = fs.get_current_dir()
  if not fs.change_dir(vendor_dir) then
    fs.append_file(build_log_path, "Failed to change to vendor directory: " .. vendor_dir .. "\n")
    return false, "Failed to change to vendor directory"
  end
  
  -- Build the command
  local command
  local normalized_current_dir = fs.normalize_path(current_dir)
  
  -- Run the appropriate build command
  fs.append_file(build_log_path, "Running " .. platform .. " build command\n")
  
  local success, output
  if platform == "windows" then
    success, output = pcall(function()
      command = "mingw32-make windows LUADIR=\"" .. normalized_current_dir .. "\" 2>&1"
      local handle = io.popen(command)
      local result = handle:read("*a")
      handle:close()
      return result
    end)
  else
    success, output = pcall(function()
      command = "make " .. platform .. " LUADIR=\"" .. normalized_current_dir .. "\" 2>&1"
      local handle = io.popen(command)
      local result = handle:read("*a")
      handle:close()
      return result
    end)
  end
  
  -- Log the command and its output
  if command then
    fs.append_file(build_log_path, "Executing: " .. command .. "\n")
  end
  
  if not success then
    fs.append_file(build_log_path, "Error executing build command: " .. tostring(output) .. "\n")
  elseif output then
    fs.append_file(build_log_path, output .. "\n")
  end
  
  -- Change back to the original directory
  fs.change_dir(original_dir)
  
  -- Check if build succeeded
  if fs.file_exists(module_path) then
    fs.append_file(build_log_path, "Build succeeded. Module created at: " .. module_path .. "\n")
    return true
  else
    fs.append_file(build_log_path, "Build failed. Module not created at: " .. module_path .. "\n")
    return false, "Failed to build LPegLabel module"
  end
end

---@private
---@return table lpeglabel The loaded LPegLabel module
-- Load the compiled module
local function load_module()
  if package.loaded.lpeglabel then
    return package.loaded.lpeglabel
  end
  
  -- Check if C module already exists
  if fs.file_exists(module_path) then
    -- Try to load the module directly
    local ok, result = pcall(function()
      -- Use package.loadlib for better error messages
      local loader = package.loadlib(module_path, "luaopen_lpeglabel")
      if not loader then
        error("Failed to load lpeglabel library: Invalid loader")
      end
      return loader()
    end)
    
    if ok then
      package.loaded.lpeglabel = result
      return result
    else
      print("Warning: Failed to load existing lpeglabel module: " .. tostring(result))
      -- If loading failed, try rebuilding
      if needs_build() then
        local build_success, build_err = build_module()
        if not build_success then
          error("Failed to build lpeglabel module: " .. tostring(build_err))
        end
        -- Try loading again after rebuild
        return load_module()
      end
    end
  else
    -- Module doesn't exist, try to build it
    if needs_build() then
      local build_success, build_err = build_module()
      if not build_success then
        error("Failed to build lpeglabel module: " .. tostring(build_err))
      end
      -- Try loading again after build
      return load_module()
    end
  end
  
  error("Failed to load lpeglabel module after all attempts")
end

-- Attempt to load the module or build it on first use
local ok, result = pcall(load_module)
if not ok then
  print("LPegLabel loading error: " .. tostring(result))
  print("Using fallback implementation with limited functionality")
  return require("lib.tools.vendor.lpeglabel.fallback")
end

-- Return the loaded module
return result