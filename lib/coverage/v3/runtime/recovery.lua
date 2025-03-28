-- Error recovery module for v3 coverage system
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
local json = require("lib.tools.json")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.runtime.recovery")

---@class coverage_v3_runtime_recovery
---@field validate_data fun(data: table): boolean, table? Validate coverage data structure
---@field repair_data fun(data: table): table, table[] Repair inconsistent coverage data
---@field backup_data fun(file_id: string): boolean, table? Create backup of coverage data
---@field restore_backup fun(file_id: string): boolean, table? Restore from backup
---@field detect_corruption fun(data: table): boolean, table[] Check for data corruption
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Cache directory for backups
local BACKUP_DIR = "./.firmo-cache/v3/coverage/backups"

-- Helper to ensure backup directory exists
local function ensure_backup_dir()
  if not fs.directory_exists(BACKUP_DIR) then
    local success, err = fs.create_directory(BACKUP_DIR)
    if not success then
      logger.error("Failed to create backup directory", {
        path = BACKUP_DIR,
        error = err
      })
      return false
    end
  end
  return true
end

-- Helper to get backup file path for a file_id
local function get_backup_path(file_id)
  return BACKUP_DIR .. "/" .. file_id:gsub("[^%w]", "_") .. ".backup.json"
end

-- Validate coverage data structure
---@param data table The coverage data to validate
---@return boolean valid Whether the data is valid
---@return table? errors List of validation errors if invalid
function M.validate_data(data)
  local errors = {}
  
  -- Check basic structure
  if type(data) ~= "table" then
    table.insert(errors, "Data must be a table")
    return false, errors
  end
  
  -- Check execution data
  if type(data.data) ~= "table" then
    table.insert(errors, "Missing or invalid execution data")
  else
    for line, flags in pairs(data.data) do
      if type(line) ~= "number" then
        table.insert(errors, "Invalid line number: " .. tostring(line))
      end
      if type(flags) ~= "number" then
        table.insert(errors, "Invalid flags for line " .. tostring(line))
      end
    end
  end
  
  -- Check execution counts
  if type(data.counts) ~= "table" then
    table.insert(errors, "Missing or invalid execution counts")
  else
    for line, count in pairs(data.counts) do
      if type(line) ~= "number" then
        table.insert(errors, "Invalid line number: " .. tostring(line))
      end
      if type(count) ~= "number" or count < 0 then
        table.insert(errors, "Invalid count for line " .. tostring(line))
      end
    end
  end
  
  -- Return true and no errors if validation passed
  if #errors == 0 then
    return true
  end
  
  return false, errors
end

-- Repair inconsistent coverage data
---@param data table The coverage data to repair
---@return table repaired The repaired data
---@return table[] repairs List of repairs made
function M.repair_data(data)
  local repairs = {}
  local repaired = {
    data = {},
    counts = {}
  }
  
  -- Repair execution data
  if type(data.data) == "table" then
    for line, flags in pairs(data.data) do
      if type(line) == "number" and type(flags) == "number" then
        repaired.data[line] = flags
      else
        table.insert(repairs, {
          type = "removed_invalid_flags",
          line = line
        })
      end
    end
  else
    table.insert(repairs, {
      type = "initialized_execution_data"
    })
  end
  
  -- Repair execution counts
  if type(data.counts) == "table" then
    for line, count in pairs(data.counts) do
      if type(line) == "number" and type(count) == "number" and count >= 0 then
        repaired.counts[line] = count
      else
        table.insert(repairs, {
          type = "removed_invalid_count",
          line = line
        })
      end
    end
  else
    table.insert(repairs, {
      type = "initialized_execution_counts"
    })
  end
  
  -- Ensure consistency between data and counts
  for line in pairs(repaired.data) do
    if not repaired.counts[line] then
      repaired.counts[line] = 0
      table.insert(repairs, {
        type = "initialized_missing_count",
        line = line
      })
    end
  end
  
  return repaired, repairs
end

