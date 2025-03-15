-- Test discovery module for firmo
local discover = {}
discover._VERSION = "1.1.0"

-- Initialize logging
local logging
local ok, log_module = pcall(function() return require("lib.tools.logging") end)
if ok and log_module then
  logging = log_module
end

local logger
if logging then
  logger = logging.get_logger("scripts.discover")
  logging.configure_from_config("scripts.discover")
  logger.debug("Test discovery module initialized", {
    version = discover._VERSION
  })
end

-- Helper function to determine if we're on Windows
local function is_windows()
  return package.config:sub(1,1) == '\\'
end

-- Load the filesystem module
local fs = require("lib.tools.filesystem")
if logger then
  logger.debug("Filesystem module loaded", {
    version = fs._VERSION
  })
end

-- Find test files in a directory
function discover.find_tests(dir, pattern)
  dir = dir or "./tests"
  pattern = pattern or "*_test.lua"
  
  if logger then
    logger.debug("Finding test files", {
      directory = dir,
      pattern = pattern
    })
  end
  
  if logger then
    logger.debug("Using filesystem module for test discovery", {
      directory = dir,
      pattern = pattern
    })
  end
  
  local include_patterns = {pattern}
  local files = fs.discover_files({dir}, include_patterns, {})
  
  if logger then
    logger.info("Test files discovered", {
      directory = dir,
      pattern = pattern,
      file_count = #files
    })
  end
  
  return files
end

return discover
