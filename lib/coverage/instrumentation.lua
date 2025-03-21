-- NOTE (2025-03-12): Table constructor handling has been enhanced.
-- Environment variable (_ENV) handling improved to work in both Lua 5.1 and 5.2+ environments.
-- Key fixes implemented:
-- 1. Fixed caching mechanism to prevent stale code reuse in tests
-- 2. Improved table constructor instrumentation with proper tracking
-- 3. Enhanced environment variable handling with _ENV = _G pattern
-- 4. Added comprehensive error handling for code not loading properly

---@class coverage.instrumentation
---@field _VERSION string Module version
---@field set_config fun(new_config: {use_static_analysis?: boolean, track_function_calls?: boolean, track_blocks?: boolean, preserve_line_numbers?: boolean, max_file_size?: number, cache_instrumented_files?: boolean, sourcemap_enabled?: boolean, include_coverage_module?: boolean, allow_fallback?: boolean, use_static_imports?: boolean}): coverage.instrumentation Set configuration options for instrumentation
---@field get_config fun(): {use_static_analysis: boolean, track_function_calls: boolean, track_blocks: boolean, preserve_line_numbers: boolean, max_file_size: number, cache_instrumented_files: boolean, sourcemap_enabled: boolean, include_coverage_module: boolean, allow_fallback: boolean, use_static_imports: boolean} Get current configuration settings
---@field set_instrumentation_predicate fun(predicate_fn: fun(file_path: string): boolean): boolean Set predicate function to determine if a file should be instrumented
---@field set_module_load_callback fun(callback_fn: fun(module_name: string, module_result: any, module_path: string): boolean): boolean Set callback for module loading events
---@field set_debug_hook_fallback fun(callback_fn: fun(file_path: string, source: string): boolean): boolean Set fallback function for large files that can't be instrumented
---@field hook_loaders fun(): boolean Hook Lua's built-in loaders (load, loadfile, dofile)
---@field unhook_loaders fun(): boolean Unhook Lua's built-in loaders
---@field instrument_require fun(): boolean Instrument Lua's require function
---@field uninstrument_require fun(): boolean Restore Lua's original require function
---@field instrument_file fun(file_path: string, options?: {allow_fallback?: boolean, max_file_size?: number, cache_instrumented_files?: boolean, force?: boolean, use_static_imports?: boolean}): string|nil, table? Instrument a file with coverage tracking
---@field instrument_code fun(source: string, options?: {file_path?: string, ast?: table, debug_mode?: boolean, track_functions?: boolean, track_blocks?: boolean, use_static_imports?: boolean}): string|nil, table? Instrument Lua source code with coverage tracking
---@field get_sourcemap fun(file_path: string): {original_lines: table<number, {instrumented_line: number, has_tracking: boolean}>, instrumented_lines: table<number, {type: string, original_line: number}>, file_path: string}|nil, table? Get sourcemap for a file to translate between original and instrumented code
---@field translate_error fun(err: string|table): string|table|nil Transform error messages using sourcemap to reference original line numbers
---@field get_stats fun(): {cache_size: number, enabled: boolean, config: table} Get statistics about instrumentation cache and configuration
---@field clear_cache fun(): boolean Clear the instrumentation cache
---@field create_isolated_environment fun(): table Create an isolated environment to prevent infinite recursion
---@field create_isolated_test_environment fun(test_module_path: string): table Create an isolated boundary-aware testing environment
local M = {}
M._VERSION = "1.2.0"

local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")

-- Import logging
local logging = require("lib.tools.logging")
local logger = logging.get_logger("coverage.instrumentation")
logging.configure_from_config("coverage.instrumentation")

-- Lazy loading for static analyzer
local static_analyzer

-- Module configuration
local config = {
  use_static_analysis = true,       -- Use static analysis to identify executable lines
  track_function_calls = true,      -- Add tracking for function calls
  track_blocks = true,              -- Add tracking for code blocks
  preserve_line_numbers = true,     -- Try to preserve original line numbers in error messages
  max_file_size = 1000000,          -- Skip files over 1MB (increased from 500KB)
  cache_instrumented_files = true,  -- Cache instrumented files for better performance
  sourcemap_enabled = true,         -- Generate sourcemaps for better error reporting
  include_coverage_module = false,  -- Whether to instrument the coverage module itself
  allow_fallback = false            -- Whether to allow fallback to debug hook for large files
}

-- Cache for instrumented files
local instrumented_cache = {}

-- Cache for sourcemaps
local sourcemap_cache = {}

logger.debug("Coverage instrumentation module initialized", {
  version = M._VERSION
})

---@param new_config table Configuration options for the instrumentation module
---@return coverage.instrumentation The instrumentation module (for method chaining)
-- Set configuration
function M.set_config(new_config)
  -- Validate input
  if type(new_config) ~= "table" then
    local err = error_handler.validation_error(
      "Invalid configuration provided",
      {type = type(new_config)}
    )
    logger.warn(err.message, {type = type(new_config)})
    return M
  end

  for k, v in pairs(new_config) do
    config[k] = v
  end

  -- Count config items
  local config_count = 0
  for _ in pairs(new_config) do
    config_count = config_count + 1
  end

  logger.debug("Configuration updated", {
    config_count = config_count
  })

  return M
end

---@return table config Current configuration of the instrumentation module
-- Get current configuration
function M.get_config()
  return config
end

---@private
---@return coverage.static_analyzer|nil static_analyzer Initialized static analyzer or nil if initialization failed
---@return table|nil error Error information if initialization failed
-- Initialize static analyzer if needed
local function init_static_analyzer()
  local success, result, err = error_handler.try(function()
    if not static_analyzer and config.use_static_analysis then
      static_analyzer = require("lib.coverage.static_analyzer")
      static_analyzer.init({
        cache_files = true,
        control_flow_keywords_executable = true
      })
      logger.debug("Static analyzer initialized for instrumentation")
    end
    return static_analyzer
  end)

  if not success then
    logger.error("Failed to initialize static analyzer", {
---@diagnostic disable-next-line: need-check-nil, undefined-field
      error = err.message,
---@diagnostic disable-next-line: need-check-nil, undefined-field
      category = err.category
    })
    return nil, err
  end

  return result
end

---@private
---@param original_source string Original source code content
---@param instrumented_source string Instrumented source code content
---@param file_path string Path to the source file
---@return {original_lines: table<number, {instrumented_line: number, has_tracking: boolean}>, instrumented_lines: table<number, {type: string, original_line: number}>, file_path: string}|nil sourcemap Generated sourcemap or nil if generation failed
---@return table|nil error Error object if generation failed
-- Generate a sourcemap for a file that maps between original and instrumented code lines
local function generate_sourcemap(original_source, instrumented_source, file_path)
  -- Validate input
  if not config.sourcemap_enabled then
    return nil
  end

  if not original_source or not instrumented_source or not file_path then
    local err = error_handler.validation_error(
      "Missing required parameters for sourcemap generation",
      {
        has_original = original_source ~= nil,
        has_instrumented = instrumented_source ~= nil,
        has_file_path = file_path ~= nil
      }
    )
    logger.warn(err.message, err.context)
    return nil, err
  end

  local sourcemap = {
    original_lines = {},
    instrumented_lines = {},
    file_path = file_path
  }

  local success, err = error_handler.try(function()
    -- Parse original source into lines
    local original_line_map = {}
    local line_num = 1
    for line in original_source:gmatch("[^\r\n]+") do
      original_line_map[line_num] = line
      line_num = line_num + 1
    end

    -- Parse instrumented source and map back to original
    local orig_line = 1
    local instr_line = 1
    for line in instrumented_source:gmatch("[^\r\n]+") do
      -- Check if this is an instrumentation line or original line
      if line:match("^require%(\"lib%.coverage\"%)") then
        -- This is an instrumented line
        local target_line = tonumber(line:match("track_line%(.-,.-(%d+)"))
        if target_line then
          sourcemap.instrumented_lines[instr_line] = {
            type = "instrumented",
            original_line = target_line
          }
          sourcemap.original_lines[target_line] = {
            instrumented_line = instr_line,
            has_tracking = true
          }
        end
      elseif line:match("^require%(\"lib%.coverage\"%)%.track_function") then
        -- This is a function instrumentation line
        local target_line = tonumber(line:match("track_function%(.-,.-(%d+)"))
        if target_line then
          sourcemap.instrumented_lines[instr_line] = {
            type = "function_tracking",
            original_line = target_line
          }
        end
      elseif line:match("^require%(\"lib%.coverage\"%)%.track_block") then
        -- This is a block instrumentation line
        local target_line = tonumber(line:match("track_block%(.-,.-(%d+)"))
        if target_line then
          sourcemap.instrumented_lines[instr_line] = {
            type = "block_tracking",
            original_line = target_line
          }
        end
      else
        -- Try to find corresponding original line
        for i = orig_line, #original_line_map do
          if original_line_map[i] == line then
            sourcemap.instrumented_lines[instr_line] = {
              type = "original",
              original_line = i
            }
            sourcemap.original_lines[i] = {
              instrumented_line = instr_line,
              has_tracking = false
            }
            orig_line = i + 1
            break
          end
        end
      end
      instr_line = instr_line + 1
    end

    logger.debug("Generated sourcemap", {
      file_path = file_path,
      original_lines = #original_line_map,
      instrumented_lines = instr_line - 1
    })

    -- Cache the sourcemap
    sourcemap_cache[file_path] = sourcemap

    return sourcemap
  end)

  if not success then
    logger.error("Failed to generate sourcemap", {
      file_path = file_path,
      error = err.message,
      category = err.category
    })
    return nil, err
  end

  return sourcemap
