--[[
    mpvcut.lua by zydezu
	(https://github.com/zydezu/mpvconfig/blob/main/scripts/mpvcut.lua)

	* Based on https://github.com/familyfriendlymikey/mpv-cut/blob/main/main.lua

    Clip, compress and re-encode selected clips
--]]

mp.msg = require("mp.msg")
mp.utils = require("mp.utils")

local options = {
    -- Save location
    save_to_directory = true,                -- save to 'save_directory' instead of the current folder of the file
    save_directory = "~/Pictures/mpv/clips", -- required for web videos
    save_to_title_directory = true,          -- save to subdirectory named after the video title

    -- Key config
    key_cut = "a",
    key_cancel_cut = "shift+a",
    key_cycle_action = "A",
    key_cycle_codec = "alt+a",
    codecs_list = { "h264", "h265", "av1" },

    -- The default action
    action = "ENCODE", -- the default action, ENCODE, ENCODE_ANIMATED, COMPRESS or CUT

    -- File size targets
    compress_size = 9.50, -- the target size for the COMPRESS action (in MB)

    -- encoding options
    encoding_type = "h265",          -- h264, h265, or av1
    animated_encoding_type = "avif", -- for encoding animated gifs, webps or avifs - gif, webp or avif

    cap_resolution = true,           -- whether to lower the resolution to the target resolution (COMPRESS/ENCODE_ANIMATED only)
    max_resolution = 1080,           -- resolution to shrink to if video is above this resolution (COMPRESS only)
    max_animated_resolution = 540,   -- resolution to shrink to if gif/avif is above this resolution (ENCODE_ANIMATED only)

    h264_crf = 23,                   -- the crf value to use for h264 clips, lower numbers mean higher quality
    h265_crf = 28,                   -- the crf value to use for h265 clips, lower numbers mean higher quality
    av1_crf = 40,                    -- the crf value to use for av1 clips, lower numbers mean higher quality

    webp_quality = 75,               -- quality for animated .webps, 0-100 low-high
    webp_compression_level = 6,      -- compression effort, a trade-off between speed and size, lower numbers provide a higher speed

    avif_crf = 42,                   -- the crf value to use for animated .avif clips, lower numbers mean higher quality
    av1_preset = 6,                  -- av1 encoding preset, a trade-off between speed and size, higher numbers provide a higher speed

    -- GPU encoding (used by the ENCODE_GPU action, respects the same codec as ENCODE)
    gpu_type = "auto",   -- auto-detect, or set manually: nvenc (NVIDIA), vaapi (AMD/Intel Linux), amf (AMD), qsv (Intel)
    nvenc_preset = "p2", -- NVENC speed preset: p1 (fastest) to p7 (best quality)
    gpu_h264_cq = 28,    -- GPU h264 quality (CQ/QP), lower = better quality
    gpu_h265_cq = 34,    -- GPU h265 quality
    gpu_av1_cq = 46,     -- GPU av1 quality (nvenc and amf only)

    -- Web videos/cache
    use_cache_for_web_videos = true, -- whether to cut web videos using the player's cache (experimental)
}
require("mp.options").read_options(options)

local function print(s)
    mp.msg.info(s)
    mp.osd_message(s)
end

local function is_url(s)
    local url_pattern = "^[%w]+://[%w%.%-_]+%.[%a]+[-%w%.%-%_/?&=]*"
    return string.match(s, url_pattern) ~= nil
end

local function copy_to_clipboard(filepath)
    local platform = mp.get_property_native("platform")
    local cmd

    if platform == "windows" then
        -- Windows: copy file URI to clipboard via PowerShell
        local uri = "file:///" .. filepath:gsub("\\", "/"):gsub(" ", "%%20")
        cmd = {
            "powershell", "-NoProfile", "-Command",
            string.format("Set-Clipboard -Value '%s'", uri:gsub("'", "''"))
        }
    elseif platform == "darwin" then
        -- macOS: use osascript to set file on clipboard
        cmd = {
            "osascript", "-e",
            string.format("set the clipboard to (POSIX file %q)", filepath)
        }
    else
        -- Linux
        if os.getenv("WAYLAND_DISPLAY") then
            -- Wayland: wl-copy with text/uri-list
            cmd = {
                "sh", "-c",
                string.format("printf 'file://%s' | wl-copy --type text/uri-list", filepath)
            }
        else
            -- X11: xclip with text/uri-list
            cmd = {
                "sh", "-c",
                string.format("printf 'file://%s' | xclip -sel c -t text/uri-list", filepath)
            }
        end
    end

    mp.command_native_async({
        name = "subprocess",
        args = cmd,
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    }, function(success, result)
        if success then
            mp.msg.info("Copied file URI to clipboard: " .. filepath)
        else
            mp.msg.warn("Failed to copy to clipboard")
        end
    end)
end


local result = mp.command_native({ name = "subprocess", args = { "ffmpeg" }, playback_only = false, capture_stdout = true, capture_stderr = true })
if result.status ~= 1 then
    mp.osd_message("FFmpeg failed to run")
end

local full_path = mp.command_native({ "expand-path", options.save_directory })
local full_path_save = ""
local web_ext = ".mkv"

local average_bitrate = -1
local avg_count = 1

local function get_bitrate()
    local video_bitrate = mp.get_property_number("video-bitrate")
    if video_bitrate then
        video_bitrate = video_bitrate / 1000
        avg_count = avg_count + 1
        if average_bitrate == -1 then
            average_bitrate = video_bitrate
        else
            average_bitrate = ((avg_count - 1) * average_bitrate + video_bitrate) / avg_count
        end
    end
end

local function sanitize_filename(name)
    return name and name:gsub('[\\/:*?"<>|]', '') or ""
end

local function get_title_subdir()
    -- Returns the expanded save_directory, optionally with a title subdirectory appended.
    -- Used for local (non-web) files when save_to_directory is true.
    if options.save_to_title_directory then
        local file_name_clean = sanitize_filename(mp.get_property("filename/no-ext"))
        return mp.command_native({ "expand-path", options.save_directory .. "/" .. file_name_clean })
    else
        return full_path
    end
end

local function init()
    -- Set save directory path
    if full_path then
        local file_name_clean = sanitize_filename(mp.get_property("filename/no-ext"))

        if (options.use_cache_for_web_videos and is_url(mp.get_property("path"))) then
            local video       = mp.get_property("video-format", "none")
            local audio       = mp.get_property("audio-codec-name", "none")

            local webm_codecs = { vp8 = true, vp9 = true }
            local webm_audio  = { opus = true, vorbis = true }

            local mp4_video   = { h264 = true, hevc = true, av1 = true }
            local mp4_audio   = { opus = true, mp3 = true, flac = true, aac = true }

            local function contains(tbl, val)
                return tbl[val] or false
            end

            if contains(webm_codecs, video) and contains(webm_audio, audio) then
                web_ext = ".webm"
            elseif contains(mp4_video, video) and contains(mp4_audio, audio) then
                web_ext = ".mp4"
            else
                web_ext = ".mkv"
            end

            local youtube_ID = ""
            local _, _, videoID = string.find(mp.get_property("filename"), "([%w_-]+)%?si=")
            local videoIDMatch = mp.get_property("filename"):match("[?&]v=([^&]+)")
            if (videoIDMatch) then
                youtube_ID = " [" .. videoIDMatch .. "]"
            elseif (videoID) then
                youtube_ID = " [" .. videoID .. "]"
            end

            -- For web videos, full_path_save is the directory clips go into.
            -- Respect save_to_title_directory here too.
            if options.save_to_title_directory then
                full_path_save = mp.command_native({ "expand-path",
                    options.save_directory .. "/" .. file_name_clean .. youtube_ID })
            else
                full_path_save = mp.command_native({ "expand-path",
                    options.save_directory })
            end
        else
            -- Local file: full_path_save not used for path building (check_paths handles it),
            -- but set it sensibly for the web-cache branch just in case.
            if options.save_to_title_directory then
                full_path_save = mp.command_native({ "expand-path",
                    options.save_directory .. "/" .. file_name_clean })
            else
                full_path_save = full_path
            end
        end
    end

    -- Reset average bitrate
    average_bitrate = -1
    avg_count = 1
end

mp.register_event("file-loaded", init)
mp.add_periodic_timer(2, get_bitrate)

local function to_hms(seconds)
    local ms = math.floor((seconds - math.floor(seconds)) * 1000)
    local secs = math.floor(seconds)
    local mins = math.floor(secs / 60)
    secs = secs % 60
    local hours = math.floor(mins / 60)
    mins = mins % 60
    return string.format("%02d-%02d-%02d-%03d", hours, mins, secs, ms)
end

local function next_table_key(t, current)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    for i = 1, #keys do
        if keys[i] == current then
            return keys[(i % #keys) + 1]
        end
    end
    return keys[1]
end

local function create_folder(path)
    local args
    if package.config:sub(1, 1) == '\\' then
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

local function check_paths(d, suffix, web_path_save, new_ext)
    -- Determine the output directory, respecting save_to_title_directory for local files.
    local out_dir
    if web_path_save then
        -- Web cache path: directory is already baked into web_path_save by init().
        return web_path_save .. " " .. suffix .. web_ext
    end

    out_dir = get_title_subdir()

    if (mp.utils.readdir(out_dir) == nil) then
        create_folder(out_dir)
    end

    return mp.utils.join_path(out_dir .. "/", d.infile_noext .. suffix .. (new_ext or ".mp4"))
end

local detected_gpu_type = nil
local function get_gpu_type()
    if detected_gpu_type then return detected_gpu_type end
    if options.gpu_type ~= "auto" then
        detected_gpu_type = options.gpu_type
        return detected_gpu_type
    end

    local platform = mp.get_property_native("platform")
    if platform == "linux" then
        local f = io.open("/dev/nvidia0", "r")
        if f then
            f:close()
            detected_gpu_type = "nvenc"
        else
            f = io.open("/dev/dri/renderD128", "r")
            if f then
                f:close(); detected_gpu_type = "vaapi"
            end
        end
    elseif platform == "windows" then
        local result = mp.command_native({
            name = "subprocess",
            args = { "wmic", "path", "win32_VideoController", "get", "name" },
            playback_only = false,
            capture_stdout = true,
            capture_stderr = true,
        })
        if result and result.stdout then
            local out = result.stdout:lower()
            if out:find("nvidia") then
                detected_gpu_type = "nvenc"
            elseif out:find("amd") or out:find("radeon") then
                detected_gpu_type = "amf"
            elseif out:find("intel") then
                detected_gpu_type = "qsv"
            end
        end
    end

    if not detected_gpu_type then
        detected_gpu_type = "nvenc"
        mp.msg.warn("Could not auto-detect GPU type, falling back to nvenc")
    else
        mp.msg.info("Auto-detected GPU encoder: " .. detected_gpu_type)
    end
    return detected_gpu_type
end

local function resolve_gpu_encoder(codec_base)
    local gpu = get_gpu_type()
    local cq_map = { h264 = options.gpu_h264_cq, h265 = options.gpu_h265_cq, av1 = options.gpu_av1_cq }
    local cq = cq_map[codec_base] or 28
    local encoder_map = {
        nvenc = { h264 = "h264_nvenc", h265 = "hevc_nvenc", av1 = "av1_nvenc" },
        vaapi = { h264 = "h264_vaapi", h265 = "hevc_vaapi", av1 = "av1_vaapi" },
        amf   = { h264 = "h264_amf", h265 = "hevc_amf", av1 = "av1_amf" },
        qsv   = { h264 = "h264_qsv", h265 = "hevc_qsv", av1 = "av1_qsv" },
    }
    local encoder = (encoder_map[gpu] or encoder_map.nvenc)[codec_base] or "h264_nvenc"
    local quality_args = {}
    local vaapi_vf = nil

    if gpu == "nvenc" then
        quality_args = { "-preset", options.nvenc_preset, "-cq", tostring(cq) }
    elseif gpu == "vaapi" then
        vaapi_vf = "format=nv12,hwupload"
        quality_args = { "-qp", tostring(cq) }
    elseif gpu == "amf" then
        quality_args = { "-rc", "cqp", "-qp_i", tostring(cq), "-qp_p", tostring(cq) }
    elseif gpu == "qsv" then
        quality_args = { "-global_quality", tostring(cq) }
    end

    if codec_base == "h265" then
        table.insert(quality_args, "-tag:v"); table.insert(quality_args, "hvc1")
    end

    return encoder, quality_args, vaapi_vf
end

ACTIONS = {}

ACTIONS.ENCODE = function(d)
    local file_extra_suffix = string.format("_FROM_%s_TO_%s (%s encode)",
        d.start_time_hms, d.end_time_hms, options.encoding_type)
    local result_path = mp.utils.join_path(d.indir, string.format("%s%s.mp4", d.infile_noext, file_extra_suffix))
    if (options.save_to_directory) then result_path = check_paths(d, file_extra_suffix) end

    local selected_audio_id = mp.get_property_number("aid")
    local ff_audio_index = nil
    local count = 0
    for _, track in ipairs(mp.get_property_native("track-list") or {}) do
        if track.type == "audio" then
            if track.id == selected_audio_id then
                ff_audio_index = count
                break
            end
            count = count + 1
        end
    end
    if ff_audio_index == nil then
        ff_audio_index = 0
    end

    -- Start with common args
    local args = {
        "ffmpeg", "-nostdin", "-y", "-loglevel", "error",
        "-ss", d.start_time,
        "-t", d.duration,
        "-i", d.inpath,
        "-map", "0:v:0",
        "-map_chapters", "-1",
        "-map", "0:a:" .. ff_audio_index .. "?",
    }

    if options.encoding_type == "av1" then
        -- AV1 using libsvtav1
        table.insert(args, "-c:v")
        table.insert(args, "libsvtav1")
        table.insert(args, "-crf")
        table.insert(args, tostring(options.av1_crf or 40))
        table.insert(args, "-preset")
        table.insert(args, tostring(options.av1_preset or 6))
        table.insert(args, "-c:a")
        table.insert(args, "copy")
    elseif options.encoding_type == "h265" then
        -- H.265 using libx265
        table.insert(args, "-c:v")
        table.insert(args, "libx265")
        table.insert(args, "-vtag")
        table.insert(args, "hvc1")
        table.insert(args, "-pix_fmt")
        table.insert(args, "yuv420p")
        table.insert(args, "-crf")
        table.insert(args, tostring(options.h265_crf or 28))
        table.insert(args, "-c:a")
        table.insert(args, "copy")
    else
        -- Default to x264
        table.insert(args, "-c:v")
        table.insert(args, "libx264")
        table.insert(args, "-pix_fmt")
        table.insert(args, "yuv420p")
        table.insert(args, "-crf")
        table.insert(args, tostring(options.h264_crf or 23))
        table.insert(args, "-c:a")
        table.insert(args, "copy")
    end

    -- Output path
    table.insert(args, result_path)
    print("Saving clip...")
    mp.command_native_async({
        name = "subprocess",
        args = args,
        playback_only = false,
    }, function(success, result)
        print("Saved clip!")
        copy_to_clipboard(result_path)
    end)
end

ACTIONS.ENCODE_GPU = function(d)
    local file_extra_suffix = string.format("_FROM_%s_TO_%s (%s gpu encode)",
        d.start_time_hms, d.end_time_hms, options.encoding_type)
    local result_path = mp.utils.join_path(d.indir, string.format("%s%s.mp4", d.infile_noext, file_extra_suffix))
    if (options.save_to_directory) then result_path = check_paths(d, file_extra_suffix) end

    local selected_audio_id = mp.get_property_number("aid")
    local ff_audio_index = nil
    local count = 0
    for _, track in ipairs(mp.get_property_native("track-list") or {}) do
        if track.type == "audio" then
            if track.id == selected_audio_id then
                ff_audio_index = count
                break
            end
            count = count + 1
        end
    end
    if ff_audio_index == nil then ff_audio_index = 0 end

    local encoder, quality_args, vaapi_vf = resolve_gpu_encoder(options.encoding_type)

    local args = {
        "ffmpeg", "-nostdin", "-y", "-loglevel", "error",
        "-ss", d.start_time,
        "-t", d.duration,
        "-i", d.inpath,
        "-map", "0:v:0",
        "-map_chapters", "-1",
        "-map", "0:a:" .. ff_audio_index .. "?",
    }

    if vaapi_vf then
        table.insert(args, "-vf")
        table.insert(args, vaapi_vf)
    end
    table.insert(args, "-c:v")
    table.insert(args, encoder)
    for _, v in ipairs(quality_args) do table.insert(args, v) end
    table.insert(args, "-c:a")
    table.insert(args, "copy")
    table.insert(args, result_path)

    print("Saving clip...")
    mp.command_native_async({
        name = "subprocess",
        args = args,
        playback_only = false,
    }, function(success, result)
        print("Saved clip!")
        copy_to_clipboard(result_path)
    end)
end

ACTIONS.ENCODE_ANIMATED = function(d)
    local file_extra_suffix = string.format("_FROM_%s_TO_%s (clip)",
        d.start_time_hms, d.end_time_hms)
    local result_path = mp.utils.join_path(d.indir,
        string.format("%s.%s", d.infile_noext, options.animated_encoding_type))
    if (options.save_to_directory) then
        result_path = check_paths(d, file_extra_suffix, nil,
            "." .. options.animated_encoding_type)
    end

    local video_height = mp.get_property_number("height")

    -- Start with common args
    local args = {
        "ffmpeg", "-nostdin", "-y", "-loglevel", "error",
        "-ss", d.start_time,
        "-t", d.duration,
        "-i", d.inpath
    }

    if video_height and options.cap_resolution and video_height > options.max_animated_resolution then
        local res_line = "scale=trunc(oh*a/2)*2:" .. options.max_animated_resolution
        table.insert(args, "-vf")
        table.insert(args, res_line)
    end

    if options.animated_encoding_type == "avif" then
        -- AV1 (avif) using libsvtav1
        table.insert(args, "-c:v")
        table.insert(args, "libsvtav1")
        table.insert(args, "-crf")
        table.insert(args, tostring(options.avif_crf or 42))
        table.insert(args, "-preset")
        table.insert(args, tostring(options.av1_preset or 6))
    elseif options.animated_encoding_type == ".webp" then
        -- webp using libwebp_anim
        table.insert(args, "-c:v")
        table.insert(args, "libwebp_anim")
        table.insert(args, "-quality")
        table.insert(args, tostring(options.webp_quality or 75))
        table.insert(args, "-compression_level")
        table.insert(args, tostring(options.webp_compression_level or 6))
        table.insert(args, "-loop")
        table.insert(args, "0")
    else
        -- Default to gif
    end

    -- Output path
    table.insert(args, result_path)

    print(result_path)

    print("Saving clip...")
    mp.command_native_async({
        name = "subprocess",
        args = args,
        playback_only = false,
    }, function(success, result)
        print("Saved clip!")
        copy_to_clipboard(result_path)
    end)
end

ACTIONS.COMPRESS = function(d)
    if options.encoding_type == "av1" then options.compress_size = options.compress_size * 1.2 end
    local target_bitrate = ((options.compress_size * 8192) / d.duration * 0.9) -- Video bitrate (KB)
    mp.msg.info("Theoretical bitrate: " .. target_bitrate)

    local max_bitrate = target_bitrate
    local video_bitrate = average_bitrate
    if video_bitrate and video_bitrate ~= -1 then -- the average bitrate system is to stop small cuts from becoming too big
        max_bitrate = video_bitrate
        mp.msg.info("Average bitrate: " .. max_bitrate)
        if target_bitrate > max_bitrate then
            target_bitrate = max_bitrate
        end
    end
    if target_bitrate > 128 then
        target_bitrate = target_bitrate - 128 -- minus audio bitrate
    end
    mp.msg.info("Using bitrate: " .. target_bitrate)

    local file_extra_suffix = string.format("_FROM_%s_TO_%s (%s compress)",
        d.start_time_hms, d.end_time_hms, options.encoding_type)
    local result_path = mp.utils.join_path(d.indir, d.infile_noext .. file_extra_suffix .. ".mp4")
    if options.save_to_directory then
        result_path = check_paths(d, file_extra_suffix)
    end

    local video_height = mp.get_property_number("height")
    local selected_audio_id = mp.get_property_number("aid")
    local ff_audio_index = nil
    local count = 0
    for _, track in ipairs(mp.get_property_native("track-list") or {}) do
        if track.type == "audio" then
            if track.id == selected_audio_id then
                ff_audio_index = count
                break
            end
            count = count + 1
        end
    end
    if ff_audio_index == nil then
        ff_audio_index = 0
    end

    local args = {
        "ffmpeg", "-nostdin", "-y", "-loglevel", "error",
        "-ss", d.start_time,
        "-t", d.duration,
        "-i", d.inpath,
        "-map", "0:v:0",
        "-map_chapters", "-1",
        "-map", "0:a:" .. ff_audio_index .. "?",
    }

    if video_height and options.cap_resolution and video_height > options.max_resolution then
        local res_line = "scale=trunc(oh*a/2)*2:" .. options.max_resolution
        table.insert(args, "-vf")
        table.insert(args, res_line)
    end

    if options.encoding_type == "av1" then
        -- AV1 using libsvtav1
        table.insert(args, "-c:v")
        table.insert(args, "libsvtav1")
        table.insert(args, "-b:v")
        table.insert(args, target_bitrate .. "k")
        table.insert(args, "-svtav1-params")
        table.insert(args, "rc=1")
        table.insert(args, "-preset")
        table.insert(args, tostring(options.av1_preset or 6))
        table.insert(args, "-c:a")
        table.insert(args, "copy")
    elseif options.encoding_type == "h265" then
        -- H.265 using libx265
        table.insert(args, "-c:v")
        table.insert(args, "libx265")
        table.insert(args, "-b:v")
        table.insert(args, target_bitrate .. "k")
        table.insert(args, "-vtag")
        table.insert(args, "hvc1")
        table.insert(args, "-pix_fmt")
        table.insert(args, "yuv420p")
        table.insert(args, "-c:a")
        table.insert(args, "copy")
    else
        -- Default to x264
        table.insert(args, "-pix_fmt")
        table.insert(args, "yuv420p")
        table.insert(args, "-c:v")
        table.insert(args, "libx264")
        table.insert(args, "-b:v")
        table.insert(args, target_bitrate .. "k")
        table.insert(args, "-c:a")
        table.insert(args, "copy")
    end

    -- Output path
    table.insert(args, result_path)

    print("Saving clip...")
    mp.command_native_async({
        name = "subprocess",
        args = args,
        playback_only = false,
    }, function(success, result)
        print("Saved clip!")
        copy_to_clipboard(result_path)
    end)
end

ACTIONS.COPY = function(d)
    local file_extra_suffix = string.format("_FROM_%s_TO_%s (cut)",
        d.start_time_hms, d.end_time_hms)
    local result_path = mp.utils.join_path(d.indir, d.infile_noext .. file_extra_suffix .. d.ext)
    if options.save_to_directory then
        result_path = check_paths(d, file_extra_suffix)
    end

    -- Fast copy with accurate start (may be slightly off if not on keyframe)
    local args = {
        "ffmpeg",
        "-nostdin", "-y",
        "-loglevel", "error",
        "-i", d.inpath,
        "-ss", d.start_time, -- output seek for better accuracy
        "-t", d.duration,
        "-c", "copy",        -- fast copy
        "-map", "0:v",       -- video only
        "-map_chapters", "-1",
        "-map", "0:a?",      -- audio if exists
        "-dn",               -- drop data streams
        "-avoid_negative_ts", "make_zero",
        result_path
    }

    print("Saving clip...")
    mp.command_native_async({
        name = "subprocess",
        args = args,
        playback_only = false,
    }, function()
        print("Saved clip!")
    end)
end

RUN_WEB_CACHE = function(d)
    local command = {
        filename = check_paths(d, "(cache)", full_path_save)
    }
    command["name"] = "dump-cache"
    command["start"] = d.start_time
    command["end"] = d.end_time
    mp.command_native_async(command, function(success, result)
        print("Saved clip!")
        copy_to_clipboard(command.filename)
    end)
end

ACTION = options.action
if not ACTIONS[ACTION] then ACTION = next_table_key(ACTIONS, nil) end

START_TIME = nil

local function get_data()
    local d = {}
    d.inpath = mp.get_property("path")
    d.indir = mp.utils.split_path(d.inpath)
    d.infile = mp.get_property("filename")
    d.infile_noext = mp.get_property("filename/no-ext")
    d.ext = mp.get_property("filename"):match("^.+(%..+)$") or ".mp4"
    return d
end

local function get_times(start_time, end_time)
    local d = {}
    d.start_time = tostring(start_time)
    d.end_time = tostring(end_time)
    d.duration = tostring(end_time - start_time)
    d.start_time_hms = tostring(to_hms(start_time))
    d.end_time_hms = tostring(to_hms(end_time))
    d.duration_hms = tostring(to_hms(end_time - start_time))
    return d
end

local function seconds_to_hms(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    local ms = math.floor((seconds - math.floor(seconds)) * 1000)

    local time_string = ""
    if hours > 0 then
        time_string = string.format("%02d:%02d:%02d.%03d", hours, minutes, secs, ms)
    else
        time_string = string.format("%02d:%02d.%03d", minutes, secs, ms)
    end

    return time_string
end

local function text_overlay_on()
    print(string.format("%s from %s", ACTION, seconds_to_hms(START_TIME)))
end

local function print_or_update_text_overlay(content)
    if START_TIME then text_overlay_on() else print(content) end
end

local function cycle_action()
    ACTION = next_table_key(ACTIONS, ACTION)
    local keys = {}
    for k in pairs(ACTIONS) do keys[#keys + 1] = k end
    table.sort(keys)
    local lines = {}
    for _, k in ipairs(keys) do
        lines[#lines + 1] = (k == ACTION and "● " or "○ ") .. k
    end
    print_or_update_text_overlay(table.concat(lines, "\n"))
end

local function cycle_codec()
    local current_index = nil
    for i, codec in ipairs(options.codecs_list) do
        if codec == options.encoding_type then
            current_index = i
            break
        end
    end

    local next_index = current_index + 1
    if next_index > #options.codecs_list then
        next_index = 1
    end

    options.encoding_type = options.codecs_list[next_index]
    print_or_update_text_overlay("Encoding codec: " .. options.encoding_type)
end

local function cut(start_time, end_time)
    local d = get_data()
    local t = get_times(start_time, end_time)
    for k, v in pairs(t) do d[k] = v end
    if is_url(d.inpath) then
        if options.use_cache_for_web_videos then
            mp.msg.info("Using web cache")
            RUN_WEB_CACHE(d)
        else
            mp.msg.error("Can't cut on a web video (use_cache_for_web_videos is set to false)")
        end
    else
        ACTIONS[ACTION](d)
    end
end

local function put_time()
    local time = mp.get_property_number("time-pos")
    if not START_TIME then
        START_TIME = time
        text_overlay_on()
        return
    end
    if time > START_TIME then
        print(string.format("%s to %s", ACTION, seconds_to_hms(time)))
        cut(START_TIME, time)
        START_TIME = nil
    else
        print("Invalid selection")
        START_TIME = nil
    end
end

local function cancel_cut()
    START_TIME = nil
    print("Cleared selection")
end

mp.add_key_binding(options.key_cut, "cut", put_time)
mp.add_key_binding(options.key_cancel_cut, "cancel_cut", cancel_cut)
mp.add_key_binding(options.key_cycle_action, "cycle_action", cycle_action)
mp.add_key_binding(options.key_cycle_codec, "cycle_codec", cycle_codec)
