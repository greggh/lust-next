#!/usr/bin/env lua
-- Version Bump Script
-- Updates version across all project files

-- Initialize logging system
local logging
---@diagnostic disable-next-line: unused-local
local ok, err = pcall(function()
  logging = require("lib.tools.logging")
end)
if not ok or not logging then
  -- Fall back to standard print if logging module isn't available
  logging = {
    configure = function() end,
    get_logger = function()
      return {
        info = print,
        error = print,
        warn = print,
        debug = print,
        verbose = print,
      }
    end,
  }
end

-- Get logger for version_bump module
---@diagnostic disable-next-line: redundant-parameter
local logger = logging.get_logger("version_bump")
-- Configure from config if possible
logging.configure_from_config("version_bump")

-- Load the filesystem module
local fs = require("lib.tools.filesystem")
logger.debug("Loaded filesystem module", { version = fs._VERSION })

-- Configuration
local config = {
  -- Known files that should contain version information
  version_files = {
    -- Main source of truth
    {
      path = "lua/%s/version.lua",
      pattern = "M.major = (%d+).-M.minor = (%d+).-M.patch = (%d+)",
      replacement = function(new_version)
        local major, minor, patch = new_version:match("(%d+)%.(%d+)%.(%d+)")
        return string.format("M.major = %s\nM.minor = %s\nM.patch = %s", major, minor, patch)
      end,
      complex = true,
    },
    -- Documentation files
    { path = "README.md", pattern = "Version: v([%d%.]+)", replacement = "Version: v%s" },
    { path = "CHANGELOG.md", pattern = "## %[Unreleased%]", replacement = "## [Unreleased]\n\n## [%s] - %s" },
    -- Optional source files
    { path = "lua/%s/init.lua", pattern = 'version = "([%d%.]+)"', replacement = 'version = "%s"' },
    { path = "lua/%s.lua", pattern = 'version = "([%d%.]+)"', replacement = 'version = "%s"' },
    -- Package files
    { path = "%s.rockspec", pattern = 'version = "([%d%.]+)"', replacement = 'version = "%s"' },
    { path = "package.json", pattern = '"version": "([%d%.]+)"', replacement = '"version": "%s"' },
  },
}

-- Get the project name from the script argument or from the current directory
local project_name = arg[1]
if not project_name then
  local pwd = fs.get_absolute_path(".")
  ---@diagnostic disable-next-line: need-check-nil
  local project_name_with_path = pwd:match("/([^/]+)$")
  project_name = project_name_with_path:gsub("%-", "_")
end

-- Get the new version from the command line
local new_version = arg[2]
if not new_version then
  -- Usage info should be printed directly to stdout, regardless of log level
  print("Usage: lua version_bump.lua [project_name] <new_version>")
  print("Example: lua version_bump.lua 1.2.3")
  os.exit(1)
end

-- Validate version format
if not new_version:match("^%d+%.%d+%.%d+$") then
  logger.error("Version must be in the format X.Y.Z (e.g., 1.2.3)")
  os.exit(1)
end

-- Get the current date for CHANGELOG updates
local current_date = os.date("%Y-%m-%d")

-- Load the filesystem module
local fs = require("lib.tools.filesystem")
logger.debug("Loaded filesystem module", { version = fs._VERSION })

-- Function to extract version from file using pattern
local function extract_version(path, pattern)
  local content, err = fs.read_file(path)
  if not content then
    return nil, "Could not read " .. path .. ": " .. tostring(err)
  end

  -- Handle patterns that return multiple captures (like the structured version.lua)
  local major, minor, patch = content:match(pattern)
  if major and minor and patch then
    -- This is a structured version with multiple components
    return major .. "." .. minor .. "." .. patch
  end

  -- Regular single capture pattern
  local version = content:match(pattern)
  return version
end

-- Format path with project name
local function format_path(path_template)
  return path_template:format(project_name)
end

-- Check if a file exists
local function file_exists(path)
  return fs.file_exists(path)
end

