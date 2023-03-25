class_name AnimaStrings

static func from_camel_to_snack_case(string:String) -> String:
	var result = PackedStringArray()
	var is_first_char = true

	for character in string:
		if character == character.to_lower() or is_first_char:
			result.append(character.to_lower())
		else:
			result.append('_' + character.to_lower())

		is_first_char = false

	return ''.join(result).replace(' ', '_')


static func sanitize_meta_key(string: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\W")

	return regex.sub(string, "")
	
