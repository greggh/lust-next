# Comprehensive Coverage Module Plan for firmo

## Reference Projects & Locations

These projects provide inspiration and reference implementations for our coverage module:

1. **Peter Hickman's Email Example**:

   - `/home/gregg/Projects/for-review/Getting coverage.mhtml`
   - Simple implementation showing basic debug hook approach and pattern matching

2. **Coverage Project**:

   - `/home/gregg/Projects/for-review/Coverage/`
   - Pure Lua implementation with patching for non-executable lines

3. **lcovtools**:

   - `/home/gregg/Projects/for-review/lcovtools/`
   - C++ implementation focused on performance and memory efficiency

4. **luacov** (Original):

   - `/home/gregg/Projects/for-review/luacov/`
   - Comprehensive pure Lua implementation with multiple formatters

5. **cluacov** (C extensions for luacov):

   - `/home/gregg/Projects/for-review/cluacov/`
   - C extensions that improve performance and reduce false negatives

6. **Lua Language Source** (for C extension reference):
   - `/home/gregg/Projects/for-review/lua_langauge_source/`
   - Contains source code for Lua 5.1, 5.2, 5.3, and 5.4

## Phase 1: Building a Reliable Pure Lua Coverage Module

### 1.1. File Structure

```
/lib/coverage/
     init.lua                 # Main module interface
     core.lua                 # Core coverage functionality
     debug_hook.lua           # Debug hook implementation
     file_manager.lua         # File discovery and pattern matching
     instrumentation.lua      # Source code instrumentation (optional)
     patchup.lua              # Line patchup for non-executed lines
     reporting.lua            # Reporting interface
     vendor/                  # For cluacov integration
         cluacov/             # C extensions folder
```

### 1.2. Fixing Common Issues

Based on issue #114 and PR #115 from luacov, we need to address these key problems:

1. **File Discovery Consistency**:

   - Ensure include/exclude patterns work consistently with `discover_uncovered`
   - Apply patterns uniformly across both executed and non-executed files
   - Implement a more robust file discovery mechanism

2. **Path Normalization**:

   - Use consistent path handling throughout the codebase
   - Normalize all paths before comparison to prevent platform issues

3. **Module Loading Detection**:
   - Set debug hooks prior to loading test files
   - Hook into require/dofile to catch module loading

### 1.3. Core Implementation: debug_hook.lua

```lua
-- Core debug hook implementation
local M = {}
local fs = require("lib.tools.filesystem")
local config = {}
local tracked_files = {}
local coverage_data = {
  files = {},
  lines = {},
  functions = {}
}

-- Should we track this file?
local function should_track_file(file_path)
  local normalized_path = fs.normalize_path(file_path)

  -- Quick lookup for already-decided files
  if tracked_files[normalized_path] ~= nil then
    return tracked_files[normalized_path]
  end

  -- Apply exclude patterns (fast reject)
  for _, pattern in ipairs(config.exclude) do
    if fs.matches_pattern(normalized_path, pattern) then
      tracked_files[normalized_path] = false
      return false
    end
  end

  -- Apply include patterns
  for _, pattern in ipairs(config.include) do
    if fs.matches_pattern(normalized_path, pattern) then
      tracked_files[normalized_path] = true
      return true
    end
  end

  -- Check source directories
  for _, dir in ipairs(config.source_dirs) do
    local normalized_dir = fs.normalize_path(dir)
    if normalized_path:sub(1, #normalized_dir) == normalized_dir then
      tracked_files[normalized_path] = true
      return true
    end
  end

  -- Default decision based on file extension
  local is_lua = normalized_path:match("%.lua$") ~= nil
  tracked_files[normalized_path] = is_lua
  return is_lua
end

-- Initialize tracking for a file
local function initialize_file(file_path)
  local normalized_path = fs.normalize_path(file_path)

  -- Skip if already initialized
  if coverage_data.files[normalized_path] then
    return
  end

  -- Count lines in file
  local line_count = 0
  local source = fs.read_file(file_path)
  if source then
    for _ in source:gmatch("[^\r\n]+") do
      line_count = line_count + 1
    end
  end

  coverage_data.files[normalized_path] = {
    lines = {},
    functions = {},
    line_count = line_count,
    source = source
  }
end

-- Debug hook function
function M.debug_hook(event, line)
  if event == "line" then
    local info = debug.getinfo(2, "S")
    if not info or not info.source or info.source:sub(1, 1) ~= "@" then
      return
    end

    local file_path = info.source:sub(2)  -- Remove @ prefix

    if should_track_file(file_path) then
      local normalized_path = fs.normalize_path(file_path)

      -- Initialize file data if needed
      if not coverage_data.files[normalized_path] then
        initialize_file(file_path)
      end

      -- Track line
      coverage_data.files[normalized_path].lines[line] = true
      coverage_data.lines[normalized_path .. ":" .. line] = true
    end
  elseif event == "call" then
    local info = debug.getinfo(2, "Sn")
    if not info or not info.source or info.source:sub(1, 1) ~= "@" then
      return
    end

    local file_path = info.source:sub(2)

    if should_track_file(file_path) then
      local normalized_path = fs.normalize_path(file_path)

      -- Initialize file data if needed
      if not coverage_data.files[normalized_path] then
        initialize_file(file_path)
      end

      -- Track function
      local func_name = info.name or ("line_" .. info.linedefined)
      coverage_data.files[normalized_path].functions[func_name] = true
      coverage_data.functions[normalized_path .. ":" .. func_name] = true
    end
  end
end

-- Set configuration
function M.set_config(new_config)
  config = new_config
  tracked_files = {}  -- Reset cached decisions
  return M
end

-- Get coverage data
function M.get_coverage_data()
  return coverage_data
end

-- Reset coverage data
function M.reset()
  coverage_data = {
    files = {},
    lines = {},
    functions = {}
  }
  tracked_files = {}
  return M
end

return M
```

