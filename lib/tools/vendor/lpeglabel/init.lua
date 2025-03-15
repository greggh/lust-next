-- LPegLabel loader for lust-next
-- This module attempts to load or compile the LPegLabel C module
-- Original source: https://github.com/sqmedeiros/lpeglabel
-- MIT License

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

-- Check if we need to build the module
local function needs_build()
  return not fs.file_exists(module_path)
end

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