-- Formatter registry initialization
local M = {
  -- Export a list of built-in formatters for documentation
  built_in = {
    coverage = {"summary", "json", "html", "lcov"},
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
    "junit"
  }
  
  for _, module_name in ipairs(formatter_modules) do
    local ok, register_fn = pcall(require, "lib.reporting.formatters." .. module_name)
    if ok and type(register_fn) == "function" then
      register_fn(formatters)
    else
      print("WARNING: Failed to load formatter module: " .. module_name)
    end
  end
  
  return formatters
end

return M