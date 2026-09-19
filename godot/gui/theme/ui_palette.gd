class_name UIPalette
extends RefCounted
## Single source of truth for the interface colors and sizes: the "rally at sunset" identity
## of Drone Rally Cam (warm dark surfaces, cream text, rally-tape orange accent).
## The menu theme is generated from these values by `debug/tools/build_theme.gd`; the
## viewfinder (HudStyle) reads the fonts, HUD_REC, ACCENT and SUCCESS from here.


const BG := Color("#14161A")
const BG_TOP := Color("#1B1E23")
const BG_BOTTOM := Color("#101216")
## Over the 3D stage: dark enough for cream text over a noon sky.
const SCRIM := Color(0.05, 0.06, 0.08, 0.84)

const SURFACE := Color("#1E2126")
const SURFACE_ALT := Color("#262A31")
const SURFACE_PRESSED := Color("#2E333B")
const SURFACE_DISABLED := Color("#1A1C20")

const BORDER := Color("#2E333B")
const BORDER_STRONG := Color("#3A4049")

const TEXT := Color("#F2EFE9")
const TEXT_2 := Color("#A7A39B")
const TEXT_DISABLED := Color("#5F5C57")
const TEXT_ON_ACCENT := Color("#1A0E08")

const ACCENT := Color("#FF6A2B")
const ACCENT_HOVER := Color("#FF8552")
const ACCENT_PRESSED := Color("#E0561C")
const ACCENT_SOFT := Color("#3A2419")

const DANGER := Color("#FF5A4F")
const DANGER_SOFT := Color("#2E1B1B")
const DANGER_HOVER := Color("#3D2020")
const DANGER_BORDER := Color("#7A302B")

const SUCCESS := Color("#69C36F")
const WARN := Color("#FFB020")
const SKY := Color("#7FB7D8")
const SHADOW := Color(0.0, 0.0, 0.0, 0.45)
## Dark halo outside the focus ring, so it reads over any background.
const FOCUS_HALO := Color(0.03, 0.03, 0.04, 0.9)

## Clip grades.
const GRADE_S := Color("#FFC94A")
const GRADE_A := SUCCESS
const GRADE_B := WARN
const GRADE_C := DANGER

const GRAPH_PITCH := Color("#FF6B63")
const GRAPH_ROLL := Color("#69C36F")
const GRAPH_YAW := Color("#7FB7D8")
const GRAPH_GRID := Color("#3A4049")

## In-flight HUD (white on video)
const HUD_TEXT := Color(1, 1, 1, 1)
const HUD_SHADOW := Color(0, 0, 0, 0.35)
const HUD_BOX := Color(0, 0, 0, 0.25)
const HUD_REC := Color("#FF3B30")

const FONT_REGULAR := "res://gui/RecursiveSansLnrSt-Med.otf"
const FONT_BOLD := "res://gui/RecursiveSansLnrSt-Bold.otf"
const FONT_MONO := "res://hud/RecursiveMonoLnrSt-Regular.otf"

const SCREEN_MARGIN_H := 72
const SCREEN_MARGIN_TOP := 56
const SCREEN_MARGIN_BOTTOM := 104


## Color of a clip grade (S, A, B, C).
static func grade_color(grade: String) -> Color:
	match grade:
		"S":
			return GRADE_S
		"A":
			return GRADE_A
		"B":
			return GRADE_B
	return GRADE_C


## WCAG relative luminance, for the contrast checks.
static func luminance(color: Color) -> float:
	var channels: Array[float] = []
	for c: float in [color.r, color.g, color.b]:
		channels.append(c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


## WCAG contrast ratio between two opaque colors (1 to 21).
static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
