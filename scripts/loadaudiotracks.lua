--[[
    loadaudiotracks.lua
    
    * script based on 
    https://github.com/mpv-player/mpv/issues/10554#issuecomment-2360602290 
    by https://github.com/guidocella
    * Modified by zydezu
--]]

mp.input = require("mp.input")

local function show_error(message)
    mp.msg.error(message)
    if mp.get_property_native("vo-configured") then
        mp.osd_message(message)
    end
end

local function format_track(track)
    local bitrate = track["demux-bitrate"] or track["hls-bitrate"]

    return (track.selected and "●" or "○") ..
        (track.title and " " .. track.title or "") ..
        " (" .. (
            (track.lang and track.lang .. " " or "") ..
            (track.codec and track.codec .. " " or "") ..
            (track["demux-w"] and track["demux-w"] .. "x" .. track["demux-h"]
             .. " " or "") ..
            (track["demux-fps"] and not track.image
             and string.format("%.4f", track["demux-fps"]):gsub("%.?0*$", "") ..
             " fps " or "") ..
            (track["demux-channel-count"] and track["demux-channel-count"] ..
             "ch " or "") ..
            (track["codec-profile"] and track.type == "audio"
             and track["codec-profile"] .. " " or "") ..
            (track["demux-samplerate"] and track["demux-samplerate"] / 1000 ..
             " kHz " or "") ..
            (bitrate and string.format("%.0f", bitrate / 1000) ..
             " kbps " or "")
        ):sub(1, -2) .. ")"
end

local function ask_for_audio_track()
    local items = {}
    local selected_tracks = {}
    local selected_count = 0

    for _, track in ipairs(mp.get_property_native("track-list")) do
        if track.type == "audio" then
            items[#items + 1] = format_track(track)
            if track.selected then
                selected_tracks[track.id] = true
                selected_count = selected_count + 1
            end
        end
    end

    if #items == 0 then
        show_error("No available audio tracks.")
        return
    end

    mp.input.select({
        prompt = "Toggle another audio track:",
        items = items,
        submit = function (id)
            if selected_count == 0 then
                mp.set_property("aid", id)
                return
            end

            if selected_tracks[id] then
                -- if selected_count == 1 then
                --     show_error("This track is already selected.")
                --     return
                -- end

                selected_tracks[id] = nil
                selected_count = selected_count - 1

                if selected_count == 1 then
                    mp.set_property("lavfi-complex", "")
                    -- This doesn't always work.
                    mp.set_property("aid", next(selected_tracks))
                    return
                end
            else
                selected_tracks[id] = true
                selected_count = selected_count + 1
            end

            local graph = ''
            for selected_id in pairs(selected_tracks) do
                graph = graph .. "[aid" .. selected_id .. "]"
            end

            mp.set_property("lavfi-complex",
                            graph .. "amix=inputs=" .. selected_count .. "[ao]")
        end,
    })
end

mp.add_key_binding("ctrl+z", "ask_for_audio_track", ask_for_audio_track)