local function check_pixel_format()
    local video_params = mp.get_property_native("video-params")
    if video_params and video_params["hw-pixelformat"] == "p010" then
        mp.set_property("hwdec", "no")
    end
    mp.msg.info("Detected p010 format — disabling hardware decoding")
end

mp.register_event("video-reconfig", check_pixel_format)