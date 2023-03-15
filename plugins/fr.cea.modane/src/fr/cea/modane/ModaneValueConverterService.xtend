package fr.cea.modane

import com.google.inject.Inject
import fr.cea.modane.conversion.DOX_COMMENTValueConverter
import org.eclipse.xtext.common.services.DefaultTerminalConverters
import org.eclipse.xtext.conversion.IValueConverter
import org.eclipse.xtext.conversion.ValueConverter

class ModaneValueConverterService extends DefaultTerminalConverters {
	@Inject
	var DOX_COMMENTValueConverter terminalsDescriptionValueConverter

	@ValueConverter(rule = "fr.cea.modane.Modane.DOX_COMMENT")
	def IValueConverter<String> TerminalsDOX_COMMENT() {
		terminalsDescriptionValueConverter
	}
}