### 1.4. File Manager Implementation: file_manager.lua

This module fully utilizes the filesystem module with no duplication:

```lua
local M = {}
local fs = require("lib.tools.filesystem")

-- Find all Lua files in directories matching patterns
function M.discover_files(config)
  local discovered = {}
  local include_patterns = config.include or {}
  local exclude_patterns = config.exclude or {}
  local source_dirs = config.source_dirs or {"."}

  -- Process explicitly included files first
  for _, pattern in ipairs(include_patterns) do
    -- If it's a direct file path (not a pattern)
    if not pattern:match("[%*%?%[%]]") and fs.file_exists(pattern) then
      local normalized_path = fs.normalize_path(pattern)
      discovered[normalized_path] = true
    end
  end

  -- Convert source dirs to absolute paths
  local absolute_dirs = {}
  for _, dir in ipairs(source_dirs) do
    if fs.directory_exists(dir) then
      table.insert(absolute_dirs, fs.normalize_path(dir))
    end
  end

  -- Use filesystem module to find all .lua files
  local lua_files = fs.discover_files(
    absolute_dirs,
    include_patterns,
    exclude_patterns
  )

  -- Add discovered files
  for _, file_path in ipairs(lua_files) do
    local normalized_path = fs.normalize_path(file_path)
    discovered[normalized_path] = true
  end

  return discovered
end

-- Update coverage data with discovered files
function M.add_uncovered_files(coverage_data, config)
  local discovered = M.discover_files(config)
  local added = 0

  for file_path in pairs(discovered) do
    if not coverage_data.files[file_path] then
      -- Count lines in file
      local line_count = 0
      local source = fs.read_file(file_path)
      if source then
        for _ in source:gmatch("[^\r\n]+") do
          line_count = line_count + 1
        end
      end

      coverage_data.files[file_path] = {
        lines = {},
        functions = {},
        line_count = line_count,
        discovered = true,
        source = source
      }

      added = added + 1
    end
  end

  return added
end

return M
```

### 1.5. Patchup Module: patchup.lua

This addresses the issue of lines that aren't executed by the VM:

```lua
local M = {}
local fs = require("lib.tools.filesystem")

-- Is this line a comment or blank?
local function is_comment_or_blank(line)
  -- Remove trailing comment
  local code = line:gsub("%-%-.*$", "")
  -- Remove whitespace
  code = code:gsub("%s+", "")
  -- Check if anything remains
  return code == ""
end

-- Is this a non-executable line that should be patched?
local function is_patchable_line(line_text)
  return line_text:match("^%s*end%s*$") or
         line_text:match("^%s*else%s*$") or
         line_text:match("^%s*until%s*$") or
         line_text:match("^%s*elseif%s+.+then%s*$") or
         line_text:match("^%s*local%s+function%s+") or
         line_text:match("^%s*function%s+[%w_:%.]+%s*%(")
end

-- Patch coverage data for a file
function M.patch_file(file_path, file_data)
  -- Make sure we have source code
  if not file_data.source then
    file_data.source = fs.read_file(file_path)
    if not file_data.source then
      return false
    end
  end

  -- Split into lines
  local lines = {}
  for line in file_data.source:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  -- Update line_count if needed
  if not file_data.line_count or file_data.line_count == 0 then
    file_data.line_count = #lines
  end

  -- Process each line
  local patched = 0
  for i, line_text in ipairs(lines) do
    -- Skip lines that are already covered or are comments/blanks
    if not file_data.lines[i] and not is_comment_or_blank(line_text) then
      if is_patchable_line(line_text) then
        file_data.lines[i] = true
        patched = patched + 1
      end
    end
  end

  return patched
end

-- Patch all files in coverage data
function M.patch_all(coverage_data)
  local total_patched = 0

  for file_path, file_data in pairs(coverage_data.files) do
    local patched = M.patch_file(file_path, file_data)
    total_patched = total_patched + patched
  end

  return total_patched
end

return M
```

### 1.6. Instrumentation Module: instrumentation.lua (Optional)

This module is optional because it provides an alternative approach to coverage via source code instrumentation rather than debug hooks. It can be more accurate but is more invasive:

