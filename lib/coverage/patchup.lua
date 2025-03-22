---@class coverage.patchup
---@field _VERSION string Module version (following semantic versioning)
---@field patch_file fun(file_path: string, file_data: {lines: table<number, {executable: boolean, executed: boolean, covered: boolean, source: string}>, discovered: boolean, source_text: string, code_map?: table}): number, table? Patch coverage data for a file by fixing non-executable lines (comments, blank lines, etc.)
---@field patch_all fun(coverage_data: {files: table<string, table>, lines: table, executed_lines: table, covered_lines: table}): number, table? Patch all files in coverage data and update coverage statistics
---@field count_files fun(files_table: table): number, table? Count files in a table with error handling
---@field get_line_classification fun(file_path: string, line_num: number): string|nil, table? Get classification for a specific line (comment, code, structural, empty, etc.)
---@field get_stats fun(): {patched_files: number, patched_lines: number, errors: number, multiline_comments: number, single_line_comments: number, blank_lines: number, structural_lines: number} Get comprehensive statistics about patchup operations
---@field is_patchable fun(file_path: string): boolean, string? Check if a file can be patched (exists and is a Lua file)
---@field analyze_file fun(file_path: string): {comments: number, code: number, blank: number, structural: number, total: number}|nil, table? Analyze file content for line classification
---@field fix_coverage_data fun(coverage_data: table): table, table? Fix and enhance coverage data for reporting
---@field handle_multiline_comments fun(file_path: string, file_data: table): number, table? Fix multiline comment blocks in coverage data
---@field update_coverage_stats fun(coverage_data: table): table Updated coverage statistics

--- Firmo coverage patchup module
--- This module fixes and enhances coverage data for accurate reporting by identifying
--- and correctly marking non-executable lines in the source code. The patchup process
--- is critical for generating meaningful coverage metrics, as it ensures that only
--- truly executable lines are counted when calculating coverage percentages.
---
--- The module handles:
--- - Single-line and multi-line comments
--- - Blank lines and whitespace-only lines
--- - Structural code elements (end statements, else clauses)
--- - Documentation blocks and other non-executable constructs
---
--- Without patchup, coverage reports would show artificially low percentages because
--- many non-executable lines would be incorrectly counted as "not covered" despite
--- being impossible to execute. This module solves that problem by analyzing source
--- code structure and properly categorizing each line.
---
--- @author Firmo Team
--- @version 1.2.0
local M = {}
M._VERSION = "1.2.0"

local fs = require("lib.tools.filesystem")
local static_analyzer = require("lib.coverage.static_analyzer")
local error_handler = require("lib.tools.error_handler")

-- Import logging
local logging = require("lib.tools.logging")
local logger = logging.get_logger("coverage.patchup")
logging.configure_from_config("coverage.patchup")

logger.debug("Coverage patchup module initialized", {
  version = M._VERSION,
})

---@private
---@param line string Line of code to check
---@return boolean is_comment Whether the line is a comment or blank
-- Determines if a line is a comment or blank by removing trailing comments and whitespace
-- Returns true for empty lines, lines with only whitespace, or lines containing only comments
local function is_comment_or_blank(line)
  -- Remove trailing single-line comment
  local code = line:gsub("%-%-.*$", "")
  -- Remove whitespace
  code = code:gsub("%s+", "")
  -- Check if anything remains
  return code == ""
end

