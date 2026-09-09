@tool
extends RefCounted
const DESTINATION := "res://scenes/showcases/substation_atmosphere.tscn"

func build() -> String:
	var g = load("res://scripts/showcases/pump_station_builder.gd").new()
	g.rng.seed = 90726
	g.root = Node3D.new()
	g.root.name = "AbandonedSubstation"
	g.root.set_script(load("res://scripts/showcases/substation_viewer.gd"))
	g.root.set("capture_on_start", true)
	g.concrete = g.weather(Color(0.34,0.36,0.35),Color(0.055,0.072,0.065),0.0)
	g.floor_mat = g.weather(Color(0.25,0.27,0.26),Color(0.045,0.06,0.055),0.0,true)
	g.steel = g.weather(Color(0.15,0.20,0.18),Color(0.04,0.055,0.045),0.65)
	g.rust = g.weather(Color(0.29,0.20,0.11),Color(0.055,0.04,0.028),0.55)
	g.dark = g.plain(Color(0.025,0.03,0.027),0.85)
	g.chalk = g.plain(Color(0.58,0.56,0.47),0.6)
	var ceramic: Material = g.plain(Color(0.35,0.20,0.115),0.24)
	var yellow: Material = g.plain(Color(0.62,0.46,0.13),0.8)
	g.group("BuildingShell")
	g.box("WestFloor",Vector3(-6.5,-0.3,0),Vector3(11,0.6,34),g.floor_mat)
	g.box("EastFloor",Vector3(6.5,-0.3,0),Vector3(11,0.6,34),g.floor_mat)
	g.box("CableTrenchBottom",Vector3(0,-1.4,0),Vector3(2,0.3,34),g.concrete)
	for x: float in [-1.05,1.05]:
		g.box("TrenchSide",Vector3(x,-0.7,0),Vector3(0.15,1.4,34),g.concrete)
	for x: float in [-12.3,12.3]:
		g.box("SideWall",Vector3(x,5.5,0),Vector3(0.6,11,34),g.concrete)
		for z: float in [-15,-8,0,8,15]:
			g.box("Pier",Vector3(x*0.97,5.1,z),Vector3(0.65,10.2,0.85),g.concrete)
	g.box("RearWall",Vector3(0,5.5,-17),Vector3(24.6,11,0.6),g.concrete)
	for x: float in [-9,9]:
		g.box("EntrancePier",Vector3(x,5.5,17),Vector3(6,11,0.6),g.concrete)
	g.box("EntranceHeader",Vector3(0,9,17),Vector3(12,4,0.6),g.concrete)
	g.box("EntryApron",Vector3(0,-0.3,22),Vector3(24,0.6,10),g.floor_mat)
	g.group("CableTrenchAndGrates")
	for x: float in [-0.6,-0.2,0.2,0.6]:
		g.tube("PowerCable",Vector3(x,-0.85,-16),Vector3(x,-0.85,16),0.085,g.dark)
	for z: float in [-15,-12,-9,-6,-3,0,3,6,9,12,15]:
		if z == 9 or z == 6:
			continue
		for j: int in range(18):
			g.box("TrenchGrating",Vector3(0,0.025,z-1.35+j*0.15),Vector3(2.0,0.05,0.035),g.steel)
		for x: float in [-0.93,0.93]:
			g.box("GrateFrame",Vector3(x,0.015,z),Vector3(0.06,0.08,2.85),g.rust)
	for z: float in [5,10]:
		g.rail(Vector3(-1.2,0,z),Vector3(1.2,0,z))
	g.group("RearControlGallery")
	g.box("GalleryFloor",Vector3(0,3.65,-13.7),Vector3(23,0.35,6),g.concrete)
	g.box("GalleryRoof",Vector3(0,7.1,-13.7),Vector3(23,0.22,6),g.concrete)
	g.box("GalleryParapet",Vector3(0,4.3,-10.7),Vector3(23,0.9,0.24),g.concrete)
	for x: float in [-10,-6,-2,2,6,10]:
		g.box("GallerySupport",Vector3(x,1.75,-11),Vector3(0.45,3.5,0.5),g.concrete)
		g.box("WindowMullion",Vector3(x,5.7,-10.65),Vector3(0.06,2.0,0.08),g.rust)
		g.box("Console",Vector3(x,4.4,-12),Vector3(2.5,1.0,0.9),g.steel)
		g.box("ConsoleFace",Vector3(x,5,-11.9),Vector3(2.4,0.35,0.65),g.dark)
		for j: int in range(5):
			g.box("Meter",Vector3(x-0.9+j*0.45,5.03,-11.56),Vector3(0.25,0.17,0.025),g.chalk)
	for y: float in [4.8,5.7,6.7]:
		g.box("WindowTransom",Vector3(0,y,-10.65),Vector3(23,0.05,0.06),g.rust)
	g.stairs(Vector3(-9,0,-2.8),Vector3(-9,3.82,-10.7),2.3,24)
	g.rail(Vector3(-7.7,3.83,-10.7),Vector3(11.3,3.83,-10.7))
	for x: float in [-4.7,4.7]:
		g.group("TransformerWest" if x < 0 else "TransformerEast")
		g.box("OilContainmentPlinth",Vector3(x,0.2,-3),Vector3(4.5,0.4,6),g.concrete)
		g.box("TransformerTank",Vector3(x,1.8,-3),Vector3(2.8,2.7,3.6),g.steel)
		g.box("TankLid",Vector3(x,3.24,-3),Vector3(3.0,0.16,3.8),g.rust)
		for side: float in [-1,1]:
			for j: int in range(15):
				g.box("RadiatorFin",Vector3(x+side*1.65,1.7,-4.6+j*0.23),Vector3(0.5,2.2,0.055),g.steel)
			g.tube("CoolingManifold",Vector3(x+side*1.7,2.85,-4.6),Vector3(x+side*1.7,2.85,-1.3),0.095,g.rust)
		g.tube("ConservatorTank",Vector3(x-1.4,4.3,-4),Vector3(x+1.4,4.3,-4),0.42,g.steel,40)
		for dx: float in [-0.9,0,0.9]:
			g.tube("BushingCore",Vector3(x+dx,3.3,-2),Vector3(x+dx,4.9,-2),0.095,ceramic)
			for j: int in range(9):
				g.ring("PorcelainDisc",Vector3(x+dx,3.5+j*0.14,-2),0.20,0.045,ceramic,Vector3.UP)
			g.tube("Terminal",Vector3(x+dx,4.8,-2),Vector3(x+dx,5.2,-2),0.055,g.rust)
			g.tube("BusRiser",Vector3(x+dx,5.2,-2),Vector3(x+dx,7.8,-2),0.027,g.rust)
		g.box("WarningPlate",Vector3(x,1.7,-1.18),Vector3(0.6,0.42,0.025),yellow)
		g.beam("WarningSlash",Vector3(x-0.14,1.58,-1.15),Vector3(x+0.14,1.82,-1.15),0.045,0.025,g.dark)
		g.rail(Vector3(x-2.2,0,0.3),Vector3(x+2.2,0,0.3))
	g.group("SwitchgearBanks")
	for z: float in [-7,-4.8,-2.6,-0.4,1.8,4,6.2,8.4]:
		g.box("SwitchgearCabinet",Vector3(10.4,1.55,z),Vector3(1.5,3.1,1.95),g.steel)
		g.box("DoorInset",Vector3(9.62,1.55,z),Vector3(0.035,2.8,1.7),g.dark)
		g.box("MeterPlate",Vector3(9.59,2.4,z),Vector3(0.025,0.36,0.65),g.chalk)
		g.tube("IsolatorHandle",Vector3(9.5,1.3,z-0.25),Vector3(9.5,1.3,z+0.25),0.035,g.rust)
		for j: int in range(8):
			g.box("VentLouvre",Vector3(9.57,0.35+j*0.09,z),Vector3(0.045,0.028,1.2),g.steel)
	g.group("RoofAndBusbars")
	for z: float in [-16,-10,-4,2,8,14]:
		g.beam("RoofTie",Vector3(-12,9.3,z),Vector3(12,9.3,z),0.16,0.2,g.rust)
		for x: float in [-10,-6,-2,2,6,10]:
			g.beam("SawtoothRafter",Vector3(x-2,9.3,z),Vector3(x,11.3,z),0.12,0.15,g.steel)
			g.beam("VerticalGlazingFrame",Vector3(x,11.3,z),Vector3(x+2,9.3,z),0.09,0.10,g.steel)
			if g.rng.randf()>0.25:
				var panel: MeshInstance3D = g.box("WeatheredRoofSheet",Vector3(x-1,10.35,z),Vector3(2.8,0.065,5.7),g.steel)
				panel.rotation.z = PI/4.0
	for x: float in [-5.6,-4.7,-3.8,3.8,4.7,5.6]:
		g.tube("OverheadCopperBus",Vector3(x,7.8,-14),Vector3(x,7.8,10),0.04,g.rust)
	g.group("AbandonedMaintenance")
	for i: int in range(95):
		var x: float = g.rng.randf_range(-11,11)
		if absf(x)<1.3:
			continue
		var debris: MeshInstance3D = g.box("ConcreteChip",Vector3(x,0.04,g.rng.randf_range(-10,16)),Vector3(g.rng.randf_range(0.04,0.22),0.06,g.rng.randf_range(0.07,0.30)),g.concrete)
		debris.rotation.y = g.rng.randf()*TAU
	for x: float in [-7,-6]:
		g.box("PackingCrate",Vector3(x,0.4,10),Vector3(0.8,0.8,1.2),g.rust)
	g.lighting()
	var warm := OmniLight3D.new()
	warm.position = Vector3(5,5,-12)
	warm.light_color = Color(1,0.55,0.22)
	warm.light_energy = 2.5
	warm.omni_range = 9
	g.part.add_child(warm)
	var camera := Camera3D.new()
	camera.name = "ReferenceCamera"
	camera.position = Vector3(-4.0,2.5,15)
	camera.look_at_from_position(camera.position,Vector3(0,3,-5))
	camera.fov = 66
	camera.current = true
	g.root.add_child(camera)
	g.assign_owners(g.root)
	for n: MeshInstance3D in g.root.find_children("*","MeshInstance3D",true,false):
		assert(n.mesh != null and n.mesh.get_surface_count()>0,"空网格："+str(n.name))
	var packed := PackedScene.new()
	assert(packed.pack(g.root)==OK)
	var error: Error = ResourceSaver.save(packed,DESTINATION)
	var count: int = g.root.find_children("*","MeshInstance3D",true,false).size()
	g.root.free()
	return "变电站保存=%s 网格=%d" % [error,count]
