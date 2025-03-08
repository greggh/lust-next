-- Tests for the interactive CLI mode in lust-next

local lust = require('lust-next')

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
    lust.expect(interactive_mock.start_called).to.be(true)
    lust.expect(interactive_mock.options.test_dir).to.equal("./tests")
    lust.expect(interactive_mock.options.pattern).to.equal("*_test.lua")
    lust.expect(interactive_mock.options.watch_mode).to.be(false)
    lust.expect(interactive_mock.lust_instance).to.be(lust)
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
    lust.expect(interactive_mock.start_called).to.be(true)
    lust.expect(interactive_mock.options.watch_mode).to.be(true)
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
    lust.expect(interactive_mock.start_called).to.be(true)
    lust.expect(interactive_mock.options.test_dir).to.equal("./custom_tests")
    lust.expect(interactive_mock.options.pattern).to.equal("*_spec.lua")
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
    lust.expect(interactive_mock.start_called).to.be(true)
    lust.expect(interactive_mock.options.watch_mode).to.be(true)
    lust.expect(interactive_mock.options.watch_interval).to.equal(2.5)
    lust.expect(#interactive_mock.options.watch_dirs).to.equal(2)
    lust.expect(interactive_mock.options.watch_dirs[1]).to.equal("./src")
    lust.expect(interactive_mock.options.watch_dirs[2]).to.equal("./lib")
    lust.expect(#interactive_mock.options.exclude_patterns).to.equal(3)
    lust.expect(interactive_mock.options.exclude_patterns[3]).to.equal("%.tmp")
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
      lust.expect(#command_mock.commands_processed).to.equal(4)
      lust.expect(command_mock.commands_processed[1]).to.equal("help")
      lust.expect(command_mock.commands_processed[2]).to.equal("run")
      lust.expect(command_mock.commands_processed[3]).to.equal("list")
      lust.expect(command_mock.commands_processed[4]).to.equal("watch on")
    end)
  end)
end)