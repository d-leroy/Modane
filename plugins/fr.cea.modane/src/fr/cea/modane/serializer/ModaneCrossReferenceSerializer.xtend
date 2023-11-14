package fr.cea.modane.serializer

import com.google.common.collect.Lists
import com.google.inject.Inject
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.conversion.IValueConverterService
import org.eclipse.xtext.conversion.ValueConverterException
import org.eclipse.xtext.linking.impl.LinkingHelper
import org.eclipse.xtext.naming.IQualifiedNameConverter
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.serializer.diagnostic.ISerializationDiagnostic
import org.eclipse.xtext.serializer.diagnostic.ISerializationDiagnostic.Acceptor
import org.eclipse.xtext.serializer.tokens.CrossReferenceSerializer
import org.eclipse.xtext.Assignment
import fr.cea.modane.modane.OverrideFunction

class ModaneCrossReferenceSerializer extends CrossReferenceSerializer {

	@Inject
	LinkingHelper linkingHelper;
	
	@Inject
	IQualifiedNameConverter qualifiedNameConverter;

	@Inject
	IValueConverterService valueConverter;
	
	override String getCrossReferenceNameFromScope(EObject semanticObject, CrossReference crossref, EObject target, IScope scope, Acceptor errors) {
		var String ruleName=linkingHelper.getRuleNameFrom(crossref)
		var boolean foundOne=false
		var List<ISerializationDiagnostic> recordedErrors=null
		for (IEObjectDescription desc : scope.getElements(target)) {
			foundOne=true 
			var String unconverted=qualifiedNameConverter.toString(desc.getName())
			try {
				if (semanticObject instanceof OverrideFunction && crossref.eContainer() instanceof Assignment && (crossref.eContainer() as Assignment).feature == "func") {
					if (unconverted.contains('::')) {
						return unconverted.substring(unconverted.lastIndexOf(':')+1)
					} else {
						return unconverted
					}
				} else {
					return valueConverter.toString(unconverted, ruleName)
				}
			} catch (ValueConverterException e) {
				if (errors !== null) {
					if (recordedErrors === null) recordedErrors=Lists.newArrayList()
					recordedErrors.add(diagnostics.getValueConversionExceptionDiagnostic(semanticObject, crossref, unconverted, e))
				}
			}
		}
		if (errors !== null) {
			if (recordedErrors !== null) for (ISerializationDiagnostic diag : recordedErrors) errors.accept(diag)
			if (!foundOne) errors.accept(diagnostics.getNoEObjectDescriptionFoundDiagnostic(semanticObject, crossref, target, scope))
		}
		return null 
	}
}
