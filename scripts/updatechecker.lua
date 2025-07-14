--[[
    updatechecker.lua by zydezu
	(https://github.com/zydezu/mpvconfig/blob/main/scripts/updatechecker.lua)

    A basic updatechecker for the mpvconfig repository
--]]

mp.utils = require("mp.utils")

local options = {
    update_checker = true,
}
(require "mp.options").read_options(options)

local local_readme_path = mp.command_native({"expand-path", "~~/README.md"})
local remote_readme_url = "https://raw.githubusercontent.com/zydezu/mpvconfig/main/README.md"
local local_date

local function extract_latest_heading_date(text)
    local latest_date = nil
    for date in text:gmatch("### (%d%d%d%d%-%d%d%-%d%d)") do
        if not latest_date or date > latest_date then
            latest_date = date
        end
    end
    return latest_date
end

local function get_fetch_command(url)
    local is_windows = package.config:sub(1, 1) == "\\"
    if is_windows then
        return {"powershell", "-NoProfile", "-Command",
            "(Invoke-WebRequest -Uri '" .. url .. "' -UseBasicParsing).Content"}
    else
        return {"curl", "-fsSL", url}
    end
end

local function exec_async(args, callback)
    local ret = mp.command_native_async({
        name = "subprocess",
        args = args,
        capture_stdout = true,
        capture_stderr = true
    }, callback)

    return ret and ret.status or nil
end

local function process_result(success, result, error)
    if success then
        local remote_date = extract_latest_heading_date(result.stdout)
        if not remote_date then
            return
        end

        if remote_date > local_date then
            print("Update available")
            mp.osd_message("mpvconfig update available (" .. remote_date .. ")", 2)
        else
            print("No update available")
        end
    else
        mp.msg.error("Failed to fetch remote README.md")
        mp.msg.error(error)
    end
end

local function check_for_update()
    if not options.update_checker then
        return
    end

    local local_file = io.open(local_readme_path, "r")
    if not local_file then
        mp.msg.warn("Local README.md not found.")
        return
    end
    local local_content = local_file:read("*a")
    local_file:close()

    local_date = extract_latest_heading_date(local_content)
    if not local_date then
        mp.msg.warn("No date found in local README.md.")
        return
    end

    local command = get_fetch_command(remote_readme_url)
    exec_async(command, process_result)
end

mp.register_event("file-loaded", check_for_update)