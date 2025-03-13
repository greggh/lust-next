#!/usr/bin/env lua
-- Version Check Script
-- Validates version consistency across project files

-- Initialize logging system
local logging
local ok, err = pcall(function() logging = require("lib.tools.logging") end)
if not ok or not logging then
  -- Fall back to standard print if logging module isn't available
  logging = {
    configure = function() end,
    get_logger = function() return {
      info = print,
      error = print,
      warn = print,
      debug = print,
      verbose = print
    } end
  }
end

-- Get logger for version_check module
local logger = logging.get_logger("scripts.version_check")
-- Configure from config if possible
logging.configure_from_config("scripts.version_check")

-- Set script version
local VERSION = "1.1.0"
logger.debug("Version check script initialized", {
  version = VERSION
})

-- Configuration
local config = {
  -- Known files that should contain version information
  version_files = {
    -- Main source of truth
    { path = "src/version.lua", pattern = "M.major = (%d+).-M.minor = (%d+).-M.patch = (%d+)", required = true },
    -- Documentation files
    { path = "README.md", pattern = "Version: v([%d%.]+)", required = true },
    { path = "CHANGELOG.md", pattern = "## %[([%d%.]+)%]", required = true },
    -- Optional source files
    { path = "lua/%s/init.lua", pattern = "M%._VERSION = [^\"]*\"([%d%.]+)\"|M%.version = [^\"]*\"([%d%.]+)\"|version = \"([%d%.]+)\"", required = false },
    { path = "lua/%s.lua", pattern = "version = \"([%d%.]+)\"", required = false },
    -- Package files
    { path = "%s.rockspec", pattern = "version = \"([%d%.]+)\"", required = false },
    { path = "package.json", pattern = "\"version\": \"([%d%.]+)\"", required = false },
  }
}

-- Load the filesystem module
local fs = require("lib.tools.filesystem")
logger.debug("Loaded filesystem module", {version = fs._VERSION})

-- Get the project name from the script argument or from the current directory
local project_name = arg[1]
if not project_name then
  local pwd = fs.get_absolute_path(".")
  local project_name_with_path = pwd:match("/([^/]+)$")
  project_name = project_name_with_path:gsub("%-", "_")
end

-- Function to read a file's content
local function read_file(path)
  logger.debug("Reading file", {
    path = path
  })
  
  local content, err = fs.read_file(path)
  if not content then
    logger.warn("Failed to open file for reading", {
      path = path,
      error = err
    })
    return nil, err
  end
  
  logger.debug("File read successfully", {
    path = path,
    content_length = #content
  })
  
  return content
end

-- Function to extract version from file using pattern
local function extract_version(path, pattern)
  logger.debug("Extracting version", {
    path = path,
    pattern = pattern
  })
  
  local content, err = read_file(path)
  if not content then
    local error_msg = "Could not read "..path..": "..tostring(err)
    logger.error("Version extraction failed", {
      path = path,
      error = error_msg
    })
    return nil, error_msg
  end
  
  -- First, check for structured version with major.minor.patch format
  local major, minor, patch = content:match(pattern)
  if major and minor and patch then
    local version = major.."."..minor.."."..patch
    logger.debug("Extracted structured version", {
      path = path,
      major = major,
      minor = minor,
      patch = patch,
      version = version
    })
    return version
  end
  
  -- Handle multiple capture patterns (separated by |)
  local version
  if pattern:find("|") then
    logger.debug("Processing multi-pattern version extraction", {
      path = path
    })
    
    for p in pattern:gmatch("([^|]+)") do
      version = content:match(p)
      if version then 
        logger.debug("Pattern matched", {
          path = path,
          pattern = p,
          version = version
        })
        break 
      end
    end
  else
    version = content:match(pattern)
  end
  
  -- Also handle multiple captures in a single pattern
  if type(version) ~= "string" then
    if version then
      logger.debug("Processing multiple captures", {
        path = path,
        capture_type = type(version)
      })
      
      for i, v in pairs(version) do
        if v and v ~= "" then
          version = v
          logger.debug("Selected capture", {
            path = path,
            capture_index = i,
            value = v
          })
          break
        end
      end
    end
  end
  
  if version then
    logger.debug("Version extracted successfully", {
      path = path,
      version = version
    })
  else
    logger.warn("No version found in file", {
      path = path,
      pattern = pattern
    })
  end
  
  return version