```lua
local M = {}
local fs = require("lib.tools.filesystem")

-- Replace a require call to use our instrumented version
function M.instrument_require()
  local original_require = require

  _G.require = function(module_name)
    local result = original_require(module_name)

    -- Try to find the module's source file
    local module_info = package.loaded[module_name]
    -- Record that this module was loaded
    -- (implementation details)

    return result
  end
end

-- Instrument a Lua source file by adding coverage tracking
function M.instrument_file(file_path, config)
  if not fs.file_exists(file_path) then
    return nil, "File not found"
  end

  local source = fs.read_file(file_path)
  if not source then
    return nil, "Could not read file"
  end

  local lines = {}
  local line_num = 1

  for line in source:gmatch("[^\r\n]+") do
    -- Skip comments and empty lines
    if not line:match("^%s*%-%-") and not line:match("^%s*$") then
      -- Add tracking code before executable lines
      table.insert(lines, string.format(
        'require("lib.coverage").track_line(%q, %d); %s',
        file_path, line_num, line
      ))
    else
      table.insert(lines, line)
    end
    line_num = line_num + 1
  end

  return table.concat(lines, "\n")
end

-- Override Lua's built-in loaders to use instrumented code
function M.hook_loaders()
  -- Save original loader
  local original_loadfile = loadfile

  -- Replace with instrumented version
  _G.loadfile = function(filename)
    if not filename then
      return original_loadfile()
    end

    -- Check if we should instrument this file
    -- (implementation details)

    -- Use original loader for now
    return original_loadfile(filename)
  end

  return true
end

return M
```

### 1.7. Main Module Interface: init.lua

