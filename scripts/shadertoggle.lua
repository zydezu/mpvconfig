local utils = require 'mp.utils'

local o = {
	shaderdirectory = "~~/shaders/"
}
(require 'mp.options').read_options(o)

function init() -- store the name of all shaders in a table
    path = '"' .. mp.command_native({"expand-path", o.shaderdirectory}) .. '"'
    i = 0
    for dir in io.popen('dir '.. path ..' /b'):lines() do
        i = i + 1
        shaders[i] = dir
    end
    maxindex = i
end

function toggleshader()
    if maxindex == 0 then
        mp.osd_message("There are no shaders")
    else
        shaderindex = shaderindex + 1
        if shaderindex > maxindex then
            shaderindex = 0
            mp.commandv('change-list', 'glsl-shaders', 'set', '')
            mp.osd_message("Turned off shader")
        else
            mp.commandv('change-list', 'glsl-shaders', 'set', mp.command_native({"expand-path", o.shaderdirectory .. shaders[shaderindex]}))
            mp.osd_message("Changed shader to: " .. shaders[shaderindex])
        end
    end
end

mp.add_key_binding("CTRL+s", "toggleshader", toggleshader);
shaderindex = 0
maxindex = 0
shaders = {}
init()