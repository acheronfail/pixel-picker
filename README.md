![Pixel Picker Banner](./Resources/banner.png)

Pixel Picker is like Digital Color Meter, but lives in your menu bar and lets you get the color of any pixel easily. Just hit your shortcut, up comes a magnifying glass, and away you go!

### Features

* 📸 Pick *any* pixel on your screen with ease
* 🔎 Different magnification levels
* ✏ Multiple color export formats
* 🖥 Multi-monitor support
* 🎨 Supports different color spaces
* ⌨️ Global keyboard shortcut activation
* 🌄 Customisable preview
* 🌓 WCAG contrast level checker
* ✨

![demo of pixel-picker](./Resources/demo.png)

## Installation

#### Via Homebrew:

```bash
brew install --cask pixel-picker
```

#### Via GitHub Releases

Simply download the dmg from the [releases](https://github.com/acheronfail/pixel-picker/releases) tab and drag "PixelPicker.app" into your `/Applications` folder.

## Usage

After you've installed Pixel Picker, it will live in your menu bar. You have many different ways of activating the picker:

* Configure a keyboard shortcut in the dropdown menu and press that to activate the picker
* Select the "Pick a Pixel" item in the dropdown menu to activate the picker
* Simply right-click the menu item and the picker will activate
* _Pro-tip:_ Use the <kbd>H</kbd>, <kbd>J</kbd>, <kbd>K</kbd> and <kbd>L</kbd> keys to move the picker pixel by pixel

Once you have the picker open, it should be quite straightforward! Move your mouse around the screen and click (or press <kbd>space</kbd> on the pixel you want.
You can also hold down the <kbd>control (⌃)</kbd> key (this can be changed to another key) while the picker is open, and the picker will enter "Focus Mode". This will zoom the pixel preview even further, and will slow down the picker's movement to make it easier to pick that hard-to-get pixel!

**ProTip:** Remember, you can use the left or right arrow keys to cycle between color formats while the picker is open.

### Options

All of Pixel Picker's options are in its menubar dropdown. Simply click on the menu bar item, and you can configure the picker right there in your menu.

Pixel Picker provides some neat options:

* 🔳 **Show Grid**
    * Whether or not to show a grid around the pixels in the picker's preview.
* 🎨 **Color Space**
    * Computer screens are complex things, and have various color spaces. You can either leave this setting as its default (it will choose the default color space of your screen) or you can specify a specific color space and Pixel Picker will try and use that instead (compatibility depends on your computer's screen/monitor).
* ✏️ **Color Format**
    * How should the color be copied when you select it? Examples include CSS Hex: `#aabbcc`, or Java RGB: `new Color(158, 198, 117)`, etc.
* 🔍 **Magnification**
	- How far in should the preview zoom/how big should each pixel be?
* 🧐 **Focus Modifier**
    * Choose which modifier activates focus mode. When focus mode is active, the picker zooms even closer in, and your mouse moves slower to help you pick the right pixel.
* 🔢 **Float Precision**
    * This controls how many digits will come after the decimal point when using float-based color formats.
* ⌨️ **Picker Shortcut**
    * The global keyboard shortcut to use that will activate Pixel Picker.
* 🚀 **Launch at Login**
    * If this is enabled then Pixel Picker will be launched when you log into your computer.
* 🌓 **WCAG Constrast Level**
    * If enabled, will compare the current and last picked color and show the [WCAG constrast level](https://www.w3.org/TR/WCAG20/): Fail, OK, AA, or AAA.

#### Extra Overrides or Hidden Settings

In some releases Pixel Picker might have some experimental overrides that can be toggled via the Terminal (`defaults write ...`, etc). Look under the "Experimental Overrides" section at `Pixel Picker` -> `About` for more information.

## Questions/Concerns

None yet!

## Developing

Pixel Picker builds as a universal macOS app (`arm64` and `x86_64`) with Xcode 26
or later and requires **macOS 14 Sonoma or later**. ScreenCaptureKit replaces the
removed legacy screen-capture API, and Launch at Login uses ServiceManagement.

Dependencies are pinned in the Xcode project's `Package.resolved` and resolved
with Swift Package Manager. Carthage is no longer required; the old tracked
`Carthage/Checkouts` tree is retained as historical source and is not built.
The upstream MASShortcut package replaces the old custom fork (its custom
`allowAnyShortcut` option was unused by Pixel Picker).

```bash
./scripts/test.sh
./scripts/build.sh
open "Pixel Picker.xcodeproj"
```

The test scheme uses a dedicated `Testing` configuration with the
`PIXEL_PICKER_TESTING` compilation condition. Test-only startup and temporary
settings paths are compiled separately from normal Debug and Release builds;
no runtime environment variable controls this behavior.

The build script archives for both architectures, verifies every bundled Mach-O
binary and the app signature, then creates a ZIP, DMG, and checksum manifest in
`dist/`. Local builds use ad-hoc signatures and do not alter the macOS keychain.

The Build GitHub Action runs tests natively on Apple silicon and Intel, then
builds universal preview artifacts on both. The manually triggered Draft release
workflow signs packages and the Sparkle feed and creates **only a draft release**.
It never publishes a release or modifies an existing release.

See [RELEASING.md](RELEASING.md) for one-time key generation, `gh secret set`
commands, the public-key plist update, and draft-only testing instructions.

## License

[GPLv3](./LICENSE)
