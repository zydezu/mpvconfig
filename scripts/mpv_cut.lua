---@diagnostic disable: lowercase-global, undefined-global

msg = require("mp.msg")
utils = require("mp.utils")

-- #region globals
local settings = {
    key_mark_cut = "c",
    video_extension = "mp4",
    custom_output_path = "",

    -- if you want faster cutting, leave this blank
    ffmpeg_custom_parameters = "",

    web = {
        -- small file settings
        key_mark_cut = "shift+c",

        audio_target_bitrate = 128, -- kbps
        video_target_file_size = 7.50,  -- mb, keeping this less than 8 since the process is not perfectly accurate.
        video_target_scale = "1280:-1" -- https://trac.ffmpeg.org/wiki/Scaling everthing after "scale=" will be considered, keep "original" for no changes to the scaling
    }
}

local vars = {
    path = nil,
    filename = nil,
    only_filename = nil,

    is_web_mark_pos = nil,

    pos = {
        start_pos = nil,
        end_pos = nil,

        cut_duration = nil
    }
}
-- #endregion

-- #region utils
function str_split(input, separator)
    if not separator then
        separator = "%s"
    end

    local t = {}
    for str in string.gmatch(input, "([^" .. separator .. "]+)") do
        table.insert(t, str)
    end

    return t
end

function to_timestamp(time)
    local hrs = time / 3600
    local mins = (time % 3600) / 60
    local secs = time % 60

    return string.format("%02d:%02d:%02d.%02d", math.floor(hrs), math.floor(mins), math.floor(secs), (time % 1) * 1000)
end

function reset_pos()
    vars.pos.start_pos = nil
    vars.pos.end_pos = nil
end

function exec_native(args)
    log(msg.info, string.format("Executing command: %s", table.concat(args, " ")))

    local ret = mp.command_native({
        name = "subprocess",
        args = args,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false
    })

    log(msg.info, string.format("Finished executing %s.", args[1]))

    return ret.status, ret.stdout, ret.stderr
end

function exec_async(args)
    log(msg.info, string.format("Executing command: %s", table.concat(args, " ")))

    local ret_val = false
    mp.command_native_async({
        name = "subprocess",
        args = args,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false
    }, function(res, val, err)
        if val.status > 0 then
            local err = val.stderr:gsub("^%s*(.-)%s*$", "%1")
            log(msg.error, err, nil, err)
            ret_val = false
        else
            log(msg.info, string.format("Finished executing %s.", args[1]))
            ret_val = true
        end
    end)

    return ret_val
end

function log(type, fmt, delay, log_msg)
    if delay and delay > 0 then
        mp.osd_message(fmt, delay)
    end

    if log_msg then
        local file_object = io.open("mpv-cut.log", 'a')

        if not file_object then
            log(msg.error, "Unable to open file for appending!")
            return
        end

        file_object:write(log_msg .. '\n')
        file_object:close()
    end

    type(fmt)
end
-- #endregion

-- #region main
function ffmpeg_cut(time_start, time_end, input_file, output_file)
    if string.len(settings.ffmpeg_custom_parameters) > 0 and not vars.is_web_mark_pos then
        -- Best way I figured
        ffmpeg_custom_arguments = {}
        for substr in settings.ffmpeg_custom_parameters:gmatch("%S+") do
            table.insert(ffmpeg_custom_arguments, substr)
        end

        local arr_start = {"ffmpeg", "-async", "1", "-y", "-i", input_file}
        for _, value in pairs(ffmpeg_custom_arguments) do
            table.insert(arr_start, value)
        end

        local arr_end = {"-ss", time_start, "-to", time_end, output_file}
        for _, value in pairs(arr_end) do
            table.insert(arr_start, value)
        end

        local status, stdout, stderr = exec_native(arr_start)
        if status > 0 then
            stderr = stderr:gsub("^%s*(.-)%s*$", "%1")
            log(msg.error, stderr, nil, stderr)
            return false
        end

        return true
    end

    local status, stdout, stderr = exec_native({"ffmpeg", "-async", "1", "-y", "-ss", time_start, "-to", time_end, "-i", input_file, "-c:v", "copy", "-c:a", "aac", "-b:a", "320k", output_file})
    if status > 0 then
        stderr = stderr:gsub("^%s*(.-)%s*$", "%1")
        log(msg.error, stderr, nil, stderr)
        return false
    end

    return true
end

