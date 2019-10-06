# Types needed to access CastleDB data
class_name CastleDB

class Tile:
	var file := ""
	var size := 0
	var x := 0
	var y := 0
	var stride := 0
	var id := 0
	
	func _init(file ="", size = 0, x = 0, y = 0, stride = 0):
		self.file = file
		self.size = size
		self.x = x
		self.y = y
		self.stride = stride
		self.id = y * stride + x + 1
		