--[[
    mpvcrop.lua by zydezu
	(https://github.com/zydezu/mpvconfig/blob/main/scripts/mpvcrop.lua)

    Interactively select a crop region on the video (move the mouse, tap a key
    twice to drop opposite corners) and re-encode it
--]]

mp.msg = require("mp.msg")
mp.utils = require("mp.utils")
mp.assdraw = require("mp.assdraw")

local options = {
    -- Save location
    save_to_directory = true,                -- save to 'save_directory' instead of the current folder of the file
    save_directory = "~/Pictures/mpv/clips", -- required for web videos
    save_to_title_directory = true,          -- save to subdirectory named after the video title

    -- Key bindings
    key_toggle_crop = "v",   -- enter crop mode; while active, also drops a corner at the mouse position
    key_cancel_crop = "shift+v", -- exit crop mode / cancel the in-progress selection
    key_cycle_codec = "alt+x",
    key_cycle_gpu = "alt+c", -- toggle GPU/CPU encoding

    -- Encode target
    codecs_list = { "h264", "h265", "av1" }, -- list of codecs to cycle through
    encoding_type = "h265",                  -- active codec: h264, h265, or av1
    gpu_default = true,                      -- start with GPU encoding enabled
    min_crop_size = 20,                      -- minimum crop width/height, in source pixels

    -- Optional resolution cap applied after cropping
    cap_resolution = false,
    max_resolution = 1080, -- resolution cap (height) if cap_resolution is enabled

    -- CPU encoding quality
    h264_crf = 23, -- lower crf = better quality
    h265_crf = 28,
    av1_crf = 40,
    av1_preset = 6, -- trade-off between speed and size, higher = faster

    -- GPU encoding
    gpu_type = "auto",                    -- auto-detect, or set manually: nvenc (NVIDIA), vaapi (AMD/Intel Linux), amf (AMD), qsv (Intel), videotoolbox (macOS)
    vaapi_device = "/dev/dri/renderD128", -- render node used for vaapi (only used as a fallback if auto-detection is skipped)
    nvenc_preset = "p4",                  -- NVENC speed preset: p1 (fastest) to p7 (best quality)
    gpu_h264_cq = 25,                     -- GPU quality (CQ/QP), lower = better quality
    gpu_h265_cq = 30,
    gpu_av1_cq = 42,                      -- please check your GPU for AV1 support
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
        local uri = "file:///" .. filepath:gsub("\\", "/"):gsub(" ", "%%20")
        cmd = {
            "powershell", "-NoProfile", "-Command",
            string.format("Set-Clipboard -Value '%s'", uri:gsub("'", "''"))
        }
    elseif platform == "darwin" then
        cmd = {
            "osascript", "-e",
            string.format("set the clipboard to (POSIX file %q)", filepath)
        }
    else
        if os.getenv("WAYLAND_DISPLAY") then
            cmd = {
                "sh", "-c",
                string.format("printf 'file://%s' | wl-copy --type text/uri-list", filepath)
            }
        else
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
local ffmpeg_check = mp.command_native({ name = "subprocess", args = { "ffmpeg" }, playback_only = false, capture_stdout = true, capture_stderr = true })
if ffmpeg_check.status ~= 1 then
    mp.osd_message("FFmpeg failed to run")
end

-- Crop UI state
local crop_active = false
local selection_v = nil -- {x0,y0,x1,y1} in source video pixel coords
local corner1_v = nil   -- {x,y} in source video pixel coords, set once the first corner is dropped
local cursor_v = nil    -- {x,y} in source video pixel coords, live mouse position
local encode_use_gpu = options.gpu_default
local overlay = mp.create_osd_overlay("ass-events")

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
        detected_gpu_type = "videotoolbox"
    elseif platform == "windows" then
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

-- Crop happens on software frames (no hwaccel decode), so only the encoder needs GPU-specific args
local function resolve_gpu_encoder(codec_base)
    local gpu = get_gpu_type()
    local cq_map = { h264 = options.gpu_h264_cq, h265 = options.gpu_h265_cq, av1 = options.gpu_av1_cq }
    local cq = cq_map[codec_base] or 28
    local encoder_map = {
        nvenc        = { h264 = "h264_nvenc", h265 = "hevc_nvenc", av1 = "av1_nvenc" },
        vaapi        = { h264 = "h264_vaapi", h265 = "hevc_vaapi", av1 = "av1_vaapi" },
        amf          = { h264 = "h264_amf", h265 = "hevc_amf", av1 = "av1_amf" },
        qsv          = { h264 = "h264_qsv", h265 = "hevc_qsv", av1 = "av1_qsv" },
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

local function create_folder(path)
    local args
    if package.config:sub(1, 1) == '\\' then
        local win_path = path:gsub("/", "\\")
        args = { "cmd", "/c", "mkdir", win_path }
    else
        args = { "mkdir", "-p", path }
    end

    local res = mp.utils.subprocess({ args = args })
    if res.status == 0 then
        mp.msg.info("Successfully created folder: " .. path)
    else
        mp.msg.error("Failed to create folder: " .. path)
    end
end

local function get_output_dir(d)
    if not options.save_to_directory then return d.indir end
    if options.save_to_title_directory then
        return mp.command_native({ "expand-path", options.save_directory .. "/" .. sanitize_filename(d.infile_noext) })
    end
    return mp.command_native({ "expand-path", options.save_directory })
end

local function check_paths(d, suffix)
    local out_dir = get_output_dir(d)
    if mp.utils.readdir(out_dir) == nil then
        create_folder(out_dir)
    end
    return mp.utils.join_path(out_dir .. "/", d.infile_noext .. suffix .. ".mp4")
end

local function get_data()
    local d = {}
    d.inpath = mp.get_property("path")
    d.indir = mp.utils.split_path(d.inpath)
    d.infile = mp.get_property("filename")
    d.infile_noext = mp.get_property("filename/no-ext")
    return d
end

-- Builds an ffmpeg arg list for a whole-file crop + re-encode described by spec:
--   gpu       bool        use GPU encoder (false = CPU/libx264/libx265/libsvtav1)
--   codec     string      "h264", "h265", or "av1"
--   audio_idx number      zero-based audio stream index
--   crop      string      the "crop=w:h:x:y" filter
--   scale     number|nil  cap output height to this value (nil = no cap)
-- The output path must be appended by the caller before passing to ffmpeg.
local function build_encode_args(d, spec)
    local args = { "ffmpeg", "-nostdin", "-y", "-loglevel", "error" }

    local encoder, quality_args, vaapi_vf, hw_device
    if spec.gpu then
        encoder, quality_args, vaapi_vf, hw_device = resolve_gpu_encoder(spec.codec)
        if hw_device then
            table.insert(args, "-vaapi_device"); table.insert(args, hw_device)
        end
    end

    table.insert(args, "-i"); table.insert(args, d.inpath)
    table.insert(args, "-map"); table.insert(args, "0:v:0")
    table.insert(args, "-map_chapters"); table.insert(args, "-1")
    table.insert(args, "-map"); table.insert(args, "0:a:" .. spec.audio_idx .. "?")

    local vf_parts = { spec.crop }
    if spec.scale then
        vf_parts[#vf_parts + 1] = "scale=trunc(oh*a/2)*2:" .. spec.scale
    end

    if spec.gpu then
        vf_parts[#vf_parts + 1] = vaapi_vf or "format=nv12"
        table.insert(args, "-vf"); table.insert(args, table.concat(vf_parts, ","))
        table.insert(args, "-c:v"); table.insert(args, encoder)
        for _, v in ipairs(quality_args) do table.insert(args, v) end
    else
        if spec.codec ~= "av1" then
            vf_parts[#vf_parts + 1] = "format=yuv420p"
        end
        table.insert(args, "-vf"); table.insert(args, table.concat(vf_parts, ","))

        if spec.codec == "av1" then
            table.insert(args, "-c:v"); table.insert(args, "libsvtav1")
            table.insert(args, "-crf"); table.insert(args, tostring(options.av1_crf or 40))
            table.insert(args, "-preset"); table.insert(args, tostring(options.av1_preset or 6))
        elseif spec.codec == "h265" then
            table.insert(args, "-c:v"); table.insert(args, "libx265")
            table.insert(args, "-tag:v"); table.insert(args, "hvc1")
            table.insert(args, "-crf"); table.insert(args, tostring(options.h265_crf or 28))
        else
            table.insert(args, "-c:v"); table.insert(args, "libx264")
            table.insert(args, "-crf"); table.insert(args, tostring(options.h264_crf or 23))
        end
    end

    table.insert(args, "-c:a"); table.insert(args, "copy")
    return args
end

local function run_crop_encode(x, y, w, h)
    local d = get_data()
    if not d.inpath or is_url(d.inpath) then
        print("Cropping only works on local files")
        return
    end

    local mode = (encode_use_gpu and "gpu" or "cpu")
        .. (options.cap_resolution and string.format(" %dp", options.max_resolution) or "")
    local suffix = string.format("_CROP_%dx%d+%d+%d (%s %s)", w, h, x, y, options.encoding_type, mode)
    local result_path = mp.utils.join_path(d.indir, d.infile_noext .. suffix .. ".mp4")
    if options.save_to_directory then
        result_path = check_paths(d, suffix)
    end

    local args = build_encode_args(d, {
        gpu       = encode_use_gpu,
        codec     = options.encoding_type,
        audio_idx = get_audio_index(),
        crop      = string.format("crop=%d:%d:%d:%d", w, h, x, y),
        scale     = options.cap_resolution and options.max_resolution or nil,
    })
    table.insert(args, result_path)

    print("Cropping and encoding...")
    mp.command_native_async({
        name = "subprocess",
        args = args,
        playback_only = false,
    }, function(success, result)
        if success and result.status == 0 then
            print("Saved cropped video!")
            copy_to_clipboard(result_path)
        else
            print("Crop encoding failed!")
        end
    end)
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function get_video_dims()
    return mp.get_property_number("width"), mp.get_property_number("height")
end

-- source pixel coords -> OSD pixel coords (accounting for the black bars mpv reports via osd-dimensions)
local function video_to_osd(vx, vy, dim, vw, vh)
    local disp_w = dim.w - dim.ml - dim.mr
    local disp_h = dim.h - dim.mt - dim.mb
    return dim.ml + (vx / vw) * disp_w, dim.mt + (vy / vh) * disp_h
end

local function osd_to_video(ox, oy, dim, vw, vh)
    local disp_w = dim.w - dim.ml - dim.mr
    local disp_h = dim.h - dim.mt - dim.mb
    if disp_w <= 0 or disp_h <= 0 then return 0, 0 end
    local vx = (ox - dim.ml) / disp_w * vw
    local vy = (oy - dim.mt) / disp_h * vh
    return clamp(vx, 0, vw), clamp(vy, 0, vh)
end

local function render()
    if not crop_active then return end
    local dim = mp.get_property_native("osd-dimensions")
    local vw, vh = get_video_dims()
    if not dim or not vw or not vh or dim.w <= 0 or dim.h <= 0 then return end

    local ass = mp.assdraw.ass_new()

    local function shape(tags, fn)
        ass:new_event()
        ass:an(7)
        ass:pos(0, 0)
        ass:append("{\\bord0\\shad0" .. tags .. "}")
        ass:draw_start()
        fn()
        ass:draw_stop()
    end

    local sel
    if selection_v then
        local x0, y0 = video_to_osd(selection_v.x0, selection_v.y0, dim, vw, vh)
        local x1, y1 = video_to_osd(selection_v.x1, selection_v.y1, dim, vw, vh)
        sel = { x0 = math.min(x0, x1), y0 = math.min(y0, y1), x1 = math.max(x0, x1), y1 = math.max(y0, y1) }
    end

    if sel then
        shape("\\c&H000000&\\alpha&H80&", function()
            ass:rect_cw(0, 0, dim.w, sel.y0)
            ass:rect_cw(0, sel.y1, dim.w, dim.h)
            ass:rect_cw(0, sel.y0, sel.x0, sel.y1)
            ass:rect_cw(sel.x1, sel.y0, dim.w, sel.y1)
        end)
        local b = 2
        shape("\\c&H00D7FF&\\alpha&H00&", function()
            ass:rect_cw(sel.x0, sel.y0, sel.x1, sel.y0 + b)
            ass:rect_cw(sel.x0, sel.y1 - b, sel.x1, sel.y1)
            ass:rect_cw(sel.x0, sel.y0, sel.x0 + b, sel.y1)
            ass:rect_cw(sel.x1 - b, sel.y0, sel.x1, sel.y1)
        end)
    else
        shape("\\c&H000000&\\alpha&H80&", function()
            ass:rect_cw(0, 0, dim.w, dim.h)
        end)
        if cursor_v then
            local cx, cy = video_to_osd(cursor_v.x, cursor_v.y, dim, vw, vh)
            local r = 5
            shape("\\c&H00D7FF&\\alpha&H00&", function()
                ass:rect_cw(cx - r, cy - 1, cx + r, cy + 1)
                ass:rect_cw(cx - 1, cy - r, cx + 1, cy + r)
            end)
        end
    end

    local fs = math.max(14, math.floor(dim.h / 45))
    local step_hint = corner1_v and "move to the opposite corner, then press " .. options.key_toggle_crop .. " again"
        or "move the mouse, then press " .. options.key_toggle_crop .. " to drop the first corner"
    ass:new_event()
    ass:an(7)
    ass:pos(16, 16)
    ass:append(string.format(
        "{\\bord2\\shad0\\c&HFFFFFF&\\3c&H000000&\\fs%d}CROP MODE - %s\\N%s: cancel   %s: codec (%s)   %s: gpu (%s)",
        fs, step_hint, options.key_cancel_crop, options.key_cycle_codec, options.encoding_type,
        options.key_cycle_gpu, encode_use_gpu and "on" or "off"))

    if sel then
        local w = math.floor((selection_v.x1 - selection_v.x0) / 2) * 2
        local h = math.floor((selection_v.y1 - selection_v.y0) / 2) * 2
        local vx = math.floor(math.min(selection_v.x0, selection_v.x1))
        local vy = math.floor(math.min(selection_v.y0, selection_v.y1))
        local label_x, label_y, an
        if sel.y0 - fs - 8 < 0 then
            label_x, label_y, an = sel.x0 + 4, sel.y0 + 4, 7
        else
            label_x, label_y, an = sel.x0, sel.y0 - 4, 1
        end
        ass:new_event()
        ass:an(an)
        ass:pos(label_x, label_y)
        ass:append(string.format("{\\bord2\\shad0\\c&H00D7FF&\\3c&H000000&\\fs%d}%dx%d @ (%d,%d)", fs, w, h, vx, vy))
    end

    overlay.data = ass.text
    overlay.res_x = dim.w
    overlay.res_y = dim.h
    overlay:update()
end

local function cycle_codec()
    local idx
    for i, c in ipairs(options.codecs_list) do
        if c == options.encoding_type then
            idx = i; break
        end
    end
    idx = (idx or 0) + 1
    if idx > #options.codecs_list then idx = 1 end
    options.encoding_type = options.codecs_list[idx]
    print("Encoding codec: " .. options.encoding_type)
    render()
end

local function cycle_gpu()
    encode_use_gpu = not encode_use_gpu
    print("GPU encode: " .. (encode_use_gpu and "on" or "off"))
    render()
end

local function finalize_selection()
    local s = selection_v
    local x0, x1 = math.min(s.x0, s.x1), math.max(s.x0, s.x1)
    local y0, y1 = math.min(s.y0, s.y1), math.max(s.y0, s.y1)
    if (x1 - x0) < options.min_crop_size or (y1 - y0) < options.min_crop_size then
        selection_v = nil
        return
    end
    selection_v = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

-- Tracks the mouse via the read-only mouse-pos property instead of the MOUSE_MOVE/MBTN_LEFT
-- key bindings: the OSC (modernx) already claims those keys for its own drag/click handling,
-- and mpv only delivers a key event to whichever script's binding wins that contest.
local function on_mouse_pos_change(_, pos)
    if not crop_active or not pos or not pos.hover then return end
    local dim = mp.get_property_native("osd-dimensions")
    local vw, vh = get_video_dims()
    if not dim or not vw or not vh then return end
    local vx, vy = osd_to_video(pos.x, pos.y, dim, vw, vh)
    cursor_v = { x = vx, y = vy }
    if corner1_v then
        selection_v = { x0 = corner1_v.x, y0 = corner1_v.y, x1 = vx, y1 = vy }
    end
    render()
end

local function exit_crop_mode()
    if not crop_active then return end
    crop_active = false
    selection_v = nil
    corner1_v = nil
    cursor_v = nil
    mp.unobserve_property(on_mouse_pos_change)
    overlay:remove()
end

local function drop_corner()
    if not corner1_v then
        if not cursor_v then return end
        corner1_v = { x = cursor_v.x, y = cursor_v.y }
        selection_v = { x0 = corner1_v.x, y0 = corner1_v.y, x1 = corner1_v.x, y1 = corner1_v.y }
        render()
        return
    end

    finalize_selection()
    if not selection_v then
        print("Selection too small")
        corner1_v = nil
        render()
        return
    end

    local vw, vh = get_video_dims()
    local x = math.floor(selection_v.x0)
    local y = math.floor(selection_v.y0)
    local w = clamp(math.floor((selection_v.x1 - selection_v.x0) / 2) * 2, 2, vw - x)
    local h = clamp(math.floor((selection_v.y1 - selection_v.y0) / 2) * 2, 2, vh - y)

    exit_crop_mode()
    run_crop_encode(x, y, w, h)
end

local function enter_crop_mode()
    if crop_active then return end
    crop_active = true
    selection_v = nil
    corner1_v = nil
    cursor_v = nil
    mp.observe_property("mouse-pos", "native", on_mouse_pos_change)
    render()
end

local function toggle_or_drop_corner()
    if crop_active then
        drop_corner()
        return
    end
    local path = mp.get_property("path")
    if not path or is_url(path) then
        print("Cropping only works on local files")
        return
    end
    enter_crop_mode()
end

mp.observe_property("osd-dimensions", "native", function()
    if crop_active then render() end
end)

mp.add_key_binding(options.key_toggle_crop, "toggle_or_drop_corner", toggle_or_drop_corner)
mp.add_key_binding(options.key_cancel_crop, "cancel_crop", exit_crop_mode)
mp.add_key_binding(options.key_cycle_codec, "cycle_codec", cycle_codec)
mp.add_key_binding(options.key_cycle_gpu, "cycle_gpu", cycle_gpu)
