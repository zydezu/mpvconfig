--[[
    autosubfontchange.lua by zydezu
    (https://github.com/zydezu/mpvconfig/blob/main/scripts/autosubfontchange.lua)

    This script changes the subtitle font depending on the 
    language detected in the subtitles.

    Add this to mpv.conf for faster subtitle changes when switching between file types
    [video]
    sub-font="Segoe UI Semibold"
    profile-cond=video_codec and (container_fps ~= nil and container_fps > 1)

    [audio]
    sub-font="A-OTF Shin Go Pro M"
    # script-opts-append=modernx-persistent_progress=yes
    profile-cond=audio_codec and (container_fps == nil or container_fps == 1)
]]

mp.utils = require("mp.utils")

local options = {
    video_only = true,  -- only change subtitle font for video files, not audio files
    english_font = "Segoe UI Semibold",
    japanese_font = "A-OTF Shin Go Pro M",
}
(require "mp.options").read_options(options)

if not options.english_font then options.english_font = mp.get_property_native('osd-font') end

local checked = false
local current_lang = nil

local function contains_japanese(text)
    -- Match any character in Hiragana, Katakana, or common Kanji Unicode ranges
    return text:find("[\227-\233]") ~= nil
end

local function is_video()
    local tracks = mp.get_property_native("track-list")
    if not tracks then
        return false
    end

    for _, track in ipairs(tracks) do
        if track.type == "video" then
            local codec = track.codec or ""
            local image_codecs = {
                mjpeg = true,
                png = true,
                jpeg = true,
                bmp = true,
                tiff = true,
                gif = true,
                webp = true,
                ppm = true,
                pgm = true,
                pam = true,
            }
            if not image_codecs[codec] then
                return true
            end
        end
    end

    return false
end

local function check_subtitles(_, subtext)
    if checked or not subtext then return end

    if options.video_only and not is_video() then
        print("Not a video, stopping detection")
        checked = true
        return
    end

    if #subtext < 1 then return end
    if contains_japanese(subtext) then
        if current_lang ~= "Japanese" then
            current_lang = "Japanese"
            mp.set_property("sub-font", options.japanese_font)
            print("Switched to " .. options.japanese_font .. " (Japanese)")
        end
    else
        if current_lang ~= "English" then
            current_lang = "English"
            mp.set_property("sub-font", options.english_font)
            print("Switched to " .. options.english_font .. " (English)")
        end
    end
end

mp.register_event("file-loaded", function()
    checked = false
end)

mp.observe_property("sub-text", "string", check_subtitles)