local lust = require("lust-next")
local fs = require("lib.tools.filesystem")
local describe, it, expect = lust.describe, lust.it, lust.expect

describe("Filesystem Module", function()
    local test_dir = "/tmp/lust-next-fs-test"
    local test_file = "/tmp/lust-next-fs-test/test.txt"
    local test_content = "Hello, world!"
    
    -- Helper function to clean up test directory
    local function cleanup()
        fs.delete_directory(test_dir, true)
    end
    
    -- Run cleanup before tests
    cleanup()
    
    -- We don't have after_all, so we'll clean up in the last test
    -- The last test in the file is in the "Information Functions" describe block
    
    describe("Core File Operations", function()
        it("should create directories", function()
            local success = fs.create_directory(test_dir)
            expect(success).to.be(true)
            expect(fs.directory_exists(test_dir)).to.be(true)
        end)
        
        it("should write and read files", function()
            local write_success = fs.write_file(test_file, test_content)
            expect(write_success).to.be(true)
            expect(fs.file_exists(test_file)).to.be(true)
            
            local content = fs.read_file(test_file)
            expect(content).to.be(test_content)
        end)
        
        it("should append to files", function()
            local append_content = "\nAppended content"
            local append_success = fs.append_file(test_file, append_content)
            expect(append_success).to.be(true)
            
            local content = fs.read_file(test_file)
            expect(content).to.be(test_content .. append_content)
        end)
        
        it("should copy files", function()
            local copy_file = "/tmp/lust-next-fs-test/test-copy.txt"
            local success = fs.copy_file(test_file, copy_file)
            expect(success).to.be(true)
            expect(fs.file_exists(copy_file)).to.be(true)
            
            local content = fs.read_file(copy_file)
            expect(content).to.be(test_content .. "\nAppended content")
        end)
        
        it("should move files", function()
            local moved_file = "/tmp/lust-next-fs-test/test-moved.txt"
            local copy_file = "/tmp/lust-next-fs-test/test-copy.txt"
            
            local success = fs.move_file(copy_file, moved_file)
            expect(success).to.be(true)
            expect(fs.file_exists(moved_file)).to.be(true)
            expect(fs.file_exists(copy_file)).to.be(false)
        end)
        
        it("should delete files", function()
            local moved_file = "/tmp/lust-next-fs-test/test-moved.txt"
            local success = fs.delete_file(moved_file)
            expect(success).to.be(true)
            expect(fs.file_exists(moved_file)).to.be(false)
        end)
    end)
    
    describe("Directory Operations", function()
        it("should ensure directory exists", function()
            local nested_dir = "/tmp/lust-next-fs-test/nested/path"
            local success = fs.ensure_directory_exists(nested_dir)
            expect(success).to.be(true)
            expect(fs.directory_exists(nested_dir)).to.be(true)
        end)
        
        it("should get directory contents", function()
            -- Create a few test files
            fs.write_file("/tmp/lust-next-fs-test/file1.txt", "File 1")
            fs.write_file("/tmp/lust-next-fs-test/file2.txt", "File 2")
            
            local contents = fs.get_directory_contents(test_dir)
            expect(#contents).to.be.at_least(3) -- file1.txt, file2.txt, nested/ directory
            
            -- Check if files exist in the listing
            local has_file1 = false
            local has_file2 = false
            local has_nested = false
            
            for _, item in ipairs(contents) do
                if item == "file1.txt" then has_file1 = true end
                if item == "file2.txt" then has_file2 = true end
                if item == "nested" then has_nested = true end
            end
            
            expect(has_file1).to.be(true)
            expect(has_file2).to.be(true)
            expect(has_nested).to.be(true)
        end)
        
        it("should delete directories", function()
            local nested_dir = "/tmp/lust-next-fs-test/nested"
            
            -- Try non-recursive delete on non-empty directory (should fail)
            local success, err = fs.delete_directory(nested_dir, false)
            expect(success).to.be(nil)
            expect(err).to.contain("Directory not empty")
            expect(fs.directory_exists(nested_dir)).to.be(true)
            
            -- Try recursive delete (should succeed)
            success = fs.delete_directory(nested_dir, true)
            expect(success).to.be(true)
            expect(fs.directory_exists(nested_dir)).to.be(false)
        end)
    end)
    
    describe("Path Manipulation", function()
        it("should normalize paths", function()
            expect(fs.normalize_path("/path/to//file")).to.be("/path/to/file")
            expect(fs.normalize_path("/path/to/file/")).to.be("/path/to/file")
            expect(fs.normalize_path("path\\to\\file")).to.be("path/to/file")
        end)
        
        it("should join paths", function()
            expect(fs.join_paths("/path", "to", "file")).to.be("/path/to/file")
            expect(fs.join_paths("/path/", "/to/", "/file")).to.be("/path/to/file")
            expect(fs.join_paths("path", "./to", "../path/file")).to.be("path/./to/../path/file")
        end)
        
        it("should get directory name", function()
            local dir1 = fs.get_directory_name("/path/to/file")
            expect(dir1).to.be("/path/to")
            
            local dir2 = fs.get_directory_name("file.txt")
            expect(dir2).to.be(".")
            
            local dir3 = fs.get_directory_name("/path/")
            expect(dir3).to.be("/path")
        end)
        
        it("should get file name", function()
            -- Get file name from path with directories
            local name1 = fs.get_file_name("/path/to/file.txt")
            expect(name1).to.be("file.txt")
            
            -- Directory path should return empty string
            local name2 = fs.get_file_name("/path/to/")
            expect(name2).to.be("")
            
            -- Just a filename should return itself
            local name3 = fs.get_file_name("file.txt")
            expect(name3).to.be("file.txt")
        end)
        
        it("should get file extension", function()
            expect(fs.get_extension("/path/to/file.txt")).to.be("txt")
            expect(fs.get_extension("file.tar.gz")).to.be("gz")
            expect(fs.get_extension("file")).to.be("")
        end)
        
        it("should convert to absolute path", function()
            -- This is a bit tricky to test since it depends on current directory
            local abs_path = fs.get_absolute_path("relative/path")
            expect(abs_path:sub(1, 1)).to.be("/") -- Should start with /
        end)
        
        it("should convert to relative path", function()
            expect(fs.get_relative_path("/a/b/c/d", "/a/b")).to.be("c/d")
            expect(fs.get_relative_path("/a/b/c", "/a/b/c/d")).to.be("..")
            expect(fs.get_relative_path("/a/b/c", "/a/b/c")).to.be(".")
            expect(fs.get_relative_path("/a/b/c", "/x/y/z")).to.be("../../../a/b/c")
        end)
    end)
    
    describe("File Discovery", function()
        it("should convert glob to pattern", function()
            local pattern = fs.glob_to_pattern("*.lua")
            expect(pattern ~= nil).to.be(true)
            expect(("test.lua"):match(pattern) ~= nil).to.be(true)
            expect(("test.txt"):match(pattern) == nil).to.be(true)
        end)
        
        it("should test if path matches pattern", function()
            expect(fs.matches_pattern("test.lua", "*.lua")).to.be(true)
            expect(fs.matches_pattern("test.txt", "*.lua")).to.be(false)
            expect(fs.matches_pattern("test/file.lua", "test/*.lua")).to.be(true)
            expect(fs.matches_pattern("test/file.lua", "test/*.txt")).to.be(false)
        end)
        
        it("should discover files", function()
            -- Create test directory structure
            fs.ensure_directory_exists("/tmp/lust-next-fs-test/discover/a")
            fs.ensure_directory_exists("/tmp/lust-next-fs-test/discover/b")
            fs.write_file("/tmp/lust-next-fs-test/discover/file1.lua", "test")
            fs.write_file("/tmp/lust-next-fs-test/discover/file2.txt", "test")
            fs.write_file("/tmp/lust-next-fs-test/discover/a/file3.lua", "test")
            fs.write_file("/tmp/lust-next-fs-test/discover/b/file4.lua", "test")
            
            local files = fs.discover_files({"/tmp/lust-next-fs-test/discover"}, {"*.lua"})
            
            -- Print the found files for debugging
            print("\nFound files:")
            for _, file in ipairs(files) do
                print("  - " .. file)
            end
            
            expect(#files).to.be(3) -- Should find all 3 .lua files
            
            -- Test with exclude patterns
            local filtered_files = fs.discover_files(
                {"/tmp/lust-next-fs-test/discover"}, 
                {"*.lua"}, 
                {"a/*"}
            )
            expect(#filtered_files).to.be(2) -- Should exclude file3.lua in directory a
        end)
        
        it("should scan directory", function()
            local files = fs.scan_directory("/tmp/lust-next-fs-test/discover", false)
            expect(#files).to.be(2) -- Should only get files in the root, not subdirectories
            
            local all_files = fs.scan_directory("/tmp/lust-next-fs-test/discover", true)
            expect(#all_files).to.be(4) -- Should get all files recursively
        end)
        
        it("should find matches", function()
            local all_files = fs.scan_directory("/tmp/lust-next-fs-test/discover", true)
            
            -- Print all scanned files
            print("\nAll files from scan_directory:")
            for _, file in ipairs(all_files) do
                print("  - " .. file)
            end
            
            local lua_files = fs.find_matches(all_files, "*.lua")
            
            -- Print lua matches
            print("\nLua files from find_matches:")
            for _, file in ipairs(lua_files) do
                print("  - " .. file)
            end
            
            expect(#lua_files).to.be(3) -- Should find all 3 .lua files
        end)
    end)
    
    describe("Information Functions", function()
        it("should check if file exists", function()
            expect(fs.file_exists(test_file)).to.be(true)
            expect(fs.file_exists("/tmp/non-existent-file.txt")).to.be(false)
        end)
        
        it("should check if directory exists", function()
            expect(fs.directory_exists(test_dir)).to.be(true)
            expect(fs.directory_exists("/tmp/non-existent-directory")).to.be(false)
        end)
        
        it("should get file size", function()
            local size = fs.get_file_size(test_file)
            expect(size).to.be(#(test_content .. "\nAppended content"))
        end)
        
        it("should check if path is file or directory", function()
            -- Test for file
            expect(fs.is_file(test_file)).to.be(true)
            expect(fs.is_directory(test_file)).to.be(false)
            
            -- Test for directory
            local is_file = fs.is_file(test_dir)
            expect(is_file).to.be(false)
            
            local is_dir = fs.is_directory(test_dir)
            expect(is_dir).to.be(true)
        end)
        
        it("should get modification time", function()
            local time = fs.get_modified_time(test_file)
            expect(time ~= nil).to.be(true)
            expect(type(time)).to.be("number")
        end)
        
        -- Final cleanup after all tests have run
        it("should clean up test directory", function()
            local success = fs.delete_directory(test_dir, true)
            expect(success).to.be(true)
            expect(fs.directory_exists(test_dir)).to.be(false)
        end)
    end)
end)