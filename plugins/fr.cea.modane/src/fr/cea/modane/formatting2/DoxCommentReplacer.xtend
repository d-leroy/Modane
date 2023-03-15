package fr.cea.modane.formatting2

import org.eclipse.xtext.formatting2.ITextReplacer
import org.eclipse.xtext.formatting2.ITextReplacerContext
import org.eclipse.xtext.formatting2.regionaccess.ITextSegment

class DoxCommentReplacer implements ITextReplacer {
	
	val ITextSegment doxComment
	static val char prefix = '*'
	
	new(ITextSegment doxComment)
	{
		this.doxComment = doxComment
	}

	override createReplacements(ITextReplacerContext context) {
		val access = doxComment.textRegionAccess
		val lines = doxComment.lineRegions
		val oldIndentation = lines.get(0).indentation.text
		val indentationString = context.indentationString
		val newIndentation = indentationString + " " + prefix + " "
		for (var i = 1; i < lines.size - 1; i++) {
			val line = lines.get(i)
			val text = line.text
			val prefixOffset = prefixOffset(text)
			val target =
					if (prefixOffset >= 0)
						access.regionForOffset(line.offset, prefixOffset + 1)
					else if (text.startsWith(oldIndentation))
						access.regionForOffset(line.offset, oldIndentation.length)
					else
						access.regionForOffset(line.offset, 0)
			context.addReplacement(target.replaceWith(newIndentation))
		}
		if (lines.size > 1) {
			val line = lines.get(lines.size - 1)
			context.addReplacement(line.indentation.replaceWith(indentationString + " "))
		}
		return context
	}

	private def int prefixOffset(String string) {
		for (var i = 0; i < string.length; i++) {
			val charAt = string.charAt(i)
			if (prefix.equals(charAt)) {
				val j = i + 1
				if (j < string.length && Character.isWhitespace(string.charAt(j)))
					return j
				else
					return i
			}
			if (!Character.isWhitespace(charAt))
				return -1
		}
		return -1
	}

	override getRegion() {
		return doxComment
	}
	
}