---@private
---@param line string|nil Line of code to check
---@param file_path string|nil Path to the file
---@param line_num number|nil Line number in the file
---@param file_data {source?: table<number, string>, code_map?: table}|nil File data from coverage
---@return boolean is_in_comment Whether the line is in a multi-line comment
-- Check if line is inside a multi-line comment using multiple detection strategies
-- 1. First tries to use the static_analyzer's centralized API for accurate detection
-- 2. Falls back to basic pattern matching if file path or static analyzer is not available
-- 3. For single lines, uses simple pattern detection for --[[ and ]] markers
local function is_in_multiline_comment(line, file_path, line_num, file_data)
  -- Use the centralized API from static_analyzer if file_path is available
  if file_path and static_analyzer and static_analyzer.is_in_multiline_comment then
    return static_analyzer.is_in_multiline_comment(file_path, line_num)
  end

  -- Fallback for cases where we only have a line string
  if not file_path or not line_num then
    -- Simple pattern-based detection for single line
    local starts = line and line:find("%-%-%[%[")
    local ends = line and line:find("%]%]")

    -- Very basic state tracking for single line
    if starts and not ends then
      return true
    elseif ends then
      return true
    end

    return false
  end

  -- Fallback if static_analyzer API isn't available or failed
  logger.debug({
    message = "Using fallback multiline comment detection",
    file_path = file_path,
    line = line_num,
    reason = "static_analyzer API unavailable",
  })

  -- Create a temporary context for multiline comment tracking
  local context = {
    in_comment = false,
    line_status = {},
  }

  -- Process source lines up to our target line
  if file_data and file_data.source then
    for i = 1, line_num do
      local current_line = file_data.source[i] or ""

      -- Use basic pattern matching for comment detection
      local starts = current_line:find("%-%-%[%[")
      local ends = current_line:find("%]%]")

      if starts and not ends then
        context.in_comment = true
      elseif ends and context.in_comment then
        context.in_comment = false
      end

      -- Store status for the line
      context.line_status[i] = context.in_comment
    end

    return context.line_status[line_num] or false
  end

  return false
end

---@private
---@param line_text string Line of code to check
---@return boolean is_patchable Whether the line is structural code that should be patched
-- Determines if a line is non-executable structural code that should be patched as covered
-- Identifies control flow structures (end, else, until, etc.), function declarations,
-- closing brackets/braces, empty tables, and module return statements that are structural
-- but don't actually execute as regular code
local function is_patchable_line(line_text)
  -- Standalone structural keywords
  if
    line_text:match("^%s*end%s*$")
    or line_text:match("^%s*else%s*$")
    or line_text:match("^%s*until%s*$")
    or line_text:match("^%s*elseif%s+.+then%s*$")
    or line_text:match("^%s*then%s*$")
    or line_text:match("^%s*do%s*$")
    or line_text:match("^%s*repeat%s*$")
  then
    return true
  end

  -- Function declarations
  if line_text:match("^%s*local%s+function%s+") or line_text:match("^%s*function%s+[%w_:%.]+%s*%(") then
    return true
  end

  -- Closing brackets, braces, parentheses on their own lines
  if line_text:match("^%s*[%]})%)]%s*$") then
    return true
  end

  -- Variable declarations without assignments
  if line_text:match("^%s*local%s+[%w_,]+%s*$") then
    return true
  end

  -- Empty tables or empty blocks
  if line_text:match("^%s*[%w_]+%s*=%s*{%s*}%s*,?%s*$") or line_text:match("^%s*{%s*}%s*,?%s*$") then
    return true
  end

  -- Module returns without expressions
  if line_text:match("^%s*return%s+[%w_%.]+%s*$") then
    return true
  end

  -- Not a patchable line
  return false
end

