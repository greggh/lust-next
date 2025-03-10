-- Formatter registry initialization
-- Import filesystem module for path normalization
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("formatters")
logging.configure_from_config("formatters")

local M = {
  -- Export a list of built-in formatters for documentation
  built_in = {
    coverage = {"summary", "json", "html", "lcov", "cobertura"},
    quality = {"summary", "json", "html"},
    results = {"junit", "tap", "csv"}
  }
}

-- Load and register all formatters
function M.register_all(formatters)
  -- Load all the built-in formatters
  local formatter_modules = {
    "summary",
    "json",
    "html",
    "lcov",
    "tap",
    "csv",
    "junit",
    "cobertura"
  }
  
  for _, module_name in ipairs(formatter_modules) do
    -- Get the current module path to use as a base
    local current_module_dir = debug.getinfo(1).source:match("@(.+)/[^/]+$") or ""
    current_module_dir = fs.normalize_path(current_module_dir)
    
    -- Try multiple possible paths to load the formatter
    local formatter_paths = {
      "lib.reporting.formatters." .. module_name,
      "../lib/reporting/formatters/" .. module_name,
      "./lib/reporting/formatters/" .. module_name,
      -- Use filesystem module to join paths properly
      fs.join_paths(current_module_dir, module_name),
    }
    
    local loaded = false
    for _, path in ipairs(formatter_paths) do
      -- Silently try to load formatter without debug output
      local ok, formatter_module_or_error = pcall(require, path)
      if ok then
        -- Handle different module formats:
        -- 1. Function that registers formatters
        if type(formatter_module_or_error) == "function" then
          formatter_module_or_error(formatters)
          loaded = true
          break
        -- 2. Table with register function
        elseif type(formatter_module_or_error) == "table" and type(formatter_module_or_error.register) == "function" then
          formatter_module_or_error.register(formatters)
          loaded = true
          break
        -- 3. Table with format_coverage/format_quality functions
        elseif type(formatter_module_or_error) == "table" then
          if type(formatter_module_or_error.format_coverage) == "function" then
            formatters.coverage[module_name] = formatter_module_or_error.format_coverage
          end
          if type(formatter_module_or_error.format_quality) == "function" then
            formatters.quality[module_name] = formatter_module_or_error.format_quality
          end
          if type(formatter_module_or_error.format_results) == "function" then
            formatters.results[module_name] = formatter_module_or_error.format_results
          end
          loaded = true
          break
        end
      end
    end
    
    if not loaded then
      logger.warn("Failed to load formatter module: " .. module_name)
    end
  end
  
  return formatters
end

return M