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

    -- Actions
    action = "ENCODE",      -- default action: ENCODE, ENCODE_ANIMATED or COMPRESS
    codecs_list = { "h264", "h265", "av1" },
    encoding_type = "h265", -- active codec: h264, h265, or av1

    -- Key bindings
    key_cut = "a",
    key_cancel_cut = "shift+a",
    key_cycle_action = "A",
    key_cycle_codec = "alt+a",
    key_cycle_encode_gpu = "alt+g",     -- toggle GPU/CPU for the ENCODE action
    key_cycle_encode_cap_res = "alt+r", -- toggle resolution cap for the ENCODE action

    -- ENCODE action defaults
    encode_gpu_default = true,     -- start with GPU encoding enabled
    encode_cap_res_default = true, -- start with resolution cap enabled
    clip_resolution = 1080,        -- target resolution (height) when resolution cap is enabled

    -- CPU encoding quality
    h264_crf = 23, -- lower = better quality
    h265_crf = 28,
    av1_crf = 40,
    av1_preset = 6, -- trade-off between speed and size, higher = faster (also used for ENCODE_ANIMATED avif)

    -- GPU encoding
    gpu_type = "auto",                    -- auto-detect, or set manually: nvenc (NVIDIA), vaapi (AMD/Intel Linux), amf (AMD), qsv (Intel), videotoolbox (macOS)
    vaapi_device = "/dev/dri/renderD128", -- render node used for vaapi (only used as a fallback if auto-detection is skipped)
    nvenc_preset = "p4",                  -- NVENC speed preset: p1 (fastest) to p7 (best quality)
    gpu_h264_cq = 25,                     -- GPU quality (CQ/QP), lower = better quality
    gpu_h265_cq = 30,
    gpu_av1_cq = 42,                      -- please check your GPU for AV1 support

    -- COMPRESS action
    compress_size = 9.50,  -- target file size in MB
    cap_resolution = true, -- shrink video if above max_resolution
    max_resolution = 1080, -- resolution cap (height) for COMPRESS

    -- ENCODE_ANIMATED action
    animated_encoding_type = "avif", -- output format: gif, webp, or avif
    max_animated_resolution = 540,   -- resolution cap (height) for ENCODE_ANIMATED
    avif_crf = 42,                   -- lower = better quality
    webp_quality = 75,               -- 0–100, higher = better quality
    webp_compression_level = 6,      -- trade-off between speed and size, lower = faster

    -- Web videos/cache
    use_cache_for_web_videos = true, -- cut web videos using the player's cache (experimental)
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


-- ffmpeg exits 1 when invoked with no args (prints usage) — any other exit means it is broken or missing
local result = mp.command_native({ name = "subprocess", args = { "ffmpeg" }, playback_only = false, capture_stdout = true, capture_stderr = true })
if result.status ~= 1 then
    mp.osd_message("FFmpeg failed to run")
end

local full_path = mp.command_native({ "expand-path", options.save_directory })
local full_path_save = ""
local web_ext = ".mkv"

local average_bitrate = -1
local avg_count = 0

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