end

-- Format path with project name
local function format_path(path_template)
  local formatted = path_template:format(project_name)
  
  logger.debug("Formatted path template", {
    template = path_template,
    project = project_name,
    result = formatted
  })
  
  return formatted
end

-- Check if a file exists
local function file_exists(path)
  logger.debug("Checking if file exists", {
    path = path
  })
  
  local exists = fs.file_exists(path)
  
  if exists then
    logger.debug("File exists", {
      path = path
    })
  else
    logger.debug("File does not exist", {
      path = path
    })
  end
  
  return exists
end

-- Main version checking function
local function check_versions()
  local versions = {}
  local errors = {}
  local canonical_version
  
  logger.info("Starting version consistency check", {
    project = project_name,
    files_to_check = #config.version_files
  })
  
  -- First, get the canonical version from version.lua
  local version_file_path = format_path(config.version_files[1].path)
  canonical_version = extract_version(version_file_path, config.version_files[1].pattern)
  
  if not canonical_version then
    local error_msg = "Could not find canonical version in " .. version_file_path
    table.insert(errors, error_msg)
    logger.error("Version check failed", {
      error = "missing_canonical_version",
      file = version_file_path
    })
    return false, errors
  end
  
  logger.info("Canonical version found", {
    version = canonical_version,
    source_file = version_file_path
  })
  
  versions[version_file_path] = canonical_version
  
  -- Check each file
  local files_checked = 0
  local matches = 0
  local mismatches = 0
  local skipped = 0
  
  for i, file_config in ipairs(config.version_files) do
    if i > 1 then -- Skip the first one, which we already checked
      local path = format_path(file_config.path)
      
      logger.debug("Checking file for version consistency", {
        file = path,
        pattern = file_config.pattern,
        required = file_config.required
      })
      
      if file_exists(path) then
        files_checked = files_checked + 1
        local version = extract_version(path, file_config.pattern)
        
        if version then
          if version ~= canonical_version then
            local error_msg = string.format(
              "Version mismatch in %s: expected %s, found %s",
              path, canonical_version, version
            )
            table.insert(errors, error_msg)
            mismatches = mismatches + 1
            
            logger.warn("Version mismatch detected", {
              file = path,
              expected = canonical_version,
              found = version
            })
          else
            matches = matches + 1
            logger.info("Version match confirmed", {
              file = path,
              version = version
            })
          end
          versions[path] = version
        else
          if file_config.required then
            local error_msg = "Could not find version in " .. path
            table.insert(errors, error_msg)
            logger.error("Version pattern not found in required file", {
              file = path,
              pattern = file_config.pattern
            })
          else
            skipped = skipped + 1
            logger.info("Skipping optional file", {
              file = path,
              reason = "version_pattern_not_found"
            })
          end
        end
      else
        if file_config.required then
          local error_msg = "Required file not found: " .. path
          table.insert(errors, error_msg)
          logger.error("Required file not found", {
            file = path
          })
        else
          skipped = skipped + 1
          logger.info("Skipping optional file", {
            file = path,
            reason = "file_not_found"
          })
        end
      end
    end
  end
  
  -- Output results
  if #errors > 0 then
    logger.error("Version check failed", {
      error_count = #errors,
      files_checked = files_checked,
      matches = matches,
      mismatches = mismatches,
      skipped = skipped
    })
    
    for i, err in ipairs(errors) do
      logger.error("Version error details", {
        index = i,
        error = err
      })
    end
    
    return false, errors
  else
    logger.info("Version check completed successfully", {
      canonical_version = canonical_version,
      files_checked = files_checked,
      matches = matches,
      skipped = skipped,
      status = "all_consistent"
    })
    
    return true, nil
  end
end

-- Run the version check
logger.debug("Starting version check script execution", {
  project = project_name
})

local success, errors = check_versions()

if not success then
  logger.error("Version check failed, exiting with error code 1", {
    error_count = #errors
  })
  os.exit(1)
else
  logger.info("Version check passed", {
    exit_code = 0
  })
end

-- Get the canonical version
local canonical_version = extract_version(format_path(config.version_files[1].path), config.version_files[1].pattern)

-- Return the canonical version for other scripts to use
logger.debug("Returning canonical version", {
  version = canonical_version
})

return canonical_version