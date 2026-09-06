# Haier AC Mac UI Context

The design language, visual hierarchy, and component terminology for the native macOS Haier AC control client.

## Language

**Vibrant Material**:
The translucent, blur-backed surface layer (`.ultraThinMaterial` / `.regularMaterial`) that lets desktop and window backgrounds subtly bleed through while providing strong contrast for text and controls.
_Avoid_: Pure flat solid colors, heavy opaque cards

**Hairline**:
A crisp 1px border with dynamic opacity used to separate surfaces and define control perimeters in both light and dark modes.
_Avoid_: Heavy borders, shadows without borders

**Temperature Pod**:
The prominent hero card displaying current and target temperatures, featuring large-scale numeric typography and integrated segmented stepper controls.
_Avoid_: Circular rotary dial, full-width plain slider

**Status Capsule**:
A compact pill-shaped badge displaying environment telemetry (ambient temperature, humidity, running mode, wind speed) with semantic color accents.
_Avoid_: Square tag, raw text label

**Mode Tint**:
A dynamic accent color resolved from the AC's operating mode (Cool: Ice Blue, Heat: Warm Amber, Fan/Dry: Mint/Teal, Off/Auto: Lavender Purple) applied to hero cards, active badges, and subtle glows.
_Avoid_: Static single-accent, uncontextualized bright rainbow colors

**Bento Pod**:
A self-contained rounded capsule or square cell organized within a modular grid (following macOS Control Center conventions), grouping controls by functional proximity.
_Avoid_: Endless vertical scroll lists, unstructured tables

**Sparkline**:
An unadorned, axis-free 24-hour temperature trend line embedded in the menu bar popover for immediate ambient awareness.
_Avoid_: Heavy full-axis charts in popovers

**Area Trend**:
A full-scale Swift Chart in the main window featuring smooth Catmull-Rom interpolation, translucent mode-tinted area fills, and a pulsing live-temperature beacon.
_Avoid_: Jagged point-to-point lines, raw data tables

**Spring Feedback**:
Subtle, physics-based spring animations (`withAnimation(.spring(...))`) applied strictly to state transitions, taps, and mode toggles.
_Avoid_: Static instant snap, continuous looping particle effects
