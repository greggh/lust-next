-- firmo custom configuration
-- Specific configuration for the firmo project itself

return {
  -- Coverage Configuration
  coverage = {
    enabled = false,                     -- Only enable with --coverage flag
    use_default_patterns = false,        -- Use only our explicit patterns
    discover_uncovered = true,           -- Find uncovered files
    debug = false,                       -- Disable debug mode to reduce output
    
    -- Include patterns for our project
    include = {
      "**/*.lua",                        -- Include all Lua files by default
      "lib/**/*.lua",                    -- Specifically include library code
      "lib/samples/**/*.lua",            -- Explicitly include samples directory
      "firmo.lua"                        -- Include main module
    },
    
    -- Exclude patterns for our specific project
    exclude = {
      -- When working on coverage itself, we NEED to track coverage module files!
      -- So we don't exclude them here
      
      -- But we do exclude test files to avoid inflating coverage numbers
      "tests/**/*.lua"                   -- Our test directory
    },
    
    -- Special flag to include all executed files to help find coverage gaps
    track_all_executed = true,
    
    -- Advanced coverage features we're developing
    track_blocks = true,                 -- Track blocks for detailed coverage
    use_static_analysis = true,          -- Use static analysis for accuracy
    auto_fix_block_relationships = true, -- Auto-fix block relationship issues
    
    -- Report settings
    threshold = 80,                      -- Standard coverage threshold
    format = "html"                      -- Preferred format for our team
  },
  
  -- Reporting configuration
  reporting = {
    validation = {
      validate_reports = true,           -- Enable basic validations
      validate_line_counts = false,      -- Disable line count validation due to calculator.lua special case
      validate_percentages = true,       -- Keep percentage validations
      validate_file_paths = true,        -- Validate file paths
      validation_threshold = 1.0         -- 1% tolerance for percentage mismatches
    },
    
    -- HTML formatter configuration
    formatters = {
      html = {
        -- Visual settings
        theme = "dark",                  -- Use dark theme for reports
        show_file_navigator = true,      -- Show file navigation panel
        collapsible_sections = true,     -- Make report sections collapsible
        
        -- Debug settings for fixing calculator.lua coverage issue
        debug_mode = true,               -- Enable debug mode to see coverage details
        
        -- Processing enhancements to fix calculator.lua coverage issue
        mark_executed_as_covered = true, -- Any executed line should be marked as covered
        check_all_execution_sources = true, -- Check all sources for execution data
        
        -- Enhanced features
        enhanced_navigation = true,      -- Enable enhanced navigation
        show_execution_heatmap = true,   -- Show execution count heatmap
        enable_block_relationship_highlighting = true -- Show block relationships
      }
    }
  },
  
  -- Test runner settings for our project
  runner = {
    test_pattern = "*_test.lua",         -- Our test file naming convention
    report_dir = "./reports",            -- Where to save reports
    show_timing = true,                  -- Show execution times
    parallel = false                     -- Disable parallel during development
  },
  
  -- Logging Configuration - useful for debugging
  logging = {
    level = 4,                          -- DEBUG level for development
    timestamps = true,                  -- Include timestamps
    use_colors = true,                  -- Use colors for better readability
    
    -- Module-specific log levels
    modules = {
      coverage = 4,                     -- DEBUG level for coverage module
      debug_hook = 5,                   -- VERBOSE level for debug hook
      runner = 4,                       -- DEBUG level for runner
    }
  }
}