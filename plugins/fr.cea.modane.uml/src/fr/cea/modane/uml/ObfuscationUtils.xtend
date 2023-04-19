package fr.cea.modane.uml

import fr.cea.modane.modane.Comment
import java.util.regex.Pattern

class ObfuscationUtils {
	static def obfuscate(Comment description)
	{
		if (description === null || description.comment.nullOrEmpty) return description
		description.comment = obfuscate(description.comment)
		return description
	}
	
	static def obfuscate(String string)
	{
		if (string.nullOrEmpty) return string
		val p = Pattern.compile("[^\\s_]+")
		val result = p.matcher(string).replaceAll([r|
			r.group.toCharArray.map[c|getRandomChar(Character::isUpperCase(c))].join + newArrayOfSize((Math.random * 3) as int).map[getRandomChar(false)].join
		])
		return result
	}
	
	static private def char getRandomChar(boolean uc)
	{
		val int rnd = (Math.random * 26) as int
		val char base = if (uc) 'A' else 'a'
		return (base + rnd) as char
	}
}