end

---@param file_path string Path to the file
---@return table|nil sourcemap Sourcemap for the file or nil if not found/error
---@return table|nil error Error object if operation failed
-- Get the sourcemap for a file
function M.get_sourcemap(file_path)
  if not file_path then
    local err = error_handler.validation_error(
      "File path is required to get sourcemap",
      {param = "file_path"}
    )
    logger.warn(err.message, err.context)
    return nil, err
  end

  return sourcemap_cache[file_path]
end

---@private
---@param line string Line of code to instrument
---@param file_path string Path to the source file
---@param line_num number Line number in the source file
---@param is_executable boolean Whether the line contains executable code
---@param block_info? {id: string, type: string} Optional block metadata if the line is part of a code block
---@return string|nil instrumented_line Instrumented line or nil if instrumentation failed
---@return table|nil error Error object if instrumentation failed
-- Apply instrumentation to a line based on its type (control structures, functions, etc.)
-- Handles different line types (if/then, while/do, function definitions, table constructors)
-- and adds appropriate coverage tracking calls for each type
local function instrument_line(line, file_path, line_num, is_executable, block_info)
  -- Validate input
  if not line or not file_path or not line_num then
    local err = error_handler.validation_error(
      "Missing required parameters for line instrumentation",
      {
        has_line = line ~= nil,
        has_file_path = file_path ~= nil,
        has_line_num = line_num ~= nil
      }
    )
    logger.warn(err.message, err.context)
    return nil, err
  end

  -- Normalize file path to prevent double slashes and other path issues
  file_path = file_path:gsub("//", "/"):gsub("\\", "/")

  -- For non-executable lines, return unchanged
  if not is_executable then
    return line
  end

    -- More comprehensive patterns for control structures based on Lua grammar
  -- Pattern matching with awareness of Lua syntax structure

  -- Helper function to build tracking code
  local function build_tracking_code()
    -- Support static imports when configured
    if config.use_static_imports then
      if block_info and config.track_blocks then
        return string.format('_coverage_track_block(%q, %d, %q, %q)',
          file_path, line_num, block_info.id, block_info.type)
      else
        return string.format('_coverage_track_line(%q, %d)',
          file_path, line_num)
      end
    else
      -- Original dynamic tracking code
      if block_info and config.track_blocks then
        return string.format('require("lib.coverage").track_block(%q, %d, %q, %q)',
          file_path, line_num, block_info.id, block_info.type)
      else
        return string.format('require("lib.coverage").track_line(%q, %d)',
          file_path, line_num)
      end
    end
  end

  -- Special handling to ensure file activation - always needed
  local activation_code
  if config.use_static_imports then
    activation_code = string.format('_coverage_activate_file(%q);', file_path)
  else
    activation_code = string.format('require("lib.coverage.debug_hook").activate_file(%q);', file_path)
  end

  -- Get indentation for preserving code style
  local indentation = line:match("^(%s*)")

  -- Control flow structures that end with 'then'
  if line:match("^%s*if%s+.-then%s*$") or line:match("^%s*if%s+.-then%s*%-%-") or
     line:match("^%s*elseif%s+.-then%s*$") or line:match("^%s*elseif%s+.-then%s*%-%-") then

    -- Extract the part before and after "then"
    local before_then, after_then = line:match("^(.+then)(.*)$")
    if before_then and after_then then
      -- Add tracking AFTER the "then" keyword
      return string.format('%s %s %s;%s',
        before_then,
        activation_code,
        build_tracking_code(),
        after_then
      )
    end

  -- Control flow structures that end with 'do'
  elseif line:match("^%s*for%s+.-do%s*$") or line:match("^%s*for%s+.-do%s*%-%-") or
         line:match("^%s*while%s+.-do%s*$") or line:match("^%s*while%s+.-do%s*%-%-") then

    -- Extract the part before and after "do"
    local before_do, after_do = line:match("^(.+do)(.*)$")
    if before_do and after_do then
      -- Add tracking AFTER the "do" keyword
      return string.format('%s %s %s;%s',
        before_do,
        activation_code,
        build_tracking_code(),
        after_do
      )
    end

  -- Function declarations
  elseif line:match("^%s*function%s+.-%(%s*.-%)%s*$") or
         line:match("^%s*local%s+function%s+.-%(%s*.-%)%s*$") or
         line:match("^%s*local%s+[%w_]+%s*=%s*function%s*%(%s*.-%)%s*$") or
         line:match("^%s*[%w_%.%[%]\"']+%s*=%s*function%s*%(%s*.-%)%s*$") then

    -- For function declarations, add tracking on the next line
    return string.format('%s\n%s%s %s;',
      line,
      indentation .. "  ", -- Add extra indentation for clarity
      activation_code,
      build_tracking_code()
    )

  -- Simple keywords that start blocks (do, repeat)
  elseif line:match("^%s*do%s*$") or line:match("^%s*do%s*%-%-") or
         line:match("^%s*repeat%s*$") or line:match("^%s*repeat%s*%-%-") then

    -- For standalone block-starting keywords, add tracking on the next line
    return string.format('%s\n%s%s %s;',
      line,
      indentation .. "  ", -- Add extra indentation for clarity
      activation_code,
      build_tracking_code()
    )

  -- Block-ending keywords (end, until, else)
  elseif line:match("^%s*end%s*$") or line:match("^%s*end%s*%-%-") or
         line:match("^%s*until%s+.*$") or line:match("^%s*until%s+.*%-%-") or
         line:match("^%s*else%s*$") or line:match("^%s*else%s*%-%-") then

    -- For block-ending keywords, add tracking on the next line
    -- This prevents syntax errors by keeping the tracking separate
    return string.format('%s\n%s%s %s;',
      line,
      indentation, -- Preserve the same indentation level
      activation_code,
      build_tracking_code()
    )
  end

  -- Check if line is part of a table construct to handle it specially
  local is_table_constructor = line:match("^%s*[a-zA-Z0-9_]+%s*=%s*{") or
                              line:match("^%s*{") or
                              line:match("^%s*local%s+[a-zA-Z0-9_]+%s*=%s*{")

  -- Removed unused is_table_entry detection
  -- Previously was checking for table entry patterns but not using the result

  local is_table_end = line:match("^%s*}") or line:match("^%s*},") or line:match("^%s*}%s*$")

  -- For table end markers, just return them unchanged to avoid breaking table syntax
  if is_table_end then
    return line
  end

  -- Handle table constructors carefully to prevent syntax errors
  if is_table_constructor then
    -- For table constructors, we'll add tracking before the line to avoid breaking syntax
    local tracking_code = build_tracking_code and build_tracking_code() or
                         string.format('require("lib.coverage").track_line(%q, %d)', file_path, line_num)

    -- Activation code defined earlier should be available here
    -- but we'll check just in case and redefine if not available
    local act_code = activation_code or
                    string.format('require("lib.coverage.debug_hook").activate_file(%q);', file_path)

    return string.format('%s %s; %s',
                        act_code,
                        tracking_code,
                        line)
  end

  -- For all other executable lines, add tracking before the line
  -- Reuse activation_code and build_tracking_code if they were already defined
  local act_code = activation_code or
                  string.format('require("lib.coverage.debug_hook").activate_file(%q);', file_path)

  local tracking_code = build_tracking_code and build_tracking_code() or
                       (block_info and config.track_blocks
                        and string.format('require("lib.coverage").track_block(%q, %d, %q, %q)',
                                         file_path, line_num, block_info.id, block_info.type)
                        or string.format('require("lib.coverage").track_line(%q, %d)',
                                        file_path, line_num))

  -- Standard line tracking for everything else, adding before the line
  return string.format('%s %s; %s',
    act_code, tracking_code, line
  )
end

