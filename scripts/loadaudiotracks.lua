--[[
    loadaudiotracks.lua
    
    * Based on 
    https://github.com/mpv-player/mpv/issues/10554#issuecomment-2360602290 
    by https://github.com/guidocella
    * Modified by zydezu

    Allows multiple audio tracks to be selected and played together
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
    local tracks = mp.get_property_native("track-list")
    local items = {}
    local selected_tracks = {}
    local track_ids = {}
    local selected_count = 0

    for _, track in ipairs(tracks) do
        if track.type == "audio" then
            items[#items + 1] = format_track(track)
            track_ids[#track_ids + 1] = track.id
            if track.selected then
                selected_tracks[track.id] = true
                selected_count = selected_count + 1
            end
        end
    end

    if #track_ids == 0 then
        show_error("No available audio tracks")
        return
    end

    if #track_ids <= 1 then
        show_error("Less than 2 tracks available, skipping audio track selection")
        return
    end

    -- Insert visual separator and special options
    local separator_index = #items + 1
    local play_all_index = #items + 2
    local clear_all_index = #items + 3

    items[separator_index] = ""
    items[play_all_index] = "🔊Play all available tracks together"
    items[clear_all_index] = "🚫Clear all audio tracks"

    mp.input.select({
        prompt = "Toggle an audio track:",
        items = items,
        submit = function (id)
            if id == separator_index then
                return -- Ignore separator
            elseif id == play_all_index then
                local graph = ""
                for _, tid in ipairs(track_ids) do
                    graph = graph .. "[aid" .. tid .. "]"
                end

                local input_count = #track_ids
                graph = graph .. "amix=inputs=" .. input_count .. "[ao]"

                mp.set_property("lavfi-complex", graph)
                mp.set_property("aid", "no")
                return
            elseif id == clear_all_index then
                mp.set_property("lavfi-complex", "")
                mp.set_property("aid", "no")
                return
            end

            local track_id = track_ids[id]
            if not track_id then return end

            if selected_tracks[track_id] then
                if selected_count == 1 then
                    show_error("This is the only track currently selected")
                    return
                end

                selected_tracks[track_id] = nil
                selected_count = selected_count - 1
            else
                selected_tracks[track_id] = true
                selected_count = selected_count + 1
            end

            if selected_count == 1 then
                mp.set_property("lavfi-complex", "")
                for tid in pairs(selected_tracks) do
                    mp.set_property("aid", tid)
                    break
                end
                return
            end

            local graph = ""
            for _, tid in ipairs(track_ids) do
                if selected_tracks[tid] then
                    graph = graph .. "[aid" .. tid .. "]"
                end
            end

            graph = graph .. "amix=inputs=" .. selected_count .. "[ao]"
            mp.set_property("lavfi-complex", graph)
            mp.set_property("aid", "no")
        end,
    })
end

mp.add_key_binding("ctrl+z", "ask_for_audio_track", ask_for_audio_track)