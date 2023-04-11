package fr.cea.modane.uml

import com.google.inject.Inject
import fr.cea.modane.ModaneStandaloneSetupGenerated
import fr.cea.modane.modane.ModaneModel
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.ecore.util.EcoreUtil

class ModaneModelReader {
	@Inject ResourceSet resourceSet
	
	def static createInstance()
	{
		val injector = new ModaneStandaloneSetupGenerated().createInjectorAndDoEMFRegistration
		injector.getInstance(ModaneModelReader)
	}
	
	def readModel(URI modaneFileURI)
	{
		val resource = resourceSet.getResource(modaneFileURI, true)
		resource.getContents().get(0) as ModaneModel
	}
	
	def resolveAll()
	{
		EcoreUtil.resolveAll(resourceSet)
	}
}