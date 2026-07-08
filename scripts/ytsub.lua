--[[
    ytsub.lua by zydezu
    (https://github.com/zydezu/mpvconfig/blob/main/scripts/ytsub.lua)
    * A fork of https://github.com/Idlusen/mpv-ytsub

    * The 'want' module loader below is adapted from a Stack Overflow answer

    Downloads and loads YouTube's auto-generated subtitles (captions),
    with an option to automatically load them without needing to press a key
--]]

-- optionally import a module, returning nil instead of erroring if it's missing
local function want(name)
    local out
    if xpcall(function() out = require(name) end, function(e) out = e end) then
        return out      -- success
    else
        return nil, out -- error
    end
end

mp.utils = require("mp.utils")
mp.input = require("mp.input")
local http = want("socket.http")
local https = want("ssl.https")

local options = {
    source_lang = "en",            -- language code (en, fr, es, de, ...) to load as a secondary subtitle alongside the original
    autoload_on_start = true,      -- automatically load auto-subs when a video starts, without needing to press select_binding/autoload_binding
    select_binding = "alt+y",      -- interactively pick which auto-sub language to load
    autoload_binding = "alt+Y",    -- load the original + source_lang auto-subs immediately
    cache_dir = "~/.cache/ytsub/", -- where downloaded subtitles are cached
    filter_sub_single_line = true, -- remove duplicate/overlapping lines from YouTube's auto-generated subtitles
}
require("mp.options").read_options(options)

options.cache_dir = mp.command_native({ "expand-path", options.cache_dir })

local function show_error(message)
    mp.msg.error(message)
    mp.osd_message("ytsub: " .. message, 5)
end

local function notify(message)
    mp.msg.info(message)
end

-- create the cache directory for subtitles if it doesn't exist
local function create_cache_dir()
    local res = mp.utils.file_info(options.cache_dir)
    if res and res.is_dir then return end

    local args
    if package.config:sub(1, 1) == "\\" then
        args = { "cmd", "/c", "mkdir", (options.cache_dir:gsub("/", "\\")) }
    else
        args = { "mkdir", "-p", options.cache_dir }
    end

    local result = mp.command_native({ name = "subprocess", args = args, playback_only = false })
    if result.status ~= 0 then
        mp.msg.error("Failed to create cache directory: " .. options.cache_dir)
    end
end
create_cache_dir()

local function filter_sub(path)
    local lines = {}
    for line in io.lines(path) do
        table.insert(lines, line)
    end

    local out = io.open(path, "w")
    if out ~= nil then
        for i, line in ipairs(lines) do
            if i < 5 or i % 8 == 5 or i % 8 == 7 or i % 8 == 0 then
                out:write(line, "\n")
            end
        end
        out:close()
    end
end

local function load_autosub(lang, sub_info, ytid, is_primary)
    local lang_name, url

    if sub_info ~= nil then
        for _, v in pairs(sub_info) do
            lang_name = v["name"]
            if v["ext"] == "vtt" then
                url = v["url"]
            end
        end
    end
    if lang_name == nil or url == nil then
        show_error("could not get lang name or url from sub info")
        return
    end

    notify("loading " .. lang_name)

    local subfile_base = mp.utils.join_path(options.cache_dir, ytid) -- matches yt-dlp's naming
    local subfile = subfile_base .. "." .. lang .. ".vtt"

    local sub_is_available = false
    local f = io.open(subfile, "r")
    if f ~= nil then
        -- sub file already cached
        io.close(f)
        sub_is_available = true
    else
        if http ~= nil and https ~= nil then
            -- downloading directly via url
            local body, status = http.request(url)
            if body ~= nil and status == 200 then
                f = assert(io.open(subfile, "wb"))
                f:write(body)
                f:close()
                sub_is_available = true
            end
        end

        if not sub_is_available then
            -- lua http modules unavailable or download failed, fall back to yt-dlp
            local ytdl_path = mp.get_property_native("user-data/mpv/ytdl/path")
            if ytdl_path ~= nil then
                mp.command_native({
                    name = "subprocess",
                    args = { ytdl_path, "--skip-download", "--sub-lang", lang, "--write-auto-sub", "-o", subfile_base, "--", ytid },
                })
                f = io.open(subfile, "r")
                if f ~= nil then
                    io.close(f)
                    sub_is_available = true
                end
            end
        end

        if sub_is_available and options.filter_sub_single_line then
            filter_sub(subfile)
        end
    end

    if not sub_is_available then
        show_error("failed to download " .. lang_name)
        return
    end

    if is_primary then
        mp.command("sub-add " .. subfile .. " select 'auto-generated' '" .. lang .. "'")
    else
        -- compute the number of subtitle tracks in order to select the new track by id
        local n_tracks = mp.get_property_native("track-list/count")
        local n_subs = 0
        for i = 0, n_tracks - 1 do
            if mp.get_property_native("track-list/" .. i .. "/type") == "sub" then
                n_subs = n_subs + 1
            end
        end
        mp.command("sub-add " .. subfile .. " auto 'auto-generated' '" .. lang .. "'")
        mp.set_property("secondary-sid", n_subs + 1)
    end
    notify(lang_name .. " loaded")
end

local function ytsub(is_auto, is_silent)
    local ytdl_output = mp.get_property_native("user-data/mpv/ytdl/json-subprocess-result")
    if ytdl_output == nil then
        if not is_silent then show_error("no ytdl info available") end
        return
    end

    local j = mp.utils.parse_json(ytdl_output["stdout"])
    local subs = j["automatic_captions"]
    if subs == nil or next(subs) == nil then
        if not is_silent then show_error("no auto-subs found") end
        return
    end

    if is_auto then
        -- load the original language as the primary subtitle and
        -- source_lang as the secondary subtitle
        local source_lang = options.source_lang

        local orig_lang
        for k, _ in pairs(subs) do
            if string.find(k, "(orig)") ~= nil then
                orig_lang = k
                break
            end
        end

        load_autosub(orig_lang, subs[orig_lang], j["id"], true)
        if source_lang ~= nil then
            if orig_lang == source_lang .. "-orig" then
                notify("source language and original language are the same (" .. source_lang .. ")")
            else
                load_autosub(source_lang, subs[source_lang], j["id"], false)
            end
        end
    else
        -- let the user select the language to load interactively
        local langs = {}
        for k, _ in pairs(subs) do
            table.insert(langs, k)
        end

        mp.input.select({
            prompt = "Select a language",
            items = langs,
            submit = function(lang_id) load_autosub(langs[lang_id], subs[langs[lang_id]], j["id"], true) end,
        })
    end
end

if options.autoload_on_start then
    mp.register_event("file-loaded", function() ytsub(true, true) end)
end

mp.add_key_binding(options.select_binding, "ytsub-select", function() ytsub(false) end)
mp.add_key_binding(options.autoload_binding, "ytsub-autoload", function() ytsub(true) end)
