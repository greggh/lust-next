---@class coverage.file_manager
---@field _VERSION string Module version
---@field discover_files fun(config?: {source_dirs?: string[], include?: string[], exclude?: string[], recursive?: boolean, normalize_paths?: boolean}): table<string, {path: string, size: number, last_modified: number, discovered: boolean}>, table? Find all Lua files in directories matching patterns
---@field add_uncovered_files fun(coverage_data: table, config?: {source_dirs?: string[], include?: string[], exclude?: string[], recursive?: boolean}): number, table? Update coverage data with discovered files
---@field count_files fun(files_table: table): number, table? Count files in a table
---@field track_file fun(file_path: string): boolean, string? Add a file for coverage tracking
---@field track_directory fun(dir_path: string, options?: {pattern?: string, recursive?: boolean, exclude?: string|string[]}): number, table? Track files in a directory
---@field is_tracked fun(file_path: string): boolean Check if a file is being tracked
---@field untrack_file fun(file_path: string): boolean Remove a file from tracking
---@field untrack_all fun(): boolean Remove all files from tracking
---@field get_tracked_files fun(): table<string, {path: string, discovered: boolean, loaded: boolean}> Get all tracked files
---@field load_file fun(file_path: string): string|nil, string? Load file content for coverage tracking
---@field set_include_pattern fun(pattern: string): boolean Set pattern for files to include
---@field set_exclude_pattern fun(pattern: string): boolean Set pattern for files to exclude
---@field scan_for_files fun(options?: {root_dir?: string, pattern?: string, exclude?: string|string[], recursive?: boolean}): table<string, {path: string, size: number, last_modified: number}> Scan filesystem for matching files
---@field normalize_file_path fun(file_path: string): string Normalize a file path for consistent tracking
---@field configure fun(options: table): coverage.file_manager Configure the file manager
---@field get_config fun(): table Get current configuration
local M = {}
M._VERSION = "1.1.0"

local fs = require("lib.tools.filesystem")

-- Import logging
local logging = require("lib.tools.logging")
local logger = logging.get_logger("coverage.file_manager")
logging.configure_from_config("coverage.file_manager")

-- Error handler is a required module for proper error handling
local error_handler = require("lib.tools.error_handler")

logger.debug("Coverage file manager module initialized", {
  version = M._VERSION
})

