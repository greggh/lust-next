local M = {}
local fs = require("lib.tools.filesystem")

-- Replace a require call to use our instrumented version
function M.instrument_require()
  local original_require = require
  
  _G.require = function(module_name)
    local result = original_require(module_name)
    
    -- Try to find the module's source file
    local module_info = package.loaded[module_name]
    -- Record that this module was loaded
    if M.on_module_load and type(module_name) == "string" then
      M.on_module_load(module_name, module_info)
    end
    
    return result
  end
  
  return M
end

-- Instrument a Lua source file by adding coverage tracking
function M.instrument_file(file_path, config)
  if not fs.file_exists(file_path) then
    return nil, "File not found"
  end
  
  local source = fs.read_file(file_path)
  if not source then
    return nil, "Could not read file"
  end
  
  local lines = {}
  local line_num = 1
  
  for line in source:gmatch("[^\r\n]+") do
    -- Skip comments and empty lines
    if not line:match("^%s*%-%-") and not line:match("^%s*$") then
      -- Add tracking code before executable lines
      table.insert(lines, string.format(
        'require("lib.coverage").track_line(%q, %d); %s',
        file_path, line_num, line
      ))
    else
      table.insert(lines, line)
    end
    line_num = line_num + 1
  end
  
  return table.concat(lines, "\n")
end

-- Override Lua's built-in loaders to use instrumented code
function M.hook_loaders()
  -- Save original loader
  local original_loadfile = loadfile
  
  -- Replace with instrumented version
  _G.loadfile = function(filename)
    if not filename then
      return original_loadfile()
    end
    
    -- Check if we should instrument this file
    if M.should_instrument and M.should_instrument(filename) then
      local instrumented, err = M.instrument_file(filename)
      if instrumented then
        return load(instrumented, "@" .. filename)
      end
    end
    
    -- Use original loader for now
    return original_loadfile(filename)
  end
  
  -- Similarly hook dofile if needed
  local original_dofile = dofile
  _G.dofile = function(filename)
    if not filename then
      return original_dofile()
    end
    
    -- Check if we should instrument this file
    if M.should_instrument and M.should_instrument(filename) then
      local instrumented, err = M.instrument_file(filename)
      if instrumented then
        return load(instrumented, "@" .. filename)()
      end
    end
    
    -- Use original loader
    return original_dofile(filename)
  end
  
  return true
end

-- Set the module load callback
function M.set_module_load_callback(callback)
  if type(callback) == "function" then
    M.on_module_load = callback
  end
  return M
end

-- Set the instrumentation predicate
function M.set_instrumentation_predicate(predicate)
  if type(predicate) == "function" then
    M.should_instrument = predicate
  end
  return M
end

return M