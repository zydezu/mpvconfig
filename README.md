# mpvconfig

![2024-12-25_23-46-32_598_mpv](https://github.com/user-attachments/assets/e3bd21b2-64d7-41d4-a0b5-bcf5364f042a)

My personal [mpv](https://mpv.io/) config.

> [!NOTE]
> Releases of the [modernX](https://github.com/zydezu/modernX) script are in a seperate repository - see here [https://github.com/zydezu/ModernX/releases](https://github.com/zydezu/ModernX/releases).

## Usage

Use `git clone https://github.com/zydezu/mpvconfig mpv`, and place it in the relevant directory. This will be typically located at `\%APPDATA%\mpv\` on Windows and `~/.config/mpv/` on Linux/MacOS.

See the [Files section](https://mpv.io/manual/master/#files) in mpv's manual for more information.

## Scripts and Associated Keybinds

Please note that many of these scripts have been slightly modified from their initial repositories. Compare the scripts to find the modifications.

| Script and description | Keybinds |
| -------------- | --------------- |
| [autoloop](https://github.com/zydezu/mpvconfig/blob/main/scripts/autoloop.lua) loops files by default that are smaller than a set duration | None |
| [autolyrics](https://github.com/zydezu/mpvconfig/blob/main/scripts/autolyrics.lua) tries to download lyrics and display them for said file | **Alt+m** - Request lyrics from musixmatch then netease if that fails<br>**Alt+n** - Request lyrics only from netease<br>**Alt+o** - Set lyrics start point to the current timestamp (if lyrics need to be synced) |
| [copypaste](https://github.com/zydezu/mpvconfig/blob/main/scripts/copypaste.lua) Copy and paste file paths, URLs and timestamps | **Ctrl+c** - Copy file path or URL to clipboard<br>**Ctrl+v** - Paste file path or URL and play it<br>**o** - Open file location or URL in browser |
| [detectdualsubs](https://github.com/zydezu/mpvconfig/blob/main/scripts/detectdualsubs.lua) Detects if there are two existing subtitles, one being an original script and the other being a translation (eg: English and Japanese subtitles) and displays them both on screen | **Ctrl+b** - Check for dual subs again (useful if subtitle tracks were changed) |
| [modernx](https://github.com/zydezu/modernx) a modern OSC for mpv with many additional features | **x** - Cycle through audio tracks <br>**c** - Cycle through subtitle tracks <br>**p** - Pin or unpin the window <br>**Tab** - Show chapter list <br> For more: [See repository](https://github.com/zydezu/modernx#buttons) |
| [mpvcut](https://github.com/zydezu/mpvconfig/blob/main/scripts/mpvcut.lua) allows clipping a segment of a video | **z** - Mark start segment <br> **z (again)** - Clip the video <br> **Shift+z** - Cancel the clip <br> **a** - Change mode (copy, encode, compress) |
| [screenshotfolder](https://github.com/zydezu/mpvconfig/blob/main/scripts/screenshotfolder.lua) saves screenshots to a designated folder | **s** - Take a screenshot |
| [selectformat](https://github.com/koonix/mpv-selectformat) allows you to change the quality of internet videos on the fly | **Ctrl+f** - Open format menu <br> Use up and down to choose a resolution, and fold and unfold selections with the arrow keys to see more codec options |
| [sponsorblock](https://github.com/po5/mpv_sponsorblock) a fully-featured port of SponsorBlock for mpv | [See repository](https://github.com/po5/mpv_sponsorblock?tab=readme-ov-file#usage) |
| [thumbfast](https://github.com/po5/thumbfast) show thumbnails when hovering the progress bar | None |
| [input.conf](https://github.com/zydezu/mpvconfig/blob/main/input.conf) an input configuration file | **-** - Decrease subtitle font size <br> **+** - Increase subtitle font size <br> **Scroll wheel** - Change volume |

## Updates

### 2025-03-13

- FEAT: add keybinding for shuffling playlist in input.conf

### 2025-03-11

- FIX: audio/tracklist indicator not showing selected track correctly in `modernX.lua`
- FIX: changes to Japanese lyric detection in `autolyrics.lua`

### 2025-02-09

- FEAT: set subtitles to a non-forced sub track as defined by --slang, in `detectdualsubs.lua`

### 2025-01-25

- FIX: sponsorblock segments not rendering properly in modernX

### 2025-01-21

- FIX: fix some subtitles not showing up on YouTube videos
- FIX: ytdl formats not being respected in modernx.lua
- FIX: crop text properly on title bar
- FIX: add edge date case

### 2025-01-17

- FEATURE: added coloured segments on the progress bar, like on Youtube with SponsorBlock to `modernX.lua` - NOTE: requires a custom version of sponsorblock.lua [https://github.com/zydezu/mpvconfig/blob/main/scripts/sponsorblock.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/sponsorblock.lua)
- This adds the following options: `show_sponsorblock_segments`, `add_sponsorblock_chapters`, `sponsorblock_sponsor_color`, `sponsorblock_intro_color`, `sponsorblock_outro_color`, `sponsorblock_interaction_color`, `sponsorblock_selfpromo_color` and `sponsorblock_filler_color`
- Fix `seekbar_cache_color` to `modernX.lua`
- Added `progress_bar_height` to `modernX.lua`
- FIX: fix thumbnail border clipping through text weird
- FEAT: `modernX.lua` now sets the tick rate to the monitors refresh rate
- FIX: fix state.title_bar not being respected after pinning
![image](https://github.com/user-attachments/assets/a7dd23bb-f59e-4f0a-bbcb-b9c5c759e802)


### 2025-01-16

- REFACTOR: organise options in mpv.conf
- FIX: add script-binding keybindings to input.conf
- FIX: title and description text is now cropped properly and doesn't run off screen

### 2025-01-15

- FIX: change some mpv.conf settings
- UPDATE: bring `selectformat.lua` up-to-date with  [https://github.com/koonix/mpv-selectformat](https://github.com/koonix/mpv-selectformat)
- REFACTOR: refactor all scripts

### 2025-01-14

- FEAT: create `detectdualsubs.lua` that detects if there are two existing subtitles, one being an original script and the other being a translation (eg: English and Japanese subtitles) and displays them both on screen

![2025-01-14_07-15-37_199_mpv](https://github.com/user-attachments/assets/84ed7a83-dc65-4afb-8d2b-17499ff050b5)


### 2025-01-10

- FIX: fix modernx.lua crashing if playing a live radio (m3u8 file)

### 2025-01-09

- Re-add `key_bindings` in `modernx.lua`
- Fixed some options not being read correctly in modernx.conf files

### 2025-01-06

- Fix lyric formatting
- Add `strip_artists` and `chinese_to_kanji_path` options to `autolyrics.lua`

### 2024-12-28

- Improve code in all scripts
- Seperate parts of `autoloop.lua` into `copypaste.lua`
- Fix making web cache clips (clipping web videos) in `mpvcut.lua`
- Remove `autoload.lua` as `autocreate-playlist` in `mpv.conf` replicates it's functionality

### 2024-12-27

- Adjust default `compresssize` value in `mpvcut.lua` to 9.50MB

### 2024-12-25

- Set `mpvcut.lua` default compress size target to 9.00MB (THANKS DISCORD >~<0)
- Added `AOTFShinGoProMedium.otf` to the fonts folder as it is used in `mpv.conf`
- Improved descriptions
- Add fallback for chapters with no names in `modernX.lua` to prevent a crash
- Add buffer indicator on `modernX.lua`
  
![58-038 jpeg](https://github.com/user-attachments/assets/12d948aa-c623-4e45-8363-b2d520af4b4c)<br>
![tartarus](https://github.com/user-attachments/assets/835f5585-63a4-4605-8b6b-e075e3cc7600)<br>
![azumanga-daioh-christmas](https://github.com/user-attachments/assets/b5a2dfd8-495e-4eb6-bb24-ed4374684154)<br>
 **MERRY XMAS!!**


### 2024-12-20

- Changed code comments in `mpv.conf`
- Rename 'localsavetofolder' to 'savetodirectory' in `mpvcut.lua` to describe the option better

### 2024-12-18

- Add various options and features from [https://github.com/Samillion/ModernZ](https://github.com/Samillion/ModernZ)
- Reorganised user_opts
- Changed hover effect on buttons
- Fix file size displaying a wrong value
- Downloads and file size estimations now respect `mpv.conf`'s `ytdl-format` option if set
- Added chapter display next to the time
- Added more sizing and color options


### 2024-12-14

- Order formats in `selectformat.lua` by bitrate
- `modernx.lua` fixes to comment parsing
- `modernx.lua` new icons

### 2024-10-21

- Implement [https://github.com/zydezu/ModernX/pull/58](https://github.com/zydezu/ModernX/pull/58)
- Implement [https://github.com/zydezu/ModernX/pull/59](https://github.com/zydezu/ModernX/pull/59)
- Add `dynamictimeformat` option to `modernX.lua`

### 2024-10-17

- Fix the 2K rendering profile (don't include only audio files with large album art in the condition)
- Change subtitles styling

### 2024-10-08

- Change subtitles styling
- Better logging for `autolyrics.lua`

### 2024-10-03

- Implement [https://github.com/zydezu/ModernX/issues/50](https://github.com/zydezu/ModernX/issues/50)
- Implement [https://github.com/zydezu/ModernX/issues/51](https://github.com/zydezu/ModernX/issues/51)
- Implement [https://github.com/zydezu/ModernX/issues/54](https://github.com/zydezu/ModernX/issues/54)

### 2024-09-08

- Implement [https://github.com/zydezu/ModernX/issues/45](https://github.com/zydezu/ModernX/issues/45)

### 2024-08-13

- Changed some configs
- Added an option for a screenshot button to `modernX.lua` [https://github.com/zydezu/ModernX/pull/40](https://github.com/zydezu/ModernX/pull/40)
- Update `screenshotfolder.lua` to not include file extensions in folder directories
- Improved YouTube comment parsing and viewing in `modernX.lua`

### 2024-08-02

- Fixed bitrate calculations in [`mpvcut.lua`](https://github.com/zydezu/mpvconfig/blob/main/scripts/mpvcut.lua)
- Fixed [`mpvcut.lua`](https://github.com/zydezu/mpvconfig/blob/main/scripts/mpvcut.lua) breaking when 'compressing' audio files

### 2024-07-29

- Fix [https://github.com/zydezu/ModernX/issues/36](https://github.com/zydezu/ModernX/issues/36), reverting the keyframe change (button functions are swapped)
- Fix [https://github.com/zydezu/ModernX/issues/35](https://github.com/zydezu/ModernX/issues/35)

### 2024-07-28

- Fixed thumbnail being behind OSC text
- Added [`selectformat.lua`](https://github.com/koonix/mpv-selectformat), allowing you to change the quality of internet videos on the fly
- [`mpvcut.lua`](https://github.com/zydezu/mpvconfig/blob/main/scripts/mpvcut.lua) now stops overwriting previously cut files
- Fixed `autoloop` not staying disabled over a playlist of files
- Implement [https://github.com/dexeonify/mpv-config/commit/583faf0](https://github.com/dexeonify/mpv-config/commit/583faf0)
- In modernX, `shift+left click` on the seekbar now scrubs to the exact position, whilst `left click` now scrubs to the keyframe position (faster)

### 2024-07-05

- Prevent downloading comments if the option is disabled on web videos in `modernx.lua`
- Stopped auto downloading lyrics on songs in `autolyrics.lua`
- Fixed album artist not registering in `autolyrics.lua`
- Fixed trying to save lyric files with "/" or "\" in their names in `autolyrics.lua`
- In `modernx.lua` album artists and artists (from the file metadata) and now displayed separately, instead of where previously 'artist' would override 'album artist'

### 2024-06-22

- Fix crashing when no comments are loaded

### 2024-06-07

- Fix downloading comments for more various YouTube links, like `https://www.youtube.com/watch?v=Pbb40i1khlc&list=WL&index=3`

### 2024-06-01

- Round file size to 1dp
- Fix downloading comments for YouTube links with `?=`

### 2024-05-29

- Removed cmd flickering when opening downloaded file

### 2024-05-25

- Add 'o' binding to `autoloop.lua` to open the file location or url in web browser
- Tweaked wording on YouTube description
- Fixed title not loading on videos fetched from a URL
- Added commas to view, comments, like and dislike counts
- Fix some old YouTube descriptions breaking line breaking
- Made '...' in descriptions make grammatical sense
- Changed default download settings to improve speed and keep the file size approximation accurate
- Fix for [https://github.com/zydezu/ModernX/issues/28](https://github.com/zydezu/ModernX/issues/28)
- Add note about colour formats in the config, how they should be in the format: BBGGRR [http://www.tcax.org/docs/ass-specs.htm](http://www.tcax.org/docs/ass-specs.htm)
- Improved the comment parsing
- All YouTube videos should load comments correctly
- Added pages to comments to not lag out player by rendering them all at once
- Changed some file approximation tooltip

### 2024-05-12

- Changed window title loading conditions

### 2024-05-09

- Added pasting functionality to mpv, you can use Ctrl+V (or the equivalent paste command) to open file paths and URLs, or navigate to timestamps
- Pressing Ctrl+C will copy the path or URL of the currently playing video
- Fixed `autoload.lua` adding out of order playlists when directly accessing a file path
- YouTube expanded descriptions automatically refresh when more information is loaded
- Increased chapter/playlist list size (limited_list function)
- Stopped descriptions beginning with 'A' breaking
- Made descriptions load and display faster
- Simplified video descriptions shown under the title - full details can still be seen by clicking
- Tweaked formatting on audio only metadata (By: Artist - Album -> Artist | Album)
- Improved [https://github.com/zydezu/ModernX/issues/22](https://github.com/zydezu/ModernX/issues/22)

### 2024-05-06

- Added `dontsaveonaudio` to `autoloop.lua`, which doesn't save the current position on audio files

### 2024-05-02

- Changed tick rate
- Made description font sizes consistent between videos

### 2024-04-28

- Added `descriptionfontsize` to modernX
- Changed default font size in modernX
- Enable thumbfast on YouTube videos (enabling the `network` option)

#### Default font changes on windows

| New font v2 | New font | Old font |
| ------ | ------ | ------ |
| ![newfontfixedmpv](https://github.com/zydezu/mpvconfig/assets/50119098/15be1ae7-3f25-4927-acd2-b30089274eab) | ![newfontmpv](https://github.com/zydezu/mpvconfig/assets/50119098/4614f90e-0525-4d51-8ac8-7ba6af1cade6) | ![oldfontmpv](https://github.com/zydezu/mpvconfig/assets/50119098/8e6ab55d-98ec-4f1e-8407-c46e65db4e50) |

### 2024-04-26

- Update default font settings
- Tweaked `dynamictitle` in ModernX to be cleaner
- Added `automatickeyframemode` and `automatickeyframelimit` to modernX, resolving [https://github.com/zydezu/ModernX/issues/23](https://github.com/zydezu/ModernX/issues/23)

### 2024-04-24

- Try to fix [https://github.com/zydezu/ModernX/issues/14](https://github.com/zydezu/ModernX/issues/14)
- Fixed [https://github.com/zydezu/ModernX/issues/25](https://github.com/zydezu/ModernX/issues/25)

### 2024-04-20

- Fixed a crash that sometimes occured when changing videos in a playlist
- Fixed playtime showing '-00:00' for a short time upon file load
- Cleaned up debug messages in the terminal

### 2024-04-19

- Fixed persistentprogresstoggle changes not showing without mouse movement or OSC showing
- Removed 'NA' showing up in audio/subtitle tooltips
- Improved `cacheloading` on autolyrics.lua

### 2024-04-06

- Fixed thumbnail chapters not showing, resolving [https://github.com/zydezu/ModernX/issues/21](https://github.com/zydezu/ModernX/issues/21)

### 2024-04-04

- Cut scripts I don't use for faster file opening times

### 2024-03-23

- Fixed downloading not working on a playlist of videos

### 2024-03-22

- Removed debug code

### 2024-03-20

- Fix yt descriptions with % crashing modernX
- Fix command message placement in modernX
- Made description splitting consistent between online and local videos
- Added the ability to toggle the persistent progress bar, with the `b` key, if `persistentprogresstoggle` is enabled

### 2024-02-24

- Merged [https://github.com/zydezu/ModernX/pull/10](https://github.com/zydezu/ModernX/pull/10), fixing some formatting in `modernX`
- Merged [https://github.com/zydezu/ModernX/pull/11](https://github.com/zydezu/ModernX/pull/11), updaing the audio/subtitle icons in `modernX`
- Fix reply icon
- Merged [https://github.com/zydezu/ModernX/pull/12](https://github.com/zydezu/ModernX/pull/12), adding the option `keybindings` to `modernX`

### 2024-02-15

- Added `showfilesize`, fixing [https://github.com/zydezu/ModernX/issues/7](https://github.com/zydezu/ModernX/issues/7)
- Fixed persistentprogress handle bar size, [https://github.com/zydezu/ModernX/issues/8](https://github.com/zydezu/ModernX/issues/8)
- Fixed [https://github.com/zydezu/mpvconfig/issues/13](https://github.com/zydezu/mpvconfig/issues/13)
- Fixed description text positioning

### 2024-01-28

- Fix [https://github.com/zydezu/ModernX/issues/6](https://github.com/zydezu/ModernX/issues/6)

### 2024-01-25

- Made switching between web videos in playlists in `modernX` more seamless, instantly clearing the description
- Improved the description string splitting functions in `modernX`

### 2024-01-23

- Added `downloadpath` in `modernX`, fixing [https://github.com/zydezu/ModernX/issues/4](https://github.com/zydezu/ModernX/issues/4)
- Fixed CJK characters in video description and uploader name, fixing [https://github.com/zydezu/mpvconfig/issues/12]
- Added an experimental toggle to view comments of a video (very unstable)

### 2024-01-15

- Fixed fetching dislikes via the YouTube Dislike API in `modernX` and screenshotting in `screenshotfolder.lua` when viewing YouTube short 'share' links, along with the `dynamictitle` option
- Updated dislike formatting and error checking

### 2024-01-14

- Altered the default yt-dlp settings in [modernx.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/modernx.lua) to make it work better on more video players, these change be changed with `ytdlpQuality`
- Added the `updatetitleyoutubestats` option in [modernx.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/modernx.lua), which when enabled, updates the window/OSC title bar with YouTube video stats (views, likes, dislikes)
- Implemented [https://github.com/cyl0/ModernX/pull/59](https://github.com/cyl0/ModernX/pull/59)
- Added the `persistentprogressheight` option to [modernx.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/modernx.lua), [as part of this issue](https://github.com/zydezu/mpvconfig/issues/9)

### 2024-01-12

- Fixed CJK characters not showing in screenshot folder and file names
- [Implemented](https://github.com/zydezu/mpvconfig/issues/9) `persistentprogress` and `persistentbuffer` in [modernx.lua](https://github.com/zydezu/mpvconfig/blob/main/scripts/modernx.lua)
![2024-01-12_08-47-05_210_mpv](https://github.com/zydezu/mpvconfig/assets/50119098/a13d4d56-d7ba-48d8-8096-95fa2b1965b4)
- Fixed issue: [Seekbarhandle does not hit the end position](https://github.com/zydezu/mpvconfig/issues/3)
- [mpvcut](https://github.com/zydezu/mpvconfig/blob/main/scripts/mpvcut.lua) fixed cache saving for certain web videos with specific characters in media names
- [screenshotfolder](https://github.com/zydezu/mpvconfig/blob/main/scripts/screenshotfolder.lua) CJK fix... again
- [autolyrics](https://github.com/zydezu/mpvconfig/blob/main/scripts/autolyrics.lua) now loads previously downloaded subtitles instantly, the script is smarter with what to download, using the new option `cacheloading`
- In [autolyrics](https://github.com/zydezu/mpvconfig/blob/main/scripts/autolyrics.lua) filenames are now closer to the track's name, also CJK filenames fix
- Stopped a crash when switching subtitles at the same time another external track added

### 2024-01-10

- Added the ability to choose a directory to save clips in (required for web video cache saving), using `savedirectory`
- Implemented saving clips from web videos, using the cache in [mpvcut.lua](https://github.com/zydezu/mpvconfig/commit/edf7b9d88e90d67922330d6f03d70628b30f22af#diff-8f6436b607b063cf868ffaef66bebbcc6cec22b62894400dad687c4caf54df1c) based off [https://github.com/Sagnac/streamsave](https://github.com/Sagnac/streamsave)

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
