# Configuration System
firmo comes with a comprehensive configuration system that allows you to customize almost every aspect of the framework's behavior. You can create a `.firmo-config.lua` file in your project's root directory to set default options.

## Creating a Configuration File
The easiest way to create a configuration file is to use the built-in command:

```bash
lua firmo.lua --create-config

```text
This will create a `.firmo-config.lua` file in your current directory with all available configuration options and their default values.

## Configuration File Structure
The configuration file should return a Lua table with the following structure:

```lua
return {
  -- Test Discovery and Selection
  test_discovery = {
    dir = "./tests",                  -- Default directory to search for tests
    pattern = "*_test.lua",           -- Pattern to match test files
    ignore_patterns = { "temp_*" },   -- Patterns to ignore
    recursive = true,                 -- Recursively search directories
  },
  -- Output Formatting
  format = {
    use_color = true,                 -- Whether to use color codes in output
    indent_char = '\t',               -- Character to use for indentation
    indent_size = 1,                  -- How many indent_chars to use per level
    show_trace = false,               -- Show stack traces for errors
    show_success_detail = true,       -- Show details for successful tests
    compact = false,                  -- Use compact output format
    dot_mode = false,                 -- Use dot mode (. for pass, F for fail)
    summary_only = false,             -- Show only summary, not individual tests
    default_format = "detailed",      -- Default format (dot, compact, summary, detailed, plain)
  },
  -- More sections for other features...
}

```text

## Using Different Configuration Files
You can specify a different configuration file at runtime:

```bash
lua firmo.lua --config my-custom-config.lua

```text

## Configuration Sections

### Test Discovery
Controls how firmo finds test files:

```lua
test_discovery = {
  dir = "./tests",                  -- Default directory to search for tests
  pattern = "*_test.lua",           -- Pattern to match test files
  ignore_patterns = { "temp_*" },   -- Patterns to ignore
  recursive = true,                 -- Recursively search directories
}

```text

### Output Formatting
Customizes the test output appearance:

```lua
format = {
  use_color = true,                 -- Whether to use color codes in output
  indent_char = '\t',               -- Character to use for indentation (tab or spaces)
  indent_size = 1,                  -- How many indent_chars to use per level
  show_trace = false,               -- Show stack traces for errors
  show_success_detail = true,       -- Show details for successful tests
  compact = false,                  -- Use compact output format (less verbose)
  dot_mode = false,                 -- Use dot mode (. for pass, F for fail)
  summary_only = false,             -- Show only summary, not individual tests
  default_format = "detailed",      -- Default format (dot, compact, summary, detailed, plain)
}

```text

### Asynchronous Testing
Controls behavior of asynchronous tests:

```lua
async = {
  timeout = 5000,                   -- Default timeout for async tests in milliseconds
  interval = 100,                   -- Check interval for async operations in milliseconds
  debug = false,                    -- Enable debug mode for async operations
}

```text

### Parallel Execution
Configure how tests run in parallel:

```lua
parallel = {
  workers = 4,                      -- Default number of worker processes
  timeout = 60,                     -- Default timeout in seconds per test file
  output_buffer_size = 10240,       -- Buffer size for capturing output
  verbose = false,                  -- Verbose output flag
  show_worker_output = true,        -- Show output from worker processes
  fail_fast = false,                -- Stop on first failure
  aggregate_coverage = true,        -- Combine coverage data from all workers
}

```text

### Coverage Analysis
Configure code coverage analysis:

```lua
coverage = {
  enabled = false,                  -- Whether coverage is enabled by default
  include = { ".*%.lua$" },         -- Files to include in coverage
  exclude = {                       -- Files to exclude from coverage
    "test_", 
    "_spec%.lua$", 
    "_test%.lua$",
  },
  threshold = 90,                   -- Coverage threshold percentage
  format = "summary",               -- Default report format (summary, json, html, lcov)
  output = nil,                     -- Custom output file path (nil=auto-generated)
  track_blocks = false,             -- Enable tracking of code blocks (if/else, loops)
  use_static_analysis = false,      -- Use static analysis for improved accuracy
  control_flow_keywords_executable = true, -- Treat control flow keywords (end, else, etc.) as executable
}

```text

