--[[
    autolyrics.lua by zydezu
	(https://github.com/zydezu/mpvconfig/blob/main/scripts/autolyrics.lua)
	
	* Based on https://github.com/guidocella/mpv-lrc

    Tries to download lyrics and display them for said file
--]]

mp.utils = require("mp.utils")
mp.input = require("mp.input")

local options = {
    musixmatch_token = "2501192ac605cc2e16b6b2c04fe43d1011a38d919fe802976084e7",
    download_for_all = false,                                       -- try to get subtitles for music without metadata
    load_for_youtube = true,                                        -- try to load lyrics on youtube videos
    store_lyrics_seperate = true,                                   -- store lyrics in ~~desktop/mpv/lrcdownloads/
    lyrics_store = "~~desktop/mpv/lrcdownloads/",                   -- where to store downloaded lyric files if store_lyrics_seperate is true
    cache_loading = true,                                           -- try to load lyrics that were already downloaded
    strip_artists = true,                                           -- remove lines with the names of the artists from NetEase lyrics
    chinese_to_kanji_path = "~~home/chinese-to-kanji.txt",          -- set to path of file
    mark_as_ja = false,                                             -- add .ja.lrc extensions to lyrics with Japanese characters
    run_automatically = false                                       -- run this script without pressing Alt+m
}
require("mp.options").read_options(options)

local manual_run = false
local got_lyrics = false
local without_timestamps = false
local downloading_name = ""
local old_subtitle_count, subtitle_count

local function show_error(message)
    mp.msg.error(message)
    if mp.get_property_native("vo-configured") and manual_run then
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

    local response, error = mp.utils.parse_json(r.stdout)

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
            mp.msg.info("Couldn't load metadata!")
        else
            title = metadata.title or metadata.TITLE or metadata.Title
            if options.download_for_all then
                title = mp.get_property("media-title")
                title = title:gsub("%b[]", "") .. " "
            end
            artist = mp.get_property("filtered-metadata/by-key/Artist") or mp.get_property("filtered-metadata/by-key/Album_Artist") or mp.get_property("filtered-metadata/by-key/Uploader")
            if options.download_for_all and not artist then
                artist = " "
            end
            album = metadata.album or metadata.ALBUM or metadata.Album or ""
        end
    else
        mp.msg.info("Couldn't load metadata!")
    end

    if not title then
        show_error("This song has no title metadata")
        return false
    end

    if not artist then
        show_error("This song has no artist metadata")
        return false
    end
    
    return title, artist, album
end

local function is_japanese(lyrics)
    return lyrics:find("[\227-\233]") ~= nil
end

local function chinese_to_kanji(lyrics)
    local mappings, error = io.open(
        mp.command_native({'expand-path', options.chinese_to_kanji_path})
    )

    if mappings == nil then
        show_error(error)
        return lyrics
    end

    -- -- Save the original lyrics to compare them for testing.
    -- local original = io.open(mp.command_native({'expand-path', '~~desktop/mpv/lrcdownloads/TESTCOMPARE.lrc'}), 'w')
    -- if original then
    --     original:write(lyrics)
    --     original:close()
    -- end

    for mapping in mappings:lines() do
        local num_matches

        -- gsub on Unicode lyrics seems to stop at the first match. I have
        -- no idea why this works.
        repeat
            lyrics, num_matches = lyrics:gsub(
                mapping:gsub(' .*', ''),
                mapping:gsub('.* ', '')
            )
        until num_matches == 0
    end

    mappings:close()

    -- Also remove the pointless owari line when present.
    for _, pattern in pairs({
        'おわり',
        '【 おわり 】',
        ' ?終わり',
        '終わる',
        'END',
    }) do
        lyrics = lyrics:gsub(']' .. pattern .. '\n', ']\n')
    end

    return lyrics
end

local function strip_artists(lyrics)
    for _, pattern in pairs({'作词', '作詞', '作曲', '制作人', '编曲', '編曲', '詞', '曲'}) do
        lyrics = lyrics:gsub('%[[%d:%.]*] ?' .. pattern .. ' ?[:：] ?.-\n', '')
    end
    return lyrics
end

local function create_folder(path)
	local args
	if package.config:sub(1,1) == '\\' then
		-- Windows: normalize slashes and use 'mkdir' with '/S' for nested folders
		local win_path = path:gsub("/", "\\")
		args = { "cmd", "/c", "mkdir", win_path }
	else
		-- Unix/macOS/Linux
		args = { "mkdir", "-p", path }
	end

	local res = mp.utils.subprocess({ args = args })
	if res.status == 0 then
		mp.msg.info("Successfully created folder: " .. path)
	else
		mp.msg.error("Failed to create folder: " .. path)
	end
end

local function save_lyrics(lyrics)
    if lyrics == "" or #lyrics < 100 then
        show_error("Lyrics not found")
        return
    end

    local current_sub_path = mp.get_property("current-tracks/sub/external-filename")

    if current_sub_path and lyrics:find("^%[") == nil then
        show_error("Only lyrics without timestamps are available, so the existing LRC file won't be overwritten")
        return
    end

    -- NetEase's LRCs can have 3-digit milliseconds, which messes up the sub's timings in mpv.
    lyrics = lyrics:gsub("(%.%d%d)%d]", "%1]")
    lyrics = lyrics:gsub("’", "'"):gsub("' ", "'"):gsub("\\", "") -- remove strange characters    

    local add_ja = false

    if is_japanese(lyrics) then
        if options.mark_as_ja then
            add_ja = true
        end
        if options.chinese_to_kanji_path ~= "" then
            lyrics = chinese_to_kanji(lyrics)
        end
    end
    if options.strip_artists then
        lyrics = strip_artists(lyrics)
    end

    local function is_url(s)
        local url_pattern = "^[%w]+://[%w%.%-_]+%.[%a]+[-%w%.%-%_/?&=]*"
        return string.match(s, url_pattern) ~= nil
    end

    local function check_if_windows()
        local a=os.getenv("windir")if a~=nil then return true else return false end
    end

    downloading_name = downloading_name:gsub("\\", " "):gsub("/", " ")

    local path = mp.get_property("path")
    local media = downloading_name .. " [" .. mp.get_property("filename/no-ext") .. "]"
    local pattern = '[\\/:*?"<>|]'

    if (is_url(path) and path or nil) and options.load_for_youtube then
        local youtube_ID = ""
        if not downloading_name then 
            youtube_ID = " [" .. mp.get_property("filename"):match("[?&]v=([^&]+)") .. "]" 
        end
        local filename = string.gsub(media:sub(1, 100):gsub(pattern, ""), "^%s*(.-)%s*$", "%1") .. youtube_ID
        path =  mp.command_native({"expand-path", options.lyrics_store .. filename})
    else
        if options.store_lyrics_seperate then
            path = mp.command_native({"expand-path", options.lyrics_store .. media})
        end
    end

    local lrc_path = (path:gsub("?", "") .. (add_ja and ".ja" or "") .. ".lrc")
    local dir_path = lrc_path:match("(.+[\\/])")

    if mp.utils.readdir(dir_path) == nil and options.store_lyrics_seperate then
        create_folder(dir_path)
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
        if manual_run then
            mp.osd_message("Lyrics downloaded")
        end
        got_lyrics = true
        without_timestamps = false
    else
        if manual_run then
            mp.osd_message("Lyrics without timestamps downloaded")
        end
        without_timestamps = true
    end
end

local function musixmatch_download()
    local title, artist, album = get_metadata()

    if not title then
        return
    end

    mp.msg.info("Fetching lyrics (musixmatch)")
    if manual_run then
        mp.osd_message("Fetching lyrics (musixmatch)")
    end
    mp.msg.info("Requesting: " .. title .. " - " .. artist)

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

    local lyrics = ""
    local body = response and response.message and response.message.body and response.message.body.macro_calls
    
    if not body then
        show_error("Invalid response structure: macro_calls not found")
        return
    end
    local matcher = body["matcher.track.get"]
    if not matcher or not matcher.message or not matcher.message.header then
        show_error("Invalid matcher.track.get structure")
        return
    end

    if matcher.message.header.status_code == 200 then
        local track = matcher.message.body and matcher.message.body.track
        if not track or not track.artist_name or not track.track_name then
            show_error("Track data missing")
            return
        end
        downloading_name = track.artist_name .. " - " .. track.track_name

        if track.has_subtitles == 1 then
            local subtitles = body["track.subtitles.get"]
            if subtitles and subtitles.message and subtitles.message.body then
                local subtitle_list = subtitles.message.body.subtitle_list
                if subtitle_list and subtitle_list[1] and subtitle_list[1].subtitle then
                    lyrics = subtitle_list[1].subtitle.subtitle_body or ""
                else
                    show_error("Subtitles data is malformed")
                end
            else
                show_error("Subtitle data missing")
            end

        elseif track.has_lyrics == 1 then
            local lyrics_data = body["track.lyrics.get"]
            if lyrics_data and lyrics_data.message and lyrics_data.message.body and lyrics_data.message.body.lyrics then
                lyrics = lyrics_data.message.body.lyrics.lyrics_body or ""
            else
                show_error("Lyrics data is missing or malformed")
            end

        elseif track.instrumental == 1 then
            show_error("This is an instrumental track")
            return
        else
            show_error("No lyrics or subtitles found")
        end
    end

    save_lyrics(lyrics)
end

local netease_songs

local function select_netease_lyrics()
    local items = {}
    for _, song in ipairs(netease_songs) do
        items[#items+1] = song.artists[1].name .. ' - ' ..
                          song.name .. ' (' ..
                          song.album.name .. ')'
    end

    mp.input.select({
        prompt = 'Select a song:',
        items = items,
        submit = function(i)
            local selected_song = netease_songs[i]
            local response = curl({
                'curl',
                '--silent',
                'https://music.xianqiao.wang/neteaseapiv2/lyric?id=' .. netease_songs[i].id,
            })

            if response then
                downloading_name = selected_song.name .. " - " .. selected_song.artists[1].name
                save_lyrics(response.lrc.lyric)
            end
        end
    })
end

local function netease_download()
    if netease_songs and mp.input then
        select_netease_lyrics()
        return
    end

    local title, artist, album = get_metadata()
    local keywords
    if title then
        keywords = title .. " " .. artist
    else
        keywords = mp.get_property('media-title')
        if not keywords then
            show_error("No metadata or media-title found")
            return
        end
    end

    mp.osd_message('Downloading lyrics')

    local response = curl({
        "curl",
        "--silent",
        "--get",
        "https://music.xianqiao.wang/neteaseapiv2/search?limit=9",
        "--data-urlencode", "keywords=" .. keywords,
    })

    if not response then
        return
    end

    if not response.result then
        show_error("Lyrics not found")
        return
    end

    netease_songs = response.result.songs

    if netease_songs == nil or #netease_songs == 0 then
        show_error("Lyrics not found")
        return
    end

    if mp.input then
        if #netease_songs == 1 then
            response = curl({
                "curl",
                "--silent",
                "https://music.xianqiao.wang/neteaseapiv2/lyric?id=" .. netease_songs[1].id,
            })
            if response then
                save_lyrics(response.lrc.lyric)
            end
            return
        end
        select_netease_lyrics()
        return
    end

    for _, song in ipairs(netease_songs) do
        mp.msg.trace(
            "Found lyrics for the song with id " .. song.id ..
            ", name " .. song.name ..
            ", artist " .. song.artists[1].name ..
            ", album " .. song.album.name ..
            ", url https://music.xianqiao.wang/neteaseapiv2/lyric?id=" .. song.id
        )
    end

    local song = netease_songs[1]
    if album then
        album = album:lower()

        for _, loop_song in ipairs(netease_songs) do
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

    response = curl({
        "curl",
        "--silent",
        "https://music.xianqiao.wang/neteaseapiv2/lyric?id=" .. song.id,
    })

    if response and response.lrc then
        save_lyrics(response.lrc.lyric)
    end
end

local function auto_download()
    if old_subtitle_count ~= subtitle_count and options.cache_loading then
        print("Subs previously downloaded - not downloading again")
    else
        got_lyrics = false
        musixmatch_download()
        if not got_lyrics then
            netease_download()
        end
        if without_timestamps then
            mp.osd_message("Lyrics without timestamps downloaded automatically")
        end
    end
end

local function get_subtitle_count()
    local track_list = mp.get_property_native("track-list", {})
    local sub_count = 0
    for _, track in ipairs(track_list) do
        if track["type"] == "sub" then
            sub_count = sub_count + 1
        end
    end
    return sub_count
end

local function check_downloaded_subs()
    old_subtitle_count, subtitle_count = get_subtitle_count(), nil

    if old_subtitle_count > 0 then
        print("Subtitles detected - aborting autolyrics.lua")
        return
    end

    if options.cache_loading then
        -- check if already downloaded lyrics exist and were loaded
        local current_sub_path = mp.get_property("current-tracks/sub/external-filename")
        mp.set_property("sub-file-paths", mp.command_native({"expand-path", options.lyrics_store}))
        mp.command(current_sub_path and "sub-reload" or "rescan-external-files")
        subtitle_count = get_subtitle_count()
    end

    if options.run_automatically then
        auto_download()
    end
end

mp.add_key_binding("alt+m", "musixmatch-download", function() 
    manual_run = true
    musixmatch_download()
end)

mp.add_key_binding("alt+n", "netease-download", function() 
    manual_run = true
    netease_download()
end)

mp.add_key_binding("alt+o", "offset-sub", function()
    local sub_path = mp.get_property("current-tracks/sub/external-filename")

    if not sub_path then
        show_error("No external subtitle is loaded")
        return
    end

    mp.set_property("sub-delay", mp.get_property_number("playback-time"))
    mp.command("sub-reload")
    mp.osd_message("Subtitles updated")
end)

check_downloaded_subs()