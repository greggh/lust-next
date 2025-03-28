-- V3 Coverage Source Map
-- Maps instrumented code back to original source locations

local M = {
  _VERSION = "3.0.0"
}

-- Store source mappings
local source_maps = {}

-- Add a mapping between instrumented and original source
function M.add_mapping(filename, instrumented_line, original_line)
  source_maps[filename] = source_maps[filename] or {}
  source_maps[filename][instrumented_line] = original_line
end

-- Get original source location for an instrumented line
function M.get_original_location(filename, instrumented_line)
  if not source_maps[filename] then
    return instrumented_line
  end
  return source_maps[filename][instrumented_line] or instrumented_line
end

-- Reset all source mappings
function M.reset()
  source_maps = {}
end

return M