function ffmpeg_resize(input_file, output_file)
    local cut_duration = math.abs(math.floor(vars.pos.cut_duration))
    log(msg.info, string.format("Cut duration: %s", cut_duration))

    local target_bitrate = (settings.web.video_target_file_size * 8192) / cut_duration -- Video bitrate
    target_bitrate = target_bitrate - settings.web.audio_target_bitrate -- Audio bitrate

    if target_bitrate < 0 then
        log(msg.error, "Target video bitrate is lower than 0!", 10)
        return false
    end

    local formatted_target_bitrate = string.format("%sk", math.floor(target_bitrate))
    log(msg.info, string.format("Target video bitrate: %s", formatted_target_bitrate))

    local vf, video_target_scale = "-vf", "scale=iw:ih"
    if settings.web.video_target_scale ~= "original" then
        video_target_scale = string.format("scale=%s", settings.web.video_target_scale)
    end

    -- Double pass from https://trac.ffmpeg.org/wiki/Encode/H.264#twopass
    local status, stdout, stderr = exec_native({"ffmpeg", "-async", "1", "-y", "-i", input_file, "-c:v", "libx264", vf, video_target_scale, "-b:v", formatted_target_bitrate, "-pass", "1", "-an", "-f", "rawvideo", "NUL"})
    if status > 0 then
        stderr = stderr:gsub("^%s*(.-)%s*$", "%1")
        log(msg.error, stderr, nil, stderr)
        return false
    end

    status, stdout, stderr = exec_native({"ffmpeg", "-async", "1", "-y", "-i", input_file, "-c:v", "libx264", vf, video_target_scale, "-b:v", formatted_target_bitrate, "-pass", "2", "-c:a", "aac", "-b:a", string.format("%sk", settings.web.audio_target_bitrate), output_file})
    if status > 0 then
        stderr = stderr:gsub("^%s*(.-)%s*$", "%1")
        log(msg.error, stderr, nil, stderr)
        return false
    end

    return true
end

function web_mark_pos()
    vars.is_web_mark_pos = true
    mark_pos(vars.is_web_mark_pos)
end

function mark_pos(is_web)
    local current_pos = mp.get_property_number("time-pos")

    msg.info(current_pos)

    if not vars.pos.start_pos then
        vars.pos.start_pos = current_pos
        log(msg.info, string.format("Marked %s as start position", to_timestamp(current_pos)), 3)
        return
    end

    vars.pos.end_pos = current_pos

    if vars.pos.start_pos >= vars.pos.end_pos then
        log(msg.error, "Invalid time selected!", 3)
        reset_pos()
        return
    end

    vars.pos.cut_duration = vars.pos.start_pos - vars.pos.end_pos

    log(msg.info, string.format("Marked %s as end position", to_timestamp(current_pos)), 3)

    local output_name = ""
    if string.len(settings.custom_output_path) > 0 then 
	    output_name = string.format("%s\\%s cut.%s", settings.custom_output_path, vars.only_filename:gsub("%" .. string.format(".%s", settings.video_extension), ""), settings.video_extension)
    else 
	    output_name = string.format("%s cut.%s", vars.only_filename:gsub("%" .. string.format(".%s", settings.video_extension), ""), settings.video_extension)
    end

    -- Cut
    if not ffmpeg_cut(to_timestamp(vars.pos.start_pos), to_timestamp(vars.pos.end_pos), vars.path, output_name) then
        log(msg.error, "Failed to execute ffmpeg! Check log for details.", 10)
        reset_pos()
        return
    end

    -- Resize video
    if is_web then
	    local output_name_resized = ""
	    if string.len(settings.custom_output_path) > 0 then 
		    output_name_resized = string.format("%s\\%s cutr.%s", settings.custom_output_path, vars.only_filename:gsub("%" .. string.format(".%s", settings.video_extension), ""), settings.video_extension)
	    else 
		    output_name_resized = string.format("%s cutr.%s", vars.only_filename:gsub("%" .. string.format(".%s", settings.video_extension), ""), settings.video_extension)
	    end

        log(msg.info, "Encoding started, please do not close", 10)

        if not ffmpeg_resize(output_name, output_name_resized) then
            log(msg.error, "Failed to execute ffmpeg on resizing! Check log for details.", 10)
            reset_pos()
            return
        end

        -- Find a better way to do this
        local status, err_msg = os.remove(output_name)
        if not status then
            log(msg.error, string.format("Failed to delete: %s!", err_msg))
        end

        status, err_msg = os.remove("ffmpeg2pass-0.log")
        if not status then
            log(msg.error, string.format("Failed to delete: %s!", err_msg))
        end

        status, err_msg = os.remove("ffmpeg2pass-0.log.mbtree")
        if not status then
            log(msg.error, string.format("Failed to delete: %s!", err_msg))
        end

        log(msg.info, string.format("Saved as %s", output_name_resized), 10)

        reset_pos()
        mp.set_property("keep-open", "no")
        vars.is_web_mark_pos = false

        return
    end

    -- Reset vars
    reset_pos()
    mp.set_property("keep-open", "no")

    log(msg.info, string.format("Saved as %s", output_name), 10)

end
-- #endregion

-- #region events
mp.register_event("file-loaded", function()
    local only_filename = mp.get_property("filename")
    local path = mp.get_property("path")
    local _, filename = utils.split_path(path)

    mp.set_property("keep-open", "always")

    -- Populate variables
    vars.path, vars.filename, vars.only_filename = path, filename, only_filename
end)

mp.add_key_binding(settings.key_mark_cut, "mark_pos", mark_pos)
mp.add_key_binding(settings.web.key_mark_cut, "web_mark_pos", web_mark_pos)
-- #endregion
