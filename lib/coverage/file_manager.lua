local M = {}
local fs = require("lib.tools.filesystem")

-- Find all Lua files in directories matching patterns
function M.discover_files(config)
  local discovered = {}
  local include_patterns = config.include or {}
  local exclude_patterns = config.exclude or {}
  local source_dirs = config.source_dirs or {"."}
  
  -- Process explicitly included files first
  for _, pattern in ipairs(include_patterns) do
    -- If it's a direct file path (not a pattern)
    if not pattern:match("[%*%?%[%]]") and fs.file_exists(pattern) then
      local normalized_path = fs.normalize_path(pattern)
      discovered[normalized_path] = true
    end
  end
  
  -- Convert source dirs to absolute paths
  local absolute_dirs = {}
  for _, dir in ipairs(source_dirs) do
    if fs.directory_exists(dir) then
      table.insert(absolute_dirs, fs.normalize_path(dir))
    end
  end
  
  -- Use filesystem module to find all .lua files
  local lua_files = fs.discover_files(
    absolute_dirs,
    include_patterns,
    exclude_patterns
  )
  
  -- Add discovered files
  for _, file_path in ipairs(lua_files) do
    local normalized_path = fs.normalize_path(file_path)
    discovered[normalized_path] = true
  end
  
  return discovered
end

-- Update coverage data with discovered files
function M.add_uncovered_files(coverage_data, config)
  local discovered = M.discover_files(config)
  local added = 0
  
  for file_path in pairs(discovered) do
    if not coverage_data.files[file_path] then
      -- Count lines in file
      local line_count = 0
      local source = fs.read_file(file_path)
      if source then
        for _ in source:gmatch("[^\r\n]+") do
          line_count = line_count + 1
        end
      end
      
      coverage_data.files[file_path] = {
        lines = {},
        functions = {},
        line_count = line_count,
        discovered = true,
        source = source
      }
      
      added = added + 1
    end
  end
  
  return added
end

return M