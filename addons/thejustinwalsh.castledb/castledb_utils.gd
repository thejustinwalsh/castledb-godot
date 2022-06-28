enum { CDB_ID, CDB_STRING, CDB_BOOL, CDB_INT, CDB_FLOAT, CDB_ENUM, CDB_REF, CDB_COLOR, CDB_FILE, CDB_TILE, CDB_NIL }

static func get_column_type(column):
	var type: String = str(column["typeStr"].to_int())
	match type:
		"0":
			return CDB_ID
		"1":
			return CDB_STRING
		"2":
			return CDB_BOOL
		"3":
			return CDB_INT
		"4":
			return CDB_FLOAT
		"5":
			return CDB_ENUM
		"6":
			return CDB_REF
		"11":
			return CDB_COLOR
		"13":
			return CDB_FILE
		"14":
			return CDB_TILE
		_:
			return CDB_NIL

static func gen_castle_types() -> String:
	return ""

static func gen_column_keys(name:String, columns:Array, lines:Array, outKeys:Array, indent:int) -> String:
	var tab = ""
	for i in indent:
		tab += "\t"

	var code = ""
	var unique_id = ""
	for column in columns:
		if get_column_type(column) == CDB_ID:
			unique_id = column["name"]
		elif get_column_type(column) == CDB_ENUM:
			code += tab + "enum %s {" % column["name"].capitalize().strip_edges().replacen(" ", "")
			var type = column["typeStr"].split(":", true, 1)
			var possible_value = type[type.size() - 1].split(",")
			for i in possible_value.size():
				if i > 0:
					code += ", "
				code += possible_value[i].capitalize().strip_edges().to_upper().replacen(" ", "_")
			code += "}" + "\n"
	code += "\n"

	if unique_id != "":
		for line in lines:
			var id = line[unique_id]
			outKeys.push_back(id)
			code += tab + "const %s := \"%s\"" % [id, id] + "\n"
	return code

static func gen_column_data(path:String, name:String, columns:Array, lines:Array, keys:Array, indent:int) -> String:
	var tab = ""
	for i in indent:
		tab += "\t"

	var code = tab + "class %sRow:" % name + "\n"
	var params = []
	var types = []
	for column in columns:
		var type = get_column_type(column)
		match type:
			CDB_ID, CDB_STRING, CDB_FILE:
				code += tab + "\t" + "var %s := \"\"" % column["name"] + "\n"
				params.push_back(column["name"])
				types.push_back(type)
			CDB_BOOL:
				code += tab + "\t" + "var %s := false" % column["name"] + "\n"
				params.push_back(column["name"])
				types.push_back(type)
			CDB_INT, CDB_ENUM:
				code += tab + "\t" + "var %s := 0" % column["name"] + "\n"
				params.push_back(column["name"])
				types.push_back(type)
			CDB_FLOAT:
				code += tab + "\t" + "var %s := 0.0" % column["name"] + "\n"
				params.push_back(column["name"])
				types.push_back(type)
			CDB_COLOR:
				code += tab + "\t" + "var %s := Color()" % column["name"] + "\n"
				params.push_back(column["name"])
				types.push_back(type)
			CDB_TILE:
				code += tab + "\t" + "var %s := CastleDB.Tile.new()" % column["name"] + "\n"
				params.push_back(column["name"])
				types.push_back(type)
			CDB_REF:
				var referenced_sheet_name = column["typeStr"]
				referenced_sheet_name.erase(0, 2)
				referenced_sheet_name = capitalize_name(referenced_sheet_name)
				code += tab + "\t" + "var %s := \"\"" % column["name"] + "\n"
				params.push_back(column["name"])
				types.push_back("%s:%s" % [str(type), referenced_sheet_name])
			_:
				pass

	# Init func
	code += tab + "\t\n"
	code += tab + "\t" + "func _init("
	for i in params.size():
		var param = params[i]
		var type = types[i]
		if i > 0: code += ", "
		match type:
			CDB_ID, CDB_STRING, CDB_FILE:
				code += "%s = \"\"" % params[i]
			CDB_BOOL:
				code += "%s = false" % params[i]
			CDB_INT, CDB_ENUM:
				code += "%s = 0" % params[i]
			CDB_FLOAT:
				code += "%s = 0.0" % params[i]
			CDB_COLOR:
				code += "%s = Color()" % params[i]
			CDB_TILE:
				code += "%s = CastleDB.Tile.new()" % params[i]
			_:
				# Check for reference
				if str(CDB_REF) in type:
					code += "%s = \"\"" % params[i]
					continue
				code += "%s = \"\"" % params[i]
	code += "):" + "\n"
	for param in params:
		code += tab +"\t\t" + "self.%s = %s" % [param, param] + "\n"
	code += tab + "\n"

	# Data
	if lines.size() > 0:
		code += tab + "var all = ["
		for i in lines.size():
			var line = lines[i];
			code += "%sRow.new(" % name
			for j in params.size():
				var param = params[j]
				var type = types[j]
				if line.has(param):
					if j > 0: code += ", "
					match type:
						CDB_ID:
							code += "%s" % line[param]
						CDB_BOOL:
							code += "%s" % "true" if line[param] else "false"
						CDB_INT, CDB_ENUM:
							code += "%d" % line[param]
						CDB_FLOAT:
							code += "%f" % line[param]
						CDB_STRING, CDB_FILE:
							code += "\"%s\"" % line[param]
						CDB_COLOR:
							code += "Color(%d)" % line[param]
						CDB_TILE:
							var img = Image.new()
							img.load(path + "/" + line[param]["file"])
							var stride = int(img.get_width() / line[param]["size"])
							code += "CastleDB.Tile.new(\"%s\", %s, %s, %s, %s)" % [ line[param]["file"], line[param]["size"], line[param]["x"], line[param]["y"], stride ]
						_:
							if str(CDB_REF) in type:
								var referenced_sheet_name = type
								referenced_sheet_name.erase(0, 2)
								code += "%s.%s" % [referenced_sheet_name, line[param]]
								continue
							code += "\"%s\"" % line[param]
			code += ")"
			if i != lines.size() - 1:
				code += ", "
		code += "]" + "\n"

	# Index
	if keys.size() > 0:
		code += tab + "var index = {"
		for i in keys.size():
			code += "%s: %s" % [keys[i], i]
			if i != keys.size() - 1:
				code += ", "
		code += "}" + "\n"
		code += tab + "\n"

	# Get function
	code += tab + "func get(id:String) -> %sRow:" % name + "\n"
	code += tab + "\t" + "if index.has(id):" + "\n"
	code += tab + "\t\t" + "return all[index[id]]" + "\n"
	code += tab + "\t" + "return null" + "\n"

	# Get index function
	code += "\n"
	code += tab + "func get_index(idx:int) -> %sRow:" % name + "\n"
	code += tab + "\t" + "if idx < all.size():" + "\n"
	code += tab + "\t\t" + "return all[idx]" + "\n"
	code += tab + "\t" + "return null" + "\n"

	return code

static func capitalize_name(var name) -> String:
	return name.capitalize().replace(" ", "")