### Test Quality Validation
Configure test quality validation:

```lua
quality = {
  enabled = false,                  -- Whether test quality validation is enabled
  level = 1,                        -- Quality level to enforce (1-5)
  strict = false,                   -- Whether to fail on first quality issue
  format = "summary",               -- Report format (summary, json, html)
  output = nil,                     -- Output file path (nil for console)
}

```text

### Code Fixing/Linting
Configure code fixing and linting:

```lua
codefix = {
  enabled = false,                  -- Enable code fixing functionality
  verbose = false,                  -- Enable verbose output
  debug = false,                    -- Enable debug output

  -- StyLua options
  use_stylua = true,                -- Use StyLua for formatting
  stylua_path = "stylua",           -- Path to StyLua executable

  -- Luacheck options
  use_luacheck = true,              -- Use Luacheck for linting
  luacheck_path = "luacheck",       -- Path to Luacheck executable

  -- Custom fixers
  custom_fixers = {
    trailing_whitespace = true,     -- Fix trailing whitespace in strings
    unused_variables = true,        -- Fix unused variables by prefixing with underscore
    string_concat = true,           -- Optimize string concatenation
    type_annotations = false,       -- Add type annotations
    lua_version_compat = false,     -- Fix Lua version compatibility issues
  },
}

```text

### Reporting Configuration
Configure report generation:

```lua
reporting = {
  report_dir = "./coverage-reports", -- Base directory for reports
  report_suffix = nil,              -- Suffix to add to report filenames
  timestamp_format = "%Y-%m-%d",    -- Format for timestamps in filenames
  templates = {                     -- Path templates for different report types
    coverage = nil,                 -- Template for coverage reports
    quality = nil,                  -- Template for quality reports
    results = nil,                  -- Template for test results
  },
  verbose = false,                  -- Enable verbose output during report generation
}

```text

### Watch Mode
Configure watch mode for continuous testing:

```lua
watch = {
  dirs = { "." },                   -- Directories to watch
  ignore = { "node_modules", ".git" }, -- Patterns to ignore
  debounce = 500,                   -- Debounce time in milliseconds
  clear_console = true,             -- Clear console before re-running tests
}

```text

### Interactive CLI Mode
Configure the interactive CLI mode:

```lua
interactive = {
  history_size = 100,               -- Number of commands to keep in history
  prompt = "> ",                    -- Command prompt
  default_dir = "./tests",          -- Default directory for test discovery
  default_pattern = "*_test.lua",   -- Default pattern for test files
}

```text

### Custom Formatters
Configure custom formatters:

```lua
formatters = {
  module = nil,                     -- Custom formatter module to load
  coverage = nil,                   -- Custom format for coverage reports
  quality = nil,                    -- Custom format for quality reports
  results = nil,                    -- Custom format for test results
}

```text

### Module Reset System
Configure the module reset system (used to prevent test state leakage):

```lua
module_reset = {
  enabled = true,                   -- Enable module reset between test files
  track_memory = true,              -- Track memory usage during reset
  protected_modules = {             -- Modules that should never be reset
    "string", "table", "math", 
    "io", "os", "coroutine", 
    "debug", "package"
  },
  exclude_patterns = {              -- Patterns to exclude from reset
    "^_G$", "^package%.", "^debug%."
  },
}

```text

## Programmatic Usage
You can also load and use the configuration system programmatically:

```lua
local firmo = require("firmo")
-- Load a specific configuration file
local config = firmo.config.load_from_file("path/to/config.lua")
-- Apply the configuration
firmo.config.apply_to_firmo(firmo)

```text

## CLI Options
The configuration system adds the following CLI options:

- `--config FILE`: Use the specified configuration file instead of `.firmo-config.lua`
- `--create-config`: Create a default configuration file at `.firmo-config.lua`