```lua
-- firmo code coverage module
local M = {}

-- Import submodules
local debug_hook = require("lib.coverage.debug_hook")
local file_manager = require("lib.coverage.file_manager")
local patchup = require("lib.coverage.patchup")
local fs = require("lib.tools.filesystem")

-- Default configuration
local DEFAULT_CONFIG = {
  enabled = false,
  source_dirs = {".", "lib"},
  include = {"*.lua", "**/*.lua"},
  exclude = {
    "*_test.lua", "*_spec.lua", "test_*.lua",
    "tests/**/*.lua", "**/test/**/*.lua", "**/tests/**/*.lua",
    "**/spec/**/*.lua", "**/*.test.lua", "**/*.spec.lua",
    "**/*.min.lua", "**/vendor/**", "**/deps/**", "**/node_modules/**"
  },
  discover_uncovered = true,
  threshold = 90,
  debug = false
}

-- Module state
local config = {}
local active = false
local original_hook = nil
local enhanced_mode = false

-- Apply configuration with defaults
function M.init(options)
  -- Start with defaults
  config = {}
  for k, v in pairs(DEFAULT_CONFIG) do
    config[k] = v
  end

  -- Apply user options
  if options then
    for k, v in pairs(options) do
      if k == "include" or k == "exclude" then
        if type(v) == "table" then
          config[k] = v
        end
      else
        config[k] = v
      end
    end
  end

  -- Reset coverage
  M.reset()

  -- Configure debug hook
  debug_hook.set_config(config)

  -- Try to load enhanced C extensions
  local has_cluacov = pcall(require, "lib.coverage.vendor.cluacov_hook")
  enhanced_mode = has_cluacov

  if config.debug then
    print("DEBUG [Coverage] Initialized with " ..
          (enhanced_mode and "enhanced C extensions" or "pure Lua implementation"))
  end

  return M
end

-- Start coverage collection
function M.start()
  if not config.enabled then
    return M
  end

  if active then
    return M  -- Already running
  end

  -- Save original hook
  original_hook = debug.gethook()

  -- Set debug hook
  debug.sethook(debug_hook.debug_hook, "cl")

  active = true
  return M
end

-- Stop coverage collection
function M.stop()
  if not active then
    return M
  end

  -- Restore original hook
  debug.sethook(original_hook)

  -- Process coverage data
  if config.discover_uncovered then
    local added = file_manager.add_uncovered_files(
      debug_hook.get_coverage_data(),
      config
    )

    if config.debug then
      print("DEBUG [Coverage] Added " .. added .. " discovered files")
    end
  end

  -- Patch coverage data for non-executable lines
  local patched = patchup.patch_all(debug_hook.get_coverage_data())

  if config.debug then
    print("DEBUG [Coverage] Patched " .. patched .. " non-executable lines")
  end

  active = false
  return M
end

-- Reset coverage data
function M.reset()
  debug_hook.reset()
  return M
end

-- Full reset (clears all data)
function M.full_reset()
  debug_hook.reset()
  return M
end

-- Get coverage report data
function M.get_report_data()
  local coverage_data = debug_hook.get_coverage_data()

  -- Calculate statistics
  local stats = {
    total_files = 0,
    covered_files = 0,
    total_lines = 0,
    covered_lines = 0,
    total_functions = 0,
    covered_functions = 0,
    files = {}
  }

  for file_path, file_data in pairs(coverage_data.files) do
    -- Count covered lines
    local covered_lines = 0
    for _ in pairs(file_data.lines) do
      covered_lines = covered_lines + 1
    end

    -- Count covered functions
    local covered_functions = 0
    for _ in pairs(file_data.functions) do
      covered_functions = covered_functions + 1
    end

    -- Calculate percentage
    local line_pct = file_data.line_count > 0
                     and (covered_lines / file_data.line_count * 100)
                     or 0

    -- Update file stats
    stats.files[file_path] = {
      total_lines = file_data.line_count or 0,
      covered_lines = covered_lines,
      total_functions = math.max(1, covered_functions),
      covered_functions = covered_functions,
      discovered = file_data.discovered or false,
      line_coverage_percent = line_pct,
      passes_threshold = line_pct >= config.threshold
    }

    -- Update global stats
    stats.total_files = stats.total_files + 1
    stats.covered_files = stats.covered_files + (covered_lines > 0 and 1 or 0)
    stats.total_lines = stats.total_lines + (file_data.line_count or 0)
    stats.covered_lines = stats.covered_lines + covered_lines
    stats.total_functions = stats.total_functions + math.max(1, covered_functions)
    stats.covered_functions = stats.covered_functions + covered_functions
  end

  -- Calculate overall percentages
  local line_coverage_percent = stats.total_lines > 0
                               and (stats.covered_lines / stats.total_lines * 100)
                               or 0

  local function_coverage_percent = stats.total_functions > 0
                                   and (stats.covered_functions / stats.total_functions * 100)
                                   or 0

  local file_coverage_percent = stats.total_files > 0
                               and (stats.covered_files / stats.total_files * 100)
                               or 0

  -- Calculate overall percentage (weighted)
  local overall_percent = (line_coverage_percent * 0.8) + (function_coverage_percent * 0.2)

  -- Add summary to stats
  stats.summary = {
    total_files = stats.total_files,
    covered_files = stats.covered_files,
    total_lines = stats.total_lines,
    covered_lines = stats.covered_lines,
    total_functions = stats.total_functions,
    covered_functions = stats.covered_functions,
    line_coverage_percent = line_coverage_percent,
    function_coverage_percent = function_coverage_percent,
    file_coverage_percent = file_coverage_percent,
    overall_percent = overall_percent,
    threshold = config.threshold,
    passes_threshold = overall_percent >= config.threshold
  }

  return stats
end

-- Generate coverage report
function M.report(format)
  -- Use reporting module for formatting
  local reporting = require("lib.reporting")
  local data = M.get_report_data()

  return reporting.format_coverage(data, format or "summary")
end

-- Save coverage report
function M.save_report(file_path, format)
  local reporting = require("lib.reporting")
  local data = M.get_report_data()

  return reporting.save_coverage_report(file_path, data, format or "html")
end

-- Debug dump
function M.debug_dump()
  local data = debug_hook.get_coverage_data()
  local stats = M.get_report_data().summary

  print("=== COVERAGE MODULE DEBUG DUMP ===")
  print("Mode: " .. (enhanced_mode and "Enhanced (C extensions)" or "Standard (Pure Lua)"))
  print("Active: " .. tostring(active))
  print("Configuration:")
  for k, v in pairs(config) do
    if type(v) == "table" then
      print("  " .. k .. ": " .. #v .. " items")
    else
      print("  " .. k .. ": " .. tostring(v))
    end
  end

  print("\nCoverage Stats:")
  print("  Files: " .. stats.covered_files .. "/" .. stats.total_files ..
        " (" .. string.format("%.2f%%", stats.file_coverage_percent) .. ")")
  print("  Lines: " .. stats.covered_lines .. "/" .. stats.total_lines ..
        " (" .. string.format("%.2f%%", stats.line_coverage_percent) .. ")")
  print("  Functions: " .. stats.covered_functions .. "/" .. stats.total_functions ..
        " (" .. string.format("%.2f%%", stats.function_coverage_percent) .. ")")
  print("  Overall: " .. string.format("%.2f%%", stats.overall_percent))

  print("\nTracked Files (first 5):")
  local count = 0
  for file_path, file_data in pairs(data.files) do
    if count < 5 then
      local covered = 0
      for _ in pairs(file_data.lines) do covered = covered + 1 end

      print("  " .. file_path)
      print("    Lines: " .. covered .. "/" .. (file_data.line_count or 0))
      print("    Discovered: " .. tostring(file_data.discovered or false))

      count = count + 1
    else
      break
    end
  end

  if count == 5 and stats.total_files > 5 then
    print("  ... and " .. (stats.total_files - 5) .. " more files")
  end

  print("=== END DEBUG DUMP ===")
  return M
end

return M
```

## Phase 2: Static Analysis Integration with Lua Parser (✅ Completed)

### 2.1. Lua Parser Integration

We've successfully integrated a Lua parser based on the lua-parser project (https://github.com/andremm/lua-parser) to enable accurate static analysis of Lua code. This significantly improves coverage accuracy by providing a precise understanding of code structure.

