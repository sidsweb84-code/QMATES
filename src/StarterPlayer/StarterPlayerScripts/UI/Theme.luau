--[[
	Theme
	Visual language for every interface: deep navy "card binder" panels with
	bright rarity accents, rounded corners and gold highlights.
]]

local C = Color3.fromRGB

local Theme = {}

Theme.Colors = {
	Backdrop = C(8, 9, 20),
	Panel = C(26, 29, 56),
	PanelDark = C(18, 20, 40),
	PanelLight = C(40, 44, 82),
	PanelHover = C(52, 57, 104),
	Stroke = C(78, 86, 150),
	StrokeLight = C(120, 130, 200),
	Text = C(255, 255, 255),
	SubText = C(184, 190, 228),
	Muted = C(118, 124, 165),
	Accent = C(255, 196, 64),
	AccentDark = C(214, 140, 20),
	Blue = C(98, 190, 255),
	BlueDark = C(40, 110, 230),
	Success = C(86, 220, 120),
	SuccessDark = C(30, 150, 80),
	Danger = C(255, 78, 100),
	DangerDark = C(190, 30, 60),
	Warning = C(255, 178, 60),
	Purple = C(176, 110, 255),
	PurpleDark = C(110, 50, 210),
	Cash = C(130, 255, 150),
	Token = C(255, 212, 80),
	Event = C(255, 140, 60),
}

Theme.Fonts = {
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
	Regular = Enum.Font.GothamMedium,
}

Theme.Radius = 14

-- Button styles: { top gradient, bottom gradient, stroke }
Theme.ButtonStyles = {
	Primary = { C(255, 214, 90), C(240, 150, 30), C(150, 80, 10) },
	Blue = { C(110, 200, 255), C(40, 120, 240), C(20, 60, 150) },
	Success = { C(110, 240, 140), C(30, 170, 80), C(15, 90, 40) },
	Danger = { C(255, 110, 120), C(210, 40, 70), C(120, 15, 35) },
	Purple = { C(200, 140, 255), C(120, 60, 220), C(60, 25, 120) },
	Secondary = { C(70, 78, 140), C(46, 52, 98), C(24, 27, 55) },
	Ghost = { C(40, 44, 82), C(32, 36, 68), C(78, 86, 150) },
}

-- Virtual design resolution (see UI/Root): layouts are authored at this size.
Theme.DesignSize = Vector2.new(1100, 680)

return Theme
