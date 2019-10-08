tool
extends EditorImportPlugin

const Utils = preload("res://addons/thejustinwalsh.castledb/castledb_utils.gd")

enum Presets { PRESET_DEFAULT }

func get_importer_name():
    return "castledb.importer"

func get_visible_name():
    return "CastleDB"
	
func get_recognized_extensions():
    return ["cdb"]
	
func get_save_extension():
    return "gd"
	
func get_resource_type():
    return "Script"
	
func get_preset_count():
    return Presets.size()
	
func get_preset_name(preset):
    match preset:
        Presets.PRESET_DEFAULT:
            return "Default"
        _:
            return "Unknown"
	
func get_import_options(preset):
    match preset:
        Presets.PRESET_DEFAULT:
            return [{
                       "name": "default",
                       "default_value": false
                    }]
        _:
            return []
			
func get_option_visibility(option, options):
    return true

func import(source_file, save_path, options, r_platform_variants, r_gen_files):
	var file = File.new()
	var err = file.open(source_file, File.READ)
	if err != OK:
		return err
	
	var json = file.get_as_text()
	file.close();
	var json_result = JSON.parse(json)
	if json_result.error != OK:
		return json_result.error
		
	var data = json_result.result
	var namespace = source_file.get_file().get_basename().capitalize()
	
	# Script Header
	var code = "extends Node" + "\n"
	code += "\n"
	code += "const CastleDB = preload(\"res://addons/thejustinwalsh.castledb/castledb_types.gd\")" + "\n"
	code += "\n"
	code += "class_name %s" % namespace + "\n"
	code += "\n"
	
	# Script child class sheets (namespace)
	var sheets:= []
	if data.has("sheets"):
		sheets = data["sheets"]
		for sheet in sheets:
			var name:String = sheet["name"].capitalize().replace(" ", "")
			if name.find("@") >= 0: continue # TODO: Implement subclass list data
			
			var keys = []
			code += "class %s:" % name + "\n"
			code += Utils.gen_column_keys(name, sheet["columns"], sheet["lines"], keys, 1)
			code += "\n"
			code += Utils.gen_column_data(source_file.get_base_dir(), name, sheet["columns"], sheet["lines"], keys, 1)
			code += "\n"
	
	for sheet in sheets:
		var name = sheet["name"].capitalize().replace(" ", "")
		if name.find("@") >= 0: continue # TODO: Implement subclass list data
		
		code +=  "var %s := %s.new()" % [name.to_lower(), name] + "\n"
	
	var main_script = GDScript.new();
	main_script.set_source_code(code)
	
	return ResourceSaver.save("%s.%s" % [save_path, get_save_extension()], main_script)
	
	
	
	
	
	