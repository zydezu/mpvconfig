--[[
    detectdualsubs.lua by zydezu
	(https://github.com/zydezu/mpvconfig/blob/main/scripts/detectdualsubs.lua)
	
    Detects if there are two existing subtitles, one being an original 
    script and the other being a translation 
    (eg: English and Japanese subtitles) and displays them both on screen

    Add secondary-sub-pos to mpv.conf to set the screen position -
    https://mpv.io/manual/master/#options-secondary-sub-pos

    Add the language tags for original subs you want a translated sub 
    to show up for in options.original_sub, and add possible translated 
    subs to options.translated_sub

    Here "[ja]" and "[en]" represents files such as: 
    "01. Beautiful World [ja].lrc" and "01. Beautiful World [en].lrc"
    the script detects if a sub has "[ja]" or "[en]" in it's filename to
    determine whether to show them bot has primary and secondary subtitles

    options.auto_set_non_forced_subs if true, set subtitles to a 
    non-forced sub track as defined by the options --slang, as sometimes 
    videos may force unneeded tracks
--]]

mp.utils = require("mp.utils")

local options = {
    original_sub = {"[ja]"},
    translated_sub = {"[en]"},
    auto_set_non_forced_subs = true
}
(require "mp.options").read_options(options)

local subtitle_filenames = {}
local subtitle_ids = {}

local function get_subtitle_count()
    local track_list = mp.get_property_native("track-list", {})
    local subtitle_count = 0
    for _, track in ipairs(track_list) do
        if track["type"] == "sub" then
            subtitle_count = subtitle_count + 1
            table.insert(subtitle_filenames, track["external-filename"])
            table.insert(subtitle_ids, track["id"])
        end
    end
    return subtitle_count
end

local function check_for_dual_subs()
    local subtitle_count = get_subtitle_count()

    if subtitle_count > 0 then
        mp.commandv("set", "sub", "1")
        if not mp.get_property("current-tracks/sub/external-filename") then
            return
        end

        local _, filename = mp.utils.split_path(mp.get_property("current-tracks/sub/external-filename"))
        local ext = filename:match("^.+(%..+)$")
        if not ext then
            return
        end
        local filename_noext = filename:gsub(ext, "")

        local original = true
        local tag_to_use, primary_track_id, secondary_track_id

        -- check if sub is original
        for i, lang in ipairs(options.original_sub) do
            local pattern = lang:gsub("[%[%]]", "%%%1") -- Escape [ and ]
            if string.find(filename_noext, pattern) then
                tag_to_use = lang
                original = true
                primary_track_id = mp.get_property_number("sid")
                break
            end
        end

        -- check if sub is translated
        for i, lang in ipairs(options.translated_sub) do
            local pattern = lang:gsub("[%[%]]", "%%%1") -- Escape [ and ]
            if string.find(filename_noext, pattern) then
                tag_to_use = lang
                original = false
                secondary_track_id = mp.get_property_number("sid")
                break
            end
        end

        if tag_to_use then
            for i, sub_filename in ipairs(subtitle_filenames) do
                _, sub_filename = mp.utils.split_path(sub_filename)
                local sub_ext = sub_filename:match("^.+(%..+)$")
                local sub_filename_noext = sub_filename:gsub(sub_ext, "")

                if ext == sub_ext then
                    if filename_noext ~= sub_filename_noext then
                        for j, lang in ipairs(original and options.translated_sub or options.original_sub) do
                            local pattern = lang:gsub("[%[%]]", "%%%1") -- Escape [ and ]
                            if string.find(sub_filename_noext, pattern) then
                                if original then
                                    secondary_track_id = subtitle_ids[i]
                                end
                                    primary_track_id = subtitle_ids[i]
                                else
                                break
                            end
                        end
                    end
                else
                    -- not same file ext so skip file
                end
            end

            if primary_track_id and secondary_track_id then
                print("Found two subtitles - showing dual subtitles")

                mp.set_property_number("sid", primary_track_id)
                mp.set_property_number("secondary-sid", secondary_track_id)

                return true
            else
                -- no dual subtitles detected
            end
        else
            return false -- nothing detected
        end
    end

    return false
end

local function osd_msg(message)
    print(message)
    mp.osd_message(message)
end

local function set_non_forced_subs()
    local track_list = mp.get_property_native("track-list")
    local slang_list = mp.get_property_native("slang")

    for _, value in ipairs(slang_list) do
        for i = 1, #track_list do
            if track_list[i].type == "sub" and track_list[i].lang == value and track_list[i].forced == false then
                mp.set_property("sid", track_list[i].id)
                print("Setting non-forced sub "..track_list[i].id)
                return
            end
        end
    end
end

local function auto_check_for_dual_subs()
    local result = check_for_dual_subs()
    if not result and options.auto_set_non_forced_subs then
        set_non_forced_subs()
    end
end

local function key_bind_check_for_dual_subs()
    osd_msg("Checking for dual subs...")
    local result = check_for_dual_subs()
    osd_msg(result and "Applied dual subs" or "Couldn't find dual subs")
end

mp.register_event("file-loaded", auto_check_for_dual_subs)
mp.add_key_binding("ctrl+b", "key_bind_check_for_dual_subs", key_bind_check_for_dual_subs)