local function get_audio_index()
    local selected_audio_id = mp.get_property_number("aid")
    local count = 0
    for _, track in ipairs(mp.get_property_native("track-list") or {}) do
        if track.type == "audio" then
            if track.id == selected_audio_id then
                return count
            end
            count = count + 1
        end
    end
    return 0
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
    avg_count = 0
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
local detected_vaapi_device = nil
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
            -- Probe the common render nodes so we know which device to hand vaapi.
            for _, node in ipairs({ "/dev/dri/renderD128", "/dev/dri/renderD129" }) do
                local rf = io.open(node, "r")
                if rf then
                    rf:close()
                    detected_gpu_type = "vaapi"
                    detected_vaapi_device = node
                    break
                end
            end
        end
    elseif platform == "darwin" then
        -- Apple Silicon and Intel Macs both expose VideoToolbox.
        detected_gpu_type = "videotoolbox"
    elseif platform == "windows" then
        -- wmic is deprecated/removed on recent Windows 11, so query via PowerShell.
        local result = mp.command_native({
            name = "subprocess",
            args = {
                "powershell", "-NoProfile", "-Command",
                "(Get-CimInstance Win32_VideoController).Name"
            },
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
        nvenc        = { h264 = "h264_nvenc", h265 = "hevc_nvenc", av1 = "av1_nvenc" },
        vaapi        = { h264 = "h264_vaapi", h265 = "hevc_vaapi", av1 = "av1_vaapi" },
        amf          = { h264 = "h264_amf", h265 = "hevc_amf", av1 = "av1_amf" },
        qsv          = { h264 = "h264_qsv", h265 = "hevc_qsv", av1 = "av1_qsv" },
        -- VideoToolbox has no AV1 encoder, so AV1 falls back to HEVC on macOS.
        videotoolbox = { h264 = "h264_videotoolbox", h265 = "hevc_videotoolbox", av1 = "hevc_videotoolbox" },
    }
    local encoder = (encoder_map[gpu] or encoder_map.nvenc)[codec_base] or "h264_nvenc"
    local quality_args = {}
    local vaapi_vf = nil
    local hw_device = nil

    if gpu == "nvenc" then
        quality_args = { "-preset", options.nvenc_preset, "-cq", tostring(cq) }
    elseif gpu == "vaapi" then
        vaapi_vf = "format=nv12,hwupload"
        hw_device = detected_vaapi_device or options.vaapi_device
        quality_args = { "-qp", tostring(cq) }
    elseif gpu == "amf" then
        quality_args = { "-rc", "cqp", "-qp_i", tostring(cq), "-qp_p", tostring(cq) }
    elseif gpu == "qsv" then
        quality_args = { "-global_quality", tostring(cq) }
    elseif gpu == "videotoolbox" then
        -- VideoToolbox uses a 0-100 quality scale where higher is better,
        -- so invert the CQ value (lower CQ -> higher q:v).
        local qv = math.max(1, math.min(100, 100 - cq))
        quality_args = { "-q:v", tostring(qv) }
        if codec_base == "av1" then
            mp.msg.warn("VideoToolbox has no AV1 encoder, using HEVC instead")
        end
    end

    if codec_base == "h265" then
        table.insert(quality_args, "-tag:v"); table.insert(quality_args, "hvc1")
    end

    return encoder, quality_args, vaapi_vf, hw_device
end

-- Build an ffmpeg arg list for a re-encode job described by spec:
--   gpu      bool        use GPU encoder (false = CPU/libx264/libx265/libsvtav1)
--   scale    number|nil  cap output height to this value (nil = no cap)
--   codec    string      "h264", "h265", or "av1"
--   audio_idx number     zero-based audio stream index
--   bitrate  string|nil  e.g. "1200k" — if set uses -b:v (for COMPRESS), else CRF/CQ
-- The output path must be appended by the caller before passing to ffmpeg.
local function build_encode_args(d, spec)
    local args = { "ffmpeg", "-nostdin", "-y", "-loglevel", "error" }

    if spec.gpu then
        local gpu = get_gpu_type()
        local encoder, quality_args, vaapi_vf, hw_device = resolve_gpu_encoder(spec.codec)

        -- hw device args must come before -i so hwupload has a device to upload to
        if hw_device then
            table.insert(args, "-vaapi_device"); table.insert(args, hw_device)
        end
        if gpu == "nvenc" then
            table.insert(args, "-hwaccel"); table.insert(args, "cuda")
            table.insert(args, "-hwaccel_output_format"); table.insert(args, "cuda")
        end

        table.insert(args, "-ss"); table.insert(args, d.start_time)
        table.insert(args, "-t"); table.insert(args, d.duration)
        table.insert(args, "-i"); table.insert(args, d.inpath)
        table.insert(args, "-map"); table.insert(args, "0:v:0")
        table.insert(args, "-map_chapters"); table.insert(args, "-1")
        table.insert(args, "-map"); table.insert(args, "0:a:" .. spec.audio_idx .. "?")

        local video_height = mp.get_property_number("height")
        local needs_scale = spec.scale and video_height and video_height > spec.scale

        if gpu == "nvenc" then
            -- Frames stay in CUDA space; scale_cuda handles resize and 10-bit→8-bit conversion
            table.insert(args, "-vf")
            table.insert(args,
                needs_scale and ("scale_cuda=-2:" .. spec.scale .. ":format=nv12") or "scale_cuda=iw:ih:format=nv12")
        elseif vaapi_vf then
            table.insert(args, "-vf")
            table.insert(args,
                needs_scale and ("scale=trunc(oh*a/2)*2:" .. spec.scale .. "," .. vaapi_vf) or vaapi_vf)
        else
            table.insert(args, "-vf")
            table.insert(args,
                needs_scale and ("scale=trunc(oh*a/2)*2:" .. spec.scale .. ",format=yuv420p") or "format=yuv420p")
        end

        table.insert(args, "-c:v"); table.insert(args, encoder)
        for _, v in ipairs(quality_args) do table.insert(args, v) end
        table.insert(args, "-c:a"); table.insert(args, "copy")
    else
        table.insert(args, "-ss"); table.insert(args, d.start_time)
        table.insert(args, "-t"); table.insert(args, d.duration)
        table.insert(args, "-i"); table.insert(args, d.inpath)
        table.insert(args, "-map"); table.insert(args, "0:v:0")
        table.insert(args, "-map_chapters"); table.insert(args, "-1")
        table.insert(args, "-map"); table.insert(args, "0:a:" .. spec.audio_idx .. "?")

        local video_height = mp.get_property_number("height")
        local vf_parts = {}
        if spec.scale and video_height and video_height > spec.scale then
            vf_parts[#vf_parts + 1] = "scale=trunc(oh*a/2)*2:" .. spec.scale
        end
        -- av1 natively handles yuv420p; h264/h265 need an explicit pixel format
        if spec.codec ~= "av1" then
            vf_parts[#vf_parts + 1] = "format=yuv420p"
        end
        if #vf_parts > 0 then
            table.insert(args, "-vf"); table.insert(args, table.concat(vf_parts, ","))
        end

        if spec.codec == "av1" then
            table.insert(args, "-c:v"); table.insert(args, "libsvtav1")
            if spec.bitrate then
                table.insert(args, "-b:v"); table.insert(args, spec.bitrate)
                table.insert(args, "-svtav1-params"); table.insert(args, "rc=1")
            else
                table.insert(args, "-crf"); table.insert(args, tostring(options.av1_crf or 40))
            end
            table.insert(args, "-preset"); table.insert(args, tostring(options.av1_preset or 6))
        elseif spec.codec == "h265" then
            table.insert(args, "-c:v"); table.insert(args, "libx265")
            table.insert(args, "-tag:v"); table.insert(args, "hvc1")
            if spec.bitrate then
                table.insert(args, "-b:v"); table.insert(args, spec.bitrate)
            else
                table.insert(args, "-crf"); table.insert(args, tostring(options.h265_crf or 28))
            end
        else
            table.insert(args, "-c:v"); table.insert(args, "libx264")
            if spec.bitrate then
                table.insert(args, "-b:v"); table.insert(args, spec.bitrate)
            else
                table.insert(args, "-crf"); table.insert(args, tostring(options.h264_crf or 23))
            end
        end
        table.insert(args, "-c:a"); table.insert(args, "copy")
    end

    return args
end

local ACTIONS = {}

-- Runtime toggles for the ENCODE action (cycled with key_cycle_encode_gpu / key_cycle_encode_cap_res)
local encode_use_gpu = options.encode_gpu_default
local encode_cap_res = options.encode_cap_res_default

ACTIONS.ENCODE = function(d)
    local mode = (encode_use_gpu and "gpu" or "cpu")
        .. (encode_cap_res and string.format(" %dp", options.clip_resolution) or "")
    local file_extra_suffix = string.format("_FROM_%s_TO_%s (%s %s)",
        d.start_time_hms, d.end_time_hms, options.encoding_type, mode)
    local result_path = mp.utils.join_path(d.indir, string.format("%s%s.mp4", d.infile_noext, file_extra_suffix))
    if options.save_to_directory then result_path = check_paths(d, file_extra_suffix) end

    local args = build_encode_args(d, {
        gpu       = encode_use_gpu,
        scale     = encode_cap_res and options.clip_resolution or nil,
        codec     = options.encoding_type,
        audio_idx = get_audio_index(),
    })
    table.insert(args, result_path)

    print("Saving clip...")
    mp.command_native_async({
        name = "subprocess",
        args = args,
        playback_only = false,
    }, function(success, result)
        if success and result.status == 0 then
            print("Saved clip!")
            copy_to_clipboard(result_path)
        else
            print("Encoding failed!")
        end
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
    elseif options.animated_encoding_type == "webp" then
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

    print("Saving clip...")
    mp.command_native_async({
        name = "subprocess",
        args = args,
        playback_only = false,
    }, function(success, result)
        if success and result.status == 0 then
            print("Saved clip!")
            copy_to_clipboard(result_path)
        else
            print("Encoding failed!")
        end
    end)
end

ACTIONS.COMPRESS = function(d)
    local compress_size = options.compress_size
    if options.encoding_type == "av1" then compress_size = compress_size * 1.2 end
    local target_bitrate = ((compress_size * 8192) / d.duration * 0.9) -- Video bitrate (KB)
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

    local args = build_encode_args(d, {
        gpu       = false,
        scale     = options.cap_resolution and options.max_resolution or nil,
        codec     = options.encoding_type,
        audio_idx = get_audio_index(),
        bitrate   = target_bitrate .. "k",
    })
    table.insert(args, result_path)

    print("Saving clip...")
    mp.command_native_async({
        name = "subprocess",
        args = args,
        playback_only = false,
    }, function(success, result)
        if success and result.status == 0 then
            print("Saved clip!")
            copy_to_clipboard(result_path)
        else
            print("Encoding failed!")
        end
    end)
end

-- ACTIONS.COPY = function(d)
--     local file_extra_suffix = string.format("_FROM_%s_TO_%s (cut)",
--         d.start_time_hms, d.end_time_hms)
--     local result_path = mp.utils.join_path(d.indir, d.infile_noext .. file_extra_suffix .. d.ext)
--     if options.save_to_directory then
--         result_path = check_paths(d, file_extra_suffix)
--     end
--
--     -- Fast copy: input-side seek so FFmpeg doesn't decode from the start
--     local args = {
--         "ffmpeg",
--         "-nostdin", "-y",
--         "-loglevel", "error",
--         "-ss", d.start_time,
--         "-i", d.inpath,
--         "-t", d.duration,
--         "-c", "copy",   -- fast copy
--         "-map", "0:v",  -- video only
--         "-map_chapters", "-1",
--         "-map", "0:a?", -- audio if exists
--         "-dn",          -- drop data streams
--         "-avoid_negative_ts", "make_zero",
--         result_path
--     }
--
--     print("Saving clip...")
--     mp.command_native_async({
--         name = "subprocess",
--         args = args,
--         playback_only = false,
--     }, function(success, result)
--         if success and result.status == 0 then
--             print("Saved clip!")
--         else
--             print("Copy failed!")
--         end
--     end)
-- end

local RUN_WEB_CACHE = function(d)
    local command = {
        filename = check_paths(d, "(cache)", full_path_save)
    }
    command["name"] = "dump-cache"
    command["start"] = d.start_time
    command["end"] = d.end_time
    mp.command_native_async(command, function(success, result)
        if success then
            print("Saved clip!")
            copy_to_clipboard(command.filename)
        else
            print("Cache dump failed!")
        end
    end)
end

local ACTION = options.action
if not ACTIONS[ACTION] then ACTION = next_table_key(ACTIONS, nil) end

local START_TIME = nil

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
        local label = k
        if k == "ENCODE" then
            label = string.format("ENCODE (GPU %s, RES CAP %s)",
                encode_use_gpu and "on" or "off",
                encode_cap_res and "on" or "off")
        end
        lines[#lines + 1] = (k == ACTION and "● " or "○ ") .. label
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

    local next_index = (current_index or 0) + 1
    if next_index > #options.codecs_list then
        next_index = 1
    end

    options.encoding_type = options.codecs_list[next_index]
    print_or_update_text_overlay("Encoding codec: " .. options.encoding_type)
end

local function cycle_encode_gpu()
    encode_use_gpu = not encode_use_gpu
    print_or_update_text_overlay("GPU encode: " .. (encode_use_gpu and "on" or "off"))
end

local function cycle_encode_cap_res()
    encode_cap_res = not encode_cap_res
    print_or_update_text_overlay("Cap resolution: " .. (encode_cap_res and (options.clip_resolution .. "p") or "off"))
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
mp.add_key_binding(options.key_cycle_encode_gpu, "cycle_encode_gpu", cycle_encode_gpu)
mp.add_key_binding(options.key_cycle_encode_cap_res, "cycle_encode_cap_res", cycle_encode_cap_res)
