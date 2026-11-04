extends RefCounted
## De sex biltyperna: egenskaper och hur de ser ut.
## Modellerna byggs av enkla delar och kan bytas mot riktiga modeller senare
## (se LÄSMIG.txt). Framåt är -Z, bilens origo ligger i karossens botten.
##
## Delar:
##   ["hull", mat, [zf, zb, wf, wb, yf, yb], [zf, zb, wf, wb, yf, yb], loss]
##        botten- och toppyta: z fram/bak, bredd fram/bak, höjd fram/bak
##   ["box", mat, storlek, position, loss]
##   ["cyl", mat, radie, längd, position, axel ("x"/"y"/"z"), loss]
## mat: "paint", "paint2", "dark", "metal", "glass", "head", "tail", "accent", "amber", "police"
## loss: delen kan lossna vid krockar (true/false)

const TYPES := [
	{
		"name": "VEKTOR", "kenney": ["res://assets/bilar/sedan-sports.glb", 29], "desc": "Allroundbil. Bra på allt, bäst på inget.",
		"top": 72.0, "accel": 11.0, "grip": 1.75, "steer": 30.0, "hp": 100.0, "armor": 1.0, "mass": 1400.0,
		"wheel_r": 0.38, "wheel_w": 0.32, "wheel_x": 0.86, "wheel_zf": -1.45, "wheel_zb": 1.45, "extra_wheels": [],
		"box": Vector3(1.95, 0.85, 4.5), "box_y": 0.55, "paint": Color(0.1, 0.45, 0.85), "accent": Color(0.0, 0.9, 1.0),
		"parts": [
			["hull", "paint", [-2.25, 2.25, 1.8, 1.9, 0.15, 0.15], [-2.22, 2.22, 1.9, 2.0, 0.55, 0.62], false],
			["hull", "paint", [-2.22, 2.22, 1.9, 2.0, 0.55, 0.62], [-2.1, 2.2, 1.7, 1.9, 0.68, 0.84], false],
			["hull", "glass", [-0.75, 1.45, 1.66, 1.8, 0.8, 0.84], [0.0, 1.05, 1.3, 1.45, 1.33, 1.33], false],
			["box", "head", Vector3(1.5, 0.06, 0.06), Vector3(0, 0.62, -2.21), false],
			["box", "tail", Vector3(1.8, 0.08, 0.06), Vector3(0, 0.74, 2.21), false],
			["box", "accent", Vector3(0.04, 0.05, 3.6), Vector3(-0.97, 0.38, 0), false],
			["box", "accent", Vector3(0.04, 0.05, 3.6), Vector3(0.97, 0.38, 0), false],
			["box", "dark", Vector3(1.9, 0.26, 0.28), Vector3(0, 0.27, -2.32), true],
			["box", "dark", Vector3(1.9, 0.26, 0.24), Vector3(0, 0.3, 2.3), true],
			["box", "paint2", Vector3(1.8, 0.06, 0.38), Vector3(0, 1.02, 2.02), true],
			["box", "dark", Vector3(0.12, 0.6, 0.4), Vector3(-0.92, 0.95, 0.4), true],
			["box", "dark", Vector3(0.12, 0.6, 0.4), Vector3(0.92, 0.95, 0.4), true],
		],
	},
	{
		"name": "STILETT", "kenney": ["res://assets/bilar/race-future.glb", 31], "desc": "Låg kilformad sportbil. Snabbast av alla men tål lite.",
		"top": 82.0, "accel": 13.0, "grip": 1.85, "steer": 28.0, "hp": 75.0, "armor": 0.8, "mass": 1150.0,
		"wheel_r": 0.36, "wheel_w": 0.36, "wheel_x": 0.9, "wheel_zf": -1.5, "wheel_zb": 1.5, "extra_wheels": [],
		"box": Vector3(2.0, 0.7, 4.6), "box_y": 0.48, "paint": Color(0.75, 0.05, 0.35), "accent": Color(1.0, 0.2, 0.75),
		"parts": [
			["hull", "paint", [-2.3, 2.3, 1.7, 2.05, 0.15, 0.2], [-2.3, 2.2, 1.6, 2.0, 0.33, 0.7], false],
			["hull", "glass", [-0.65, 1.25, 1.45, 1.7, 0.56, 0.7], [0.1, 0.95, 1.0, 1.3, 1.04, 1.04], false],
			["box", "head", Vector3(0.55, 0.04, 0.05), Vector3(-0.55, 0.38, -2.2), false],
			["box", "head", Vector3(0.55, 0.04, 0.05), Vector3(0.55, 0.38, -2.2), false],
			["box", "tail", Vector3(1.95, 0.06, 0.05), Vector3(0, 0.66, 2.21), false],
			["box", "accent", Vector3(0.05, 0.12, 1.2), Vector3(-1.0, 0.45, 0.6), false],
			["box", "accent", Vector3(0.05, 0.12, 1.2), Vector3(1.0, 0.45, 0.6), false],
			["box", "paint2", Vector3(2.1, 0.05, 0.5), Vector3(0, 1.08, 2.0), true],
			["box", "paint2", Vector3(0.05, 0.42, 0.6), Vector3(-1.0, 0.88, 2.0), true],
			["box", "paint2", Vector3(0.05, 0.42, 0.6), Vector3(1.0, 0.88, 2.0), true],
			["box", "dark", Vector3(1.9, 0.08, 0.4), Vector3(0, 0.12, -2.35), true],
			["box", "dark", Vector3(0.3, 0.2, 0.9), Vector3(-0.75, 0.55, 1.4), true],
		],
	},
	{
		"name": "MASTODONT", "kenney": ["res://assets/bilar/truck.glb", 23], "desc": "Pansrad lastbil. Långsam men nästan omöjlig att stoppa.",
		"top": 61.0, "accel": 8.5, "grip": 1.6, "steer": 26.0, "hp": 180.0, "armor": 1.7, "mass": 2600.0,
		"wheel_r": 0.5, "wheel_w": 0.44, "wheel_x": 1.05, "wheel_zf": -1.8, "wheel_zb": 1.9, "extra_wheels": [0.45],
		"box": Vector3(2.35, 1.6, 5.4), "box_y": 0.95, "paint": Color(0.25, 0.3, 0.22), "accent": Color(1.0, 0.55, 0.0),
		"parts": [
			["hull", "paint", [-2.7, 2.7, 2.3, 2.4, 0.25, 0.25], [-2.6, 2.7, 2.4, 2.4, 0.95, 0.95], false],
			["hull", "paint", [-2.6, -0.4, 2.3, 2.3, 0.95, 0.95], [-1.9, -0.4, 2.1, 2.2, 1.9, 1.9], false],
			["hull", "glass", [-2.31, -2.2, 1.9, 1.9, 1.4, 1.4], [-2.08, -1.97, 1.9, 1.9, 1.72, 1.72], false],
			["hull", "paint2", [-0.4, 2.7, 2.3, 2.3, 0.95, 0.95], [-0.3, 2.6, 2.2, 2.2, 1.75, 1.75], false],
			["box", "head", Vector3(0.5, 0.14, 0.06), Vector3(-0.8, 0.75, -2.67), false],
			["box", "head", Vector3(0.5, 0.14, 0.06), Vector3(0.8, 0.75, -2.67), false],
			["box", "tail", Vector3(0.3, 0.3, 0.06), Vector3(-0.95, 0.75, 2.71), false],
			["box", "tail", Vector3(0.3, 0.3, 0.06), Vector3(0.95, 0.75, 2.71), false],
			["box", "accent", Vector3(2.25, 0.05, 0.05), Vector3(0, 1.77, 2.62), false],
			["box", "metal", Vector3(2.5, 0.42, 0.3), Vector3(0, 0.5, -2.88), true],
			["box", "amber", Vector3(1.4, 0.12, 0.25), Vector3(0, 1.97, -1.2), true],
			["box", "metal", Vector3(0.08, 0.5, 2.0), Vector3(-1.24, 0.62, 0.9), true],
			["box", "metal", Vector3(0.08, 0.5, 2.0), Vector3(1.24, 0.62, 0.9), true],
			["box", "dark", Vector3(2.0, 0.3, 0.3), Vector3(0, 0.4, 2.8), true],
		],
	},
	{
		"name": "GETING", "kenney": ["res://assets/bilar/hatchback-sports.glb", 23], "desc": "Liten och kvick. Svänger på en femöring, går sönder lätt.",
		"top": 67.0, "accel": 12.5, "grip": 2.0, "steer": 36.0, "hp": 70.0, "armor": 0.75, "mass": 900.0,
		"wheel_r": 0.33, "wheel_w": 0.28, "wheel_x": 0.76, "wheel_zf": -1.15, "wheel_zb": 1.15, "extra_wheels": [],
		"box": Vector3(1.65, 0.9, 3.5), "box_y": 0.6, "paint": Color(0.95, 0.75, 0.05), "accent": Color(0.3, 1.0, 0.3),
		"parts": [
			["hull", "paint", [-1.75, 1.75, 1.5, 1.6, 0.2, 0.2], [-1.7, 1.7, 1.6, 1.7, 0.6, 0.66], false],
			["hull", "glass", [-1.2, 1.5, 1.5, 1.6, 0.6, 0.66], [-0.3, 1.1, 1.1, 1.3, 1.3, 1.3], false],
			["box", "dark", Vector3(0.35, 0.02, 3.3), Vector3(-0.3, 0.67, 0), false],
			["box", "dark", Vector3(0.35, 0.02, 3.3), Vector3(0.3, 0.67, 0), false],
			["box", "head", Vector3(1.1, 0.07, 0.05), Vector3(0, 0.5, -1.72), false],
			["box", "tail", Vector3(1.2, 0.08, 0.05), Vector3(0, 0.55, 1.71), false],
			["box", "accent", Vector3(0.04, 0.04, 2.6), Vector3(-0.82, 0.32, 0), false],
			["box", "accent", Vector3(0.04, 0.04, 2.6), Vector3(0.82, 0.32, 0), false],
			["box", "dark", Vector3(1.6, 0.22, 0.22), Vector3(0, 0.28, -1.82), true],
			["box", "dark", Vector3(1.6, 0.22, 0.22), Vector3(0, 0.28, 1.82), true],
			["box", "paint2", Vector3(0.05, 0.35, 0.45), Vector3(-0.6, 1.05, 1.45), true],
			["box", "paint2", Vector3(0.05, 0.35, 0.45), Vector3(0.6, 1.05, 1.45), true],
		],
	},
	{
		"name": "KAB-9", "kenney": ["res://assets/bilar/taxi.glb", 25], "desc": "Hög och kantig taxi. Tålig, med bra grepp i kurvorna.",
		"top": 70.0, "accel": 10.5, "grip": 1.8, "steer": 31.0, "hp": 120.0, "armor": 1.15, "mass": 1500.0,
		"wheel_r": 0.38, "wheel_w": 0.3, "wheel_x": 0.86, "wheel_zf": -1.5, "wheel_zb": 1.5, "extra_wheels": [],
		"box": Vector3(1.95, 1.3, 4.6), "box_y": 0.78, "paint": Color(0.95, 0.6, 0.05), "accent": Color(1.0, 0.85, 0.2),
		"parts": [
			["hull", "paint", [-2.3, 2.3, 1.9, 1.95, 0.2, 0.2], [-2.25, 2.3, 1.95, 2.0, 0.75, 0.8], false],
			["hull", "glass", [-1.4, 2.2, 1.85, 1.9, 0.75, 0.8], [-0.9, 2.1, 1.75, 1.8, 1.6, 1.6], false],
			["hull", "paint", [-0.95, 2.12, 1.78, 1.82, 1.6, 1.6], [-0.9, 2.1, 1.7, 1.75, 1.68, 1.68], false],
			["box", "head", Vector3(1.6, 0.1, 0.06), Vector3(0, 0.62, -2.28), false],
			["box", "tail", Vector3(0.35, 0.35, 0.06), Vector3(-0.75, 0.7, 2.31), false],
			["box", "tail", Vector3(0.35, 0.35, 0.06), Vector3(0.75, 0.7, 2.31), false],
			["box", "dark", Vector3(0.03, 0.15, 3.8), Vector3(-0.99, 0.5, 0), false],
			["box", "dark", Vector3(0.03, 0.15, 3.8), Vector3(0.99, 0.5, 0), false],
			["box", "amber", Vector3(0.9, 0.25, 0.32), Vector3(0, 1.82, 0.3), true],
			["box", "metal", Vector3(1.95, 0.28, 0.26), Vector3(0, 0.3, -2.36), true],
			["box", "metal", Vector3(1.95, 0.28, 0.26), Vector3(0, 0.3, 2.36), true],
			["box", "dark", Vector3(0.1, 0.25, 0.3), Vector3(-1.02, 1.0, -1.2), true],
		],
	},
	{
		"name": "RAPTOR", "kenney": ["res://assets/bilar/race.glb", 29], "desc": "Muskelbil med enorm motor. Sladdar gärna och tål en hel del.",
		"top": 78.0, "accel": 12.0, "grip": 1.55, "steer": 28.0, "hp": 135.0, "armor": 1.3, "mass": 1750.0,
		"wheel_r": 0.43, "wheel_w": 0.4, "wheel_x": 0.9, "wheel_zf": -1.65, "wheel_zb": 1.6, "extra_wheels": [],
		"box": Vector3(2.05, 0.95, 5.0), "box_y": 0.6, "paint": Color(0.08, 0.08, 0.1), "accent": Color(1.0, 0.15, 0.1),
		"parts": [
			["hull", "paint", [-2.5, 2.5, 1.95, 2.1, 0.18, 0.18], [-2.45, 2.45, 2.0, 2.1, 0.6, 0.7], false],
			["hull", "paint", [-2.45, -0.2, 1.9, 2.0, 0.6, 0.7], [-2.3, -0.2, 1.7, 1.9, 0.72, 0.84], false],
			["hull", "glass", [-0.2, 1.9, 1.8, 1.9, 0.7, 0.75], [0.4, 1.6, 1.4, 1.5, 1.25, 1.25], false],
			["hull", "paint", [1.9, 2.45, 1.9, 2.0, 0.7, 0.7], [1.9, 2.45, 1.9, 2.0, 0.84, 0.86], false],
			["box", "head", Vector3(1.7, 0.05, 0.06), Vector3(0, 0.55, -2.51), false],
			["box", "tail", Vector3(1.9, 0.1, 0.06), Vector3(0, 0.7, 2.47), false],
			["box", "accent", Vector3(0.12, 0.02, 4.6), Vector3(-0.25, 0.86, 0), false],
			["box", "accent", Vector3(0.12, 0.02, 4.6), Vector3(0.25, 0.86, 0), false],
			["cyl", "accent", 0.11, 0.3, Vector3(-0.5, 0.32, 2.55), "z", false],
			["cyl", "accent", 0.11, 0.3, Vector3(0.5, 0.32, 2.55), "z", false],
			["box", "metal", Vector3(0.6, 0.22, 0.9), Vector3(0, 0.92, -1.1), true],
			["box", "paint2", Vector3(1.9, 0.1, 0.35), Vector3(0, 0.95, 2.3), true],
			["box", "dark", Vector3(2.0, 0.08, 0.45), Vector3(0, 0.12, -2.6), true],
			["box", "dark", Vector3(0.1, 0.3, 1.3), Vector3(-1.08, 0.4, 0.0), true],
		],
	},
]

## Färger som AI-bilarna lackeras i.
const AI_PAINTS := [
	Color(0.8, 0.1, 0.1), Color(0.1, 0.6, 0.3), Color(0.55, 0.2, 0.8), Color(0.9, 0.9, 0.92),
	Color(0.15, 0.15, 0.18), Color(0.0, 0.5, 0.6), Color(0.9, 0.35, 0.05), Color(0.35, 0.35, 0.4),
]
const AI_ACCENTS := [
	Color(0.0, 1.0, 0.9), Color(1.0, 0.1, 0.6), Color(1.0, 0.8, 0.1), Color(0.4, 0.5, 1.0),
	Color(0.3, 1.0, 0.3), Color(1.0, 0.3, 0.1),
]
const AI_NAMES := ["KAIRO", "NYX", "DEKKER", "VOSS", "ZHAO", "MIRA", "RAX", "OKONKWO", "SOL", "FENG", "IVANA", "TROY"]
