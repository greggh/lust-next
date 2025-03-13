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
  
  logger.debug("Registering reporting formatters", {
    modules = formatter_modules
  })
  
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
    
    logger.trace("Attempting to load formatter", {
      module = module_name,
      paths = formatter_paths,
      base_dir = current_module_dir
    })
    
    local loaded = false
    for _, path in ipairs(formatter_paths) do
      -- Silently try to load formatter without debug output
      local ok, formatter_module_or_error = pcall(require, path)
      if ok then
        -- Handle different module formats:
        if type(formatter_module_or_error) == "function" then
          -- 1. Function that registers formatters
          logger.trace("Loaded formatter as registration function", { 
            module = module_name,
            path = path
          })
          formatter_module_or_error(formatters)
          loaded = true
          break
        elseif type(formatter_module_or_error) == "table" and type(formatter_module_or_error.register) == "function" then
          -- 2. Table with register function
          logger.trace("Loaded formatter with register() method", { 
            module = module_name,
            path = path
          })
          formatter_module_or_error.register(formatters)
          loaded = true
          break
        elseif type(formatter_module_or_error) == "table" then
          -- 3. Table with format_coverage/format_quality functions
          local functions_found = {}
          
          if type(formatter_module_or_error.format_coverage) == "function" then
            formatters.coverage[module_name] = formatter_module_or_error.format_coverage
            table.insert(functions_found, "format_coverage")
          end
          
          if type(formatter_module_or_error.format_quality) == "function" then
            formatters.quality[module_name] = formatter_module_or_error.format_quality
            table.insert(functions_found, "format_quality")
          end
          
          if type(formatter_module_or_error.format_results) == "function" then
            formatters.results[module_name] = formatter_module_or_error.format_results
            table.insert(functions_found, "format_results")
          end
          
          if #functions_found > 0 then
            logger.trace("Loaded formatter with formatting functions", {
              module = module_name,
              path = path,
              functions = functions_found
            })
            loaded = true
            break
          end
        end
      end
    end
    
    if loaded then
      logger.debug("Successfully registered formatter", { module = module_name })
    else
      logger.warn("Failed to load formatter module", { module = module_name })
    end
  end
  
  logger.debug("Formatter registration complete", {
    coverage_formatters = table.concat(M.built_in.coverage, ", "),
    quality_formatters = table.concat(M.built_in.quality, ", "),
    results_formatters = table.concat(M.built_in.results, ", ")
  })
  
  return formatters
end

return M