--- Patch coverage data for a file by fixing non-executable lines.
--- This function analyzes a file's source code and updates its coverage data by
--- correctly marking non-executable lines (comments, blank lines, etc.) as such.
--- This prevents these lines from being counted as "not covered" in coverage metrics.
---
--- The patching process:
--- 1. Validates file existence and data format
--- 2. Analyzes source code structure (using static analysis)
--- 3. Identifies all non-executable lines (comments, blanks, structural elements)
--- 4. Updates coverage data to reflect executability status
--- 5. Returns count of patched lines
---
--- The function works closely with the static analyzer to accurately identify
--- executable vs. non-executable code, handling complex cases like multiline comments
--- and structural code elements.
---
--- @usage
--- -- Patch coverage data for a single file
--- local file_data = coverage_data.files["/path/to/file.lua"]
--- local patched_count = patchup.patch_file("/path/to/file.lua", file_data)
--- print("Patched " .. patched_count .. " lines in file")
---
--- -- Handle potential errors
--- local patched_count, err = patchup.patch_file(file_path, file_data)
--- if err then
---   print("Error patching file: " .. error_handler.format_error(err))
--- end
---
--- @param file_path string Path to the file to patch
--- @param file_data {lines: table<number, {executable: boolean, executed: boolean, covered: boolean, source: string}>, discovered: boolean, source_text: string, code_map?: table} Coverage data for the file
--- @return number patched Number of lines patched
--- @return table|nil err Error information if patching failed
function M.patch_file(file_path, file_data)
  -- Validate parameters
  if not file_path then
    local err = error_handler.validation_error("Missing file path for coverage patching", {
      operation = "patch_file",
    })
    logger.error("Parameter validation failed: " .. error_handler.format_error(err))
    return 0, err
  end

  if not file_data then
    local err = error_handler.validation_error("Missing file data for coverage patching", {
      file_path = file_path,
      operation = "patch_file",
    })
    logger.error("Parameter validation failed: " .. error_handler.format_error(err))
    return 0, err
  end

  logger.debug("Patching coverage data for file", {
    file_path = file_path,
    has_static_analysis = file_data.code_map ~= nil,
  })

  -- Initialize multiline comment cache if needed
  local success, result = error_handler.try(function()
    if file_path and static_analyzer and static_analyzer.update_multiline_comment_cache then
      static_analyzer.update_multiline_comment_cache(file_path)
    end
    return true
  end)

  if not success then
    logger.warn("Failed to initialize multiline comment cache: " .. error_handler.format_error(result), {
      file_path = file_path,
      operation = "patch_file",
    })
    -- Continue despite error; not critical for patching
  end

  -- Check if we have static analysis information
  if file_data.code_map then
    -- Use static analysis with proper error handling
    local patched, executable_lines = 0, 0

    ---@diagnostic disable-next-line: lowercase-global
    success, result, result2 = error_handler.try(function()
      logger.debug("Using static analysis information for patching", {
        file_path = file_path,
        line_count = file_data.line_count,
      })

      local p, e = 0, 0

      for i = 1, file_data.line_count do
        local line_info = file_data.code_map.lines[i]

        -- Check the type of line_info to avoid indexing boolean values
        if type(line_info) == "table" then
          if not line_info.executable then
            -- This is a non-executable line (comment, blank line, etc.)

            -- Mark as non-executable in executable_lines table
            file_data.executable_lines[i] = false

            -- CRITICAL FIX: Remove coverage from non-executable lines
            -- This is the most important step - non-executable lines should NEVER be covered
            if file_data.lines[i] then
              logger.trace("Removing incorrect coverage from non-executable line", {
                file_path = file_path,
                line = i,
                type = line_info.type or "unknown",
              })
            end

            file_data.lines[i] = nil -- Explicitly remove coverage marking from non-executable lines
            p = p + 1
          else
            -- This is an executable line - keep its actual execution status
            file_data.executable_lines[i] = true
            e = e + 1

            -- CRITICAL FIX: Keep executable line status without additional checks
            -- Just maintain the actual execution status - don't add extra validation
            -- that might cause errors with the _executed_lines field that may not exist
            -- Allow the actual coverage tracking to determine if lines were covered
          end
        elseif type(line_info) == "boolean" then
          -- Handle case where line_info is a boolean directly (older format or simplified data)
          file_data.executable_lines[i] = line_info

          -- If line is not executable, remove any coverage marking
          if not line_info then
            if file_data.lines[i] then
              logger.trace("Removing incorrect coverage from non-executable line (boolean marker)", {
                file_path = file_path,
                line = i,
              })
            end

            file_data.lines[i] = nil
            p = p + 1
          else
            e = e + 1
          end
        else
          -- No line info or unsupported type - assume non-executable for safety
          logger.trace("No line info available, marking as non-executable", {
            file_path = file_path,
            line = i,
            line_info_type = type(line_info),
          })

          file_data.executable_lines[i] = false
          file_data.lines[i] = nil
          p = p + 1
        end
      end

      return p, e
    end)

    if not success then
      logger.error("Error during static analysis patching: " .. error_handler.format_error(result), {
        file_path = file_path,
        operation = "patch_file",
      })
      -- Continue with fallback approach despite error
    else
      ---@diagnostic disable-next-line: cast-local-type
      patched, executable_lines = result, result2

      logger.debug("Static analysis patching completed", {
        file_path = file_path,
        patched_lines = patched,
        executable_lines = executable_lines,
      })

      return patched
    end
  end

  logger.debug("No static analysis available, using heuristic approach", {
    file_path = file_path,
  })

  -- No static analysis info available, fall back to heuristic approach
  -- Make sure we have source code with proper error handling
  local lines

  if type(file_data.source) == "table" then
    -- Source is already an array of lines
    lines = file_data.source
    logger.debug("Using existing source lines array", {
      file_path = file_path,
      line_count = #lines,
    })
  elseif type(file_data.source) == "string" then
    -- Parse source string into lines with error handling
    success, result = error_handler.try(function()
      logger.debug("Parsing source string into lines", {
        file_path = file_path,
        source_length = #file_data.source,
      })

      local parsed_lines = {}
      for line in file_data.source:gmatch("[^\r\n]+") do
        table.insert(parsed_lines, line)
      end

      logger.debug("Source string parsed", {
        file_path = file_path,
        line_count = #parsed_lines,
      })

      return parsed_lines
    end)

    if not success then
      logger.error("Failed to parse source string: " .. error_handler.format_error(result), {
        file_path = file_path,
        operation = "patch_file",
      })
      return 0, result
    end

    lines = result
  else
    -- No source available, read from file with safe I/O operations
    logger.debug("No source available, reading from file", {
      file_path = file_path,
    })

    local source_text, read_err = error_handler.safe_io_operation(function()
      return fs.read_file(file_path)
    end, file_path, { operation = "patch_file" })

    if not source_text then
      logger.warn("Failed to read source file for patching: " .. error_handler.format_error(read_err), {
        file_path = file_path,
      })
      return 0, read_err
    end

    -- Parse the source text
    success, result = error_handler.try(function()
      local parsed_lines = {}
      for line in source_text:gmatch("[^\r\n]+") do
        table.insert(parsed_lines, line)
      end

      -- Store the parsed lines in the file_data
      file_data.source = parsed_lines

      logger.debug("Source read from file", {
        file_path = file_path,
        line_count = #parsed_lines,
      })

      return parsed_lines
    end)

    if not success then
      logger.error("Failed to parse source from file: " .. error_handler.format_error(result), {
        file_path = file_path,
        operation = "patch_file",
      })
      return 0, result
    end

    lines = result
  end

  -- Update line_count if needed
  if not file_data.line_count or file_data.line_count == 0 then
    file_data.line_count = #lines
    logger.debug("Updated line count", {
      file_path = file_path,
      line_count = file_data.line_count,
    })
  end

  -- Initialize executable_lines table if not present
  file_data.executable_lines = file_data.executable_lines or {}

  -- Process each line with comprehensive error handling
  success, result = error_handler.try(function()
    logger.debug("Processing file lines with heuristic approach", {
      file_path = file_path,
      line_count = #lines,
    })

    -- Static analyzer access check removed - was unused
    if static_analyzer then
      -- Just access to check if the function exists, but don't store the result
      if type(static_analyzer.in_multiline_comment) == "function" then
        -- Function exists but we don't need to store this information
      end
    end

    local patched = 0
    local multiline_comments = 0
    local single_comments = 0
    local patchable_lines = 0
    local executable_lines = 0

    ---@diagnostic disable-next-line: param-type-mismatch
    for i, line_text in ipairs(lines) do
      -- First check if line is in a multi-line comment block
      if is_in_multiline_comment(line_text, file_path, i, file_data) then
        -- Multi-line comment lines are non-executable
        file_data.executable_lines[i] = false

        if file_data.lines[i] then
          logger.trace("Removing incorrect coverage from multiline comment", {
            file_path = file_path,
            line = i,
          })
        end

        file_data.lines[i] = nil -- Remove any coverage marking
        patched = patched + 1
        multiline_comments = multiline_comments + 1
      -- Then check if it's a single-line comment or blank
      elseif is_comment_or_blank(line_text) then
        -- Comments and blank lines are non-executable
        file_data.executable_lines[i] = false

        if file_data.lines[i] then
          logger.trace("Removing incorrect coverage from comment or blank line", {
            file_path = file_path,
            line = i,
          })
        end

        -- IMPORTANT: Never mark non-executable lines as covered if they weren't executed
        -- (this was causing the bug where comments appeared green in HTML reports)
        file_data.lines[i] = nil -- Explicitly remove any coverage marking
        patched = patched + 1
        single_comments = single_comments + 1
      elseif is_patchable_line(line_text) then
        -- Non-executable code structure lines
        file_data.executable_lines[i] = false

        if file_data.lines[i] then
          logger.trace("Removing incorrect coverage from non-executable structure line", {
            file_path = file_path,
            line = i,
            line_text = line_text:sub(1, 30), -- Only log the first 30 chars to avoid bloat
          })
        end

        -- IMPORTANT: Never mark non-executable lines as covered if they weren't executed
        -- This is the same fix as above, for structured code elements (end, else, etc.)
        file_data.lines[i] = nil -- Explicitly remove any coverage marking
        patched = patched + 1
        patchable_lines = patchable_lines + 1
      else
        -- Potentially executable line
        file_data.executable_lines[i] = true
        executable_lines = executable_lines + 1

        -- IMPORTANT: Do NOT mark executable lines as covered if they weren't actually hit!
        -- Only leave lines as covered if they were already marked as such by the debug hook
        -- We don't touch potentially executable lines that weren't covered
      end
    end

    logger.info("File patching completed", {
      file_path = file_path,
      patched_lines = patched,
      multiline_comments = multiline_comments,
      single_comments = single_comments,
      structure_lines = patchable_lines,
      executable_lines = executable_lines,
    })

    return patched,
      {
        multiline_comments = multiline_comments,
        single_comments = single_comments,
        patchable_lines = patchable_lines,
        executable_lines = executable_lines,
      }
  end)

  if not success then
    logger.error("Error during heuristic patching: " .. error_handler.format_error(result), {
      file_path = file_path,
      operation = "patch_file",
    })
    return 0, result
  end

  return result
