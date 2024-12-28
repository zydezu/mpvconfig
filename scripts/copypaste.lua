--[[
    copypaste.lua by zydezu
    (https://github.com/zydezu/mpvconfig/blob/main/scripts/copypaste.lua)

    Copy and paste file paths, URLs and timestamps
--]]

local utils = require "mp.utils"

local o = {
    copy_keybind = [[
	["ctrl+c", "ctrl+C", "meta+c", "meta+C"]
	]],
    paste_keybind = [[
    ["ctrl+v", "ctrl+V", "meta+v", "meta+V"]
    ]],
    open_keybind = "o"
}
(require "mp.options").read_options(o)

-- File/URL pasting

o.copy_keybind = utils.parse_json(o.copy_keybind)
o.paste_keybind = utils.parse_json(o.paste_keybind)

local device = "linux"
if os.getenv("windir") ~= nil then
    device = "windows"
elseif os.execute '[ -d "/Applications" ]' == 0 and os.execute '[ -d "/Library" ]' == 0 or os.execute '[ -d "/Applications" ]' == true and os.execute '[ -d "/Library" ]' == true then
    device = "mac"
end

function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

function bind_keys(keys, name, func, opts)
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

function set_clipboard(text)
    local pipe
    if device == "linux" then
		pipe = io.popen("xclip -silent -selection clipboard -in", "w")
		pipe:write(text)
		pipe:close()
    elseif device == "windows" then
        local res = utils.subprocess({ args = {
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

function get_clipboard()
    local clipboard
    if device == "linux" then
        clipboard = os.capture("xclip -selection clipboard -o")
		return clipboard
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
        return handle_res(utils.subprocess({ args = args, cancellable = false }), args)
    elseif device == "mac" then
		clipboard = os.capture("pbpaste")
		return clipboard
    end
    return ""
end

function handle_res(res, args)
	if not res.error and res.status == 0 then
		return res.stdout
	else
		print("Error obtaining clipboard!")
	end
end

local function is_url(s)
    local url_pattern = "^[%w]+://[%w%.%-_]+%.[%a]+[-%w%.%-%_/?&=]*"
    return string.match(s, url_pattern) ~= nil
end

function add_item(name, file)
    if mp.get_property_number("playlist-count", 0) == 0 then
        mp.commandv("loadfile", file)    
    else
        mp.osd_message("Added " .. name .. " to playlist")
        mp.commandv("loadfile", file, "append-play")
    end
end

function is_timestamp(str)
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

function convert_timestamp(timestamp)
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

function copy()
    local path = mp.get_property("path")
    set_clipboard(path)
    if is_url(path) then
        mp.osd_message("Copied URL to clipboard")
    else
        mp.osd_message("Copied path to clipboard")
    end
end

function paste()
    mp.osd_message("Loading...", 10)
    local clip = get_clipboard():gsub("\n", " ")
    if not clip then return end
    clip_file = clip:gsub('"', "")
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

function open()
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

bind_keys(o.copy_keybind, "copy", copy)
bind_keys(o.paste_keybind, "paste", paste)
mp.add_forced_key_binding(o.open_keybind, "open", open)