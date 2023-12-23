local options = {
    musixmatch_token = '220215b052d6aeaa3e9a410986f6c3ae7ea9f5238731cb918d05ea',
    downloadforall = true, -- experimental, try to get subtitles for all videos
    loadforyoutube = true, -- try to load lyrics on youtube videos
    lyricsstore = "~~desktop/mpv/lrcdownloads/",
    storelyricsseperate = true, -- store lyrics in ~~desktop/mpv/lrcdownloads/
}
local utils = require 'mp.utils'
require 'mp.options'.read_options(options)
local manualrun = false
local gotlyrics = false
local withoutTimestamps = false

local function show_error(message)
    mp.msg.error(message)
    if mp.get_property_native('vo-configured') and manualrun then
        mp.osd_message(message, 5)
    end
end

local function curl(args)
    local r = mp.command_native({name = 'subprocess', capture_stdout = true, args = args})

    if r.killed_by_us then
        -- don't print an error when curl fails because the playlist index was changed
        return false
    end

    if r.status < 0 then
        show_error('subprocess error: ' .. r.error_string)
        return false
    end

    if r.status > 0 then
        show_error('curl failed with code ' .. r.status)
        return false
    end

    local response, error = utils.parse_json(r.stdout)

    if error then
        show_error('Unable to parse the JSON response')
        return false
    end

    return response
end

local function get_metadata()
    local metadata = mp.get_property_native('metadata')
    local title, artist, album
    if next(metadata) == nil then
        mp.msg.info("couldn't load metadata!")
    else
        title = metadata.title or metadata.TITLE or metadata.Title
        if options.downloadforall then
            title = mp.get_property("media-title")
            title = title:gsub('%b[]', '') .. " "
            mp.msg.info("requesting: " .. title)
        end
        artist = metadata.artist or metadata.ARTIST or metadata.Artist
        if options.downloadforall and not artist then
            artist = " "
        end
        album = metadata.album or metadata.ALBUM or metadata.Album
    end

    if not title then
        show_error('This song has no title metadata')
        return false
    end

    if not artist then
        show_error('This song has no artist metadata')
        return false
    end

    return title, artist, album
end

local function save_lyrics(lyrics)
    if lyrics == '' then
        show_error('Lyrics not found')
        return
    end

    if #lyrics < 250 then
        show_error('File likely not lyrics')
        return
    end

    local current_sub_path = mp.get_property('current-tracks/sub/external-filename')

    if current_sub_path and lyrics:find('^%[') == nil then
        show_error("Only lyrics without timestamps are available, so the existing LRC file won't be overwritten")
        return
    end

    -- NetEase's LRCs can have 3-digit milliseconds, which messes up the sub's timings in mpv.
    lyrics = lyrics:gsub('(%.%d%d)%d]', '%1]')

    local success_message = 'Lyrics downloaded'
    if options.downloadforall then
        success_message = 'Found some lyrics... are they correct?'
    end
    if current_sub_path then
        -- os.rename only works across the same filesystem
        local _, current_sub_filename = utils.split_path(current_sub_path)
        local current_sub = io.open(current_sub_path)
        local backup = io.open('/tmp/' .. current_sub_filename, 'w')
        if current_sub and backup then
            backup:write(current_sub:read('*a'))
            success_message = success_message .. '. The old one has been backed up to /tmp.'
        end
        if current_sub then
            current_sub:close()
        end
        if backup then
            backup:close()
        end
    end

    local function is_url(s)
        return nil ~=
            string.match(s,
                "^[%w]-://[-a-zA-Z0-9@:%._\\+~#=]+%." ..
                "[a-zA-Z0-9()][a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?[a-zA-Z0-9()]?" ..
                "[-a-zA-Z0-9()@:%_\\+.~#?&/=]*")
    end

    local function is_windows()
        local a=os.getenv("windir")if a~=nil then return true else return false end
    end

    local function createDirectory(directoryPath)
        local args = {'mkdir', directoryPath}
        if is_windows() then 
            args = {'powershell', '-NoProfile', '-Command', 'mkdir', directoryPath}
        end
        local res = utils.subprocess({ args = args, cancellable = false })
        if res.status ~= 0 then
            mp.msg.error("Failed to create directory: " .. directoryPath)
        else
            mp.msg.info("Directory created successfully: " .. directoryPath)
        end
    end    

    local path = mp.get_property('path')
    local media = mp.get_property("media-title")

    if (is_url(path) and path or nil) and options.loadforyoutube then
        youtubeID = " [" .. mp.get_property("filename"):match('[?&]v=([^&]+)') .. "]"
        local filename = string.gsub(media:sub(1, 35), "^%s*(.-)%s*$", "%1") .. youtubeID
        path =  mp.command_native({"expand-path", options.lyricsstore .. filename})
    else
        if options.storelyricsseperate then
            path = mp.command_native({"expand-path", options.lyricsstore .. media})
        end
    end

    local lrc_path = (path:match('(.*)%.[^/]*$') or path).. '.lrc'
    local dir_path = lrc_path:match("(.+\\).-$"):gsub("/", "\\")
    if is_windows() then
        lrc_path = lrc_path:gsub("/", "\\")
        dir_path = dir_path:gsub("/", "\\")
    end
    print(lrc_path)
    print(dir_path)
    
    if (utils.readdir(dir_path) == nil) then
        createDirectory(dir_path)
    end

    local lrc = io.open(lrc_path, 'w')
    if lrc == nil then
        show_error('Failed writing to ' .. lrc_path)
        return
    end
    lrc:write(lyrics)
    lrc:close()

    if lyrics:find('^%[') then
        mp.commandv("sub-add", lrc_path)
        mp.command(current_sub_path and 'sub-reload' or 'rescan-external-files')
        if manualrun or options.downloadforall then
            mp.osd_message(success_message)
        end
        gotlyrics = true
        withoutTimestamps = false
    else
        if manualrun then
            mp.osd_message('Lyrics without timestamps downloaded')
        end
        withoutTimestamps = true
    end
