local options = {
    saveAsTimeStamp = true,
    fileExtension = "jpg",
    includeYouTubeID = true
}
(require 'mp.options').read_options(options)

local currentTime = "0000"
local filename = "default"
local title = "default"
local count = 0

function updateTime()
    currentTime = os.date("%Y-%m-%d_%H-%M-%S")
end

function init()
    local function is_url(s)
        return nil ~=
            string.match(s,
                "^[%w]-://[-a-zA-Z0-9@:%._\\+~#=]+%." ..
                "[a-zA-Z0-9()][a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?" ..
                "[-a-zA-Z0-9()@:%_\\+.~#?&/=]*")
    end

    local filename = mp.get_property("filename/no-ext")
    local media = mp.get_property("media-title")
    local path = mp.get_property("path")

    if is_url(path) and path or nil then
        youtubeID = ""
        local _, _, videoID = string.find(mp.get_property("filename"), "([%w_-]+)%?si=")
        local videoIDMatch = mp.get_property("filename"):match('[?&]v=([^&]+)')
        if options.includeYouTubeID then
            if (videoIDMatch) then
                youtubeID = " [" .. videoIDMatch .. "]"
            elseif (videoID) then
                youtubeID = " [" .. videoID .. "]"
            end
        end
        filename = string.gsub(media:sub(1, 100), "^%s*(.-)%s*$", "%1") .. youtubeID
    end
    local pattern = '[\\/:*?"<>|]'
    title = filename:gsub(pattern, '')

    setFileDir()
end

function setFileDir()
    updateTime()

    count = 0
    mp.set_property("screenshot-directory", "~~desktop/mpv/screenshots/"..title.."/")
    if options.saveAsTimeStamp then
        mp.set_property("screenshot-template", "%tX")
    end
    mp.set_property("screenshot-format", options.fileExtension)
end

function screenshotdone()
    local tempSubPosition = mp.get_property('sub-pos')
    mp.commandv('set', 'sub-pos', 100)
    mp.commandv("screenshot");
    mp.commandv('set', 'sub-pos', tempSubPosition)
    mp.osd_message("Screenshot taken: " .. mp.command_native({"expand-path", mp.get_property("screenshot-directory")}) .. mp.get_property("screenshot-template"))
    count = count + 1
    if options.saveAsTimeStamp then
        mp.set_property("screenshot-template", "%tY-%tm-%td_%tH-%tM-%tS" .. "(" .. count .. ")")
    end
end

mp.register_event("start-file", init)
mp.register_event("file-loaded", init)
mp.add_periodic_timer(1, setFileDir)
mp.add_key_binding("s", "screenshotdone", screenshotdone);