package fr.cea.modane.conversion
import org.eclipse.xtext.conversion.ValueConverterException;
import org.eclipse.xtext.conversion.impl.AbstractLexerBasedConverter;
import org.eclipse.xtext.nodemodel.INode;

class DOX_COMMENTValueConverter extends AbstractLexerBasedConverter<String>
{
	override String toValue(String string, INode node) throws ValueConverterException {
		val result = string.replaceFirst('/\\*!', ' * ')
				.replaceFirst('\\*/', '').split('\n')
				.map[l|l.replaceFirst('\\*', '').strip]
				.join('\n').strip
		return result
	}
	
	override String toString(String value) throws ValueConverterException {
		val result = if (!value.nullOrEmpty)
		{
			'''
				/*!
				 «FOR l : value.split('\n')»
				 * «l»
				 «ENDFOR»
				 */
			'''
		} else {
			""
		}
		return result
	}
}