#### 2.1.1 Parser Module Structure

We've implemented the following structure:

```
/lib/tools/parser/
    init.lua           # Main interface to the parser
    grammar.lua        # LPeg grammar for Lua syntax
    validator.lua      # AST validation functions
    pp.lua             # Pretty printer for AST (for debugging)
    README.md          # Documentation for the parser module
```

#### 2.1.2 LPegLabel Integration (✅ Completed)

LPegLabel is a dependency of lua-parser that provides better error messages. Since it's a C module, we implemented a special approach for integration:

```
/lib/tools/vendor/lpeglabel/
    init.lua                # Our custom loader that compiles and loads the C module
    fallback.lua            # Pure Lua fallback implementation
    lplcap.c/h              # C source and header files
    lplcode.c/h             # C source and header files
    lplvm.c/h               # C source and header files
    lpltree.c/h             # C source and header files
    lpltypes.h              # Additional C header file
    lplprint.c/h            # Additional C source and header files
    makefile                # For compilation of the C module
    LICENSE                 # Original license file
    README.md               # Documentation for the module
    .gitignore              # To exclude compiled files
```

Our implementation includes:

1. A complete C source files bundle in the vendor directory
2. A build-on-first-use init.lua loader that:
   - Checks if the compiled .so/.dll file already exists
   - Attempts to compile the C code on first use if needed
   - Loads the compiled module using package.loadlib
3. A pure Lua fallback implementation for environments where compilation isn't possible

#### 2.1.3 Key Parser Features (✅ Implemented)

Our parser implementation now provides:

1. **Complete AST Generation**: Full abstract syntax tree representation of Lua code
2. **Line Mapping**: Accurate mapping between source lines and AST nodes
3. **Executable Line Detection**: Identification of which lines contain executable code vs. structural elements
4. **Function Detection**: Precise identification of function definitions, parameters, and scopes
5. **Code Maps**: Comprehensive data structures that combine AST, line and function information

#### 2.1.4 Integration with Coverage (🔄 In Progress)

The parser is now ready to enhance our coverage module with:

1. **Static Pre-analysis**: Create detailed "code maps" before execution starts
2. **Accurate Line Classification**: Prevent highlighting of non-executable lines
3. **Logical Coverage**: Ensure logically connected lines are highlighted consistently
4. **Function Analysis**: Track function coverage for more detailed metrics
5. **Enhanced Reports**: Show coverage with proper understanding of code structure

#### 2.1.5 Implementation Status

1. **License & Attribution**: ✅

   - MIT license and attribution from original lua-parser project included
   - Modifications and improvements properly documented

2. **Parser Adaptation**: ✅

   - Core lua-parser functionality incorporated
   - Grammar updated for Lua 5.4 support
   - Optimized for our specific coverage use case

3. **LPegLabel C Integration**: ✅

   - Successfully integrated with build-on-first-use mechanism
   - Implementation handles platform differences (Windows/Linux/Mac)
   - Fallback pure Lua implementation provided
   - Comprehensive error handling and reporting

4. **API Design**: ✅

   - Clean, well-documented API
   - Modular, extensible design
   - Integration points for coverage module

5. **Test Script**: ✅
   - Test script created to verify functionality
   - Demonstrated successful parsing of Lua code
   - Confirmed executable line and function detection works

Next steps involve integrating the parser module with the coverage module to utilize the static analysis capabilities.

### 2.2. Static Analysis Module

We'll create a new module that leverages the parser to analyze Lua code:

```lua
-- lib/coverage/static.lua

local M = {}
local parser = require("lib.tools.parser")
local fs = require("lib.tools.filesystem")

-- Parse a file and create a code map
function M.analyze_file(file_path)
  if not fs.file_exists(file_path) then
    return nil, "File does not exist"
  end

  local source = fs.read_file(file_path)
  if not source then
    return nil, "Could not read file"
  end

  -- Parse the file
  local ast, err = parser.parse(source, file_path)
  if not ast then
    return nil, "Parse error: " .. err
  end

  -- Build code map
  local code_map = {
    executable_lines = {},  -- Lines containing executable code
    non_executable_lines = {},  -- Non-executable lines (comments, etc.)
    functions = {},  -- Function definitions
    blocks = {},  -- Code blocks (if/else, loops, etc.)
    conditions = {},  -- Conditional expressions
    line_to_ast = {}  -- Mapping from line numbers to AST nodes
  }

  -- Process the AST to build the code map
  -- (implementation details)

  return code_map
end

-- Process a single AST node to update code map
function M.process_node(node, code_map)
  -- Process based on node type
  -- (implementation details)
end

-- Identify executable lines in code
function M.identify_executable_lines(ast, code_map)
  -- Walk the AST and identify executable statements
  -- (implementation details)
end

-- Identify logical blocks in code
function M.identify_blocks(ast, code_map)
  -- Find blocks like if/else, loops, etc.
  -- (implementation details)
end

-- Identify functions in code
function M.identify_functions(ast, code_map)
  -- Find function definitions and their boundaries
  -- (implementation details)
end

return M
```

