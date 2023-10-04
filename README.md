# mpvconfig
My personal [mpv](https://mpv.io/) config.

See my [modernX](https://github.com/zydezu/modernX) fork for more information about that script.

# Usage
Use `git clone https://github.com/zydezu/mpvconfig mpv` to download the repository, and place it in the relevant directory. This will be typically located at `\%APPDATA%\mpv\` on Windows and `~/.config/mpv/` on Linux/MacOS. 

See the [Files section](https://mpv.io/manual/master/#files) in mpv's manual for more information.

# Scripts and Associated Keybinds

Please note that many of these scripts have been slightly modified from their initial repositories. Compare the scripts to find the modifications.

| Script and description | Keybinds |
| -------------- | --------------- |
| [autoload](https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua) loads files in the directory to play through | None |
| [autoloop](https://github.com/zc62/mpv-scripts/blob/master/autoloop.lua) loops files by default that are smaller than a set duration | None |
| [modernx](https://github.com/zydezu/modernx) an modern OSC for mpv with many additional features | **x** - Cycle through audio tracks <br>**c** - Cycle through subtitle tracks <br>**P** - Pin or unpin the window <br>**TAB** - Show chapter list <br> For more: [Check repository](https://github.com/zydezu/modernx) |
| [mpv_cut](https://github.com/b1scoito/mpv-cut) allows clipping a segment of a video | **z** - Mark start segment <br> **z (again)** - Clip the video <br> **Shift+z (instead of z again)** - Re-encode the clip with a small file size |
| [qualitymenu](https://github.com/christoph-heinrich/mpv-quality-menu) allows you to select the quality of a YouTube video playing in mpv. | **f** - Open video quality menu <br> **Alt+f** - Open audio quality menu <br> **Arrows and Enter** - Navigate options and confirm a selection <br> **Esc** - Exit menu |
| [screenshotfolder](https://github.com/zydezu/mpvconfig/blob/main/scripts/screenshotfolder.lua) saves screenshots to a designated `~desktop/mpv/.../` folder | **s** - Take a screenshot |
| [SmartCopyPaste](https://github.com/Eisa01/mpv-scripts#smartcopypaste) allows various files and links to be pasted into mpv | **Ctrl+v** - Paste |
| [sponsorblock](https://github.com/po5/mpv_sponsorblock) skips sponsored segments of YouTube videos | **g** - Set segment boundaires <br> **Shift+g** - Submit a segment <br> **h** - Upvote last segment <br> **Shift+h** - Downvote last segment                      |
| [thumbfast](https://github.com/po5/thumbfast) show thumbnails on the scrubbing bar | None |
| [locatefile.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/locatefile.lua) opens the file in an explorer or a web browser | **o** - Open file |
| [shadertoggle.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/shadertoggle.lua) loads shaders found in a folder of choice and toggles through them | **Ctrl+s** - Switch shaders |
| [input.conf](https://github.com/zydezu/mpvconfig/blob/main/input.conf) an input configuration file | **-** - Decrease subtitle font size <br> **+** - Increase subtitle font size <br> **Scroll wheel** - Change volume |


# Updates

### 2023-10-04

- Added shadertoggle.lua
- Fixed a bug that would crash the ModernX OSD

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
- Screenshotting now renders subtitles at the correct position, even when OSD is showing
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
- Increased osd message duration
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
- If titlebar isn't showing, OSD will now show when the mouse is at the window buttons
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