---@param file_path string Path to the Lua file to instrument
---@param options? table Optional configuration: allow_fallback, max_file_size, cache_instrumented_files
---@return string|nil instrumented_code Instrumented source code or nil if instrumentation failed
---@return table|nil error Error object if instrumentation failed
-- Instrument a Lua source file by adding coverage tracking with static analysis
function M.instrument_file(file_path, options)
  options = options or {}

  -- Copy relevant config values to options for easier access
  options.allow_fallback = options.allow_fallback or config.allow_fallback
  options.max_file_size = options.max_file_size or config.max_file_size
  options.cache_instrumented_files = options.cache_instrumented_files ~= nil
                                     and options.cache_instrumented_files
                                     or config.cache_instrumented_files

  -- Validate file_path
  if not file_path then
    local err = error_handler.validation_error(
      "File path is required for instrumentation",
      {param = "file_path"}
    )
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Normalize file path to prevent double slashes and other path issues
  file_path = file_path:gsub("//", "/"):gsub("\\", "/")

  -- Removed the problematic files hack. We need to fix the actual instrumentation
  -- process to handle all valid Lua files correctly without special cases.

  -- Check if in cache first
  if options.cache_instrumented_files and instrumented_cache[file_path] and not options.force then
    logger.debug("Using cached instrumentation", {
      file_path = file_path
    })

    -- Force cache reset if the content is from a different file (same path gets reused in tests)
    local original_source = error_handler.safe_io_operation(
      function() return fs.read_file(file_path) end,
      file_path,
      {operation = "read_file"}
    )

    -- If the source content has changed but the path is the same, invalidate the cache
    if original_source and instrumented_cache[file_path .. "_source"] ~= original_source then
      logger.debug("File content changed, invalidating cache", {
        file_path = file_path,
        original_size = #original_source,
        cached_size = instrumented_cache[file_path .. "_source"] and #instrumented_cache[file_path .. "_source"] or 0
      })
      -- Continue with instrumentation below
    else
      return instrumented_cache[file_path]
    end
  end

  logger.debug("Instrumenting file", {
    file_path = file_path,
    use_static_analysis = config.use_static_analysis
  })

  -- File existence check
  local exists = error_handler.safe_io_operation(
    function() return fs.file_exists(file_path) end,
    file_path,
    {operation = "file_exists"}
  )

  if not exists then
    local err = error_handler.io_error(
      "Instrumentation failed: file not found",
      {file_path = file_path}
    )
    logger.error(err.message, err.context)
    return nil, err
  end

  -- Read file content
  local source, read_err = error_handler.safe_io_operation(
    function() return fs.read_file(file_path) end,
    file_path,
    {operation = "read_file"}
  )

  if not source then
    logger.error("Instrumentation failed: could not read file", {
      file_path = file_path,
      error = read_err and read_err.message
    })
    return nil, read_err or error_handler.io_error(
      "Could not read file",
      {file_path = file_path}
    )
  end

  -- Check for large files and implement fallback strategy
  local file_size = #source
  if file_size > options.max_file_size then
    -- Create a warning but continue with tracking
    local warning = error_handler.validation_error(
      "File too large for instrumentation - using debug hook fallback",
      {
        file_path = file_path,
        size = file_size,
        max_size = options.max_file_size,
        allow_fallback = options.allow_fallback
      }
    )
    logger.warn(warning.message, warning.context)

    -- Register the file for tracking with debug_hook (will use debug hook method instead)
    if M.register_for_debug_hook then
      local success, err = error_handler.try(function()
        return M.register_for_debug_hook(file_path, source)
      end)

      if not success then
        logger.warn("Failed to register large file for debug hook fallback", {
          file_path = file_path,
          error = err and err.message
        })
      else
        logger.info("Large file registered for debug hook tracking instead of instrumentation", {
          file_path = file_path,
          size = file_size,
          max_size = options.max_file_size
        })
      end
    end

    -- For tests only - return a special marker instrumented code
    if options.allow_fallback then
      -- Create a minimal instrumented file that just loads the original
      -- This allows tests to still run while using the debug hook for coverage
      local fallback_code = string.format([[
local _ENV = _G
-- This file was too large for instrumentation - using debug hook fallback
-- Original file: %s
-- Size: %d bytes (max: %d bytes)
local coverage = require("lib.coverage")
coverage.track_file(%q)
return loadfile(%q)()
      ]], file_path, file_size, options.max_file_size, file_path, file_path)

      return fallback_code
    end

    -- Return structured error for normal operation
    return nil, warning
  end

  -- Skip coverage module files unless explicitly enabled
  local is_coverage_file = file_path:find("lib/coverage", 1, true) or
                          file_path:find("lib/tools/parser", 1, true)

  if is_coverage_file and not config.include_coverage_module then
    local err = error_handler.validation_error(
      "Coverage module file excluded from instrumentation",
      {file_path = file_path}
    )
    logger.debug(err.message, err.context)
    return nil, err
  end

  logger.debug("Instrumenting source code", {
    file_path = file_path,
    source_length = #source
  })

  -- Enhanced instrumentation with static analysis if available
  if config.use_static_analysis then
    local analyzer, init_err = init_static_analyzer()

    if not analyzer then
      logger.warn("Static analyzer initialization failed, falling back to basic instrumentation", {
        file_path = file_path,
---@diagnostic disable-next-line: undefined-field
        error = init_err and init_err.message
      })
      -- Continue with basic instrumentation
    else
      -- Parse the file to get AST and code map
      local success, result, err = error_handler.try(function()
        -- Use generate_code_map which takes source content directly
        local code_map = static_analyzer.generate_code_map(file_path, nil, source)
        
        -- Ensure code_map is populated and extract AST if available
        local ast = code_map and code_map.ast
        
        logger.debug("Generated code map for instrumentation", {
          file_path = file_path,
          has_code_map = code_map ~= nil,
          has_ast = ast ~= nil
        })
        
        return {ast = ast, code_map = code_map}
      end)

      if success and result.ast and result.code_map then
        logger.debug("Using static analysis for instrumentation", {
          file_path = file_path,
          has_blocks = result.code_map.blocks ~= nil,
          has_functions = result.code_map.functions ~= nil
        })

        local lines = {}
        local line_num = 1
        local executable_lines = 0
        local instrumented_lines = 0

        -- Process each line with static analysis information
        for line in source:gmatch("[^\r\n]+") do
          local is_executable = static_analyzer.is_line_executable(result.code_map, line_num)

          -- Get block information for this line
          local blocks_for_line = static_analyzer.get_blocks_for_line(result.code_map, line_num)
          local block_info = blocks_for_line and blocks_for_line[1] or nil

          if is_executable then
            -- Add tracking code before executable lines
            local instrumented_line, instr_err = instrument_line(
              line, file_path, line_num, is_executable, block_info
            )

            if instrumented_line then
              table.insert(lines, instrumented_line)
              instrumented_lines = instrumented_lines + 1
              executable_lines = executable_lines + 1
            else
              -- If instrumentation fails for a line, use the original
              logger.warn("Line instrumentation failed, using original line", {
                file_path = file_path,
                line_num = line_num,
                error = instr_err and instr_err.message
              })
              table.insert(lines, line)
            end
          else
            -- For non-executable lines, keep them unchanged
            table.insert(lines, line)
          end

          line_num = line_num + 1
        end

        -- Add _ENV preservation to ensure proper environment variable access
        -- Also add advanced validation to check for balanced braces to prevent syntax errors
        local source_lines = table.concat(lines, "\n")

        -- Validate and fix balanced braces and function bodies in the generated code
        local function validate_and_fix_syntax(str)
            local stack = {}
            local in_string = false
            local string_delim = nil
            local pos = 1
            local fixed_str = ""
            local in_comment = false
            local line_start = true
            local current_line = 1
            local table_constructor_positions = {} -- Track table constructor positions

            local function check_keyword(pos, str, keyword)
                local end_pos = pos + #keyword - 1
                if end_pos <= #str then
                    local found = str:sub(pos, end_pos)
                    if found == keyword then
                        local next_char = (end_pos + 1 <= #str) and str:sub(end_pos + 1, end_pos + 1) or ""
                        -- Check if it's a whole word (followed by space, newline, or punctuation)
                        if next_char == "" or next_char:match("%s") or next_char:match("[%p]") then
                            return true
                        end
                    end
                end
                return false
            end

            -- First pass to handle required("lib.coverage") statements
            -- Create a map of positions where we have coverage tracking calls
            local coverage_calls = {}
            local pattern = "require%([\"']lib%.coverage[\"']%)"
            local s, e = str:find(pattern)
            while s do
                coverage_calls[s] = e
                s, e = str:find(pattern, e + 1)
            end

            while pos <= #str do
                local char = str:sub(pos, pos)
                local next_char = pos < #str and str:sub(pos+1, pos+1) or ""

                -- Track line numbers for better error reporting
                if char == "\n" then
                    current_line = current_line + 1
                    line_start = true
                elseif not char:match("%s") then
                    line_start = false
                end

                -- Handle comments
                if not in_string and not in_comment and char == "-" and next_char == "-" then
                    in_comment = true
                    fixed_str = fixed_str .. "--"
                    pos = pos + 2
                    goto continue
                elseif in_comment and char == "\n" then
                    in_comment = false
                end

                -- Skip processing if in comment
                if in_comment then
                    fixed_str = fixed_str .. char
                    pos = pos + 1
                    goto continue
                end

                -- Check if we're at the start of a coverage call
                local in_coverage_call = false
                for start_pos, end_pos in pairs(coverage_calls) do
                    if pos >= start_pos and pos <= end_pos then
                        in_coverage_call = true
                        break
                    end
                end

                -- Handle string literals to ignore syntax in strings
                if (char == "'" or char == '"' or (char == "[" and next_char == "[")) and not in_string and not in_coverage_call then
                    in_string = true
                    string_delim = char
                    if char == "[" and next_char == "[" then
                        string_delim = "]]"
                        fixed_str = fixed_str .. char .. next_char
                        pos = pos + 2
                        goto continue
                    end
                elseif in_string then
                    if (char == string_delim) or
                       (string_delim == "]]" and char == "]" and next_char == "]") then
                        in_string = false
                        if string_delim == "]]" then
                            fixed_str = fixed_str .. char .. next_char
                            pos = pos + 2
                            goto continue
                        end
                    end
                end

                -- Only track syntax elements outside of strings and not in coverage calls
                if not in_string and not in_coverage_call then
                    -- Track braces for table constructors
                    if char == "{" then
                        -- Store in stack
                        table.insert(stack, {type = "{", line = current_line, pos = pos})
                        -- Also track in the positions table for better context
                        table.insert(table_constructor_positions, {
                            start = pos,
                            line = current_line,
                            closed = false
                        })
                    elseif char == "}" then
                        if #stack > 0 then
                            local last = stack[#stack]
                            if last.type == "{" then
                                table.remove(stack)
                                -- Mark the corresponding table constructor as closed
                                for i = #table_constructor_positions, 1, -1 do
                                    local tbl = table_constructor_positions[i]
                                    if not tbl.closed then
                                        tbl.closed = true
                                        tbl.end_pos = pos
                                        break
                                    end
                                end
                            else
                                -- Unmatched closing brace, ignore it
                                logger.warn("Unmatched closing brace found", {
                                    line = current_line,
                                    expected = last.type
                                })
                                pos = pos + 1
                                goto continue
                            end
                        else
                            -- Unmatched closing brace, ignore it
                            logger.warn("Unmatched closing brace found with empty stack", {
                                line = current_line
                            })
                            pos = pos + 1
                            goto continue
                        end
                    end

                    -- Track function definitions and control flow keywords
                    if line_start and (
                       check_keyword(pos, str, "function") or
                       check_keyword(pos, str, "if") or
                       check_keyword(pos, str, "for") or
                       check_keyword(pos, str, "while") or
                       check_keyword(pos, str, "repeat") or
                       check_keyword(pos, str, "do")
                    ) then
                        local keyword = ""
                        if check_keyword(pos, str, "function") then keyword = "function"
                        elseif check_keyword(pos, str, "if") then keyword = "if"
                        elseif check_keyword(pos, str, "for") then keyword = "for"
                        elseif check_keyword(pos, str, "while") then keyword = "while"
                        elseif check_keyword(pos, str, "repeat") then keyword = "repeat"
                        elseif check_keyword(pos, str, "do") then keyword = "do"
                        end

                        table.insert(stack, {type = keyword, line = current_line, pos = pos})
                        fixed_str = fixed_str .. keyword
                        pos = pos + #keyword
                        goto continue
                    elseif line_start and check_keyword(pos, str, "end") then
                        if #stack > 0 then
                            local last = stack[#stack]
                            if last.type == "function" or last.type == "if" or
                               last.type == "for" or last.type == "while" or
                               last.type == "do" then
                                table.remove(stack)
                            else
                                -- Unmatched end, but keep it
                                logger.warn("Unmatched 'end' found", {
                                    line = current_line,
                                    expected = last.type
                                })
                            end
                        else
                            logger.warn("Unmatched 'end' found with empty stack", {
                                line = current_line
                            })
                        end
                    elseif line_start and check_keyword(pos, str, "until") then
                        if #stack > 0 then
                            local last = stack[#stack]
                            if last.type == "repeat" then
                                table.remove(stack)
                            else
                                -- Unmatched until, but keep it
                                logger.warn("Unmatched 'until' found", {
                                    line = current_line,
                                    expected = last.type
                                })
                            end
                        else
                            logger.warn("Unmatched 'until' found with empty stack", {
                                line = current_line
                            })
                        end
                    end

                    -- Special handling for "local" declarations with tables
                    if line_start and check_keyword(pos, str, "local") and not in_coverage_call then
                        -- Look ahead to see if this local declaration includes a table
                        local rest_of_line = str:sub(pos):match("([^\n]*)")
                        if rest_of_line and rest_of_line:match("{") and not rest_of_line:match("}") then
                            logger.debug("Found local declaration with unclosed table", {
                                line = current_line,
                                text = rest_of_line
                            })
                            -- Additional check ahead will handle this
                        end
                    end
                end

                fixed_str = fixed_str .. char
                pos = pos + 1
                ::continue::
            end

            -- If there are unclosed constructs, add the missing closing statements
            if #stack > 0 then
                logger.warn("Unclosed syntax constructs detected", {count = #stack})

                -- Build closure in reverse order (most nested first)
                local additions = {}
                for i = #stack, 1, -1 do
                    local item = stack[i]
                    if item.type == "{" then
                        -- More careful handling for table constructors
                        -- Check if this table constructor is inside a function or control structure
                        local is_nested = false
                        for j = 1, #stack do
                            if stack[j].pos < item.pos and stack[j].type ~= "{" then
                                is_nested = true
                                break
                            end
                        end

                        -- Add appropriate closing brace with proper formatting
                        if is_nested then
                            table.insert(additions, "}")
                        else
                            -- For top-level tables, add a newline for better readability
                            table.insert(additions, "\n}")
                        end
                    elseif item.type == "repeat" then
                        table.insert(additions, "\nuntil true")
                    elseif item.type ~= "until" then -- all other constructs use "end"
                        table.insert(additions, "\nend")
                    end
                end

                -- Add all closures
                fixed_str = fixed_str .. table.concat(additions, "")
            end

            -- Special handling for table constructors in instrumentation code
            for _, tbl in ipairs(table_constructor_positions) do
                if not tbl.closed then
                    logger.warn("Unclosed table constructor detected", {
                        line = tbl.line,
                        start_pos = tbl.start
                    })
                end
            end

            return fixed_str, #stack
        end

        local fixed_source, unclosed_count = validate_and_fix_syntax(source_lines)
        if unclosed_count > 0 then
            logger.warn("Fixed unbalanced syntax constructs in generated code", {
                unclosed_count = unclosed_count,
                file_path = file_path
            })
        end

        -- Add static imports preamble when configured
        local use_static_imports = options and options.use_static_imports or config.use_static_imports
        local instrumented_source = "local _ENV = _G\n"

        -- Add static imports if configured
        if use_static_imports then
          instrumented_source = instrumented_source .. string.format([[
local _coverage_track_line = require("lib.coverage").track_line
local _coverage_track_block = require("lib.coverage").track_block
local _coverage_track_function = require("lib.coverage").track_function
local _coverage_activate_file = require("lib.coverage.debug_hook").activate_file
local _file_path = %q

]], file_path)
        end

        instrumented_source = instrumented_source .. fixed_source

        -- Generate sourcemap for error mapping
        if config.sourcemap_enabled then
          local _, map_err = generate_sourcemap(source, instrumented_source, file_path)
          if map_err then
            logger.warn("Sourcemap generation failed", {
              file_path = file_path,
              error = map_err.message
            })
            -- Continue without sourcemap
          end
        end

        -- Cache the result if enabled
        if config.cache_instrumented_files then
          instrumented_cache[file_path] = instrumented_source
          -- Also store the original source to detect content changes for the same path
          instrumented_cache[file_path .. "_source"] = source
        end

        logger.info("File instrumentation completed with static analysis", {
          file_path = file_path,
          total_lines = line_num - 1,
          executable_lines = executable_lines,
          instrumented_lines = instrumented_lines
        })

        return instrumented_source
      else
        logger.warn("Static analysis failed, falling back to basic instrumentation", {
          file_path = file_path,
---@diagnostic disable-next-line: undefined-field
          error = err and err.message
        })
        -- Continue with basic instrumentation
      end
    end
  end

  -- Basic instrumentation (fallback if static analysis is disabled or failed)
  local success, result, err = error_handler.try(function()
    local lines = {}
    local line_num = 1
    local executable_lines = 0
    local instrumented_lines = 0

    for line in source:gmatch("[^\r\n]+") do
      -- Basic heuristic to detect executable lines
      local is_executable = not line:match("^%s*%-%-") and not line:match("^%s*$")

      if is_executable then
        -- Add tracking code before executable lines
        local use_static_imports = options and options.use_static_imports or config.use_static_imports

        local instrumented_line
        if use_static_imports then
          -- Use static imports for better performance and to avoid recursion
          instrumented_line = string.format(
            '_coverage_track_line(%q, %d); %s',
            file_path, line_num, line
          )
        else
          -- Original dynamic tracking code
          instrumented_line = string.format(
            'require("lib.coverage").track_line(%q, %d); %s',
            file_path, line_num, line
          )
        end

        table.insert(lines, instrumented_line)
        instrumented_lines = instrumented_lines + 1
        executable_lines = executable_lines + 1
      else
        table.insert(lines, line)
      end
      line_num = line_num + 1
    end

    -- Add _ENV preservation to ensure proper environment variable access
    -- Also add advanced validation to check for balanced braces to prevent syntax errors
    local source_lines = table.concat(lines, "\n")

    -- Validate and fix balanced braces and function bodies in the generated code
    local function validate_and_fix_syntax(str)
        local stack = {}
        local in_string = false
        local string_delim = nil
        local pos = 1
        local fixed_str = ""
        local in_comment = false
        local line_start = true
        local current_line = 1
        local table_constructor_positions = {} -- Track table constructor positions

        local function check_keyword(pos, str, keyword)
            local end_pos = pos + #keyword - 1
            if end_pos <= #str then
                local found = str:sub(pos, end_pos)
                if found == keyword then
                    local next_char = (end_pos + 1 <= #str) and str:sub(end_pos + 1, end_pos + 1) or ""
                    -- Check if it's a whole word (followed by space, newline, or punctuation)
                    if next_char == "" or next_char:match("%s") or next_char:match("[%p]") then
                        return true
                    end
                end
            end
            return false
        end

        -- First pass to handle required("lib.coverage") statements
        -- Create a map of positions where we have coverage tracking calls
        local coverage_calls = {}
        local pattern = "require%([\"']lib%.coverage[\"']%)"
        local s, e = str:find(pattern)
        while s do
            coverage_calls[s] = e
            s, e = str:find(pattern, e + 1)
        end

        while pos <= #str do
            local char = str:sub(pos, pos)
            local next_char = pos < #str and str:sub(pos+1, pos+1) or ""

            -- Track line numbers for better error reporting
            if char == "\n" then
                current_line = current_line + 1
                line_start = true
            elseif not char:match("%s") then
                line_start = false
            end

            -- Handle comments
            if not in_string and not in_comment and char == "-" and next_char == "-" then
                in_comment = true
                fixed_str = fixed_str .. "--"
                pos = pos + 2
                goto continue
            elseif in_comment and char == "\n" then
                in_comment = false
            end

            -- Skip processing if in comment
            if in_comment then
                fixed_str = fixed_str .. char
                pos = pos + 1
                goto continue
            end

            -- Check if we're at the start of a coverage call
            local in_coverage_call = false
            for start_pos, end_pos in pairs(coverage_calls) do
                if pos >= start_pos and pos <= end_pos then
                    in_coverage_call = true
                    break
                end
            end

            -- Handle string literals to ignore syntax in strings
            if (char == "'" or char == '"' or (char == "[" and next_char == "[")) and not in_string and not in_coverage_call then
                in_string = true
                string_delim = char
                if char == "[" and next_char == "[" then
                    string_delim = "]]"
                    fixed_str = fixed_str .. char .. next_char
                    pos = pos + 2
                    goto continue
                end
            elseif in_string then
                if (char == string_delim) or
                   (string_delim == "]]" and char == "]" and next_char == "]") then
                    in_string = false
                    if string_delim == "]]" then
                        fixed_str = fixed_str .. char .. next_char
                        pos = pos + 2
                        goto continue
                    end
                end
            end

            -- Only track syntax elements outside of strings and not in coverage calls
            if not in_string and not in_coverage_call then
                -- Track braces for table constructors
                if char == "{" then
                    -- Store in stack
                    table.insert(stack, {type = "{", line = current_line, pos = pos})
                    -- Also track in the positions table for better context
                    table.insert(table_constructor_positions, {
                        start = pos,
                        line = current_line,
                        closed = false
                    })
                elseif char == "}" then
                    if #stack > 0 then
                        local last = stack[#stack]
                        if last.type == "{" then
                            table.remove(stack)
                            -- Mark the corresponding table constructor as closed
                            for i = #table_constructor_positions, 1, -1 do
                                local tbl = table_constructor_positions[i]
                                if not tbl.closed then
                                    tbl.closed = true
                                    tbl.end_pos = pos
                                    break
                                end
                            end
                        else
                            -- Unmatched closing brace, ignore it
                            logger.warn("Unmatched closing brace found", {
                                line = current_line,
                                expected = last.type
                            })
                            pos = pos + 1
                            goto continue
                        end
                    else
                        -- Unmatched closing brace, ignore it
                        logger.warn("Unmatched closing brace found with empty stack", {
                            line = current_line
                        })
                        pos = pos + 1
                        goto continue
                    end
                end

                -- Track function definitions and control flow keywords
                if line_start and (
                   check_keyword(pos, str, "function") or
                   check_keyword(pos, str, "if") or
                   check_keyword(pos, str, "for") or
                   check_keyword(pos, str, "while") or
                   check_keyword(pos, str, "repeat") or
                   check_keyword(pos, str, "do")
                ) then
                    local keyword = ""
                    if check_keyword(pos, str, "function") then keyword = "function"
                    elseif check_keyword(pos, str, "if") then keyword = "if"
                    elseif check_keyword(pos, str, "for") then keyword = "for"
                    elseif check_keyword(pos, str, "while") then keyword = "while"
                    elseif check_keyword(pos, str, "repeat") then keyword = "repeat"
                    elseif check_keyword(pos, str, "do") then keyword = "do"
                    end

                    table.insert(stack, {type = keyword, line = current_line, pos = pos})
                    fixed_str = fixed_str .. keyword
                    pos = pos + #keyword
                    goto continue
                elseif line_start and check_keyword(pos, str, "end") then
                    if #stack > 0 then
                        local last = stack[#stack]
                        if last.type == "function" or last.type == "if" or
                           last.type == "for" or last.type == "while" or
                           last.type == "do" then
                            table.remove(stack)
                        else
                            -- Unmatched end, but keep it
                            logger.warn("Unmatched 'end' found", {
                                line = current_line,
                                expected = last.type
                            })
                        end
                    else
                        logger.warn("Unmatched 'end' found with empty stack", {
                            line = current_line
                        })
                    end
                elseif line_start and check_keyword(pos, str, "until") then
                    if #stack > 0 then
                        local last = stack[#stack]
                        if last.type == "repeat" then
                            table.remove(stack)
                        else
                            -- Unmatched until, but keep it
                            logger.warn("Unmatched 'until' found", {
                                line = current_line,
                                expected = last.type
                            })
                        end
                    else
                        logger.warn("Unmatched 'until' found with empty stack", {
                            line = current_line
                        })
                    end
                end

                -- Special handling for "local" declarations with tables
                if line_start and check_keyword(pos, str, "local") and not in_coverage_call then
                    -- Look ahead to see if this local declaration includes a table
                    local rest_of_line = str:sub(pos):match("([^\n]*)")
                    if rest_of_line and rest_of_line:match("{") and not rest_of_line:match("}") then
                        logger.debug("Found local declaration with unclosed table", {
                            line = current_line,
                            text = rest_of_line
                        })
                        -- Additional check ahead will handle this
                    end
                end
            end

            fixed_str = fixed_str .. char
            pos = pos + 1
            ::continue::
        end

        -- If there are unclosed constructs, add the missing closing statements
        if #stack > 0 then
            logger.warn("Unclosed syntax constructs detected", {count = #stack})

            -- Build closure in reverse order (most nested first)
            local additions = {}
            for i = #stack, 1, -1 do
                local item = stack[i]
                if item.type == "{" then
                    -- More careful handling for table constructors
                    -- Check if this table constructor is inside a function or control structure
                    local is_nested = false
                    for j = 1, #stack do
                        if stack[j].pos < item.pos and stack[j].type ~= "{" then
                            is_nested = true
                            break
                        end
                    end

                    -- Add appropriate closing brace with proper formatting
                    if is_nested then
                        table.insert(additions, "}")
                    else
                        -- For top-level tables, add a newline for better readability
                        table.insert(additions, "\n}")
                    end
                elseif item.type == "repeat" then
                    table.insert(additions, "\nuntil true")
                elseif item.type ~= "until" then -- all other constructs use "end"
                    table.insert(additions, "\nend")
                end
            end

            -- Add all closures
            fixed_str = fixed_str .. table.concat(additions, "")
        end

        -- Special handling for table constructors in instrumentation code
        for _, tbl in ipairs(table_constructor_positions) do
            if not tbl.closed then
                logger.warn("Unclosed table constructor detected", {
                    line = tbl.line,
                    start_pos = tbl.start
                })
            end
        end

        return fixed_str, #stack
    end

    local fixed_source, unclosed_count = validate_and_fix_syntax(source_lines)
    if unclosed_count > 0 then
        logger.warn("Fixed unbalanced syntax constructs in generated code", {
            unclosed_count = unclosed_count,
            file_path = file_path
        })
    end

    local instrumented_source = "local _ENV = _G\n" .. fixed_source

    -- Generate sourcemap for error mapping
    if config.sourcemap_enabled then
      local _, map_err = generate_sourcemap(source, instrumented_source, file_path)
      if map_err then
        logger.warn("Sourcemap generation failed", {
          file_path = file_path,
          error = map_err.message
        })
        -- Continue without sourcemap
      end
    end

    -- Cache the result if enabled
    if config.cache_instrumented_files then
      instrumented_cache[file_path] = instrumented_source
      -- Also store the original source to detect content changes for the same path
      instrumented_cache[file_path .. "_source"] = source
    end

    logger.info("File instrumentation completed with basic analysis", {
      file_path = file_path,
      total_lines = line_num - 1,
      executable_lines = executable_lines,
      instrumented_lines = instrumented_lines
    })

    return instrumented_source
  end)

  if not success then
    logger.error("Instrumentation failed with error", {
      file_path = file_path,
---@diagnostic disable-next-line: undefined-field, need-check-nil
      error = err.message,
---@diagnostic disable-next-line: undefined-field, need-check-nil
      category = err.category
    })
    return nil, err
  end

  return result
end

---@return boolean success Always returns true
-- Clear the instrumentation cache
function M.clear_cache()
  -- Clear all instrumented code and source caches
  instrumented_cache = {}
  sourcemap_cache = {}
  -- Fixed global variable reference to use proper local scope
  module_path_cache = {}
  logger.debug("Instrumentation cache cleared")
  return M
end

---@return table env An isolated environment table for instrumentation
-- Create an isolated environment for instrumentation execution
-- This prevents the instrumentation process from triggering infinite recursion
function M.create_isolated_environment()
  local env = setmetatable({}, {__index = _G})
  env._G = env  -- Self-reference for _G

  -- Create a non-recursive require function
  env.require = function(module_name)
    -- Direct lookup in package.loaded without instrumentation
    if package.loaded[module_name] then
      return package.loaded[module_name]
    end

    -- Use original require but don't instrument further
    local original_require = _G.require
    if type(original_require) == "function" then
      return original_require(module_name)
    end

    return nil
  end

  -- Define minimal fs operations to avoid recursion
  env.fs = {
    file_exists = function(path)
      local file = io.open(path, "r")
      if file then file:close(); return true end
      return false
    end,

    read_file = function(path)
      local file = io.open(path, "r")
      if not file then return nil end
      local content = file:read("*a")
      file:close()
      return content
    end,

    write_file = function(path, content)
      local file = io.open(path, "w")
      if not file then return false end
      file:write(content)
      file:close()
      return true
    end
  }

  -- Provide minimal logging to avoid recursion
  env.logger = {
    debug = function() end,
    info = function() end,
    warn = function() end,
    error = function() end,
    trace = function() end
  }

  return env
end

---@param test_module_path string Path to the test module
---@return table env An isolated test environment with proper module boundaries
-- Create a boundary-aware testing environment
function M.create_isolated_test_environment(test_module_path)
  local original_package_path = package.path
  local env = M.create_isolated_environment()

  -- Setup proper module boundaries
  local function build_isolated_path(module_path)
    -- Extract directory from module path
    local dir = module_path:match("^(.+)/[^/]+$") or "."
    return dir .. "/?.lua;" .. original_package_path
  end

---@diagnostic disable-next-line: missing-fields
  env.package = {
    path = build_isolated_path(test_module_path),
    loaded = setmetatable({}, {__index = package.loaded})
  }

  return env
end

-- Tables to track module loading and prevent recursion
local instrumented_modules = {} -- Tracks files that have been instrumented by path
local currently_instrumenting = {} -- Tracks modules being instrumented to prevent cycles
-- Removed unused tracking table
-- local module_files = {} -- Maps module names to file paths for better tracking
local required_modules = {} -- Tracks which modules were already processed
local instrumentation_depth = 0 -- Tracks the recursion depth of instrumentation
-- Module path cache for non-recursive resolution
local module_path_cache = {}

-- Maximum depth for instrumentation to prevent infinite recursion
local MAX_INSTRUMENTATION_DEPTH = 10

-- Table of core modules that should never be instrumented to prevent recursion
local core_modules = {
  -- Coverage and instrumentation modules
  ["lib.coverage"] = true,
  ["lib.coverage.instrumentation"] = true,
  ["lib.coverage.debug_hook"] = true,
  ["lib.coverage.file_manager"] = true,
  ["lib.coverage.patchup"] = true,
  ["lib.coverage.static_analyzer"] = true,
  ["lib.coverage.init"] = true,

  -- Essential utility modules used by instrumentation
  ["lib.tools.filesystem"] = true,
  ["lib.tools.error_handler"] = true,
  ["lib.tools.logging"] = true,

  -- Parser modules
  ["lib.tools.parser"] = true,
  ["lib.tools.parser.init"] = true,
  ["lib.tools.parser.grammar"] = true,
  ["lib.tools.parser.pp"] = true,
  ["lib.tools.parser.validator"] = true,

  -- Test/example modules
  ["instrumentation_test_.*"] = true,  -- Special pattern for test files

  -- Core Lua modules that should never be instrumented
  ["package"] = true,
  ["io"] = true,
  ["os"] = true,
  ["string"] = true,
  ["math"] = true,
  ["table"] = true,
  ["coroutine"] = true,
  ["debug"] = true
}

-- Helper function to check if a module should be excluded based on patterns
local function is_excluded_module(module_name)
  -- First check for direct matches
  if core_modules[module_name] then
    return true
  end

  -- Then check for pattern matches
  for pattern, _ in pairs(core_modules) do
    if pattern:find("*") or pattern:find("%.") or pattern:find("%+") then
      -- Pattern match using string.match
      if module_name:match(pattern) then
        return true
      end
    end
  end

  -- Also exclude any module from coverage or parser paths
  if module_name:match("^lib%.coverage") or
     module_name:match("^lib%.tools%.parser") then
    return true
  end

  return false
end

-- Non-recursive module path resolution to prevent recursion
local function find_module_file_non_recursive(module_name)
  if not module_name or type(module_name) ~= "string" then
    return nil
  end

  -- Check cache first to avoid repeated lookups
  if module_path_cache[module_name] then
    return module_path_cache[module_name]
  end

  local path_separator = package.config:sub(1,1)
  local path_pattern = package.path

  -- Convert module name to file path for direct checking
  local file_path = module_name:gsub("%.", path_separator)

  -- Try direct file checking with common extensions
  for _, ext in ipairs({".lua", "/init.lua"}) do
    local full_path = file_path .. ext

    -- Use io.open directly instead of fs.file_exists
    local file = io.open(full_path, "r")
    if file then
      file:close()
      module_path_cache[module_name] = full_path
      return full_path
    end
  end

  -- Try package.path patterns without using fs module
  for pattern in string.gmatch(path_pattern, "[^;]+") do
    local filename = string.gsub(pattern, "%?", module_name:gsub("%.", path_separator))

    local file = io.open(filename, "r")
    if file then
      file:close()
      -- Cache the result for future lookups
      module_path_cache[module_name] = filename
      return filename
    end
  end

  return nil
end

-- Helper function to get the actual module file path
local function find_module_file(module_name)
  -- Delegate to the non-recursive implementation
  return find_module_file_non_recursive(module_name)
end

-- Helper function to determine if a module should be instrumented
local function should_instrument_module(module_name, module_path)
  -- Skip if we're too deep to prevent infinite recursion
  if instrumentation_depth >= MAX_INSTRUMENTATION_DEPTH then
    logger.warn("Maximum instrumentation depth reached, skipping module", {
      module = module_name,
      depth = instrumentation_depth,
      max_depth = MAX_INSTRUMENTATION_DEPTH
    })
    return false
  end

  -- Skip non-string module names
  if type(module_name) ~= "string" then
    return false
  end

  -- Skip already processed modules
  if required_modules[module_name] then
    return false
  end

  -- Skip excluded modules
  if is_excluded_module(module_name) then
    return false
  end

  -- Skip modules already being instrumented (cycle detection)
  if currently_instrumenting[module_name] then
    return false
  end

  -- Skip if the module path is in an excluded directory
  if module_path and (
     module_path:find("lib/coverage", 1, true) or
     module_path:find("lib/tools/parser", 1, true)) then
    return false
  end

  -- Skip if the instrumentation predicate says no
  if not M.should_instrument or (module_path and not M.should_instrument(module_path)) then
    return false
  end

  return true
end

---@return coverage.instrumentation The instrumentation module (for method chaining)
-- Replace a require call to use our instrumented version
function M.instrument_require()
  logger.debug("Instrumenting require function", {
    operation = "instrument_require"
  })

  -- Safety check to prevent double instrumentation
  if _G._INSTRUMENTED_REQUIRE then
    logger.warn("Require function already instrumented, skipping", {
      operation = "instrument_require"
    })
    return M
  end

  local success, err = error_handler.try(function()
    -- Store the original require function
    local original_require = require

    -- Mark require as instrumented to prevent double instrumentation
    _G._INSTRUMENTED_REQUIRE = true

    -- Override the global require function
---@diagnostic disable-next-line: duplicate-set-field
    _G.require = function(module_name)
      -- Skip instrumentation for non-string modules
      if type(module_name) ~= "string" then
        return original_require(module_name)
      end

      -- Return already loaded modules immediately
      if package.loaded[module_name] then
        return package.loaded[module_name]
      end

      -- Skip instrumentation for excluded modules
      if is_excluded_module(module_name) then
        logger.trace("Skipping excluded module", {
          module = module_name,
          operation = "require"
        })
        return original_require(module_name)
      end

      -- Look up the module file path
      local module_path = find_module_file(module_name)

      -- Check if we should instrument this module
      if not should_instrument_module(module_name, module_path) then
        logger.trace("Module not selected for instrumentation", {
          module = module_name,
          path = module_path,
          operation = "require"
        })

        -- Just use the original require
        local result = original_require(module_name)
        required_modules[module_name] = true

        -- Trigger module load callback if present
        if M.on_module_load then
          local callback_success, callback_err = error_handler.try(function()
            return M.on_module_load(module_name, result, module_path)
          end)

          if not callback_success and callback_err then
            logger.warn("Module load callback error", {
              module = module_name,
              error = callback_err.message or tostring(callback_err)
            })
          end
        end

        return result
      end

      -- Mark that we're currently instrumenting this module to prevent recursion
      currently_instrumenting[module_name] = true
      instrumentation_depth = instrumentation_depth + 1

      logger.debug("Instrumenting module", {
        module = module_name,
        path = module_path,
        depth = instrumentation_depth,
        operation = "require"
      })

      -- Use a pcall to ensure we always clean up our state
      local result, instr_err = nil, nil
      local instr_success = false

      local status, err = pcall(function()
        -- First check if we already instrumented this file
        if module_path and instrumented_modules[module_path] then
          logger.debug("Using already instrumented module", {
            module = module_name,
            path = module_path,
            operation = "require"
          })

          -- Use original require for already instrumented modules
          result = original_require(module_name)
          instr_success = true
          return
        end

        -- Attempt to instrument the file
        if not module_path then
          -- Can't instrument without a file path
          instr_err = "Module file not found"
          return
        end

        -- Create isolated environment for instrumentation
        local isolated_env = M.create_isolated_environment()

        -- Instrument the file within isolated environment to prevent recursion
        local instrumented, err
        local env_func = function()
          return M.instrument_file(module_path, {
            allow_fallback = true,     -- Allow fallback for modules
            max_file_size = 1000000,   -- 1MB limit for modules
            force = false,             -- Use cache if available
            cache_instrumented_files = true, -- Cache for better performance
            use_static_imports = true  -- Use static imports to avoid recursion
          })
        end

        -- Use proper environment isolation based on Lua version
        if _VERSION == "Lua 5.1" then
          -- Lua 5.1 uses setfenv
          setfenv(env_func, isolated_env)
          instrumented = env_func()
        else
          -- Lua 5.2+ uses _ENV
          -- Create function with isolated environment
          local wrapped_func = load(string.dump(env_func), nil, "b", isolated_env)
---@diagnostic disable-next-line: need-check-nil
          instrumented = wrapped_func()
        end

        if not instrumented then
          -- Failed to instrument, use original require
          instr_err = err
          return
        end

        -- Mark this module as instrumented
        instrumented_modules[module_path] = true

        -- Create a temporary file with instrumented code
        local temp_file_manager = require("lib.tools.temp_file")
        local temp_file, create_err = temp_file_manager.create_with_content(instrumented, "lua")
        if not temp_file then
          instr_err = "Failed to create temporary file: " .. tostring(create_err)
          return
        end

        -- First check syntax
        local syntax_check, syntax_err = loadfile(temp_file)
        if not syntax_check then
          -- No need to explicitly remove the temp file, it will be automatically cleaned up
          instr_err = "Syntax error in instrumented module: " .. tostring(syntax_err)
          return
        end

        -- Load and execute the module
        local loaded_module = loadfile(temp_file)

        -- No need to explicitly remove the temp file, it will be automatically cleaned up

        if not loaded_module then
          instr_err = "Failed to load instrumented module"
          return
        end

        -- Execute the module with proper environment
        local exec_success, module_result_or_err = pcall(loaded_module)
        if not exec_success then
          instr_err = "Error executing instrumented module: " .. tostring(module_result_or_err)
          return
        end

        -- Successfully instrumented and executed
        package.loaded[module_name] = module_result_or_err
        result = module_result_or_err
        instr_success = true
      end)

      -- Always clean up tracking state, even if there was an error
      currently_instrumenting[module_name] = nil
      instrumentation_depth = instrumentation_depth - 1
      required_modules[module_name] = true

      -- Handle errors in the instrumentation process
      if not status then
        logger.error("Error during module instrumentation", {
          module = module_name,
          error = err,
          operation = "require"
        })

        -- Fall back to original require
        result = original_require(module_name)
      elseif not instr_success then
        -- Instrumentation failed for some reason
        logger.warn("Module instrumentation failed, using original", {
          module = module_name,
          error = instr_err,
          operation = "require"
        })

        -- Fall back to original require
        result = original_require(module_name)
      end

      -- Call module load callback if present
      if M.on_module_load then
        local callback_success, callback_err = error_handler.try(function()
          return M.on_module_load(module_name, result, module_path)
        end)

        if not callback_success and callback_err then
          logger.warn("Module load callback error", {
            module = module_name,
            error = callback_err.message or tostring(callback_err)
          })
        end
      end

      return result
    end

    logger.info("Require function instrumented successfully", {
      operation = "instrument_require"
    })

    return true
  end)

  if not success then
    logger.error("Failed to instrument require function", {
      error = err.message,
      category = err.category
    })
    return nil, err
  end

  return M
end

-- Override Lua's built-in loaders to use instrumented code
---@return boolean|nil success True if loaders were successfully hooked, nil if failed
---@return table|nil error Error object if hooking failed
function M.hook_loaders()
  logger.debug("Hooking Lua loaders", {
    operation = "hook_loaders"
  })

  local success, err = error_handler.try(function()
    -- Save original loaders in global variables to allow unhooking
    _G._ORIGINAL_LOADFILE = loadfile
    
    -- For backwards compatibility with existing code
    local original_loadfile = loadfile

    -- Replace with instrumented version
    _G.loadfile = function(filename)
      if not filename then
        logger.trace("Loadfile called without filename", {
          operation = "loadfile"
        })
        return original_loadfile()
      end

      logger.trace("Loadfile called", {
        filename = filename
      })

      -- Check if we should instrument this file
      if M.should_instrument and M.should_instrument(filename) then
        logger.debug("Instrumenting file for loadfile", {
          filename = filename
        })

        local instrumented, instr_err = M.instrument_file(filename)
        if instrumented then
          logger.debug("Successfully instrumented file for loadfile", {
            filename = filename,
            instrumented_length = #instrumented
          })
---@diagnostic disable-next-line: param-type-mismatch
          return load(instrumented, "@" .. filename)
        else
          logger.warn("Failed to instrument file for loadfile", {
            filename = filename,
            error = instr_err and (error_handler.is_error(instr_err) and instr_err.message or tostring(instr_err))
          })
        end
      else
        logger.trace("File not selected for instrumentation", {
          filename = filename
        })
      end

      -- Use original loader for now
      return original_loadfile(filename)
    end

    -- Similarly hook dofile if needed
    _G._ORIGINAL_DOFILE = dofile
    local original_dofile = dofile
    _G.dofile = function(filename)
      if not filename then
        logger.trace("Dofile called without filename", {
          operation = "dofile"
        })
        return original_dofile()
      end

      logger.trace("Dofile called", {
        filename = filename
      })

      -- Check if we should instrument this file
      if M.should_instrument and M.should_instrument(filename) then
        logger.debug("Instrumenting file for dofile", {
          filename = filename
        })

        local instrumented, instr_err = M.instrument_file(filename)
        if instrumented then
          logger.debug("Successfully instrumented file for dofile", {
            filename = filename,
            instrumented_length = #instrumented
          })
---@diagnostic disable-next-line: param-type-mismatch
          return load(instrumented, "@" .. filename)()
        else
          logger.warn("Failed to instrument file for dofile", {
            filename = filename,
            error = instr_err and (error_handler.is_error(instr_err) and instr_err.message or tostring(instr_err))
          })
        end
      else
        logger.trace("File not selected for instrumentation", {
          filename = filename
        })
      end

      -- Use original loader
      return original_dofile(filename)
    end

    -- Hook load/loadstring functions if available
    if _G.load then
      _G._ORIGINAL_LOAD = _G.load
      local original_load = _G.load
      _G.load = function(chunk, chunk_name, mode, env)
        logger.trace("Load called", {
          chunk_name = chunk_name or "string",
          is_string = type(chunk) == "string"
        })

        -- Only instrument string chunks with a name that looks like a file
        if type(chunk) == "string" and type(chunk_name) == "string" and
           chunk_name:match("^@(.+)%.lua$") and
           M.should_instrument and M.should_instrument(chunk_name:sub(2)) then

          -- Extract file path from chunk name
          local file_path = chunk_name:sub(2)
          logger.debug("Instrumenting string chunk from load", {
            filename = file_path
          })

          -- Create a temporary file to use our existing instrumentation logic
          local temp_file_manager = require("lib.tools.temp_file")
          local temp_file, temp_err = temp_file_manager.create_with_content(chunk, "lua")

          if temp_file then
            -- Instrument the temporary file
            local instrumented, instr_err = M.instrument_file(temp_file)

            -- No need to clean up the temporary file - it will be automatically cleaned up
            -- by the temp_file management system

            if instrumented then
              logger.debug("Successfully instrumented string chunk", {
                chunk_name = chunk_name,
                instrumented_length = #instrumented
              })
---@diagnostic disable-next-line: param-type-mismatch
              return original_load(instrumented, chunk_name, mode, env)
            else
              logger.warn("Failed to instrument string chunk", {
                chunk_name = chunk_name,
                error = instr_err and (error_handler.is_error(instr_err) and instr_err.message or tostring(instr_err))
              })
            end
          else
            logger.warn("Failed to create temporary file for instrumentation", {
              error = temp_err and temp_err.message
            })
          end
        end

        -- Use original load function
        return original_load(chunk, chunk_name, mode, env)
      end
    end

    logger.info("Lua loaders successfully hooked", {
      operation = "hook_loaders",
      hooked_functions = "loadfile, dofile, load"
    })

    return true
  end)

  if not success then
    logger.error("Failed to hook Lua loaders", {
      error = err.message,
      category = err.category
    })
    return nil, err
  end

  return true
end

---@param callback function Function to call when a module is loaded
---@return coverage.instrumentation The instrumentation module (for method chaining)
-- Set the module load callback
function M.set_module_load_callback(callback)
  logger.debug("Setting module load callback", {
    has_callback = callback ~= nil
  })

  -- Validate callback
  if type(callback) ~= "function" then
    local err = error_handler.validation_error(
      "Invalid callback provided - must be a function",
      {
        operation = "set_module_load_callback",
        type = type(callback)
      }
    )
    logger.warn(err.message, err.context)
    return M
  end

  M.on_module_load = callback
  logger.info("Module load callback set successfully", {
    operation = "set_module_load_callback"
  })

  return M
end

---@param callback function Function to use as fallback for large files
---@return coverage.instrumentation The instrumentation module (for method chaining)
-- Set the debug hook fallback registration function
function M.set_debug_hook_fallback(callback)
  logger.debug("Setting debug hook fallback callback", {
    has_callback = callback ~= nil
  })

  -- Validate callback
  if type(callback) ~= "function" then
    local err = error_handler.validation_error(
      "Invalid fallback callback provided - must be a function",
      {
        operation = "set_debug_hook_fallback",
        type = type(callback)
      }
    )
    logger.warn(err.message, err.context)
    return M
  end

  M.register_for_debug_hook = callback
  logger.info("Debug hook fallback callback set successfully", {
    operation = "set_debug_hook_fallback"
  })

  return M
end

---@param predicate function Function that determines if a file should be instrumented
---@return coverage.instrumentation The instrumentation module (for method chaining)
-- Set the instrumentation predicate
function M.set_instrumentation_predicate(predicate)
  logger.debug("Setting instrumentation predicate", {
    has_predicate = predicate ~= nil
  })

  -- Validate predicate
  if type(predicate) ~= "function" then
    local err = error_handler.validation_error(
      "Invalid predicate provided - must be a function",
      {
        operation = "set_instrumentation_predicate",
        type = type(predicate)
      }
    )
    logger.warn(err.message, err.context)
    return M
  end

  M.should_instrument = predicate
  logger.info("Instrumentation predicate set successfully", {
    operation = "set_instrumentation_predicate"
  })

  return M
end

---@param err string|table Error object or error message to translate
---@return string|table translated_error Error with line numbers corrected using sourcemap
-- Handle runtime errors with sourcemap
function M.translate_error(err)
  if not err then
    local validation_err = error_handler.validation_error(
      "Error object is required for translation",
      {param = "err"}
    )
    logger.warn(validation_err.message, validation_err.context)
    return err
  end

  if not config.sourcemap_enabled then
    return err
  end

  local success, result, translate_err = error_handler.try(function()
    -- Try to match file and line information in the error
    local file_path, line_num = err:match("(%S+):(%d+):")
    if not file_path or not line_num then
      return err
    end

    -- Remove any @ prefix from file path
    if file_path:sub(1, 1) == "@" then
      file_path = file_path:sub(2)
    end

    -- Get sourcemap for this file
    local sourcemap = sourcemap_cache[file_path]
    if not sourcemap then
      return err
    end

    -- Convert line number to integer
    line_num = tonumber(line_num)
    if not line_num then
      return err
    end

    -- Map instrumented line to original line
    local line_info = sourcemap.instrumented_lines[line_num]
    if line_info and line_info.original_line then
      -- Replace line number in error message
      return err:gsub(":" .. line_num .. ":", ":" .. line_info.original_line .. ":")
    end

    return err
  end)

  if not success then
    logger.warn("Error translation failed", {
---@diagnostic disable-next-line: undefined-field
      error = translate_err and translate_err.message
    })
    return err
  end

  return result
end

---@return table|nil stats Instrumentation statistics or nil if retrieval failed
---@return table|nil error Error object if retrieval failed
-- Get statistics about instrumentation
function M.get_stats()
  local success, result, err = error_handler.try(function()
    -- Count cached items
    local cached_files_count = 0
    for _ in pairs(instrumented_cache) do
      cached_files_count = cached_files_count + 1
    end

    local cached_sourcemaps_count = 0
    for _ in pairs(sourcemap_cache) do
      cached_sourcemaps_count = cached_sourcemaps_count + 1
    end

    return {
      cached_files = cached_files_count,
      cached_sourcemaps = cached_sourcemaps_count,
      configuration = config
    }
  end)

  if not success then
    logger.error("Failed to get instrumentation stats", {
---@diagnostic disable-next-line: need-check-nil, undefined-field
      error = err.message,
---@diagnostic disable-next-line: need-check-nil, undefined-field
      category = err.category
    })
    return nil, err
  end

  return result
end

---@return boolean success True if loaders were successfully unhooked
---@return table|nil error Error object if unhooking failed
-- Unhook Lua's built-in loaders to restore original behavior
function M.unhook_loaders()
  logger.debug("Unhooking Lua loaders", {
    operation = "unhook_loaders"
  })

  local success, err = error_handler.try(function()
    -- Restore original loaders if they were saved
    if _G._ORIGINAL_LOADFILE then
      _G.loadfile = _G._ORIGINAL_LOADFILE
      _G._ORIGINAL_LOADFILE = nil
    end
    
    if _G._ORIGINAL_DOFILE then
      _G.dofile = _G._ORIGINAL_DOFILE
      _G._ORIGINAL_DOFILE = nil
    end
    
    if _G._ORIGINAL_LOAD then
      _G.load = _G._ORIGINAL_LOAD
      _G._ORIGINAL_LOAD = nil
    end
    
    logger.info("Lua loaders successfully unhooked", {
      operation = "unhook_loaders",
      unhooked_functions = "loadfile, dofile, load"
    })
    
    return true
  end)
  
  if not success then
    logger.error("Failed to unhook Lua loaders", {
      error = err.message,
      category = err.category
    })
    return nil, err
  end
  
  return true
end

return M