### 2.3. Enhanced Debug Hook

Update the debug hook to use the static analysis data:

```lua
-- In debug_hook.lua

-- Store code maps for analyzed files
local code_maps = {}

-- Check if a line is executable
local function is_executable_line(file_path, line)
  local normalized_path = fs.normalize_path(file_path)
  local code_map = code_maps[normalized_path]

  if code_map then
    return code_map.executable_lines[line] == true
  end

  -- If no code map, assume executable
  return true
end

-- Initialize file with static analysis
local function initialize_file_with_analysis(file_path)
  local normalized_path = fs.normalize_path(file_path)

  -- Skip if already initialized
  if coverage_data.files[normalized_path] then
    return
  end

  -- Get code map from static analysis
  local static = require("lib.coverage.static")
  local code_map, err = static.analyze_file(file_path)

  if not code_map then
    -- Fall back to simple initialization
    initialize_file(file_path)
    return
  end

  -- Store code map for future reference
  code_maps[normalized_path] = code_map

  -- Initialize with data from static analysis
  coverage_data.files[normalized_path] = {
    lines = {},
    functions = {},
    line_count = code_map.total_lines or 0,
    executable_lines = code_map.executable_lines,
    non_executable_lines = code_map.non_executable_lines,
    source = code_map.source,
    blocks = code_map.blocks
  }
end
```

## Phase 3: C Extensions Integration

### 3.1. Create Lua 5.4 Support

First, we'll extend cluacov to support Lua 5.4:

1. Create a new directory for Lua 5.4:

```
/lib/coverage/vendor/cluacov/src/cluacov/lua54/
```

2. Copy the required header files from Lua 5.4:

```
- llimits.h
- lobject.h
```

3. Update the deepactivelines.c file to support Lua 5.4:

```c
#include "lua.h"
#include "lauxlib.h"

#if LUA_VERSION_NUM == 501
#include "lua51/lobject.h"
#elif LUA_VERSION_NUM == 502
#include "lua52/lobject.h"
#elif LUA_VERSION_NUM == 503
#include "lua53/lobject.h"
#elif LUA_VERSION_NUM == 504
#include "lua54/lobject.h"
#else
#error unsupported Lua version
#endif

/* Rest of the implementation follows */
```

### 2.2. Create Integration Adapter

```lua
-- /lib/coverage/vendor/adapter.lua
local M = {}

-- Try to load cluacov components
local success_hook, hook_module = pcall(require, "lib.coverage.vendor.cluacov_hook")
local success_deep, deeplines_module = pcall(require, "lib.coverage.vendor.cluacov_deepactivelines")

-- Check if C extensions are available
M.available = success_hook and success_deep

-- Create a new debug hook using cluacov
function M.create_hook(runner_state)
  if not M.available then
    return nil
  end

  -- Create a new hook function
  return hook_module.new(runner_state)
end

-- Get deep active lines from a function
function M.get_active_lines(func)
  if not M.available or type(func) ~= "function" then
    return {}
  end

  -- Get active lines from function
  return deeplines_module.get(func)
end

return M
```

### 2.3. Enhancing init.lua with C Extensions

```lua
-- In init.lua, add C extension support:

-- Try to load C extension adapter
local has_extensions, adapter = pcall(require, "lib.coverage.vendor.adapter")
enhanced_mode = has_extensions and adapter.available

-- When setting the debug hook, use the C version if available:
function M.start()
  if not config.enabled then return M end
  if active then return M end

  -- Save original hook
  original_hook = debug.gethook()

  if enhanced_mode then
    -- Create runner state for cluacov
    local runner_state = {
      configuration = config,
      initialized = true,
      data = debug_hook.get_coverage_data().files,
      file_included = function(file)
        return should_track_file(file)
      end
    }

    -- Create enhanced debug hook
    local enhanced_hook = adapter.create_hook(runner_state)
    debug.sethook(enhanced_hook, "l")
  else
    -- Use standard Lua hook
    debug.sethook(debug_hook.debug_hook, "cl")
  end

  active = true
  return M
end
```

## Phase 3: Testing Plan

### 3.1. Unit Tests

Create comprehensive tests for each component:

1. **Debug Hook Tests**:

   - Test with various file types
   - Test with different include/exclude patterns
   - Test line and function tracking

2. **File Manager Tests**:

   - Test file discovery with complex patterns
   - Test handling of non-existent files
   - Test path normalization across platforms

3. **Patchup Tests**:
   - Test detection of various non-executable lines
   - Test source code parsing for comments
   - Test handling of edge cases

### 3.2. Integration Tests

Create tests for the combined system:

1. **Complete Coverage Flow Test**:

   - Start coverage
   - Run real code
   - Stop coverage
   - Generate report
   - Verify accuracy

2. **Pattern Matching Test**:

   - Test various include/exclude combinations
   - Verify discovered files match expectations
   - Check integration with `discover_uncovered`

3. **C Extensions Test**:
   - Test with and without C extensions
   - Verify consistent results between implementations
   - Check Lua 5.4 support

