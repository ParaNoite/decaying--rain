class_name RainCleaverWeapon
extends Node3D

const Factory := preload("res://character_test_lab/scripts/model_factory.gd")

var _steel: StandardMaterial3D
var _dark_metal: StandardMaterial3D
var _leather: StandardMaterial3D
var _amber: StandardMaterial3D
var _cyan: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_weapon()


func _build_materials() -> void:
	_steel = Factory.material("Rain-etched steel", Color("60686a"), 0.82, 0.31)
	_dark_metal = Factory.material("Blackened hardware", Color("171d1f"), 0.72, 0.24)
	_leather = Factory.material("Wrapped leather", Color("493126"), 0.0, 0.83)
	_amber = Factory.material("Amber raincloth", Color("bf762c"), 0.08, 0.58)
	_cyan = Factory.material("Charged rain vial", Color("4ec6d5"), 0.18, 0.18, Color("54e8f2"), 4.2)


func _build_weapon() -> void:
	Factory.cylinder(self, "MainShaft", 0.035, 0.043, 1.72, Vector3(0, 0.18, 0), Vector3.ZERO, _dark_metal, 16)
	Factory.cylinder(self, "LowerGrip", 0.052, 0.052, 0.47, Vector3(0, -0.35, 0), Vector3.ZERO, _leather, 14)
	for index: int in range(7):
		Factory.torus(self, "GripWrap%02d" % index, 0.043, 0.058, Vector3(0, -0.54 + index * 0.065, 0), Vector3.ZERO, _amber if index in [1, 5] else _leather)
	Factory.cylinder(self, "BladeCollar", 0.095, 0.11, 0.16, Vector3(0, 0.95, 0), Vector3.ZERO, _dark_metal, 8)
	Factory.blade_mesh(self, "CleaverBlade", Vector3(0.05, 1.34, 0), Vector3.ZERO, _steel)
	Factory.box(self, "BladeSpine", Vector3(0.09, 0.74, 0.11), Vector3(0, 1.30, 0), Vector3.ZERO, _dark_metal)
	Factory.box(self, "BladeInset", Vector3(0.035, 0.45, 0.085), Vector3(0.135, 1.33, -0.005), Vector3(0, 0, -10), _cyan)
	Factory.cylinder(self, "Counterweight", 0.12, 0.075, 0.28, Vector3(0, -0.82, 0), Vector3.ZERO, _steel, 8)
	Factory.cylinder(self, "VialHousing", 0.09, 0.09, 0.23, Vector3(0, 0.78, 0), Vector3(0, 0, 90), _dark_metal, 12)
	Factory.cylinder(self, "RainVial", 0.046, 0.046, 0.26, Vector3(0, 0.78, 0), Vector3(0, 0, 90), _cyan, 16)
	Factory.box(self, "GuardLeft", Vector3(0.28, 0.055, 0.075), Vector3(-0.12, 0.92, 0), Vector3(0, 0, -14), _steel)
	Factory.box(self, "GuardRight", Vector3(0.22, 0.055, 0.075), Vector3(0.11, 0.92, 0), Vector3(0, 0, 18), _steel)
