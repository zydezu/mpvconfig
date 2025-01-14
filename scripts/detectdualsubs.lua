local utils = require "mp.utils"

local options = {
    original_sub = {"[ja]"},
    translated_sub = {"[en]"},
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

            print(track["external-filename"] .. " | " .. track["id"])
        end
    end
    return subtitle_count
end

local function check_for_dual_subs()
    local subtitle_count = get_subtitle_count()

    if subtitle_count > 0 then
        local sub_path = mp.get_property("current-tracks/sub/external-filename")
        local subtitles_path, filename = utils.split_path(sub_path)
        local ext = filename:match("^.+(%..+)$")
        local filename_noext = filename:gsub(ext, "")

        local tag_to_use
        local original = true

        local primary_track_id
        local secondary_track_id

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
                local _, sub_filename = utils.split_path(sub_filename)
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
                    -- Not same file ext so skip file
                end
            end

            if primary_track_id and secondary_track_id then
                print("Found two matching subtitles - showing both")

                mp.set_property_number("sid", primary_track_id)
                mp.set_property_number("secondary-sid", secondary_track_id)
            else
                print("No other subtitle detected")
            end

        else
            return -- nothing detected
        end
    end
end

mp.register_event("file-loaded", check_for_dual_subs)
mp.add_key_binding("CTRL+b", "check_for_dual_subs", check_for_dual_subs)