### 3.3. Edge Case Tests

1. **Module Loading Test**:

   - Test coverage of files loaded with require()
   - Test coverage of files loaded with dofile()
   - Verify modules loaded before coverage starts

2. **Error Handling Test**:
   - Test behavior with syntax errors
   - Test with non-existent files
   - Test with read-only files

## Phase 4: Implementation Process

### 4.1. Development Approach

1. **Start Clean**:

   - Start with a clean implementation directly on main branch
   - Create the new file structure
   - Implement each module separately

2. **Incremental Testing**:

   - Write and validate one module at a time
   - Add tests for each component
   - Regularly run tests for the whole system

3. **Integration Steps**:
   - Build pure Lua implementation first
   - Add C extension support after pure Lua works
   - Finalize with complete end-to-end testing

### 4.2. Timeline (Estimated)

- **Week 1**:

  - Design and implement pure Lua components
  - Create basic test suite

- **Week 2**:

  - Add C extension support
  - Implement Lua 5.4 compatibility
  - Comprehensive testing

- **Week 3**:
  - Fix any issues found during testing
  - Performance optimization
  - Documentation

## Phase 5: Documentation

### 5.1. User Documentation

1. **API Reference**:

   - Document each public function
   - Example usage patterns
   - Configuration options

2. **Usage Guide**:
   - Getting started examples
   - Common configurations
   - Troubleshooting tips

### 5.2. Enhanced HTML Reports

1. **Dark Mode Theme**:

   - Implement a dark mode theme for better readability
   - Use contrasting colors for coverage highlighting
   - Ensure accessibility for color-blind users
   - Example CSS:

   ```css
   :root {
     /* Dark mode colors */
     --bg-color: #1e1e1e;
     --text-color: #e1e1e1;
     --header-color: #333;
     --summary-bg: #2a2a2a;
     --border-color: #444;
     --line-number-bg: #333;
     --progress-bar-bg: #333;
     --progress-fill-gradient: linear-gradient(
       to right,
       #ff6666 0%,
       #ffdd66 60%,
       #66ff66 80%
     );
     --file-header-bg: #2d2d2d;
     --file-item-border: #444;
     --covered-bg: #265c26; /* Darker green for dark mode */
     --covered-highlight: #4caf50; /* Brighter green for executed lines */
     --uncovered-bg: #5c2626; /* Darker red for dark mode */
     --syntax-keyword: #569cd6; /* Blue */
     --syntax-string: #6a9955; /* Green */
     --syntax-comment: #608b4e; /* Lighter green */
     --syntax-number: #ce9178; /* Orange */
   }
   ```

2. **Line Coverage Visualization Improvements**:

   - Clearly distinguish between executable and non-executable lines
   - Use distinct styling for executable but uncovered lines
   - Keep structural code (like "end", "else") visually neutral
   - Highlight executed lines with higher contrast

3. **Interactive Features**:

   - Add code folding for long files
   - Implement file filtering and search
   - Add summary panel that stays visible during scrolling
   - Create navigation for quick jumping between uncovered sections

4. **Logical Visualization**:
   - Show connected code blocks with consistent styling
   - Highlight branches that were not fully covered
   - Visualize function coverage with in-place metrics

### 5.3. Developer Documentation

1. **Architecture Overview**:

   - Module relationships
   - Data flow diagrams
   - Extension points
   - Parser and static analysis integration

2. **Contribution Guide**:
   - How to add support for new Lua versions
   - Testing guidelines
   - Code style conventions
   - Parser maintenance and updates

## Phase 7: Quality Analysis Integration

### 7.1. Static Analysis for Test Quality

The parser we've integrated will also be valuable for enhancing the quality module:

1. **Test Structure Analysis**:

   - Parse test files to identify test patterns and structure
   - Analyze assertion coverage and complexity
   - Identify potential test gaps or inadequate testing

2. **Code Complexity Metrics**:

   - Calculate cyclomatic complexity for functions
   - Identify highly complex code that needs more tests
   - Generate recommendations for test improvements

3. **Test-to-Code Mapping**:
   - Map tests to their corresponding implementation code
   - Identify untested or under-tested code paths
   - Suggest test additions based on AST analysis

### 7.2. Quality Module Enhancements

```lua
-- lib/quality/static_analysis.lua
local M = {}
local parser = require("lib.tools.parser")
local fs = require("lib.tools.filesystem")

-- Analyze test file quality
function M.analyze_test_file(file_path)
  -- Parse the file
  local source = fs.read_file(file_path)
  local ast, err = parser.parse(source, file_path)
  if not ast then
    return nil, "Parse error: " .. err
  end

  -- Calculate quality metrics
  local metrics = {
    assertion_count = 0,
    test_count = 0,
    describe_blocks = 0,
    assertion_types = {},
    complexity = 0,
    test_to_function_ratio = 0,
    test_recommendations = {}
  }

  -- Process the AST to extract test quality metrics
  M.process_ast_for_quality(ast, metrics)

  return metrics
end

-- Process AST for quality metrics
function M.process_ast_for_quality(ast, metrics)
  -- Walk the AST to find tests and assertions
  -- Count different types of assertions
  -- Calculate complexity metrics
  -- (implementation details)
end

-- Generate quality recommendations
function M.generate_recommendations(metrics, code_map)
  -- Based on metrics and code structure, generate recommendations
  -- (implementation details)
end

return M
```