-- Create backup of coverage data
---@param file_id string The file identifier
---@return boolean success Whether backup was successful
---@return table? error Error information if backup failed
function M.backup_data(file_id)
  -- Ensure backup directory exists
  if not ensure_backup_dir() then
    return false, error_handler.io_error(
      "Failed to create backup directory",
      {directory = BACKUP_DIR}
    )
  end
  
  -- Get data from cache file
  local cache_path = "./.firmo-cache/v3/coverage/" .. file_id:gsub("[^%w]", "_") .. ".json"
  local content = fs.read_file(cache_path)
  if not content then
    return false, error_handler.io_error(
      "Failed to read cache file",
      {file = cache_path}
    )
  end
  
  -- Write backup
  local backup_path = get_backup_path(file_id)
  local success, err = fs.write_file(backup_path, content)
  if not success then
    return false, error_handler.io_error(
      "Failed to write backup file",
      {file = backup_path},
      err
    )
  end
  
  logger.debug("Created backup", {
    file_id = file_id,
    path = backup_path
  })
  
  return true
end

-- Restore from backup
---@param file_id string The file identifier
---@return boolean success Whether restore was successful
---@return table? error Error information if restore failed
function M.restore_backup(file_id)
  -- Get backup file path
  local backup_path = get_backup_path(file_id)
  if not fs.file_exists(backup_path) then
    return false, error_handler.io_error(
      "Backup file not found",
      {file = backup_path}
    )
  end
  
  -- Read backup
  local content = fs.read_file(backup_path)
  if not content then
    return false, error_handler.io_error(
      "Failed to read backup file",
      {file = backup_path}
    )
  end
  
  -- Parse backup data
  local data = json.decode(content)
  if not data then
    return false, error_handler.validation_error(
      "Invalid backup data",
      {file = backup_path}
    )
  end
  
  -- Validate backup data
  local valid, errors = M.validate_data(data)
  if not valid then
    return false, error_handler.validation_error(
      "Invalid backup data structure",
      {file = backup_path, errors = errors}
    )
  end
  
  -- Write to cache file
  local cache_path = "./.firmo-cache/v3/coverage/" .. file_id:gsub("[^%w]", "_") .. ".json"
  local success, err = fs.write_file(cache_path, content)
  if not success then
    return false, error_handler.io_error(
      "Failed to restore from backup",
      {file = cache_path},
      err
    )
  end
  
  logger.debug("Restored from backup", {
    file_id = file_id,
    path = backup_path
  })
  
  return true
end

-- Check for data corruption
---@param data table The coverage data to check
---@return boolean corrupted Whether corruption was detected
---@return table[] issues List of corruption issues found
function M.detect_corruption(data)
  local issues = {}
  
  -- Check for missing required fields
  if not data.data then
    table.insert(issues, {
      type = "missing_field",
      field = "data"
    })
  end
  
  if not data.counts then
    table.insert(issues, {
      type = "missing_field",
      field = "counts"
    })
  end
  
  -- Check for inconsistencies between data and counts
  if type(data.data) == "table" and type(data.counts) == "table" then
    for line in pairs(data.data) do
      if not data.counts[line] then
        table.insert(issues, {
          type = "missing_count",
          line = line
        })
      end
    end
    
    for line in pairs(data.counts) do
      if not data.data[line] then
        table.insert(issues, {
          type = "orphaned_count",
          line = line
        })
      end
    end
  end
  
  -- Check for invalid values
  if type(data.data) == "table" then
    for line, flags in pairs(data.data) do
      if type(line) ~= "number" or type(flags) ~= "number" then
        table.insert(issues, {
          type = "invalid_flags",
          line = line
        })
      end
    end
  end
  
  if type(data.counts) == "table" then
    for line, count in pairs(data.counts) do
      if type(line) ~= "number" or type(count) ~= "number" or count < 0 then
        table.insert(issues, {
          type = "invalid_count",
          line = line
        })
      end
    end
  end
  
  return #issues > 0, issues
end

return M