-- Update the version in a file
local function update_version(file_config, new_version)
  local path = format_path(file_config.path)

  if not file_exists(path) then
    logger.warn("⚠️ File not found, skipping: " .. path)
    return true
  end

  local content, err = fs.read_file(path)
  if not content then
    logger.error("❌ Error reading file: " .. path .. " - " .. tostring(err))
    return false
  end

  -- Special handling for CHANGELOG.md
  if path:match("CHANGELOG.md$") then
    -- Check if [Unreleased] section exists
    if not content:match("## %[Unreleased%]") then
      logger.error("❌ CHANGELOG.md does not have an [Unreleased] section. Please add one.")
      return false
    end

    -- Ensure [Unreleased] has content for the new version
    if content:match("## %[Unreleased%]%s*\n\n## ") then
      logger.warn("⚠️ Warning: [Unreleased] section in CHANGELOG.md appears to be empty.")
    end

    -- Replace the Unreleased section header to add the new version
    local new_content =
      content:gsub("## %[Unreleased%]", string.format("## [Unreleased]\n\n## [%s] - %s", new_version, current_date))

    -- Update comparison links at the bottom
    local old_version = extract_version(path, "## %[([%d%.]+)%]")
    if old_version then
      -- Ensure the template URL exists
      if content:match("%[Unreleased%]: .+/compare/v[%d%.]+%.%.%.HEAD") then
        -- Update existing comparison links
        new_content = new_content:gsub(
          "%[Unreleased%]: (.+)/compare/v[%d%.]+%.%.%.HEAD",
          string.format("[Unreleased]: %%1/compare/v%s...HEAD", new_version)
        )
        new_content = new_content:gsub(
          "%[" .. old_version .. "%]: .+/compare/v.-%.%.%.v" .. old_version,
          string.format("[%s]: %%1/compare/v%s...v%s", old_version, old_version:match("^%d+%.%d+%.%d+"), old_version)
        )

        -- Add new version comparison link
        new_content = new_content:gsub(
          "%[Unreleased%]: (.+)/compare/v" .. new_version .. "%.%.%.HEAD",
          string.format(
            "[Unreleased]: %%1/compare/v%s...HEAD\n[%s]: %%1/compare/v%s...v%s",
            new_version,
            new_version,
            old_version,
            new_version
          )
        )
      end
    end

    local success, write_err = fs.write_file(path, new_content)
    if not success then
      logger.error("❌ Error writing file: " .. path .. " - " .. tostring(write_err))
      return false
    end

    logger.info("✅ Updated version in: " .. path)
    return true
  else
    -- Standard replacement for other files
    local old_version = extract_version(path, file_config.pattern)
    if not old_version then
      logger.warn("⚠️ Could not find version pattern in: " .. path)
      return true -- Not a fatal error
    end

    local new_content
    if file_config.complex then
      -- Use a function-based replacement for complex patterns
      if type(file_config.replacement) == "function" then
        -- For structured version files like version.lua
        local replacement_text = file_config.replacement(new_version)
        new_content = content:gsub(file_config.pattern, replacement_text)
      else
        logger.error("❌ Complex replacement specified but no function provided for: " .. path)
        return false
      end
    else
      -- Simple string replacement
      local replacement = string.format(file_config.replacement, new_version)
      local pattern_escaped = file_config.pattern:gsub("%(", "%%("):gsub("%)", "%%)"):gsub("%%", "%%%%")
      new_content = content:gsub(pattern_escaped, replacement)
    end

    if new_content == content then
      logger.warn("⚠️ No changes made to: " .. path)
      return true
    end

    local success, write_err = fs.write_file(path, new_content)
    if not success then
      logger.error("❌ Error writing file: " .. path .. " - " .. tostring(write_err))
      return false
    end

    logger.info("✅ Updated version " .. old_version .. " → " .. new_version .. " in: " .. path)
    return true
  end
end

-- Main function to update all versions
local function bump_version(new_version)
  logger.info("Bumping version to: " .. new_version)

  local all_success = true

  -- First, update the canonical version
  local version_file_config = config.version_files[1]
  local version_file_path = format_path(version_file_config.path)

  if not file_exists(version_file_path) then
    logger.error("❌ Canonical version file not found: " .. version_file_path)

    -- Ask if we should create it
    io.write("Would you like to create it? (y/n): ")
    local answer = io.read()
    if answer:lower() == "y" or answer:lower() == "yes" then
      -- Get the directory path
      local dir_path = version_file_path:match("(.+)/[^/]+$")
      if dir_path then
        fs.ensure_directory_exists(dir_path)
        fs.write_file(version_file_path, string.format('return "%s"', new_version))
        logger.info("✅ Created version file: " .. version_file_path)
      else
        logger.error("❌ Could not determine directory path for: " .. version_file_path)
        return false
      end
    else
      return false
    end
  end

  -- Update each file
  for _, file_config in ipairs(config.version_files) do
    local success = update_version(file_config, new_version)
    if not success then
      all_success = false
    end
  end

  if all_success then
    logger.info("\n🎉 Version bumped to " .. new_version .. " successfully!")
    logger.info("\nRemember to:")
    logger.info("1. Review the changes, especially in CHANGELOG.md")
    logger.info('2. Commit the changes: git commit -m "Release: Version ' .. new_version .. '"')
    logger.info("3. Create a tag: git tag -a v" .. new_version .. ' -m "Version ' .. new_version .. '"')
    logger.info("4. Push the changes: git push && git push --tags")
    return true
  else
    logger.warn("\n⚠️ Version bump completed with some errors.")
    return false
  end
end

-- Run the version bump
local success = bump_version(new_version)
if not success then
  os.exit(1)
end