### 7.3. Integration with Reporting

The quality module will leverage the same HTML reporting enhancements:

1. **Combined Coverage & Quality Reports**:

   - Show coverage and quality metrics side by side
   - Highlight areas needing both coverage and quality improvements
   - Provide actionable suggestions based on static analysis

2. **Quality Visualization**:

   - Heat maps for test quality across the codebase
   - Assertion density visualization
   - Test complexity indicators

3. **Interactive Exploration**:
   - Navigate between implementation code and tests
   - Explore assertion coverage for complex functions
   - Filter and search across quality metrics

## Additional Improvements and Features

From the previous plan documents, we should also consider these additional features:

### Performance Optimizations

1. **Faster Pattern Matching**:

   - Optimize file pattern matching algorithms
   - Cache pattern matching results
   - Add bloom filters for quick rejection

2. **Memory Usage Improvements**:
   - Optimize data structures for large codebases
   - Add streaming data processing for huge projects
   - Implement memory usage tracking and limits

### Extended Coverage Types

1. **Branch Coverage**:

   - Track conditional branches (if/else)
   - Report branch execution percentage
   - Visualize which branches were not taken

2. **Function Coverage**:
   - Track function call chains
   - Report function complexity metrics
   - Identify unused or rarely called functions

### Reporting Enhancements

1. **Visualization Options**:

   - Source code view with highlighted lines
   - Interactive HTML reports
   - Terminal-based coverage visualization
   - Trend analysis over time

2. **CI/CD Integration**:
   - PR coverage diff reporting
   - Badge generation for README
   - Threshold enforcement for CI pipelines

### User Experience Improvements

1. **Watch Mode**:

   - Real-time coverage updates during development
   - Auto-refresh reports as code changes
   - Focus mode for working on specific modules

2. **IDE Integration**:
   - VSCode extension support
   - Editor highlighting for uncovered code
   - Quick navigation to problem areas

## Phase 6: Open Source Contribution

### 6.1. Contributing Back to cluacov

After implementing Lua 5.4 support for our vendored version of cluacov:

1. **Create Pull Request to Original Project**:

   - Fork the cluacov repository on GitHub (https://github.com/mpeterv/cluacov)
   - Implement Lua 5.4 support
   - Submit PR with comprehensive documentation
   - Include test cases demonstrating compatibility

2. **Documentation for Contributors**:
   - Document the process we used to add Lua 5.4 support
   - Create guide for adding support for future Lua versions
   - Include any performance benchmarks or improvements

### 6.2. Comparative Documentation

Create comprehensive comparison documentation to help users choose the right implementation:

1. **Implementation Comparison Table**:

   ```
   | Feature                  | Pure Lua (Debug Hook) | Instrumentation | cluacov C Extensions |
   |--------------------------|:---------------------:|:---------------:|:--------------------:|
   | Accuracy                 | Good                  | Better          | Best                 |
   | Performance impact       | Medium                | High            | Low                  |
   | Memory usage             | Medium                | High            | Low                  |
   | Works without compiling  | ✅                   | ✅              | ❌                   |
   | Captures all lines       | ❌                   | ✅              | ✅                   |
   | Handles loaded modules   | Partial               | ✅              | ✅                   |
   | Setup complexity         | Low                   | Medium          | High                 |
   | Platform independence    | High                  | High            | Medium               |
   ```

2. **Benchmark Results**:

   - Create example project with various edge cases
   - Run all three implementations against it
   - Document performance metrics (execution time, memory usage)
   - Include coverage percentage differences
   - Provide visualizations of the differences

3. **Sample Reports**:

   - Include sample HTML reports from all three implementations
   - Highlight differences in coverage calculations
   - Show examples of missed lines in each approach
   - Demonstrate false positives/negatives

4. **Decision Guide**:
   - Create flowchart to help users choose the right implementation
   - Document use cases where each approach excels
   - Provide configuration templates for different scenarios

## Conclusion

This comprehensive plan addresses the fundamental issues with the current coverage module while providing three tiers of coverage accuracy:

1. **Pure Lua (Debug Hook)**: Simple, portable, and works everywhere without dependencies
2. **Instrumentation**: More accurate through code transformation, but potentially slower
3. **C Extensions (cluacov)**: Best accuracy and performance, but requires compilation

By implementing all three approaches, we provide users the flexibility to choose the right balance of accuracy, performance, and simplicity for their specific needs.

The plan also ensures we contribute back to the open source community by submitting our Lua 5.4 support improvements to the original cluacov project.

Through detailed comparison documentation and benchmarks, users will be able to make informed decisions about which coverage implementation best suits their requirements.