end

mp.add_key_binding('Alt+m', 'musixmatch-download', function() 
    manualrun = true
    musixmatchdownload() 
end)

function musixmatchdownload()
    local title, artist = get_metadata()

    if not title then
        return
    end

    mp.msg.info('Downloading lyrics')
    if manualrun then
        mp.osd_message('Downloading lyrics (musixmatch)')
    end

    local response = curl({
        'curl',
        '--silent',
        '--get',
        '--cookie', 'x-mxm-token-guid=' .. options.musixmatch_token, -- avoids a redirect
        'https://apic-desktop.musixmatch.com/ws/1.1/macro.subtitles.get',
        '--data', 'app_id=web-desktop-app-v1.0',
        '--data', 'usertoken=' .. options.musixmatch_token,
        '--data-urlencode', 'q_track=' .. title,
        '--data-urlencode', 'q_artist=' .. artist,
    })

    if not response then
        return
    end

    if response.message.header.status_code == 401 and response.message.header.hint == 'renew' then
        show_error('The Musixmatch token has been rate limited - https://github.com/guidocella/mpv-lrc >>> script-opts/lrc.conf explains how to generate a new one.')
        return
    end

    if response.message.header.status_code ~= 200 then
        show_error('Request failed with status code ' .. response.message.header.status_code .. '. Hint: ' .. response.message.header.hint)
        return
    end

    local body = response.message.body.macro_calls

    local lyrics = ''
    if body['matcher.track.get'].message.header.status_code == 200 then
        if body['matcher.track.get'].message.body.track.has_subtitles == 1 then
            lyrics = body['track.subtitles.get'].message.body.subtitle_list[1].subtitle.subtitle_body
        elseif body['matcher.track.get'].message.body.track.has_lyrics == 1 then -- lyrics without timestamps
            lyrics = body['track.lyrics.get'].message.body.lyrics.lyrics_body
        elseif body['matcher.track.get'].message.body.track.instrumental == 1 then
            show_error('This is an instrumental track')
            return
        end
    end

    save_lyrics(lyrics)
end

mp.add_key_binding('Alt+n', 'netease-download', function() 
    manualrun = true
    neteasedownload() 
end)

function neteasedownload()
    local title, artist, album = get_metadata()

    if not title then
        return
    end

    mp.msg.info('Downloading lyrics (netease)')
    if manualrun then
        mp.osd_message('Downloading lyrics')
    end

    local response = curl({
        'curl',
        '--silent',
        '--get',
        'https://music.xianqiao.wang/neteaseapiv2/search?limit=10',
        '--data-urlencode', 'keywords=' .. title .. ' ' .. artist,
    })

    if not response then
        return
    end

    local songs = response.result.songs

    if songs == nil or #songs == 0 then
        show_error('Lyrics not found')
        return
    end

    for _, song in ipairs(songs) do
        mp.msg.info(
            'Found lyrics for the song with id ' .. song.id ..
            ', name ' .. song.name ..
            ', artist ' .. song.artists[1].name ..
            ', album ' .. song.album.name ..
            ', url https://music.xianqiao.wang/neteaseapiv2/lyric?id=' .. song.id
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

    mp.msg.info(
        'Downloading lyrics for the song with id ' .. song.id ..
        ', name ' .. song.name ..
        ', artist ' .. song.artists[1].name ..
        ', album ' .. song.album.name
    )

    response = curl({
        'curl',
        '--silent',
        'https://music.xianqiao.wang/neteaseapiv2/lyric?id=' .. song.id,
    })

    if response then
        save_lyrics(response.lrc.lyric)
    end
end

mp.add_key_binding('Alt+o', 'offset-sub', function()
    local sub_path = mp.get_property('current-tracks/sub/external-filename')

    if not sub_path then
        show_error('No external subtitle is loaded')
        return
    end

    print(mp.get_property_number('playback-time'))
    mp.set_property('sub-delay', mp.get_property_number('playback-time'))
    mp.command('sub-reload')
    mp.osd_message('Subtitles updated')
end)

function autodownload()
    gotlyrics = false
    musixmatchdownload()
    if not gotlyrics then
        neteasedownload()
    end
    if withoutTimestamps then
        mp.osd_message('Lyrics without timestamps downloaded automatically')
    end
end

mp.register_event("file-loaded", autodownload)