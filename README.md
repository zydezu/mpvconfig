# mpvconfig
My personal [mpv](https://mpv.io/) config.

See my [modernX](https://github.com/zydezu/modernX) fork for more information about that script.

# Usage
Use `git clone https://github.com/zydezu/mpvconfig mpv` to download the repository, and place it in the relevant directory. This will be typically located at `\%APPDATA%\mpv\` on Windows and `~/.config/mpv/` on Linux/MacOS. 

See the [Files section](https://mpv.io/manual/master/#files) in mpv's manual for more information.

# Updates

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
