--[[
    autolyrics.lua by zydezu
	(https://github.com/zydezu/mpvconfig/blob/main/scripts/autolyrics.lua)
	
	* Based on https://github.com/guidocella/mpv-lrc

    Tries to download lyrics and display them for said file
--]]

mp.utils = require("mp.utils")

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
            artist = mp.get_property("filtered-metadata/by-key/Album_Artist") or mp.get_property("filtered-metadata/by-key/Artist") or mp.get_property("filtered-metadata/by-key/Uploader")
            if options.download_for_all and not artist then
                artist = " "
            end
            album = metadata.album or metadata.ALBUM or metadata.Album
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

    print(title)
    print(artist)
    print(album)
    
    return title, artist, album
end

local function is_japanese(lyrics)
    -- http://lua-users.org/wiki/LuaUnicode Lua patterns don't support Unicode
    -- ranges, and you can't even iterate over \u{XXX} sequences in Lua 5.1 and
    -- 5.2, so just search for some hiragana and katakana characters.

    for _, kana in pairs({
        'あ', 'い', 'う', 'え', 'お',
        'か', 'き', 'く', 'け', 'こ',
        'さ', 'し', 'す', 'せ', 'そ',
        'た', 'ち', 'つ', 'て', 'と',
        'な', 'に', 'ぬ', 'ね', 'の',
        'は', 'ひ', 'ふ', 'へ', 'ほ',
        'ま', 'み', 'む', 'め', 'も',
        'や',       'ゆ',       'よ',
        'ら', 'り', 'る', 'れ', 'ろ',
        'わ',                   'を',
        'ア', 'イ', 'ウ', 'エ', 'オ',
        'カ', 'キ', 'ク', 'ケ', 'コ',
        'サ', 'シ', 'ス', 'セ', 'ソ',
        'タ', 'チ', 'ツ', 'テ', 'ト',
        'ナ', 'ニ', 'ヌ', 'ネ', 'ノ',
        'ハ', 'ヒ', 'フ', 'ヘ', 'ホ',
        'マ', 'ミ', 'ム', 'メ', 'モ',
        'ヤ',       'ユ',       'ヨ',
        'ラ', 'リ', 'ル', 'レ', 'ロ',
        'ワ',                   'ヲ',
        'ン', 'ガ', 'ギ', 'グ', 'ゲ', 'ゴ',
        'ザ', 'ジ', 'ズ', 'ゼ', 'ゾ',
        'ダ', 'ヂ', 'ヅ', 'デ', 'ド',
        'バ', 'ビ', 'ブ', 'ベ', 'ボ',
    }) do
        if lyrics:find(kana) then
            return true
        end
    end
    return false
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

    local is_windows = check_if_windows()

    local function create_directory(directory_path)
        local args = {"mkdir", directory_path}
        if is_windows then args = {"powershell", "-NoProfile", "-Command", "mkdir", directory_path} end
        local res = mp.utils.subprocess({ args = args, cancellable = false })
        if res.status ~= 0 then
            mp.msg.error("Failed to create directory: " .. directory_path)
        else
            mp.msg.info("Directory created successfully: " .. directory_path)
        end
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
    if is_windows then
        lrc_path = lrc_path:gsub("/", "\\")
        dir_path = dir_path:gsub("/", "\\")
    end

    if mp.utils.readdir(dir_path) == nil and options.store_lyrics_seperate then
        if not is_windows then
            local subdir_path = mp.utils.split_path(dir_path)
            create_directory(subdir_path) -- required for linux as it cannot create mpv/lrcdownloads/
        end
        create_directory(dir_path)
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
    local title, artist = get_metadata()

    if not title then
        return
    end

    mp.msg.info("Fetching lyrics (musixmatch)")
    if manual_run then
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
        downloading_name = body["matcher.track.get"].message.body.track.track_name
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

local function netease_download()
    local title, artist, album = get_metadata()

    if not title then
        return
    end

    mp.msg.info("Fetching lyrics (netease)")
    if manual_run then
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
    downloading_name = song.name .. " - " .. song.artists[1].name

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
    local subtitle_count = 0
    for _, track in ipairs(track_list) do
        if track["type"] == "sub" then
            subtitle_count = subtitle_count + 1
        end
    end
    return subtitle_count
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

mp.add_key_binding("alt+n", "netease-download", function() 
    manual_run = true
    netease_download()
end)

mp.add_key_binding("alt+m", "musixmatch-download", function() 
    manual_run = true
    auto_download()
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