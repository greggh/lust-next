-- Interactive CLI module for lust-next
local interactive = {}
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("interactive")
logging.configure_from_config("interactive")

-- Try to load required modules
local has_discovery, discover = pcall(require, "discover")
local has_runner, runner = pcall(require, "runner")
local has_watcher, watcher = pcall(require, "lib.tools.watcher")
local has_codefix, codefix = pcall(require, "lib.tools.codefix")

-- ANSI color codes
local colors = {
  red = string.char(27) .. '[31m',
  green = string.char(27) .. '[32m',
  yellow = string.char(27) .. '[33m',
  blue = string.char(27) .. '[34m',
  magenta = string.char(27) .. '[35m',
  cyan = string.char(27) .. '[36m',
  white = string.char(27) .. '[37m',
  bold = string.char(27) .. '[1m',
  normal = string.char(27) .. '[0m',
}

-- Current state of the interactive CLI
local state = {
  lust = nil,
  test_dir = "./tests",
  test_pattern = "*_test.lua",
  current_files = {},
  focus_filter = nil,
  tag_filter = nil,
  watch_mode = false,
  watch_dirs = {"."},
  watch_interval = 1.0,
  exclude_patterns = {"node_modules", "%.git"},
  last_command = nil,
  history = {},
  history_pos = 1,
  codefix_enabled = false,
  running = true,
}

-- Print the interactive CLI header
local function print_header()
  io.write("\027[2J\027[H")  -- Clear screen
  print(colors.bold .. colors.cyan .. "Lust-Next Interactive CLI" .. colors.normal)
  print(colors.green .. "Type 'help' for available commands" .. colors.normal)
  print(string.rep("-", 60))
  logger.debug("Interactive CLI initialized")
end

-- Print help information
local function print_help()
  print(colors.bold .. "Available commands:" .. colors.normal)
  print("  help                Show this help message")
  print("  run [file]          Run all tests or a specific test file")
  print("  list                List available test files")
  print("  filter <pattern>    Filter tests by name pattern")
  print("  focus <name>        Focus on specific test (partial name match)")
  print("  tags <tag1,tag2>    Run tests with specific tags")
  print("  watch <on|off>      Toggle watch mode")
  print("  watch-dir <path>    Add directory to watch")
  logger.debug("Help information displayed")
  print("  watch-exclude <pat> Add exclusion pattern for watch")
  print("  codefix <cmd> <dir> Run codefix (check|fix) on directory")
  print("  dir <path>          Set test directory")
  print("  pattern <pat>       Set test file pattern")
  print("  clear               Clear the screen")
  print("  status              Show current settings")
  print("  history             Show command history")
  print("  exit                Exit the interactive CLI")
  print("\n" .. colors.bold .. "Keyboard shortcuts:" .. colors.normal)
  print("  Up/Down             Navigate command history")
  print("  Ctrl+C              Exit interactive mode")
  print(string.rep("-", 60))
end

