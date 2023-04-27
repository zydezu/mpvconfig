local utils = require 'mp.utils'

local options = {
    saveAsTimeStamp = false;
    fileExtension = "png"
}
(require 'mp.options').read_options(options)

local currentTime = "0000"
local filename = "default"
local title = "default"

function getOption()
    -- Use recommended way to get options
    local options = {autoloop_duration = 5}
    read_options(options)
    autoloop_duration = options.autoloop_duration
end

function updateTime()
    currentTime = os.date("%Y-%m-%d_%H-%M-%S")
end

function init()
    filename = mp.get_property("filename")
    title = string.gsub(filename, "%..+$", "")
    setFileDir()
end

function setFileDir()
    updateTime()

    mp.set_property("screenshot-directory", "~~desktop/mpv/"..title.."/")
    if options.saveAsTimeStamp then
        mp.set_property("screenshot-template", currentTime)
    end
    mp.set_property("screenshot-format", options.fileExtension)
end

mp.register_event("start-file", init)
mp.add_periodic_timer(1, setFileDir)