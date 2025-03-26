---@class CoverageLoaderCache
---@field add_module fun(file_path: string, module: any) Add a module to the cache
---@field get_module fun(file_path: string): any|nil Get a module from the cache
---@field remove_module fun(file_path: string) Remove a module from the cache
---@field reset fun() Reset the cache
---@field get_stats fun(): table Get cache statistics
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")

-- Version
M._VERSION = "0.1.0"

-- Module cache
local module_cache = {}
local cache_hits = 0
local cache_misses = 0

-- Add a module to the cache
---@param file_path string The file path of the module
---@param module any The module to cache
function M.add_module(file_path, module)
  -- Parameter validation
  error_handler.assert(type(file_path) == "string", "file_path must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(module ~= nil, "module must not be nil", error_handler.CATEGORY.VALIDATION)
  
  module_cache[file_path] = {
    module = module,
    timestamp = os.time()
  }
  
  logger.debug("Added module to cache", {
    file_path = file_path,
    cache_size = M.get_stats().cache_size
  })
end

-- Get a module from the cache
---@param file_path string The file path of the module
---@return any|nil module The cached module or nil if not found
function M.get_module(file_path)
  -- Parameter validation
  error_handler.assert(type(file_path) == "string", "file_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  local entry = module_cache[file_path]
  
  if entry then
    -- Update statistics
    cache_hits = cache_hits + 1
    
    -- Update timestamp
    entry.timestamp = os.time()
    
    logger.debug("Cache hit", {
      file_path = file_path,
      cache_hits = cache_hits
    })
    
    return entry.module
  else
    -- Update statistics
    cache_misses = cache_misses + 1
    
    logger.debug("Cache miss", {
      file_path = file_path,
      cache_misses = cache_misses
    })
    
    return nil
  end
end

-- Remove a module from the cache
---@param file_path string The file path of the module
function M.remove_module(file_path)
  -- Parameter validation
  error_handler.assert(type(file_path) == "string", "file_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  if module_cache[file_path] then
    module_cache[file_path] = nil
    
    logger.debug("Removed module from cache", {
      file_path = file_path,
      cache_size = M.get_stats().cache_size
    })
  end
end

-- Reset the cache
function M.reset()
  module_cache = {}
  cache_hits = 0
  cache_misses = 0
  
  logger.info("Reset module cache")
end

-- Get cache statistics
---@return table stats Cache statistics
function M.get_stats()
  local cache_size = 0
  for _ in pairs(module_cache) do
    cache_size = cache_size + 1
  end
  
  return {
    cache_size = cache_size,
    cache_hits = cache_hits,
    cache_misses = cache_misses,
    hit_ratio = cache_hits + cache_misses > 0 and (cache_hits / (cache_hits + cache_misses)) or 0
  }
end

return M