end

--- Patch all files in coverage data for comprehensive coverage accuracy.
--- This function applies the patching process to all files in the coverage data,
--- ensuring consistent and accurate coverage metrics across the entire codebase.
--- It handles validation, error management, and provides progress reporting.
---
--- The comprehensive patching process:
--- 1. Validates coverage data structure
--- 2. Iterates through all files in the coverage data
--- 3. Applies the patch_file function to each file
--- 4. Collects and aggregates patching statistics
--- 5. Updates global coverage statistics
---
--- After patching, the coverage data will have much more accurate metrics because
--- non-executable lines will be properly marked and excluded from coverage percentage
--- calculations.
---
--- @usage
--- -- Patch all files in coverage data
--- local patched_files, err = patchup.patch_all(coverage_data)
--- if err then
---   print("Error during patching: " .. error_handler.format_error(err))
--- else
---   print("Patched " .. patched_files .. " files")
---   -- Generate reports with accurate metrics
---   local report = generate_coverage_report(coverage_data)
--- end
---
--- @param coverage_data {files: table<string, {lines: table<number, {executable: boolean, executed: boolean, covered: boolean, source: string}>, discovered: boolean, source_text: string}>, lines: table, executed_lines: table, covered_lines: table} Coverage data containing files to patch
--- @return number total_patched Total number of lines patched across all files
--- @return table|nil err Error information if patching failed
function M.patch_all(coverage_data)
  -- Validate parameters
  if not coverage_data then
    local err = error_handler.validation_error("Missing coverage data for patching", {
      operation = "patch_all",
    })
    logger.error("Parameter validation failed: " .. error_handler.format_error(err))
    return 0, err
  end

  if not coverage_data.files or type(coverage_data.files) ~= "table" then
    local err = error_handler.validation_error("Invalid coverage data structure - missing files table", {
      operation = "patch_all",
      data_type = type(coverage_data.files),
    })
    logger.error("Parameter validation failed: " .. error_handler.format_error(err))
    return 0, err
  end

  -- Use error handler for file counting and logging
  local success, file_count = error_handler.try(function()
    return M.count_files(coverage_data.files)
  end)

  if not success then
    logger.warn("Failed to count files: " .. error_handler.format_error(file_count), {
      operation = "patch_all",
    })
    ---@diagnostic disable-next-line: cast-local-type
    file_count = 0 -- Continue with estimated count
  end

  logger.debug("Starting coverage data patching for all files", {
    file_count = file_count,
  })

  -- Process all files with proper error handling
  local total_patched = 0
  local processed_files = 0
  local patched_files = 0

  -- Add a catch-all try/catch to ensure we don't crash if one file fails
  ---@diagnostic disable-next-line: lowercase-global
  success, result = error_handler.try(function()
    for file_path, file_data in pairs(coverage_data.files) do
      processed_files = processed_files + 1
      logger.debug("Patching file", {
        file_path = file_path,
        file_index = processed_files,
        total_files = file_count,
      })

      -- Protect each file patching operation
      local patched, patch_err = M.patch_file(file_path, file_data)

      if patch_err then
        logger.warn("Error patching file (continuing with next file): " .. error_handler.format_error(patch_err), {
          file_path = file_path,
          operation = "patch_all",
        })
        -- Continue with next file despite error
      else
        if patched > 0 then
          patched_files = patched_files + 1
        end

        total_patched = total_patched + patched
      end
    end

    return {
      total_patched = total_patched,
      processed_files = processed_files,
      patched_files = patched_files,
    }
  end)

  if not success then
    logger.error("Error during coverage patching: " .. error_handler.format_error(result), {
      operation = "patch_all",
      files_processed = processed_files,
      total_files = file_count,
    })

    -- Return what we've patched so far
    return total_patched, result
  end

  logger.info("Coverage patching completed for all files", {
    total_files = processed_files,
    patched_files = result.patched_files,
    total_patched_lines = result.total_patched,
  })

  return total_patched
end

---@param files_table table<string, any> Table of files to count
---@return number count Number of files in the table
---@return table|nil err Error information if counting failed
-- Helper function to count files in a table
function M.count_files(files_table)
  -- Validate parameter
  if not files_table then
    return 0,
      error_handler.validation_error("Missing files table for counting", {
        operation = "count_files",
      })
  end

  if type(files_table) ~= "table" then
    return 0,
      error_handler.validation_error("Invalid files table type, expected table", {
        operation = "count_files",
        provided_type = type(files_table),
      })
  end

  -- Count files with error handling
  local success, result = error_handler.try(function()
    local count = 0
    for _ in pairs(files_table) do
      count = count + 1
    end
    return count
  end)

  if not success then
    logger.warn("Error counting files: " .. error_handler.format_error(result), {
      operation = "count_files",
    })
    return 0, result
  end

  return result
end

return M
