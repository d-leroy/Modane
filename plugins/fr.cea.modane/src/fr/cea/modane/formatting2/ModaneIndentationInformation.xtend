package fr.cea.modane.formatting2

import org.eclipse.xtext.formatting.IIndentationInformation

class ModaneIndentationInformation implements IIndentationInformation {
	override getIndentString() {
		'  '
	}
}