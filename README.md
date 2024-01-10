# mpvconfig
![2023-12-09_12-28-51_412_mpv](https://github.com/zydezu/mpvconfig/assets/50119098/0a96511e-0a42-4f6d-b5f7-23a40ec6020f)

My personal [mpv](https://mpv.io/) config.

> [!NOTE]
> Releases of the [modernX](https://github.com/zydezu/modernX) script are in a seperate repository - see here [https://github.com/zydezu/ModernX/releases](https://github.com/zydezu/ModernX/releases).

# Usage
Use `git clone https://github.com/zydezu/mpvconfig mpv`, and place it in the relevant directory. This will be typically located at `\%APPDATA%\mpv\` on Windows and `~/.config/mpv/` on Linux/MacOS. 

See the [Files section](https://mpv.io/manual/master/#files) in mpv's manual for more information.

# Scripts and Associated Keybinds

Please note that many of these scripts have been slightly modified from their initial repositories. Compare the scripts to find the modifications.

| Script and description | Keybinds |
| -------------- | --------------- |
| [autoload](https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua) loads files in the directory to play through | None |
| [autoloop](https://github.com/zc62/mpv-scripts/blob/master/autoloop.lua) loops files by default that are smaller than a set duration | None |
| [modernx](https://github.com/zydezu/modernx) an modern OSC for mpv with many additional features | **x** - Cycle through audio tracks <br>**c** - Cycle through subtitle tracks <br>**P** - Pin or unpin the window <br>**TAB** - Show chapter list <br> For more: [Check repository](https://github.com/zydezu/modernx#buttons) |
| [mpvcut]([https://github.com/b1scoito/mpv-cut](https://github.com/familyfriendlymikey/mpv-cut)) allows clipping a segment of a video | **z** - Mark start segment <br> **z (again)** - Clip the video <br> **shift+z** - Cancel the clip <br> **a** - Change mode (copy, encode, compress) |
| [qualitymenu](https://github.com/christoph-heinrich/mpv-quality-menu) allows you to select the quality of a YouTube video playing in mpv. | **f** - Open video quality menu <br> **Alt+f** - Open audio quality menu <br> **Arrows and Enter** - Navigate options and confirm a selection <br> **Esc** - Exit menu |
| [screenshotfolder](https://github.com/zydezu/mpvconfig/blob/main/scripts/screenshotfolder.lua) saves screenshots to a designated `~desktop/mpv/.../` folder | **s** - Take a screenshot |
| [SmartCopyPaste](https://github.com/Eisa01/mpv-scripts#smartcopypaste) allows various files and links to be pasted into mpv | **Ctrl+v** - Paste |
| [sponsorblock](https://github.com/po5/mpv_sponsorblock) skips sponsored segments of YouTube videos | **g** - Set segment boundaires <br> **Shift+g** - Submit a segment <br> **h** - Upvote last segment <br> **Shift+h** - Downvote last segment                      |
| [thumbfast](https://github.com/po5/thumbfast) show thumbnails on the scrubbing bar | None |
| [locatefile.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/locatefile.lua) opens the file in an explorer or a web browser | **o** - Open file |
| [shadertoggle.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/shadertoggle.lua) loads shaders found in a folder of choice and toggles through them | **Ctrl+s** - Switch shaders |
| [input.conf](https://github.com/zydezu/mpvconfig/blob/main/input.conf) an input configuration file | **-** - Decrease subtitle font size <br> **+** - Increase subtitle font size <br> **Scroll wheel** - Change volume |


# Updates

### 2024-01-10

- Added the ability to choose a directory to save clips in (required for web video cache saving), using `savedirectory`
- Implemented saving clips from web videos, using the cache in [mpvcut.lua](https://github.com/zydezu/mpvconfig/commit/edf7b9d88e90d67922330d6f03d70628b30f22af#diff-8f6436b607b063cf868ffaef66bebbcc6cec22b62894400dad687c4caf54df1c) based off [https://github.com/Sagnac/streamsave]https://github.com/Sagnac/streamsave

### 2023-12-31

- Stopped [autolyrics.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/autolyrics.lua) crashing when `downloadforall` is disabled

### 2023-12-30

- Fix a bug with calculating file size

### 2023-12-28

- Fixed some dates crashing [modernx.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/modernx.lua)

### 2023-12-23

- Added the `dontsaveduration` option to [autoloop.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/autoloop.lua), which doesn't save the position of videos under the specified length, but also doesn't loop them - perfect for short videos under a minute or so
- Opening the downloaded file's folder now works for other operating systems (this needs testing)
- Enabled `autolyrics.lua` functionality for YouTube videos, and .lrc files can now be saved to a specified path
![2023-12-23_05-02-18_325_ArcControl](https://github.com/zydezu/mpvconfig/assets/50119098/1cd17f86-30cd-481b-a02d-e6f8bdf56e29)
- Fixed `autolyrics.lua` on unix systems

### 2023-12-22

- Fixed [this issue](https://github.com/zydezu/mpvconfig/issues/7) - [modernx 0.2.3] The OSC doesn't hide #7... this is because I forgot to finish writing this line...
```lua
if (not (state.paused and user_opts.donttimeoutonpause)) then
    hide_osc()
end
```

### 2023-12-16

- Fixed screenshotting playing YouTube videos [screenshotfolder](https://github.com/zydezu/mpvconfig/blob/main/scripts/screenshotfolder.lua)
- Fixed quality menu for ytdl:// playing videos

### 2023-12-16

- Edited video info formatting
- When playing YouTube videos, information like views, likes and dislikes are added to the window title
- [modernx.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/modernx.lua) properly respects the `raisesubswithosc` option


### 2023-12-13

- Fixed a bug with `user_opts.dynamictitle` in [modernx.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/modernx.lua) not properly updating the title when switching video in a playlist
- Made changes to [autolyrics.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/autolyrics.lua), specifically improving the `options.downloadforall` feature
- Updated [qualitymenu.lua](https://github.com/christoph-heinrich/mpv-quality-menu) from its repository to 4.1.1 - 2023-Oct-22

### 2023-12-09

- Adapted [lrc.lua](https://github.com/guidocella/mpv-lrc), to automatically download lyrics for songs (with metadata)
- The description now doesn't prevent you from clicking buttons
- The description closes properly when navigating files in a playlist
- Tweaked metadata formatting
- Fixed a crash in [modernx.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/modernx.lua), where some date metadata could cause a crash
- Fixed description line breaks not working in description metadata of some old youtube videos

![2023-12-09_12-03-14_260_mpv](https://github.com/zydezu/mpvconfig/assets/50119098/1b7da399-fef3-4990-9286-8ecfd3d0ed0a)


### 2023-11-27

- Added the `donttimeoutonpause` option, which when enabled, doesn't hide the osc whilst hovering over it, when paused.
- Changed filename formats when cutting a video

### 2023-11-23

- Fixed [error loading modernx.lua with mpv v0.37.0-7](https://github.com/zydezu/mpvconfig/issues/6)
- Made `user_opts.title` function properly
- Tweaked some messages

### 2023-11-22

- Tweaked some config scripts
- Videos that [auto loop](https://github.com/zydezu/mpvconfig/blob/main/scripts/autoloop.lua) ignore `save-position-on-quit`, so always play from the start, this option can be configured in `script-opts/autoloop.conf` as `playfromstart=false` (to disable)
- Replaced mpvcut.lua with a heavily modified one from [https://github.com/familyfriendlymikey/mpv-cut](https://github.com/familyfriendlymikey/mpv-cut), that should provide faster compression
- More consistant code

### 2023-11-17

- Added a dislike counter (under the description) for supported YouTube videos
- Made improvements to the formatting of the description/clickable description - especially with web videos
- Additionally date formatting is now an option `user_opts.dateformat`
!["An image of KOMM SUSSER TODs date"](https://cdn.discordapp.com/attachments/1160645107637309441/1174867243050467348/2023-11-17_00-21-51_818_mpv.png)
![An image of KOMM SUSSER TODs, with date, like count and dislike count](https://cdn.discordapp.com/attachments/1160645107637309441/1174867243344076850/2023-11-17_00-21-38_898_mpv.png)

### 2023-11-02

- Added the keybind CTRL/Shift + left/right to jump to the previous/next chapters
- Changed compact mode key bindings, right clicking now goes to the previous/next chapter, shift clicking now jumps backward/forwards a minute
- Made OSC timing out smarter
- Fixed the issue: [Mute button not working as expected #5](https://github.com/zydezu/mpvconfig/issues/5)
- Fixed a crash when pressing Shift on the playlist buttons

### 2023-10-10

- Fixed virtual title bar when toggling border/pinning

### 2023-10-04

- Added shadertoggle.lua
- Fixed a bug that would crash the ModernX OSC

### 2023-08-29

- Fixed a small download bug

### 2023-08-19

- Fixed UI not scaling properly on mpv.net


### 2023-08-12 (Part 2)

- Fixed download location on unix systems
- Added more keybinds (X and C for cycling audio and caption tracks)
- Fixed long metadata lag
- Fixed subtitles sometimes showing in the wrong position when toggling window pinning or fullscreen
- OSC shows up when using keybinds (Shift + < or Shift + >) to change playlist items
- Fixed a crash when dragging the seekbar quickly to the end, and the next video immidiately playing


### 2023-08-12

- Added an option to change the font size of the time text
- Screenshotting now renders subtitles at the correct position, even when OSC is showing
- Pressing `P` will now pin the window
- Changed download filename formatting
- Removed some unused settings,
- Improved the `dynamictitle` setting as it now incorporates file metadata

### 2023-08-08

- Bug fixes


### 2023-08-07

- Fixed m3u files crashing `modernX.lua`


### 2023-08-06

- Fixed long descriptions lagging the player
- Added a scrolling description box


### 2023-08-05

- Added an approximate download size to the download button


### 2023-07-30

- Revamped settings


### 2023-07-27

- Tweaked description error handling


### 2023-07-01

- Fixed pasting some links


### 2023-06-30

- Updated the autoload script


### 2023-06-28

- Fixed broken icons on some systems
- Fixed some bugs


### 2023-06-27

- Changed screenshot and download file destinations


### 2023-06-26

- Fixed some bugs


### 2023-05-31

- Added a download icon on web videos


### 2023-05-29

- Updated some scripts


### 2023-05-27

- Fixed subtitle positioning when OSC is shown on different resolutions


### 2023-05-21

- Added an option for round icons


### 2023-05-14

- Slightly tweaked settings


### 2023-05-08

- Added an osc message on screenshot
- Slightly changed file path and duplicate screenshots


### 2023-05-08

- Optimised code
- Increased OSC message duration
- Tweaked the quality menu
- Quality menu now works with ytdl:// links
- Added a keybind to toggle shaders (temporary)
- Added a dynamic title option to ModernX, change the title depending on if {media-title} and {filename} differ (like with playing urls, audio or some media)
- Taking multiple screenshots in a second (with timestamp) mode on will now save them all without error

### 2023-05-07

- Tweaked some settings

### 2023-05-06

- Tweaked some code

### 2023-05-01

- Tweaked some configuration files

### 2023-04-27

- Revamped 'mpv.conf'
- Created `screenshotfolder.lua`, saving screenshots in `~~desktop/mpv/[filename]`
- Created `input.conf`, and added the quality menu to it

### 2023-04-24

- Added the 'thumbnailborder' and 'raisesubswithosc' options

### 2023-04-23

- Changed config file
- Changed hover behaviour
- Reduced flickering
- Fixed a debug message showing

### 2023-04-21

- Add window title to borderless and fullscreen mode

### 2023-04-20

- Fixed some bugs with icons

### 2023-04-16

- Added ability to hide pin window button
- Changed some phrasing
- If titlebar isn't showing, OSC will now show when the mouse is at the window buttons
- Tooltips now always stay on the screen
- Pinning the window will remove the border, unpinning will show it
- Right clicking the ontop button will not change border status
- Added `sponsorblock.py`

### 2023-04-15

- Added pin window (stay ontop) button
- Lots of bug fixes

### 2023-02-23

- Added compact mode
- Added loop button
- Added more clicking events
- Fixed many bugs

### 2023-02-08

- First fork, added scripts
