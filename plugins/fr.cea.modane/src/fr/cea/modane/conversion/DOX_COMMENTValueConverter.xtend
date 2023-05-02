package fr.cea.modane.conversion
import org.eclipse.xtext.conversion.ValueConverterException;
import org.eclipse.xtext.conversion.impl.AbstractLexerBasedConverter;
import org.eclipse.xtext.nodemodel.INode;

class DOX_COMMENTValueConverter extends AbstractLexerBasedConverter<String>
{
	override String toValue(String string, INode node) throws ValueConverterException {
		val lines = string.split('\n')
		if (lines.size > 2) {
			val contentLines = lines.subList(1, lines.length - 1)
			val result = contentLines
					.map[l|l.replaceFirst('\\s*\\* ', '')]
					.join('\n')
			return result
		} else {
			val result = lines.map[l|l.replaceFirst('\\s*', '')]
				.join('\n').replaceFirst('/\\*!', '').replaceFirst('\\*/', '')
			return result
		}
	}
	
	override String toString(String value) throws ValueConverterException {
		val result = if (!value.nullOrEmpty)
		{
			'''
				/*!
				 «FOR l : value.split('\n') SEPARATOR '\n'»* «l»«ENDFOR»
				 */
			'''
		} else {
			""
		}
		return result
	}
}