-- Show current state/settings
local function print_status()
  print(colors.bold .. "Current settings:" .. colors.normal)
  print("  Test directory:     " .. state.test_dir)
  print("  Test pattern:       " .. state.test_pattern)
  print("  Focus filter:       " .. (state.focus_filter or "none"))
  print("  Tag filter:         " .. (state.tag_filter or "none"))
  print("  Watch mode:         " .. (state.watch_mode and "enabled" or "disabled"))
  
  if state.watch_mode then
    print("  Watch directories:  " .. table.concat(state.watch_dirs, ", "))
    print("  Watch interval:     " .. state.watch_interval .. "s")
    print("  Exclude patterns:   " .. table.concat(state.exclude_patterns, ", "))
  end
  
  print("  Codefix:            " .. (state.codefix_enabled and "enabled" or "disabled"))
  print("  Available tests:    " .. #state.current_files)
  print(string.rep("-", 60))
  
  logger.debug("Status displayed - Tests: " .. #state.current_files .. 
               ", Watch: " .. (state.watch_mode and "on" or "off") .. 
               ", Focus: " .. (state.focus_filter or "none"))
end

-- List available test files
local function list_test_files()
  if #state.current_files == 0 then
    print(colors.yellow .. "No test files found in " .. state.test_dir .. colors.normal)
    logger.warn("No test files found in directory: " .. state.test_dir)
    return
  end
  
  print(colors.bold .. "Available test files:" .. colors.normal)
  for i, file in ipairs(state.current_files) do
    print("  " .. i .. ". " .. file)
  end
  print(string.rep("-", 60))
  logger.debug("Listed " .. #state.current_files .. " test files")
end

-- Discover test files
local function discover_test_files()
  if has_discovery then
    logger.debug("Discovering test files in " .. state.test_dir .. " with pattern " .. state.test_pattern)
    state.current_files = discover.find_tests(state.test_dir, state.test_pattern)
    logger.debug("Found " .. #state.current_files .. " test files")
    return #state.current_files > 0
  else
    print(colors.red .. "Error: Discovery module not available" .. colors.normal)
    logger.error("Discovery module not available")
    return false
  end
end

-- Run tests
local function run_tests(file_path)
  if not has_runner then
    print(colors.red .. "Error: Runner module not available" .. colors.normal)
    logger.error("Runner module not available")
    return false
  end
  
  -- Reset lust state
  state.lust.reset()
  logger.debug("Lust state reset before test run")
  
  local success = false
  
  if file_path then
    -- Run single file
    print(colors.cyan .. "Running file: " .. file_path .. colors.normal)
    logger.info("Running single test file: " .. file_path)
    local results = runner.run_file(file_path, state.lust)
    success = results.success and results.errors == 0
    logger.info("Test run completed with " .. (success and "success" or "failures"))
  else
    -- Run all discovered files
    if #state.current_files == 0 then
      if not discover_test_files() then
        print(colors.yellow .. "No test files found. Check test directory and pattern." .. colors.normal)
        logger.warn("No test files found to run. Check test directory and pattern.")
        return false
      end
    end
    
    print(colors.cyan .. "Running " .. #state.current_files .. " test files..." .. colors.normal)
    logger.info("Running " .. #state.current_files .. " test files")
    success = runner.run_all(state.current_files, state.lust)
    logger.info("Test run completed with " .. (success and "success" or "failures"))
  end
  
  return success
end

-- Start watch mode
local function start_watch_mode()
  if not has_watcher then
    print(colors.red .. "Error: Watch module not available" .. colors.normal)
    logger.error("Watch module not available, can't start watch mode")
    return false
  end
  
  if not has_runner then
    print(colors.red .. "Error: Runner module not available" .. colors.normal)
    logger.error("Runner module not available, can't start watch mode")
    return false
  end
  
  print(colors.cyan .. "Starting watch mode..." .. colors.normal)
  print("Watching directories: " .. table.concat(state.watch_dirs, ", "))
  print("Press Enter to return to interactive mode")
  
  logger.info("Starting watch mode on directories: " .. table.concat(state.watch_dirs, ", "))
  
  watcher.set_check_interval(state.watch_interval)
  watcher.init(state.watch_dirs, state.exclude_patterns)
  
  -- Initial test run
  if #state.current_files == 0 then
    discover_test_files()
  end
  
  local last_run_time = os.time()
  local debounce_time = 0.5 -- seconds to wait after changes before running tests
  local last_change_time = 0
  local need_to_run = true
  
  -- Watch loop
  local watch_running = true
  
  -- Create a non-blocking input check
  local function check_input()
    local input_available = io.read(0) ~= nil
    if input_available then
      -- Consume the input
      io.read("*l")
      watch_running = false
    end
    return input_available
  end
  
  -- Clear terminal
  io.write("\027[2J\027[H")
  
  -- Initial test run
  state.lust.reset()
  runner.run_all(state.current_files, state.lust)
  
  print(colors.cyan .. "\n--- WATCHING FOR CHANGES (Press Enter to return to interactive mode) ---" .. colors.normal)
  logger.info("Watch mode active, waiting for changes")
  
  while watch_running do
    local current_time = os.time()
    
    -- Check for file changes
    local changed_files = watcher.check_for_changes()
    if changed_files then
      last_change_time = current_time
      need_to_run = true
      
      print(colors.yellow .. "\nFile changes detected:" .. colors.normal)
      for _, file in ipairs(changed_files) do
        print("  - " .. file)
      end
      
      logger.info("File changes detected: " .. #changed_files .. " files changed")
      logger.debug("Changed files: " .. table.concat(changed_files, ", "))
    end
    
    -- Run tests if needed and after debounce period
    if need_to_run and current_time - last_change_time >= debounce_time then
      print(colors.cyan .. "\n--- RUNNING TESTS ---" .. colors.normal)
      print(os.date("%Y-%m-%d %H:%M:%S"))
      
      -- Clear terminal
      io.write("\027[2J\027[H")
      
      logger.info("Running tests after file changes (debounce: " .. debounce_time .. "s)")
      state.lust.reset()
      runner.run_all(state.current_files, state.lust)
      last_run_time = current_time
      need_to_run = false
      
      print(colors.cyan .. "\n--- WATCHING FOR CHANGES (Press Enter to return to interactive mode) ---" .. colors.normal)
      logger.info("Watch mode resumed after test run")
    end
    
    -- Check for input to exit watch mode
    if check_input() then
      break
    end
    
    -- Small sleep to prevent CPU hogging
    os.execute("sleep 0.1")
  end
  
  return true
end

-- Run codefix operations
local function run_codefix(command, target)
  if not has_codefix then
    print(colors.red .. "Error: Codefix module not available" .. colors.normal)
    logger.error("Codefix module not available")
    return false
  end
  
  if not command or not target then
    print(colors.yellow .. "Usage: codefix <check|fix> <directory>" .. colors.normal)
    logger.warn("Invalid codefix usage - command or target missing")
    return false
  end
  
  -- Initialize codefix if needed
  if not state.codefix_enabled then
    logger.debug("Initializing codefix module")
    codefix.init({
      enabled = true,
      verbose = true
    })
    state.codefix_enabled = true
  end
  
  print(colors.cyan .. "Running codefix: " .. command .. " " .. target .. colors.normal)
  logger.info("Running codefix operation: " .. command .. " on " .. target)
  
  local codefix_args = {command, target}
  local success = codefix.run_cli(codefix_args)
  
  if success then
    print(colors.green .. "Codefix completed successfully" .. colors.normal)
    logger.info("Codefix operation completed successfully")
  else
    print(colors.red .. "Codefix failed" .. colors.normal)
    logger.warn("Codefix operation failed")
  end
  
  return success
end

-- Add command to history
local function add_to_history(command)
  -- Don't add empty commands or duplicates of the last command
  if command == "" or (state.history[#state.history] == command) then
    return
  end
  
  table.insert(state.history, command)
  state.history_pos = #state.history + 1
  
  -- Limit history size
  if #state.history > 100 then
    table.remove(state.history, 1)
  end
end

-- Process a command
local function process_command(input)
  -- Add to history
  add_to_history(input)
  
  -- Split into command and arguments
  local command, args = input:match("^(%S+)%s*(.*)$")
  if not command then return false end
  
  command = command:lower()
  state.last_command = command
  
  if command == "help" or command == "h" then
    print_help()
    return true
    
  elseif command == "exit" or command == "quit" or command == "q" then
    state.running = false
    return true
    
  elseif command == "clear" or command == "cls" then
    print_header()
    return true
    
  elseif command == "status" then
    print_status()
    return true
    
  elseif command == "list" or command == "ls" then
    list_test_files()
    return true
    
  elseif command == "run" or command == "r" then
    if args and args ~= "" then
      return run_tests(args)
    else
      return run_tests()
    end
    
  elseif command == "dir" or command == "directory" then
    if not args or args == "" then
      print(colors.yellow .. "Current test directory: " .. state.test_dir .. colors.normal)
      return true
    end
    
    state.test_dir = args
    print(colors.green .. "Test directory set to: " .. state.test_dir .. colors.normal)
    
    -- Rediscover tests with new directory
    discover_test_files()
    return true
    
  elseif command == "pattern" or command == "pat" then
    if not args or args == "" then
      print(colors.yellow .. "Current test pattern: " .. state.test_pattern .. colors.normal)
      return true
    end
    
    state.test_pattern = args
    print(colors.green .. "Test pattern set to: " .. state.test_pattern .. colors.normal)
    
    -- Rediscover tests with new pattern
    discover_test_files()
    return true
    
  elseif command == "filter" then
    if not args or args == "" then
      state.focus_filter = nil
      print(colors.green .. "Test filter cleared" .. colors.normal)
      return true
    end
    
    state.focus_filter = args
    print(colors.green .. "Test filter set to: " .. state.focus_filter .. colors.normal)
    
    -- Apply filter to lust
    if state.lust and state.lust.set_filter then
      state.lust.set_filter(state.focus_filter)
    end
    
    return true
    
  elseif command == "focus" then
    if not args or args == "" then
      state.focus_filter = nil
      print(colors.green .. "Test focus cleared" .. colors.normal)
      return true
    end
    
    state.focus_filter = args
    print(colors.green .. "Test focus set to: " .. state.focus_filter .. colors.normal)
    
    -- Apply focus to lust
    if state.lust and state.lust.focus then
      state.lust.focus(state.focus_filter)
    end
    
    return true
    
  elseif command == "tags" then
    if not args or args == "" then
      state.tag_filter = nil
      print(colors.green .. "Tag filter cleared" .. colors.normal)
      return true
    end
    
    state.tag_filter = args
    print(colors.green .. "Tag filter set to: " .. state.tag_filter .. colors.normal)
    
    -- Apply tags to lust
    if state.lust and state.lust.filter_tags then
      local tags = {}
      for tag in state.tag_filter:gmatch("([^,]+)") do
        table.insert(tags, tag:match("^%s*(.-)%s*$")) -- Trim spaces
      end
      state.lust.filter_tags(tags)
    end
    
    return true
    
  elseif command == "watch" then
    if args == "on" or args == "true" or args == "1" then
      state.watch_mode = true
      print(colors.green .. "Watch mode enabled" .. colors.normal)
      return start_watch_mode()
    elseif args == "off" or args == "false" or args == "0" then
      state.watch_mode = false
      print(colors.green .. "Watch mode disabled" .. colors.normal)
      return true
    else
      -- Toggle watch mode
      state.watch_mode = not state.watch_mode
      print(colors.green .. "Watch mode " .. (state.watch_mode and "enabled" or "disabled") .. colors.normal)
      
      if state.watch_mode then
        return start_watch_mode()
      end
      
      return true
    end
    
  elseif command == "watch-dir" or command == "watchdir" then
    if not args or args == "" then
      print(colors.yellow .. "Current watch directories: " .. table.concat(state.watch_dirs, ", ") .. colors.normal)
      return true
    end
    
    -- Reset the default directory if this is the first watch dir
    if #state.watch_dirs == 1 and state.watch_dirs[1] == "." then
      state.watch_dirs = {}
    end
    
    table.insert(state.watch_dirs, args)
    print(colors.green .. "Added watch directory: " .. args .. colors.normal)
    return true
    
  elseif command == "watch-exclude" or command == "exclude" then
    if not args or args == "" then
      print(colors.yellow .. "Current exclusion patterns: " .. table.concat(state.exclude_patterns, ", ") .. colors.normal)
      return true
    end
    
    table.insert(state.exclude_patterns, args)
    print(colors.green .. "Added exclusion pattern: " .. args .. colors.normal)
    return true
    
  elseif command == "codefix" then
    -- Split args into command and target
    local codefix_cmd, target = args:match("^(%S+)%s*(.*)$")
    if not codefix_cmd or not target or target == "" then
      print(colors.yellow .. "Usage: codefix <check|fix> <directory>" .. colors.normal)
      return false
    end
    
    return run_codefix(codefix_cmd, target)
    
  elseif command == "history" or command == "hist" then
    print(colors.bold .. "Command History:" .. colors.normal)
    for i, cmd in ipairs(state.history) do
      print("  " .. i .. ". " .. cmd)
    end
    return true
    
  else
    print(colors.red .. "Unknown command: " .. command .. colors.normal)
    print("Type 'help' for available commands")
    return false
  end
end

-- Read a line with history navigation
local function read_line_with_history()
  local line = io.read("*l")
  return line
end

-- Main entry point for the interactive CLI
function interactive.start(lust, options)
  options = options or {}
  
  -- Set initial state
  state.lust = lust
  
  if options.test_dir then state.test_dir = options.test_dir end
  if options.pattern then state.test_pattern = options.pattern end
  if options.watch_mode ~= nil then state.watch_mode = options.watch_mode end
  
  -- Discover test files
  discover_test_files()
  
  -- Print header
  print_header()
  
  -- Print initial status
  print_status()
  
  -- Start watch mode if enabled
  if state.watch_mode then
    start_watch_mode()
  end
  
  -- Main loop
  while state.running do
    io.write(colors.green .. "> " .. colors.normal)
    local input = read_line_with_history()
    
    if input then
      process_command(input)
    end
  end
  
  print(colors.cyan .. "Exiting interactive mode" .. colors.normal)
  return true
end

return interactive