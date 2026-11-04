extends RefCounted
## Banorna. Varje punkt är [x, z, höjd, kurvradie]. Banan går runt i den ordning
## punkterna står och sluter sig själv. Start/mål ligger vid första punkten.
## Höjden är relativt "base_y" (hur högt över marken banan ligger).
## "tunnels" är sträckor (punkt i -> i+1) som får tak.
## "open" är sträckor utan räcken, där man kan åka av och falla ner.
## "jumps" är [sträcka, lucka i meter]: en ramp mitt på sträckan, med en lucka (0 = bara ett krön).

const TRACKS := [
	{
		"name": "NEONKVARTEREN",
		"desc": "Kvartersbana som klättrar och går över sig själv. Skarpa hörn, regn.",
		"width": 18.0, "lanes": 3,
		"points": [
			[0, -150, 0, 0], [300, -150, 4, 30], [300, 100, 12, 28], [-100, 100, 22, 25],
			[-100, -300, 14, 28], [-300, -300, 4, 30], [-300, -150, -4, 30],
		],
		"base_y": 45.0,
		"tunnels": [],
		"open": [1, 4],
		"jumps": [[2, 16.0], [0, 0.0]],
		"neon": Color(1.0, 0.15, 0.6), "neon2": Color(0.0, 0.9, 1.0),
		"sky_top": Color(0.04, 0.03, 0.12), "sky_horizon": Color(0.85, 0.32, 0.35),
		"sun": Color(1.0, 0.45, 0.4), "fog": Color(0.32, 0.18, 0.32), "fog_density": 0.0028,
		"rain": true, "city_height": 1.0,
	},
	{
		"name": "VIADUKTEN",
		"desc": "En åtta i två plan. Snabba svep, uppför och utför i orange smog.",
		"width": 18.0, "lanes": 3,
		"points": [
			[-100, -100, 0, 0], [200, 200, 0, 90], [450, 200, 14, 70], [450, -200, 28, 70],
			[200, -200, 24, 90], [-200, 200, 24, 90], [-450, 200, 30, 70], [-450, -200, 10, 70],
			[-200, -200, 0, 90],
		],
		"base_y": 40.0,
		"exposure": 1.12,
		"tunnels": [],
		"open": [3, 7],
		"jumps": [[2, 18.0], [6, 14.0]],
		"neon": Color(1.0, 0.5, 0.05), "neon2": Color(1.0, 0.2, 0.1),
		"sky_top": Color(0.12, 0.06, 0.05), "sky_horizon": Color(1.0, 0.5, 0.2),
		"sun": Color(1.0, 0.55, 0.25), "fog": Color(0.55, 0.3, 0.15), "fog_density": 0.0035,
		"rain": false, "city_height": 1.25,
	},
	{
		"name": "UNDRE STADEN",
		"desc": "Smal och slingrig, korsar sig själv två gånger. Tunnel, regn och grönt neon.",
		"width": 14.0, "lanes": 2,
		"points": [
			[0, 0, 0, 0], [200, 0, 4, 25], [200, 150, 0, 20], [100, 150, 0, 20],
			[100, 260, 2, 20], [320, 260, 10, 30], [320, 420, 20, 25], [-150, 420, 26, 30],
			[-150, 200, 24, 20], [160, 200, 22, 20], [160, 60, 12, 20], [-200, 60, 4, 22],
			[-200, 0, 0, 25],
		],
		"base_y": 32.0,
		"tunnels": [6],
		"open": [1, 8],
		"jumps": [[4, 14.0], [10, 16.0]],
		"neon": Color(0.2, 1.0, 0.4), "neon2": Color(0.7, 0.2, 1.0),
		"sky_top": Color(0.02, 0.04, 0.06), "sky_horizon": Color(0.3, 0.35, 0.4),
		"sun": Color(0.6, 0.7, 0.9), "fog": Color(0.12, 0.18, 0.2), "fog_density": 0.004,
		"rain": true, "city_height": 0.9,
	},
	{
		"name": "STOCKHOLM",
		"desc": "Solig sommardag. Broar över vattnet mellan färgglada stenhus och kopparspiror.",
		"width": 18.0, "lanes": 3,
		"points": [
			[0, 0, 2, 0], [400, 0, 6, 70], [520, 200, 14, 70], [360, 400, 22, 60],
			[100, 380, 26, 50], [60, 150, 22, 45], [40, -180, 14, 50], [-250, -200, 6, 60],
			[-430, -60, 10, 60], [-220, 0, 4, 40],
		],
		"base_y": 16.0,
		"tunnels": [],
		"open": [3, 8],
		"jumps": [[0, 14.0], [5, 0.0]],
		"neon": Color(1.0, 0.8, 0.0), "neon2": Color(0.0, 0.45, 0.85),
		"sky_top": Color(0.22, 0.45, 0.85), "sky_horizon": Color(0.68, 0.8, 0.95),
		"sun": Color(1.0, 0.96, 0.88), "fog": Color(0.72, 0.82, 0.95), "fog_density": 0.0011,
		"rain": false, "city_height": 1.0, "exposure": 0.85, "day": true,
	},
]
