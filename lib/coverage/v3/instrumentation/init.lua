-- firmo v3 coverage instrumentation module
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local parser = require("lib.tools.parser.grammar")
local transformer = require("lib.coverage.v3.instrumentation.transformer")
local sourcemap = require("lib.coverage.v3.instrumentation.sourcemap")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.instrumentation")

---@class coverage_v3_instrumentation
---@field instrument fun(source: string): string|nil, table|nil, table? Instrument Lua source code with coverage tracking
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Runtime tracking functions that will be injected
local runtime_functions = [[
local track_line, track_function_entry, track_function_exit, track_branch = 
  require("lib.coverage.v3.runtime.tracker").track_line,
  require("lib.coverage.v3.runtime.tracker").track_function_entry,
  require("lib.coverage.v3.runtime.tracker").track_function_exit,
  require("lib.coverage.v3.runtime.tracker").track_branch

]]

-- Instrument Lua source code with coverage tracking
---@param source string The Lua source code to parse
---@return string|nil instrumented The instrumented code, or nil on error
---@return table|nil sourcemap The sourcemap for the instrumented code, or nil on error
---@return table? error Error information if instrumentation failed
function M.instrument(source)
  if type(source) ~= "string" then
    return nil, nil, error_handler.validation_error(
      "Source must be a string",
      {provided_type = type(source)}
    )
  end

  logger.debug("Instrumenting source code", {
    source_length = #source
  })

  -- Parse source into AST
  local ast, err = parser.parse(source)
  if not ast then
    return nil, nil, error_handler.validation_error(
      "Failed to parse source code",
      {error = err}
    )
  end

  -- Create sourcemap
  local map = sourcemap.create()

  -- Add original source lines
  for line in source:gmatch("[^\r\n]+") do
    map.add_source_line(line)
  end

  -- Transform AST with tracking calls
  local transformed_ast = transformer.transform(ast, map)
  if not transformed_ast then
    return nil, nil, error_handler.validation_error(
      "Failed to transform AST",
      {error = "Failed to transform AST"}
    )
  end

  -- Generate instrumented code
  local generated_code = transformer.generate_code(transformed_ast)

  -- Add runtime functions at the start
  local instrumented = runtime_functions .. "\n" .. source

  -- Add instrumented lines
  for line in instrumented:gmatch("[^\r\n]+") do
    map.add_instrumented_line(line)
  end

  -- Validate sourcemap
  local valid, validation_err = map.validate()
  if not valid then
    return nil, nil, error_handler.validation_error(
      "Invalid sourcemap",
      {error = validation_err}
    )
  end

  return instrumented, map
end

return M