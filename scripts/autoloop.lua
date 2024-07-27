-- Auto looping

local utils = require "mp.utils"

local o = {
    autoloop_duration = 10,
    dontsaveduration = 60,  -- don't save position on videos under this length 
                            -- (set the same as autoloop_duration to disable this function)
    dontsaveonaudio = true, -- don't save position on audio files
    playfromstart = true,   -- doesn't 'resume-playback' looping videos
    copy_keybind = [[
	["ctrl+c", "ctrl+C", "meta+c", "meta+C"]
	]],
    paste_keybind = [[
    ["ctrl+v", "ctrl+V", "meta+v", "meta+V"]
    ]],
    open_keybind = 'o'
}
(require "mp.options").read_options(o)
manuallydisabled = false

function set_loop()
    if not manuallydisabled then
        mp.osd_message("")
        local duration = mp.get_property_native("duration")

        -- Checks whether the loop status was changed for the last file
        was_loop = mp.get_property_native("loop-file")

        -- Cancel operation if there is no file duration
        if not duration then
            return
        end

        -- Loops file if was_loop is false, and file meets requirements
        if not was_loop then
            if duration <= o.autoloop_duration then
                print("Autolooped file")
                mp.set_property_native("loop-file", true)
            end
            if duration <= o.autoloop_duration or duration <= o.dontsaveduration or 
            (mp.get_property_native("current-tracks/video") == nil) or (mp.get_property_native("current-tracks/video")["albumart"] == true) then
                print("Not saving video position")
                mp.set_property_bool("file-local-options/save-position-on-quit", false)
                mp.set_property("file-local-options/watch-later-options", "start") -- so videos don't load paused
                if o.playfromstart and mp.get_property_number("playback-time") > 0 then -- always play video from the start
                    mp.commandv("seek", 0, "absolute-percent", "exact")
                end
            end
        -- Unloops file if was_loop is true, and file does not meet requirements
        elseif was_loop and duration > o.autoloop_duration then
            mp.set_property_native("loop-file", false)
        end
    end
    mp.observe_property('loop-file', 'bool',
        function(name, val) manuallydisabled = true end
    )
end

mp.register_event("file-loaded", set_loop)

-- File/URL pasting

o.copy_keybind = utils.parse_json(o.copy_keybind)
o.paste_keybind = utils.parse_json(o.paste_keybind)

local device = "linux"
if os.getenv("windir") ~= nil then
    device = "windows"
elseif os.execute '[ -d "/Applications" ]' == 0 and os.execute '[ -d "/Library" ]' == 0 or os.execute '[ -d "/Applications" ]' == true and os.execute '[ -d "/Library" ]' == true then
    device = "mac"
end

function fileexists(name)
    local f = io.open(name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

function bindkeys(keys, name, func, opts)
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

function setclipboard(text)
    local pipe
    if device == "linux" then
		pipe = io.popen("xclip -silent -selection clipboard -in", "w")
		pipe:write(text)
		pipe:close()
    elseif device == "windows" then
        local res = utils.subprocess({ args = {
            'powershell', '-NoProfile', '-Command', string.format([[& {
                Trap {
                    Write-Error -ErrorRecord $_
                    Exit 1
                }
                Add-Type -AssemblyName PresentationCore
                [System.Windows.Clipboard]::SetText('%s')
            }]], text)
        } })
    elseif device == "mac" then
        pipe = io.popen("pbcopy","w")
		pipe:write(text)
		pipe:close()
    end
end

function getclipboard()
    local clipboard
    if device == "linux" then
        clipboard = os.capture("xclip -selection clipboard -o")
		return clipboard
    elseif device == "windows" then
        local args = {
            'powershell', '-NoProfile', '-Command', [[& {
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
        return handleres(utils.subprocess({ args = args, cancellable = false }), args)
    elseif device == "mac" then
		clipboard = os.capture("pbpaste")
		return clipboard
    end
    return ""
end

function handleres(res, args)
	if not res.error and res.status == 0 then
		return res.stdout
	else
		print("Error obtaining clipboard!")
	end
end

local function is_url(s)
    return nil ~=
        string.match(s,
            "^[%w]-://[-a-zA-Z0-9@:%._\\+~#=]+%." ..
            "[a-zA-Z0-9()][a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?" ..
            "[-a-zA-Z0-9()@:%_\\+.~#?&/=]*")
end

function addItem(name, file)
    if mp.get_property_number('playlist-count', 0) == 0 then
        mp.commandv('loadfile', file)    
    else
        mp.osd_message("Added " .. name .. " to playlist")
        mp.commandv('loadfile', file, 'append-play')
    end
end

function isTimestamp(str)
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

function convertTimestamp(timestamp)
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
    
    local totalSeconds = hours * 3600 + minutes * 60 + seconds
    return totalSeconds
end

function copy()
    local path = mp.get_property("path")
    setclipboard(path)
    if is_url(path) then
        mp.osd_message("Copied URL to clipboard")
    else
        mp.osd_message("Copied path to clipboard")
    end
end

function paste()
    mp.osd_message("Loading...", 10)
    local clip = getclipboard():gsub("\n", " ")
    if not clip then return end
    clipFile = clip:gsub('"', "")
    if is_url(clip) then
        addItem("URL", clip)
    elseif fileexists(clipFile) then
        addItem("file", clipFile)
    elseif isTimestamp(clip) then
        local time = convertTimestamp(clip)
        if time then
            mp.commandv('seek', time, 'absolute', 'exact')
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
        elseif device == 'windows' then
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
        elseif device == 'windows' then
            local ret = mp.command_native_async({
                name = "subprocess",
                args = { "explorer","/select,",path}
            })
        elseif device == "mac" then
            cmd = file_browser_macos_cmd
        end 
        cmd = cmd:gsub("$path", path)
    end
    if device ~= 'windows' then
        os.execute(cmd)
    end
end

bindkeys(o.copy_keybind, "copy", copy)
bindkeys(o.paste_keybind, "paste", paste)
mp.add_forced_key_binding(o.open_keybind, "open", open)