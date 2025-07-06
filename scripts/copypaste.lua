--[[
    copypaste.lua by zydezu
    (https://github.com/zydezu/mpvconfig/blob/main/scripts/copypaste.lua)

    Copy and paste file paths, URLs and timestamps
--]]

mp.utils = require("mp.utils")

local display_protocol = os.getenv("XDG_SESSION_TYPE")

local options = {
    copy_keybind = [[
	["ctrl+c", "ctrl+C", "meta+c", "meta+C"]
	]],
    paste_keybind = [[
    ["ctrl+v", "ctrl+V", "meta+v", "meta+V"]
    ]],
    open_keybind = "o",
    linux_copy_command = { "xclip", "-silent", "-selection", "clipboard", "-in" },
    linux_paste_command = { "xclip", "-selection", "clipboard", "-o" },
    copy_youtube_timestamp = true,
}

if display_protocol == "wayland" then
	options.linux_copy_command = { "wl-copy" }
	options.linux_paste_command = { 'wl-paste' }
end

(require "mp.options").read_options(options)

-- File/URL pasting

options.copy_keybind = mp.utils.parse_json(options.copy_keybind)
options.paste_keybind = mp.utils.parse_json(options.paste_keybind)

local device = "linux"
if os.getenv("windir") ~= nil then
    device = "windows"
elseif os.execute '[ -d "/Applications" ]' == 0 and os.execute '[ -d "/Library" ]' == 0 or os.execute '[ -d "/Applications" ]' == true and os.execute '[ -d "/Library" ]' == true then
    device = "mac"
end

local function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

local function bind_keys(keys, name, func, opts)
	if not keys then
		mp.add_forced_key_binding(keys, name, func, opts)
		return
	end

	for i = 1, #keys do
		if i == 1 then
			mp.add_forced_key_binding(keys[i], name, func, opts)
		else
			mp.add_forced_key_binding(keys[i], name .. i, func, opts)
		end
	end
end

local function handle_res(res, args)
	if not res.error and res.status == 0 then
		return res.stdout
	else
		print("Error obtaining clipboard!")
	end
end

local function set_clipboard(text)
    local pipe
    if device == "linux" then
		local command = table.concat(options.linux_copy_command, " ")
		pipe = io.popen(command, "w")
        pipe:write(text)
        pipe:close()
    elseif device == "windows" then
        mp.utils.subprocess({ args = {
            "powershell", "-NoProfile", "-Command", string.format([[& {
                Trap {
                    Write-Error -ErrorRecord $_
                    Exit 1
                }
                Add-Type -AssemblyName PresentationCore
                [System.Windows.Clipboard]::SetText("%s")
            }]], text)
        } })
    elseif device == "mac" then
        pipe = io.popen("pbcopy","w")
        pipe:write(text)
        pipe:close()
    end
end

local function get_clipboard()
    if device == "linux" then
        local args = options.linux_paste_command
		return handle_res(mp.utils.subprocess({ args = args, cancellable = false }), args)
    elseif device == "windows" then
        local args = {
            "powershell", "-NoProfile", "-Command", [[& {
                Trap {
                    Write-Error -ErrorRecord $_
                    Exit 1
                }
                $clip = Get-Clipboard -Raw -Format Text -TextFormatType UnicodeText
                if (-not $clip) {
                    $clip = Get-Clipboard -Raw -Format FileDropList
                }
                $u8clip = [System.Text.Encoding]::UTF8.GetBytes($clip)
                [Console]::OpenStandardOutput().Write($u8clip, 0, $u8clip.Length)
            }]]
        }
        return handle_res(mp.utils.subprocess({ args = args, cancellable = false }), args)
    elseif device == "mac" then
		local args = { "pbpaste" }
		return handle_res(mp.utils.subprocess({ args = args, cancellable = false }), args)
    end
    return ""
end

local function is_url(s)
    local url_pattern = "^[%w]+://[%w%.%-_]+%.[%a]+[-%w%.%-%_/?&=]*"
    return string.match(s, url_pattern) ~= nil
end

local function add_item(name, file)
    if mp.get_property_number("playlist-count", 0) == 0 then
        mp.commandv("loadfile", file)
    else
        mp.osd_message("Added " .. name .. " to playlist")
        mp.commandv("loadfile", file, "append-play")
    end
end

local function is_timestamp(str)
    local pattern = "^%d+:%d+$" -- Matches "1:05", "0:54", "12:05"

    if string.match(str, pattern) then
        return true
    else
        pattern = "^%d+:%d+:%d+$" -- Matches "1:12:02", "119:14"
        if string.match(str, pattern) then
            return true
        else
            return false
        end
    end
end

local function convert_timestamp(timestamp)
    local hours, minutes, seconds = 0, 0, 0

    local parts = {}
    for part in string.gmatch(timestamp, "%d+") do
        table.insert(parts, tonumber(part))
    end

    if #parts == 2 then
        minutes = parts[1]
        seconds = parts[2]
    elseif #parts == 3 then
        hours = parts[1]
        minutes = parts[2]
        seconds = parts[3]
    else
        return nil -- Invalid format
    end

    local total_seconds = hours * 3600 + minutes * 60 + seconds
    return total_seconds
end

local function copy()
    local path = mp.get_property("path")

    local function remove_timestamp_from_url(inputpath)
        if type(inputpath) == "string" then
            local new_path = inputpath:gsub("([&?])t=%d+", function(sep)
                return sep == "?" and "?" or ""
            end)
            new_path = new_path:gsub("[?&]$", "")
            if new_path ~= inputpath then
                inputpath = new_path
            end
        end
        return inputpath
    end

    local function add_timestamp_to_url(url, seconds)
        if type(url) ~= "string" or type(seconds) ~= "number" then
            return url
        end
        url = remove_timestamp_from_url(url)
        local sep = url:find("?") and "&" or "?"
        return url .. sep .. "t=" .. tostring(seconds)
    end

    if options.copy_youtube_timestamp and is_url(path) then
        path = remove_timestamp_from_url(path)
        local time_pos = mp.get_property_number("time-pos", 0)
        if time_pos > 0 then
            path = add_timestamp_to_url(path, math.floor(time_pos))
        end
    end

    set_clipboard(path)
    if is_url(path) then
        mp.osd_message("Copied URL to clipboard")
    else
        mp.osd_message("Copied path to clipboard")
    end
end

local function paste()
    mp.osd_message("Loading...", 10)
    local clip = get_clipboard():gsub("\n", " ")
    if not clip then return end
    local clip_file = clip:gsub('"', "")
    if is_url(clip) then
        add_item("URL", clip)
    elseif file_exists(clip_file) then
        add_item("file", clip_file)
    elseif is_timestamp(clip) then
        local time = convert_timestamp(clip)
        if time then
            mp.commandv("seek", time, "absolute", "exact")
        end
    end
end

local function open()
    -- for ubuntu
    local url_browser_linux_cmd = "xdg-open \"$url\""
    local file_browser_linux_cmd = "dbus-send --print-reply --dest=org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems array:string:\"file:$path\" string:\"\""
    local url_browser_macos_cmd = "open \"$url\""
    local file_browser_macos_cmd = "open -a Finder -R \"$path\""

    local path = mp.get_property("path")
    local cmd = ""
    if is_url(path) then
        if device == "linux" then
            cmd = url_browser_linux_cmd
        elseif device == "windows" then
            local ret = mp.command_native_async({
                name = "subprocess",
                args = {"powershell","start",path}
            })
        elseif device == "mac" then
            cmd = url_browser_macos_cmd
        end
        cmd = cmd:gsub("$url", path)
    else
        if device == "linux" then
            cmd = file_browser_linux_cmd
        elseif device == "windows" then
            local ret = mp.command_native_async({
                name = "subprocess",
                args = { "explorer", "/select," ,path}
            })
        elseif device == "mac" then
            cmd = file_browser_macos_cmd
        end
        cmd = cmd:gsub("$path", path)
    end
    if device ~= "windows" then
        os.execute(cmd)
    end
end

bind_keys(options.copy_keybind, "copy", copy)
bind_keys(options.paste_keybind, "paste", paste)
mp.add_forced_key_binding(options.open_keybind, "open", open)
