#!/usr/bin/env lua
-- Script to find print statements that need to be converted to the logging system

-- Initialize logging system
local logging
---@diagnostic disable-next-line: unused-local
local ok, err = pcall(function()
  logging = require("lib.tools.logging")
end)
if not ok or not logging then
  -- Fall back to standard print if logging module isn't available
  logging = {
    configure = function() end,
    get_logger = function()
      return {
        info = print,
        error = print,
        warn = print,
        debug = print,
        verbose = print,
      }
    end,
  }
end

-- Get logger for find_print_statements module
---@diagnostic disable-next-line: redundant-parameter
local logger = logging.get_logger("find_print_statements")
-- Configure from config if possible
logging.configure_from_config("find_print_statements")

-- Load the filesystem module
local fs = require("lib.tools.filesystem")
logger.debug("Loaded filesystem module", { version = fs._VERSION })

-- Configuration
local config = {
  root_dir = ".",
  excluded_dirs = {
    "%.git",
    "node_modules",
    "coverage%-reports",
    "logs",
    "output%-reports",
    "report%-examples",
    "reports%-example",
    "temp%-reports%-demo",
    "html%-report%-examples",
  },
  included_extensions = {
    "%.lua$",
  },
  -- Patterns to search for
  patterns = {
    "print%s*%(", -- Simple print call
    "print%s*%([^)]*%)", -- Print with arguments
    "print%s*%(['\"]", -- Print with string
    "print%(%...%)", -- Print with table args
  },
  -- Files to ignore (these legitimately need print functions)
  ignore_files = {
    "%.firmo%-next%-config%.lua%.template$",
    "logging%.lua$", -- Logging module itself
  },
}

-- Function to check if a file should be ignored
local function should_ignore_file(file_path)
  for _, pattern in ipairs(config.ignore_files) do
    if file_path:match(pattern) then
      return true
    end
  end
  return false
end

-- Function to find Lua files
local function find_lua_files(dir, files)
  files = files or {}

  logger.debug("Finding Lua files using filesystem module", {
    directory = dir,
  })

  -- Use filesystem module to discover files
  local include_patterns = config.included_extensions
  local exclude_patterns = config.excluded_dirs

  local all_files = fs.discover_files({ dir }, include_patterns, exclude_patterns)

  -- Apply additional filters
  for _, file_path in ipairs(all_files) do
    -- Check if file should be ignored
    if not should_ignore_file(file_path) then
      table.insert(files, file_path)
    end
  end

  logger.debug("Found Lua files", {
    count = #files,
  })

  return files
end

-- Function to count print statements in a file
local function count_print_statements(file_path)
  local content, err = fs.read_file(file_path)
  if not content then
    logger.error("Could not read file: " .. file_path .. " - " .. (err or "unknown error"))
    return 0
  end

  -- Count matches for each pattern
  local count = 0
  for _, pattern in ipairs(config.patterns) do
    for _ in content:gmatch(pattern) do
      count = count + 1
    end
  end

  -- Avoid false positives by checking for logger.xxx calls that contain "print"
  local logger_count = 0
  for _ in content:gmatch("logger%.[^(]*%(.-print") do
    logger_count = logger_count + 1
  end

  -- Return the actual count
  return count - logger_count
end

-- Main function
local function find_print_statements()
  logger.info("Finding Lua files with print statements...")

  -- Find all Lua files
  local files = find_lua_files(config.root_dir)
  logger.info("Found " .. #files .. " Lua files to check")

  -- Check each file for print statements
  local files_with_print = {}
  local total_prints = 0

  for _, file in ipairs(files) do
    local count = count_print_statements(file)
    if count > 0 then
      table.insert(files_with_print, {
        path = file,
        count = count,
      })
      total_prints = total_prints + count
    end
  end

  -- Sort by count (descending)
  table.sort(files_with_print, function(a, b)
    return a.count > b.count
  end)

  -- Report results
  logger.info("----------------------------------------------------")
  logger.info("Found " .. #files_with_print .. " files with print statements")
  logger.info("Total print statements: " .. total_prints)
  logger.info("----------------------------------------------------")

  -- Group by directory for better organization
  local by_directory = {}
  for _, file in ipairs(files_with_print) do
    -- Extract directory
    local dir = file.path:match("^(.+)/[^/]+$") or "."

    -- Initialize directory entry if not exists
    by_directory[dir] = by_directory[dir] or {
      total = 0,
      files = {},
    }

    -- Add file info
    table.insert(by_directory[dir].files, {
      name = file.path:match("/([^/]+)$") or file.path,
      path = file.path,
      count = file.count,
    })
    by_directory[dir].total = by_directory[dir].total + file.count
  end

  -- Sort directories by total count
  local dirs = {}
  for dir, info in pairs(by_directory) do
    table.insert(dirs, {
      path = dir,
      total = info.total,
      files = info.files,
    })
  end

  table.sort(dirs, function(a, b)
    return a.total > b.total
  end)

  -- Print results by directory
  for _, dir in ipairs(dirs) do
    logger.info("\nDirectory: " .. dir.path .. " (" .. dir.total .. " prints)")

    -- Sort files in directory by count
    table.sort(dir.files, function(a, b)
      return a.count > b.count
    end)

    -- Print file details
    for _, file in ipairs(dir.files) do
      logger.info(string.format("  %-40s %3d prints", file.name, file.count))
    end
  end

  logger.info("\nRun this tool periodically to track progress in converting print statements to logging.")
end

-- Run the main function
find_print_statements()