---@param config? table Configuration options including source_dirs, include and exclude patterns
---@return table discovered Table of discovered files (keys are file paths, values are true)
---@return table|nil err Error information if file discovery failed
-- Find all Lua files in directories matching patterns
function M.discover_files(config)
  -- Validate input
  if config ~= nil and type(config) ~= "table" then
    local err = error_handler.validation_error(
      "Config must be a table or nil",
      {provided_type = type(config), operation = "file_manager.discover_files"}
    )
    logger.error("Invalid config: " .. error_handler.format_error(err))
    return {}, err
  end
  
  logger.debug("Starting file discovery", {
    source_dirs = config.source_dirs or {"."},
    include_patterns = config.include or {},
    exclude_patterns = config.exclude or {}
  })
  
  local discovered = {}
  local include_patterns = config.include or {}
  local exclude_patterns = config.exclude or {}
  local source_dirs = config.source_dirs or {"."}
  
  -- Process explicitly included files first
  logger.debug("Processing explicit file includes", {
    pattern_count = #include_patterns
  })
  
  local explicit_files = 0
  for _, pattern in ipairs(include_patterns) do
    -- If it's a direct file path (not a pattern)
    if not pattern:match("[%*%?%[%]]") then
      -- Use safe_io_operation for file existence check
      local file_exists, err = error_handler.safe_io_operation(
        function() return fs.file_exists(pattern) end,
        pattern,
        {operation = "file_manager.discover_files.check_explicit"}
      )
      
      if not file_exists then
        logger.debug("Failed to check file existence: " .. error_handler.format_error(err), {
          pattern = pattern
        })
        goto continue_pattern
      end
      
      if file_exists then
        -- Use safe_io_operation for path normalization
        local normalized_path, err = error_handler.safe_io_operation(
          function() return fs.normalize_path(pattern) end,
          pattern,
          {operation = "file_manager.discover_files.normalize"}
        )
        
        if not normalized_path then
          logger.debug("Failed to normalize path: " .. error_handler.format_error(err), {
            pattern = pattern
          })
          goto continue_pattern
        end
        
        discovered[normalized_path] = true
        explicit_files = explicit_files + 1
        
        logger.debug("Added explicit file", {
          pattern = pattern,
          normalized_path = normalized_path
        })
      end
    end
    
    ::continue_pattern::
  end
  
  -- Convert source dirs to absolute paths
  logger.debug("Converting source directories to absolute paths", {
    directory_count = #source_dirs
  })
  
  local absolute_dirs = {}
  local valid_dirs = 0
  for _, dir in ipairs(source_dirs) do
    -- Check directory existence with error handling
    local dir_exists, err = error_handler.safe_io_operation(
      function() return fs.directory_exists(dir) end,
      dir,
      {operation = "file_manager.discover_files.check_directory"}
    )
    
    if not dir_exists then
      logger.debug("Failed to check directory existence: " .. error_handler.format_error(err), {
        directory = dir
      })
      goto continue_directory
    end
    
    if dir_exists then
      -- Normalize path with error handling
      local normalized_dir, err = error_handler.safe_io_operation(
        function() return fs.normalize_path(dir) end,
        dir,
        {operation = "file_manager.discover_files.normalize_directory"}
      )
      
      if not normalized_dir then
        logger.debug("Failed to normalize directory path: " .. error_handler.format_error(err), {
          directory = dir
        })
        goto continue_directory
      end
      
      table.insert(absolute_dirs, normalized_dir)
      valid_dirs = valid_dirs + 1
      
      logger.debug("Added source directory", {
        original = dir,
        normalized = normalized_dir
      })
    else
      logger.warn("Skipping nonexistent directory", {
        directory = dir
      })
    end
    
    ::continue_directory::
  end
  
  -- Use filesystem module to find all .lua files
  logger.debug("Discovering Lua files", {
    directory_count = #absolute_dirs,
    include_pattern_count = #include_patterns,
    exclude_pattern_count = #exclude_patterns
  })
  
  local lua_files = {}
  local discover_err = nil
  
  -- Use error handling for file discovery
  local success, result, err = error_handler.try(function()
    return fs.discover_files(
      absolute_dirs,
      include_patterns,
      exclude_patterns
    )
  end)
  
  if not success then
    discover_err = error_handler.io_error(
      "Failed to discover files",
      {
        directories = absolute_dirs,
        include_patterns = include_patterns,
        exclude_patterns = exclude_patterns,
        operation = "file_manager.discover_files"
      },
      result
    )
    
    logger.error("File discovery failed: " .. error_handler.format_error(discover_err))
    lua_files = {}
  else
    lua_files = result
  end
  
  -- Add discovered files
  logger.debug("Processing discovered files", {
    file_count = #lua_files
  })
  
  for _, file_path in ipairs(lua_files) do
    -- Normalize path with error handling
    local normalized_path, err = error_handler.safe_io_operation(
      function() return fs.normalize_path(file_path) end,
      file_path,
      {operation = "file_manager.discover_files.normalize_discovered"}
    )
    
    if not normalized_path then
      logger.debug("Failed to normalize discovered file path: " .. error_handler.format_error(err), {
        file_path = file_path
      })
      goto continue_file
    end
    
    discovered[normalized_path] = true
    
    ::continue_file::
  end
  
  local total_discovered = 0
  for _ in pairs(discovered) do
    total_discovered = total_discovered + 1
  end
  
  logger.info("File discovery completed", {
    total_files = total_discovered,
    explicit_files = explicit_files,
    source_directories = valid_dirs,
    had_errors = discover_err ~= nil
  })
  
  -- Return both the discovered files and any error that occurred
  return discovered, discover_err
end

