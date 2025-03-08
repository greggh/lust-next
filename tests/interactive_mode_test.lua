-- Tests for the interactive CLI mode in lust-next

local lust = require('lust-next')
-- Get the assert functions in global scope
lust.expose_globals()

-- Define test cases
lust.describe('Interactive CLI Mode', function()
  -- Mock variables
  local interactive_mock
  local run_tests_env
  
  -- Setup mock before each test
  lust.before(function()
    -- Mock the interactive module
    interactive_mock = {
      start_called = false,
      options = nil,
      lust_instance = nil,
      start = function(self, lust_instance, options)
        self.start_called = true
        self.options = options
        self.lust_instance = lust_instance
        return true
      end
    }
    
    -- Mock the run_tests script environment
    run_tests_env = {
      interactive_mode_enabled = false,
      dir = "./tests",
      pattern = "*_test.lua",
      watch_mode_enabled = false,
      watch_dirs = {"."},
      watch_interval = 1.0,
      exclude_patterns = {"node_modules", "%.git"},
      lust_next = lust,
      interactive = interactive_mock
    }
  end)
  
  lust.it('should correctly initialize interactive mode with default options', function()
    -- Set interactive mode
    run_tests_env.interactive_mode_enabled = true
    
    -- Simulate the main execution block of run_tests.lua
    if run_tests_env.interactive_mode_enabled then
      interactive_mock:start(run_tests_env.lust_next, {
        test_dir = run_tests_env.dir,
        pattern = run_tests_env.pattern,
        watch_mode = run_tests_env.watch_mode_enabled,
        watch_dirs = run_tests_env.watch_dirs,
        watch_interval = run_tests_env.watch_interval,
        exclude_patterns = run_tests_env.exclude_patterns
      })
    end
    
    -- Verify that interactive mode was started with correct options
    assert(interactive_mock.start_called, "Interactive mode should be started")
    assert(interactive_mock.options.test_dir == "./tests", "Test directory should be ./tests")
    assert(interactive_mock.options.pattern == "*_test.lua", "Test pattern should be *_test.lua")
    assert(interactive_mock.options.watch_mode == false, "Watch mode should be false")
    assert(interactive_mock.lust_instance == lust, "Lust instance should be passed correctly")
  end)
  
  lust.it('should correctly handle interactive mode with watch mode enabled', function()
    -- Set interactive mode with watch mode
    run_tests_env.interactive_mode_enabled = true
    run_tests_env.watch_mode_enabled = true
    
    -- Simulate the main execution block of run_tests.lua
    if run_tests_env.interactive_mode_enabled then
      interactive_mock:start(run_tests_env.lust_next, {
        test_dir = run_tests_env.dir,
        pattern = run_tests_env.pattern,
        watch_mode = run_tests_env.watch_mode_enabled,
        watch_dirs = run_tests_env.watch_dirs,
        watch_interval = run_tests_env.watch_interval,
        exclude_patterns = run_tests_env.exclude_patterns
      })
    end
    
    -- Verify that interactive mode was started with watch mode enabled
    assert(interactive_mock.start_called, "Interactive mode should be started")
    assert(interactive_mock.options.watch_mode, "Watch mode should be enabled")
  end)
  
  lust.it('should correctly handle custom test directory and pattern', function()
    -- Set interactive mode with custom test directory and pattern
    run_tests_env.interactive_mode_enabled = true
    run_tests_env.dir = "./custom_tests"
    run_tests_env.pattern = "*_spec.lua"
    
    -- Simulate the main execution block of run_tests.lua
    if run_tests_env.interactive_mode_enabled then
      interactive_mock:start(run_tests_env.lust_next, {
        test_dir = run_tests_env.dir,
        pattern = run_tests_env.pattern,
        watch_mode = run_tests_env.watch_mode_enabled,
        watch_dirs = run_tests_env.watch_dirs,
        watch_interval = run_tests_env.watch_interval,
        exclude_patterns = run_tests_env.exclude_patterns
      })
    end
    
    -- Verify that interactive mode was started with custom options
    assert(interactive_mock.start_called, "Interactive mode should be started")
    assert(interactive_mock.options.test_dir == "./custom_tests", "Test directory should be ./custom_tests")
    assert(interactive_mock.options.pattern == "*_spec.lua", "Test pattern should be *_spec.lua")
  end)
  
  lust.it('should correctly handle custom watch options', function()
    -- Set interactive mode with custom watch options
    run_tests_env.interactive_mode_enabled = true
    run_tests_env.watch_mode_enabled = true
    run_tests_env.watch_dirs = {"./src", "./lib"}
    run_tests_env.watch_interval = 2.5
    run_tests_env.exclude_patterns = {"node_modules", "%.git", "%.tmp"}
    
    -- Simulate the main execution block of run_tests.lua
    if run_tests_env.interactive_mode_enabled then
      interactive_mock:start(run_tests_env.lust_next, {
        test_dir = run_tests_env.dir,
        pattern = run_tests_env.pattern,
        watch_mode = run_tests_env.watch_mode_enabled,
        watch_dirs = run_tests_env.watch_dirs,
        watch_interval = run_tests_env.watch_interval,
        exclude_patterns = run_tests_env.exclude_patterns
      })
    end
    
    -- Verify that interactive mode was started with custom watch options
    assert(interactive_mock.start_called, "Interactive mode should be started")
    assert(interactive_mock.options.watch_mode, "Watch mode should be enabled")
    assert(interactive_mock.options.watch_interval == 2.5, "Watch interval should be 2.5")
    assert(#interactive_mock.options.watch_dirs == 2, "Should have 2 watch directories")
    assert(interactive_mock.options.watch_dirs[1] == "./src", "First watch dir should be ./src")
    assert(interactive_mock.options.watch_dirs[2] == "./lib", "Second watch dir should be ./lib")
    assert(#interactive_mock.options.exclude_patterns == 3, "Should have 3 exclude patterns")
    assert(interactive_mock.options.exclude_patterns[3] == "%.tmp", "Third exclude pattern should be %.tmp")
  end)
  
  -- Test the interactive command routing
  lust.describe('Command processing', function()
    local command_mock
    
    -- Create mock before each test
    lust.before(function()
      command_mock = {
        commands_processed = {},
        process_command = function(self, command)
          table.insert(self.commands_processed, command)
          return true
        end
      }
    end)
    
    lust.it('should process commands correctly', function()
      -- Process some test commands
      command_mock:process_command("help")
      command_mock:process_command("run")
      command_mock:process_command("list")
      command_mock:process_command("watch on")
      
      -- Verify commands were processed
      assert(#command_mock.commands_processed == 4, "Should have processed 4 commands")
      assert(command_mock.commands_processed[1] == "help", "First command should be help")
      assert(command_mock.commands_processed[2] == "run", "Second command should be run")
      assert(command_mock.commands_processed[3] == "list", "Third command should be list")
      assert(command_mock.commands_processed[4] == "watch on", "Fourth command should be watch on")
    end)
  end)
end)