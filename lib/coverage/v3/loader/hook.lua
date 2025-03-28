-- Module loader hook for v3 coverage system
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local parser = require("lib.tools.parser.grammar")
local transformer = require("lib.coverage.v3.instrumentation.transformer")
local sourcemap = require("lib.coverage.v3.instrumentation.sourcemap")
local cache = require("lib.coverage.v3.loader.cache")
local central_config = require("lib.core.central_config")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.loader.hook")

---@class coverage_v3_loader_hook
---@field install fun(): boolean Install module loader hook
---@field uninstall fun(): boolean Uninstall module loader hook
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Original loader functions
local original_loaders = {}

-- Track loaded modules to handle circular dependencies
local loading_modules = {}

-- Helper to get module path from name
local function get_module_path(name)
  -- Convert module name to path
  local path = name:gsub("%.", "/")
  
  -- Try standard Lua paths
  local paths = {
    "./" .. path .. ".lua",
    path .. ".lua",
    path .. "/init.lua"
  }
  
  -- Try each path
  for _, p in ipairs(paths) do
    local file = io.open(p)
    if file then
      file:close()
      return p
    end
  end
  
  return nil
end

-- Helper to read module source
local function read_module_source(path)
  local file = io.open(path)
  if not file then
    return nil, string.format("Cannot open %s", path)
  end
  
  local source = file:read("*a")
  file:close()
  
  return source
end

-- Helper to instrument module source
local function instrument_module(source, path)
  -- Parse source into AST
  local ast, err = parser.parse(source, path)
  if not ast then
    return nil, err
  end
  
  -- Transform AST to add coverage tracking
  local instrumented_ast, source_map = transformer.transform(ast)
  if not instrumented_ast then
    return nil, "Failed to transform AST"
  end
  
  -- Generate instrumented code
  local instrumented_code = transformer.generate(instrumented_ast)
  if not instrumented_code then
    return nil, "Failed to generate code"
  end
  
  -- Create source map
  local map = sourcemap.create(path, source, instrumented_code)
  if not map then
    return nil, "Failed to create source map"
  end
  
  return instrumented_code, map
end

-- Module loader function
local function coverage_loader(name)
  -- Check if module is already being loaded (circular dependency)
  if loading_modules[name] then
    return nil, string.format("Circular dependency detected: %s", name)
  end
  
  -- Get module path
  local path = get_module_path(name)
  if not path then
    return nil
  end
  
  -- Check cache first
  local cached = cache.get(path)
  if cached then
    logger.debug("Using cached module", {
      name = name,
      path = path
    })
    return cached.loader
  end
  
  -- Mark module as being loaded
  loading_modules[name] = true
  
  -- Read source
  local source, err = read_module_source(path)
  if not source then
    loading_modules[name] = nil
    return nil, err
  end
  
  -- Instrument source
  local instrumented_code, source_map = instrument_module(source, path)
  if not instrumented_code then
    loading_modules[name] = nil
    return nil, source_map -- source_map contains error in this case
  end
  
  -- Create loader function
  local loader, err = load(instrumented_code, "@" .. path)
  if not loader then
    loading_modules[name] = nil
    return nil, err
  end
  
  -- Cache the instrumented module
  cache.set(path, {
    loader = loader,
    source_map = source_map
  })
  
  -- Module loaded successfully
  loading_modules[name] = nil
  
  logger.debug("Loaded and instrumented module", {
    name = name,
    path = path
  })
  
  return loader
end

-- Install module loader hook
function M.install()
  -- Get configuration
  local config = central_config.get_config()
  if not config.coverage.enabled or not config.coverage.use_instrumentation then
    logger.debug("Coverage instrumentation disabled")
    return false
  end
  
  -- Save original loaders
  for i, loader in ipairs(package.loaders) do
    original_loaders[i] = loader
  end
  
  -- Insert our loader after the preload loader
  table.insert(package.loaders, 2, coverage_loader)
  
  logger.debug("Installed module loader hook")
  
  return true
end

-- Uninstall module loader hook
function M.uninstall()
  -- Restore original loaders
  for i, loader in ipairs(original_loaders) do
    package.loaders[i] = loader
  end
  
  -- Clear cache
  cache.clear()
  
  logger.debug("Uninstalled module loader hook")
  
  return true
end

return M