---@param coverage_data table The coverage data object to update
---@param config? table Configuration options for file discovery
---@return number added Number of files added to coverage data
---@return table|nil err Error information if operation failed
-- Update coverage data with discovered files
function M.add_uncovered_files(coverage_data, config)
  -- Validate input parameters
  if not coverage_data or type(coverage_data) ~= "table" then
    local err = error_handler.validation_error(
      "Coverage data must be a table",
      {provided_type = type(coverage_data), operation = "file_manager.add_uncovered_files"}
    )
    logger.error("Invalid coverage data: " .. error_handler.format_error(err))
    return 0, err
  end
  
  if not coverage_data.files or type(coverage_data.files) ~= "table" then
    local err = error_handler.validation_error(
      "Coverage data must have a files table",
      {operation = "file_manager.add_uncovered_files"}
    )
    logger.error("Invalid coverage data structure: " .. error_handler.format_error(err))
    return 0, err
  end
  
  logger.debug("Adding uncovered files to coverage data", {
    existing_file_count = M.count_files(coverage_data.files)
  })
  
  local discovered, discover_err = M.discover_files(config)
  local added = 0
  local missing_files = 0
  
  for file_path in pairs(discovered) do
    if not coverage_data.files[file_path] then
      logger.debug("Processing uncovered file", {
        file_path = file_path
      })
      
      -- Count lines in file with error handling
      local line_count = 0
      local source, read_err = error_handler.safe_io_operation(
        function() return fs.read_file(file_path) end,
        file_path,
        {operation = "file_manager.add_uncovered_files.read_file"}
      )
      
      if not source then
        missing_files = missing_files + 1
        logger.warn("Failed to read uncovered file: " .. error_handler.format_error(read_err), {
          file_path = file_path
        })
        goto continue_file
      end
      
      -- Count lines with error handling
      local success, result, err = error_handler.try(function()
        local count = 0
        for _ in source:gmatch("[^\r\n]+") do
          count = count + 1
        end
        return count
      end)
      
      if not success then
        logger.warn("Failed to count lines in file: " .. error_handler.format_error(result), {
          file_path = file_path
        })
        line_count = 0
      else
        line_count = result
      end
      
      coverage_data.files[file_path] = {
        lines = {},
        functions = {},
        line_count = line_count,
        discovered = true,
        source = source
      }
      
      added = added + 1
      
      logger.debug("Added uncovered file", {
        file_path = file_path,
        line_count = line_count
      })
      
      ::continue_file::
    end
  end
  
  logger.info("Uncovered files processing completed", {
    files_added = added,
    files_missing = missing_files,
    total_coverage_files = M.count_files(coverage_data.files),
    had_discovery_errors = discover_err ~= nil
  })
  
  -- Return both the count of added files and any error that occurred
  return added, discover_err
end

---@param files_table table Table of files to count
---@return number count The number of files in the table
---@return table|nil err Error information if counting failed
-- Helper function to count files in a table
function M.count_files(files_table)
  -- Validate input
  if not files_table then
    local err = error_handler.validation_error(
      "Files table must be provided",
      {provided_type = type(files_table), operation = "file_manager.count_files"}
    )
    logger.debug("Invalid files table: " .. error_handler.format_error(err))
    return 0, err
  end
  
  if type(files_table) ~= "table" then
    local err = error_handler.validation_error(
      "Files table must be a table",
      {provided_type = type(files_table), operation = "file_manager.count_files"}
    )
    logger.debug("Invalid files table type: " .. error_handler.format_error(err))
    return 0, err
  end
  
  -- Safely count files
  local success, result, err = error_handler.try(function()
    local count = 0
    for _ in pairs(files_table) do
      count = count + 1
    end
    return count
  end)
  
  if not success then
    local count_err = error_handler.runtime_error(
      "Failed to count files",
      {operation = "file_manager.count_files"},
      result
    )
    logger.debug("Error counting files: " .. error_handler.format_error(count_err))
    return 0, count_err
  end
  
  return result
end

return M