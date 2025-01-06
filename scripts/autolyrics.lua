--[[
    autolyrics.lua by zydezu
	(https://github.com/zydezu/mpvconfig/blob/main/scripts/autolyrics.lua)
	
	* Based on https://github.com/guidocella/mpv-lrc

    Tries to download lyrics and display them for said file
--]]

local utils = require "mp.utils"

local options = {
    musixmatch_token = "220215b052d6aeaa3e9a410986f6c3ae7ea9f5238731cb918d05ea",
    downloadforall = false,         -- experimental, try to get subtitles for all videos
    loadforyoutube = true,          -- try to load lyrics on youtube videos
    lyricsstore = "~~desktop/mpv/lrcdownloads/",
    storelyricsseperate = true,     -- store lyrics in ~~desktop/mpv/lrcdownloads/
    cacheloading = true,            -- try to load lyrics that were already downloaded
    runautomatically = false        -- run this script without pressing Alt+m
}
(require "mp.options").read_options(options)

local manualrun = false
local gotlyrics = false
local withoutTimestamps = false
local downloadingName = ""

local function show_error(message)
    mp.msg.error(message)
    if mp.get_property_native("vo-configured") and manualrun then
        mp.osd_message(message, 5)
    end
end

local function curl(args)
    local r = mp.command_native({name = "subprocess", capture_stdout = true, args = args})

    if r.killed_by_us then
        -- don't print an error when curl fails because the playlist index was changed
        return false
    end

    if r.status < 0 then
        show_error("subprocess error: " .. r.error_string)
        return false
    end

    if r.status > 0 then
        show_error("curl failed with code " .. r.status)
        return false
    end

    local response, error = utils.parse_json(r.stdout)

    if error then
        show_error("Unable to parse the JSON response")
        return false
    end

    return response
end

local function get_metadata()
    local metadata = mp.get_property_native("metadata")
    local title, artist, album
    if metadata then
        if next(metadata) == nil then
            mp.msg.info("couldn't load metadata!")
        else
            title = metadata.title or metadata.TITLE or metadata.Title
            if options.downloadforall then
                title = mp.get_property("media-title")
                title = title:gsub("%b[]", "") .. " "
            end
            artist = mp.get_property("filtered-metadata/by-key/Album_Artist") or mp.get_property("filtered-metadata/by-key/Artist") or mp.get_property("filtered-metadata/by-key/Uploader")
            if options.downloadforall and not artist then
                artist = " "
            end
            album = metadata.album or metadata.ALBUM or metadata.Album
        end
    else
        mp.msg.info("couldn't load metadata!")
    end

    if not title then
        show_error("This song has no title metadata")
        return false
    end

    if not artist then
        show_error("This song has no artist metadata")
        return false
    end

    print(title)
    print(artist)
    print(album)
    
    return title, artist, album
end

local function save_lyrics(lyrics)
    if lyrics == "" then
        show_error("Lyrics not found")
        return
    end

    if #lyrics < 250 then
        show_error("File likely not lyrics")
        return
    end

    local current_sub_path = mp.get_property("current-tracks/sub/external-filename")

    if current_sub_path and lyrics:find("^%[") == nil then
        show_error("Only lyrics without timestamps are available, so the existing LRC file won't be overwritten")
        return
    end

    -- NetEase's LRCs can have 3-digit milliseconds, which messes up the sub's timings in mpv.
    lyrics = lyrics:gsub("(%.%d%d)%d]", "%1]")
    lyrics = lyrics:gsub("’", "'"):gsub("' ", "'") -- remove strange characters

    local success_message = "Lyrics downloaded"
    if options.downloadforall then
        success_message = "Found and applied lyrics"
    end
    if current_sub_path then
        -- os.rename only works across the same filesystem
        local _, current_sub_filename = utils.split_path(current_sub_path)
        local current_sub = io.open(current_sub_path)
        local backup = io.open("/tmp/" .. current_sub_filename, "w")
        if current_sub and backup then
            backup:write(current_sub:read("*a"))
            success_message = success_message .. ". The old one has been backed up to /tmp."
        end
        if current_sub then
            current_sub:close()
        end
        if backup then
            backup:close()
        end
    end

    local function is_url(s)
        local url_pattern = "^[%w]+://[%w%.%-_]+%.[%a]+[-%w%.%-%_/?&=]*"
        return string.match(s, url_pattern) ~= nil
    end

    function is_windows()
        local a=os.getenv("windir")if a~=nil then return true else return false end
    end

    local isWindows = is_windows()

    local function createDirectory(directoryPath)
        local args = {"mkdir", directoryPath}
        if isWindows then args = {"powershell", "-NoProfile", "-Command", "mkdir", directoryPath} end
        local res = utils.subprocess({ args = args, cancellable = false })
        if res.status ~= 0 then
            mp.msg.error("Failed to create directory: " .. directoryPath)
        else
            mp.msg.info("Directory created successfully: " .. directoryPath)
        end
    end    

    downloadingName = downloadingName:gsub("\\", " "):gsub("/", " ")

    local path = mp.get_property("path")
    local media = downloadingName .. " [" .. mp.get_property("filename/no-ext") .. "]"
    local pattern = '[\\/:*?"<>|]'

    if (is_url(path) and path or nil) and options.loadforyoutube then
        local youtubeID = ""
        if not downloadingName then 
            youtubeID = " [" .. mp.get_property("filename"):match("[?&]v=([^&]+)") .. "]" 
        end
        local filename = string.gsub(media:sub(1, 100):gsub(pattern, ""), "^%s*(.-)%s*$", "%1") .. youtubeID
        path =  mp.command_native({"expand-path", options.lyricsstore .. filename})
    else
        if options.storelyricsseperate then
            path = mp.command_native({"expand-path", options.lyricsstore .. media})
        end
    end

    print(downloadingName)

    local lrc_path = (path:gsub("?", "") .. ".lrc")
    local dir_path = lrc_path:match("(.+[\\/])")
    if isWindows then
        lrc_path = lrc_path:gsub("/", "\\")
        dir_path = dir_path:gsub("/", "\\")
    end
    -- print(lrc_path)
    -- print(dir_path)
    
    if (utils.readdir(dir_path) == nil and options.storelyricsseperate) then
        if not isWindows then
            subdir_path = utils.split_path(dir_path)
            createDirectory(subdir_path) -- required for linux as it cannot create mpv/lrcdownloads/
        end
        createDirectory(dir_path)
    end


    local lrc = io.open(lrc_path, "w")
    if lrc == nil then
        show_error("Failed writing to " .. lrc_path)
        return
    end
    lrc:write(lyrics)
    lrc:close()

    if lyrics:find("^%[") then
        mp.command(current_sub_path and "sub-reload" or "rescan-external-files") 
        if manualrun then
            mp.osd_message(success_message)
        end
        gotlyrics = true
        withoutTimestamps = false
    else
        if manualrun then
            mp.osd_message("Lyrics without timestamps downloaded")
        end
        withoutTimestamps = true
    end
end

mp.add_key_binding("Alt+m", "musixmatch-download", function() 
    manualrun = true
    autodownload()
end)

function musixmatchdownload()
    local title, artist = get_metadata()

    if not title then
        return
    end

    mp.msg.info("Fetching lyrics (musixmatch)")
    if manualrun then
        mp.osd_message("Fetching lyrics (musixmatch)")
    end

    if artist then
        mp.msg.info("Requesting: " .. title .. " - " .. artist)
    else 
        mp.msg.info("Requesting: " .. title)
    end
    local response = curl({
        "curl",
        "--silent",
        "--get",
        "--cookie", "x-mxm-token-guid=" .. options.musixmatch_token, -- avoids a redirect
        "https://apic-desktop.musixmatch.com/ws/1.1/macro.subtitles.get",
        "--data", "app_id=web-desktop-app-v1.0",
        "--data", "usertoken=" .. options.musixmatch_token,
        "--data-urlencode", "q_track=" .. title,
        "--data-urlencode", "q_artist=" .. artist,
    })

    if not response then
        return
    end

    if response.message.header.status_code == 401 and response.message.header.hint == "renew" then
        show_error("The Musixmatch token has been rate limited - https://github.com/guidocella/mpv-lrc >>> script-opts/lrc.conf explains how to generate a new one.")
        return
    end

    if response.message.header.status_code ~= 200 then
        show_error("Request failed with status code " .. response.message.header.status_code .. ". Hint: " .. response.message.header.hint)
        return
    end

    local body = response.message.body.macro_calls
    local lyrics = ""
    if body["matcher.track.get"].message.header.status_code == 200 then
        downloadingName = body["matcher.track.get"].message.body.track.track_name
        if body["matcher.track.get"].message.body.track.has_subtitles == 1 then
            lyrics = body["track.subtitles.get"].message.body.subtitle_list[1].subtitle.subtitle_body
        elseif body["matcher.track.get"].message.body.track.has_lyrics == 1 then -- lyrics without timestamps
            lyrics = body["track.lyrics.get"].message.body.lyrics.lyrics_body
        elseif body["matcher.track.get"].message.body.track.instrumental == 1 then
            show_error("This is an instrumental track")
            return
        end
    end

    save_lyrics(lyrics)
end

mp.add_key_binding("Alt+n", "netease-download", function() 
    manualrun = true
    options.downloadforall = true
    neteasedownload() 
end)

function neteasedownload()
    local title, artist, album = get_metadata()

    if not title then
        return
    end

    mp.msg.info("Fetching lyrics (netease)")
    if manualrun then
        mp.osd_message("Fetching lyrics (netease)")
    end

    if artist then
        mp.msg.info("Requesting: " .. title .. " - " .. artist)
    else 
        mp.msg.info("Requesting: " .. title)
    end
    local response = curl({
        "curl",
        "--silent",
        "--get",
        "https://music.xianqiao.wang/neteaseapiv2/search?limit=9",
        "--data-urlencode", "keywords=" .. title .. " " .. artist,
    })

    if not response then
        return
    end

    local songs = response.result.songs

    if songs == nil or #songs == 0 then
        show_error("Lyrics not found")
        return
    end

    for _, song in ipairs(songs) do
        mp.msg.trace(
            "Found lyrics for the song with id " .. song.id ..
            ", name " .. song.name ..
            ", artist " .. song.artists[1].name ..
            ", album " .. song.album.name ..
            ", url https://music.xianqiao.wang/neteaseapiv2/lyric?id=" .. song.id
        )
    end

    local song = songs[1]
    if album then
        album = album:lower()

        for _, loop_song in ipairs(songs) do
            if loop_song.album.name:lower() == album then
                song = loop_song
                break
            end
        end
    end

    mp.msg.trace(
        "Downloading lyrics for the song with id " .. song.id ..
        ", name " .. song.name ..
        ", artist " .. song.artists[1].name ..
        ", album " .. song.album.name
    )
    downloadingName = song.name .. " - " .. song.artists[1].name

    response = curl({
        "curl",
        "--silent",
        "https://music.xianqiao.wang/neteaseapiv2/lyric?id=" .. song.id,
    })

    if response then
        save_lyrics(response.lrc.lyric)
    end
end

mp.add_key_binding("Alt+o", "offset-sub", function()
    local sub_path = mp.get_property("current-tracks/sub/external-filename")

    if not sub_path then
        show_error("No external subtitle is loaded")
        return
    end

    mp.set_property("sub-delay", mp.get_property_number("playback-time"))
    mp.command("sub-reload")
    mp.osd_message("Subtitles updated")
end)

function get_subtitle_count()
    local track_list = mp.get_property_native("track-list", {})
    local subtitle_count = 0
    for _, track in ipairs(track_list) do
        if track["type"] == "sub" then
            subtitle_count = subtitle_count + 1
        end
    end
    return subtitle_count
end

function autodownload()
    if (old_subtitle_count ~= subtitle_count) and options.cacheloading then
        print("Subs previously downloaded - not downloading again")
    else
        gotlyrics = false
        musixmatchdownload()
        if not gotlyrics then
            neteasedownload()
        end
        if withoutTimestamps then
            mp.osd_message("Lyrics without timestamps downloaded automatically")
        end
    end
end

function checkdownloadedsubs()
    local old_subtitle_count, subtitle_count = get_subtitle_count(), nil

    if old_subtitle_count > 0 then
        print("Subtitles detected - aborting download process")
        return
    end
    
    if options.cacheloading then
        -- check if already downloaded lyrics exist and were loaded
        local current_sub_path = mp.get_property("current-tracks/sub/external-filename")
        mp.set_property("sub-file-paths", mp.command_native({"expand-path", options.lyricsstore}))
        mp.command(current_sub_path and "sub-reload" or "rescan-external-files")
        subtitle_count = get_subtitle_count()
    end

    if options.runautomatically then
        autodownload()
    end
end

checkdownloadedsubs()