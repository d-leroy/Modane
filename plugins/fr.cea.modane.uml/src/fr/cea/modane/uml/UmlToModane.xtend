/*******************************************************************************
 * Copyright (c) 2022 CEA
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.modane.uml

import com.google.inject.Inject
import fr.cea.modane.ModaneStandaloneSetupGenerated
import fr.cea.modane.Utils
import fr.cea.modane.generator.ModaneGeneratorMessageDispatcher
import fr.cea.modane.generator.ModaneGeneratorMessageDispatcher.MessageType
import fr.cea.modane.modane.ArgDefinition
import fr.cea.modane.modane.Direction
import fr.cea.modane.modane.EntryPoint
import fr.cea.modane.modane.Enumeration
import fr.cea.modane.modane.EnumerationLiteral
import fr.cea.modane.modane.Function
import fr.cea.modane.modane.Interface
import fr.cea.modane.modane.ItemFamily
import fr.cea.modane.modane.ItemGroupType
import fr.cea.modane.modane.ItemType
import fr.cea.modane.modane.Legacy
import fr.cea.modane.modane.ModaneFactory
import fr.cea.modane.modane.ModaneModel
import fr.cea.modane.modane.Module
import fr.cea.modane.modane.OverrideFunction
import fr.cea.modane.modane.Pty
import fr.cea.modane.modane.PtyMultiplicity
import fr.cea.modane.modane.PtyOrArgType
import fr.cea.modane.modane.Service
import fr.cea.modane.modane.ServiceOrModule
import fr.cea.modane.modane.SimpleType
import fr.cea.modane.modane.Struct
import fr.cea.modane.modane.UserCategory
import fr.cea.modane.modane.VarDefinition
import fr.cea.modane.modane.VarReference
import fr.cea.modane.modane.Variable
import java.util.ArrayList
import java.util.List
import java.util.Set
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.emf.ecore.xmi.XMLResource
import org.eclipse.uml2.uml.Class
import org.eclipse.uml2.uml.Model
import org.eclipse.uml2.uml.NamedElement
import org.eclipse.uml2.uml.Operation
import org.eclipse.uml2.uml.Package
import org.eclipse.uml2.uml.Parameter
import org.eclipse.uml2.uml.ParameterDirectionKind
import org.eclipse.uml2.uml.PrimitiveType
import org.eclipse.uml2.uml.Profile
import org.eclipse.uml2.uml.Property
import org.eclipse.uml2.uml.Stereotype
import org.eclipse.uml2.uml.Type
import org.eclipse.xtext.resource.SaveOptions

import static extension fr.cea.modane.ModaneStringExtensions.*
import static extension fr.cea.modane.uml.ArcaneProfileExtensions.*
import static extension fr.cea.modane.uml.EObjectExtensions.*
import static extension fr.cea.modane.uml.ElementExtensions.*
import static extension fr.cea.modane.uml.ModelMetricsExtensions.*

class UmlToModane
{
	@Inject ResourceSet resourceSet
	@Inject ModaneGeneratorMessageDispatcher messageDispatcher

	Profile profile
	UserCategory defaultCategory

	extension PackageExtensions pe
	extension ClassExtensions ce
	extension InterfaceExtensions ie
	extension OperationExtensions oe
	extension EnumerationLiteralExtensions ele
	
	Set<URI> resourceURICache
	
	def setResourceURICache(Set<URI> cache) {
		resourceURICache = cache
	}

	def static createInstance()
	{
		val injector = new ModaneStandaloneSetupGenerated().createInjectorAndDoEMFRegistration
		injector.getInstance(UmlToModane)
	}

	def readModel(URI umlFileURI)
	{
		UmlUtils::readUmlModel(umlFileURI)
	}
	
	def getMessageDispatcher()
	{
		messageDispatcher
	}
	
	def generate(Model umlModel, String absoluteOutputPath, String packagePrefix, boolean writeModaneFiles, boolean obfuscate)
	{
		val startTime = System.currentTimeMillis

		messageDispatcher.post(MessageType.Exec, "Starting UML to Modane model transformation")
		val resources = createModaneModelsResources(umlModel, absoluteOutputPath, packagePrefix, writeModaneFiles, obfuscate)
		val afterConvertionTime = System.currentTimeMillis
		messageDispatcher.post(MessageType.Exec, "UML to Modane model transformation ended in " + (afterConvertionTime-startTime)/1000.0 + "s")
		
		return resources
	}

	def List<ModaneModel> createModaneModels(Model umlModel, String packagePrefix)
	{
		profile = umlModel.getAppliedProfile("ArcaneProfile")
		defaultCategory = ModaneFactory::eINSTANCE.createUserCategory => [
			name = "User"
			description = ModaneFactory::eINSTANCE.createComment => [
				comment = "Default category"
			]
		]

		pe = new PackageExtensions(packagePrefix)
		ce = new ClassExtensions(profile)
		ie = new InterfaceExtensions(profile)
		oe = new OperationExtensions(profile)
		ele = new EnumerationLiteralExtensions(profile)

		val models = new ArrayList<ModaneModel>

		// On a besoin d'un ModaneModel pour stocker la catégorie par défaut
		models += ModaneFactory::eINSTANCE.createModaneModel => [name = "CategoriesModel" elements += defaultCategory]

		models += umlModel.toModaneModel(models)
		models.forEach[m|m.eAllContents.filter(fr.cea.modane.modane.NamedElement).forEach[e|e.name = e.name.strip]]
		messageDispatcher.post(MessageType.Exec, '    ' + umlModel.usedUmlEclass.size + " UML classes and " + models.totalNbElements + " model elements")
		messageDispatcher.post(MessageType.Exec, '    List of models: ')
		for (m : models)
			if (!m.name.nullOrEmpty)
				messageDispatcher.post(MessageType.Exec, '        - ' + m.name)

		return models
	}

	/**
	 * Il faut d'abord créer toutes les resources dans le resourceSet puis
	 * les sauvegarder pour éviter les problèmes de résolution des dépendances.
	 * Les resources ne contenant pas d'éléments ne sont pas créées.
	 * Le outputPath est utile pour les resource même si les fichiers ne sont pas écrits.
	 * Le outputPath est absolu pour pouvoir fonctionner hors d'Eclipse.
	 * On va donc construire une URI de type file.
	 */
	def createModaneModelsResources(Model umlModel, String absoluteOuputPath, String packagePrefix, boolean writeFiles, boolean obfuscate)
	{
		val models = createModaneModels(umlModel, packagePrefix)
		models.forEach[x | x.addResource(absoluteOuputPath, Utils.FileExtension, resourceSet)]
		EcoreUtil::resolveAll(resourceSet)

		if (writeFiles)
		{
			for (r : resourceSet.resources)
			{
				val uri = r.URI.toString
				if (!resourceURICache.exists[resURI|resURI.toString == uri]) {
					r.allContents.filter(NamedElement).forEach[e|e.name = e.name.trim]
					messageDispatcher.post(MessageType.Exec, 'Writing resource: ' + r.URI.toString)
					r.save(saveOptions)
				}
			}
		}

		return resourceSet.resources
	}

	private def getSaveOptions()
	{
		val builder = SaveOptions::newBuilder
		builder.format
		//builder.noValidation
		val saveOptions = builder.options.toOptionsMap
		saveOptions.put(XMLResource::OPTION_LINE_WIDTH, 160)
		return saveOptions
	}

	/** Si le modèle contient des éléments, création d'un fichier Modane et ajout à la liste 'files' */
	private def addResource(ModaneModel model, String absoluteOutputPath, String fileExt, ResourceSet rSet)
	{
		if (!model.elements.empty)
		{
			val uri = URI::createFileURI(absoluteOutputPath + '/' + model.getFileName(fileExt))
			val resource = rSet.createResource(uri)
			resource.contents.add(model)
		}
	}

	private def getFileName(ModaneModel it, String fileExt)
	{
		if (name.nullOrEmpty) 'default' + fileExt
		else name + '/' + name + fileExt
	}

	private def ModaneModel create ModaneFactory::eINSTANCE.createModaneModel toModaneModel(Package p, List<ModaneModel> models)
	{
		name = p.fullName
		// creation des elements
		// Le sortBy est fait pour le Jira MODANE-197 qui contient de longues explications...
		for ( m : p.ownedMembers.filter[x | !x.name.nullOrEmpty].sortBy[x | x.name] )
		{
			// pas de creation des variables abtraites
			if (m.isStereotypeApplied(profile.variableSt) && !(m as Class).abstract) elements += (m as Class).toVariable
			else if (m.isStereotypeApplied(profile.enumSt)) elements += (m as org.eclipse.uml2.uml.Enumeration).toEnumeration
			else if (m.isStereotypeApplied(profile.structSt)) elements += (m as Class).toStruct
			else if (m.isStereotypeApplied(profile.interfSt)) elements += (m as org.eclipse.uml2.uml.Interface).toInterface
			else if (m.isStereotypeApplied(profile.serviceSt)) elements += (m as Class).toService
			else if (m.isStereotypeApplied(profile.moduleSt)) elements += (m as Class).toModule
			else if (m.isStereotypeApplied(profile.legacySt)) elements += (m as Class).toLegacy
			else if (m.isStereotypeApplied(profile.itemFamilySt)) elements += (m as Class).toItemFamily
			// Les packages insérés par Magicdraw possèdent le stéréotype AuxiliaryResource
			// alors que ceux qui nous intéressent ne sont pas stéréotypés.
			else if (m instanceof Package && m.appliedStereotypes.empty) models += (m as Package).toModaneModel(models)
		}
	}

	private def Variable create ModaneFactory::eINSTANCE.createVariable toVariable(Class c)
	{
		name = c.name.separateWithDefault
		axlName = c.name
		description = c.description
		dump = c.varDump
		executionDepend = c.varExecDep
		needSync = c.varNeedSync
		restore = c.varRestore
		multiplicity = c.varMult
		supports += c.varSupport
		type = c.varType
		family = c.varItemFamily?.toItemFamily
	}

	private def ItemFamily create ModaneFactory::eINSTANCE.createItemFamily toItemFamily(Class c)
	{
		name = c.name
		support = c.itemFamilySupport
	}

	private def Struct create ModaneFactory::eINSTANCE.createStruct toStruct(Class c)
	{
		name = c.name
		description = c.description
		for (p : c.parentStructs) parents += (p as Class).toStruct
		for (p : c.pties) properties += (p as Property).toPty
	}

	private def Legacy create ModaneFactory::eINSTANCE.createLegacy toLegacy(Class c)
	{
		name = c.name
		description = c.description
		originNamespace = c.legacyNamespace
		originFile = c.legacyFile
	}

	private def Pty create ModaneFactory::eINSTANCE.createPty toPty(Property p)
	{
		name = p.name.separateWithDefault
		description = p.description
		if (p.lowerBound == 0)
		{
			if (p.upperBound == -1) multiplicity = PtyMultiplicity::ZERO_STAR
			else multiplicity = PtyMultiplicity::ZERO_ONE
		}
		else
		{
			if (p.upperBound == -1) multiplicity = PtyMultiplicity::ONE_STAR
			else multiplicity = PtyMultiplicity::ONE_ONE
		}
		if (p.defaultValue !== null) defaultValue = p.defaultValue.stringValue.replaceAll('::','.')
		type = p.type.toArgType
		namefr = p.getNameFr(profile.ptySt)
		if (p.isUserEnabled(profile.ptySt)) categories += defaultCategory
	}

	private def ArgDefinition create ModaneFactory::eINSTANCE.createArgDefinition toArgument(Parameter p)
	{
		name = p.name.separateWithDefault
		multiple = (p.upperBound == -1 )
		type = p.type.toArgType
		if (p.defaultValue !== null) defaultValue = p.defaultValue.stringValue.replaceAll('::','.')
		if (p.direction == ParameterDirectionKind::OUT_LITERAL) direction = Direction::OUT
		else if (p.direction == ParameterDirectionKind::INOUT_LITERAL) direction = Direction::INOUT
		else direction = Direction::IN
	}

	private def Enumeration create ModaneFactory::eINSTANCE.createEnumeration toEnumeration(org.eclipse.uml2.uml.Enumeration e)
	{
		name = e.name
		description = e.description
		for (l : e.ownedLiterals.filter(x | x.isStereotypeApplied(profile.enumLiteralSt))) literals += l.toEnumerationLiteral
	}

	private def EnumerationLiteral create ModaneFactory::eINSTANCE.createEnumerationLiteral toEnumerationLiteral(org.eclipse.uml2.uml.EnumerationLiteral l)
	{
		name = l.name
		val stringValue = l.value
		if (stringValue.nullOrEmpty)
			valueProvided = false
		else try
		{
			value = Integer.parseInt(stringValue)
			valueProvided = true
		} catch (NumberFormatException e) {
			valueProvided = false
		}
		description = l.description
		namefr = l.getNameFr(profile.enumLiteralSt)
		if (l.isUserEnabled(profile.enumLiteralSt)) categories += defaultCategory
	}

	private def Interface create ModaneFactory::eINSTANCE.createInterface toInterface(org.eclipse.uml2.uml.Interface i)
	{
		name = i.name
		description = i.description
		for (p : i.parentInterfaces) parents += (p as org.eclipse.uml2.uml.Interface).toInterface
		for (p : i.pties) properties += (p as Property).toPty
		for (f : i.funcs) functions += f.toFunction
	}

	private def Module create ModaneFactory::eINSTANCE.createModule toModule(Class c)
	{
		init(it, c, profile.moduleSt)
		for (f : c.entryPoints) entryPoints += f.toEntryPoint
	}

	private def Service create ModaneFactory::eINSTANCE.createService toService(Class c)
	{
		init(it, c, profile.serviceSt)
		type = c.serviceType
		singleton = c.isSingleton
	}

	private def init(ServiceOrModule it, Class c, Stereotype s)
	{
		name = c.name
		namefr = c.getNameFr(s)
		description = c.description
		if (c.isUserEnabled(s)) categories += defaultCategory
		for (i : c.implementedInterfaces) interfaces += i.toInterface
		for (p : c.pties) properties += (p as Property).toPty

		// override fonctions et fonctions
		for (f : c.funcs)
		{
			// recherche d'une méthode de même nom dans une interface
			val umlInterface = c.implementedInterfaces.findFirst(i | i.allOperations.exists(o | o.name == f.name))
			
			if (umlInterface === null)
			{
				// pas d'opération dans les interfaces => c'est une fonction
				functions += f.toFunction 
			}
			else
			{
				val interfaceOp = umlInterface.allOperations.findFirst[o | o.name == f.name]
				overrideFuncs += f.toOverrideFunction(interfaceOp.toFunction)
			}
		}
	}

	private def OverrideFunction create ModaneFactory::eINSTANCE.createOverrideFunction toOverrideFunction(Operation o, Function interfaceFunc)
	{
		description = o.description
		func = interfaceFunc
		for (v : o.funcInNotOutVars) inVars += v.toUmlClass.toVariable.toVarReference
		for (v : o.funcOutVars)
		{
			if (o.funcInVars.contains(v))
			{
				inOutVars += v.toUmlClass.toVariable.toVarReference
			}
			else
			{
				outVars += v.toUmlClass.toVariable.toVarReference
			}
		}
	}

	private def EntryPoint create ModaneFactory::eINSTANCE.createEntryPoint toEntryPoint(Operation o)
	{
		name = o.name
		description = o.description
		location = o.epLocation
		autoLoad = o.epAutoLoad
		for (v : o.epInNotOutVars) inVars += v.toUmlClass.toVariable.toVarReference
		for (v : o.epOutVars)
		{
			if (o.epInVars.contains(v))
			{
				inOutVars += v.toUmlClass.toVariable.toVarReference
			}
			else
			{
				outVars += v.toUmlClass.toVariable.toVarReference
			}
		}
		for (cf : o.epCalledFuncs) calls += cf.toOperation.toFunction
	}

	private def Function create ModaneFactory::eINSTANCE.createFunction toFunction(Operation o)
	{
		name = o.name
		description = o.description
		sequential = !o.funcParallel
		support = o.funcSupport
		const = o.funcConst
		for (v : o.funcInNotOutVars)
		{
			val c = v.toUmlClass
			if (c.abstract) args += c.toVarDefinition(true, false)
			else inVars += c.toVariable.toVarReference
		}
		for (v : o.funcOutVars)
		{
			val c = v.toUmlClass
			val isIn = o.funcInVars.contains(v)
			if (c.abstract) args += c.toVarDefinition(isIn, true)
			else
			{
				if (isIn)
				{
					inOutVars += c.toVariable.toVarReference
				}
				else
				{
					outVars += c.toVariable.toVarReference
				}
			}
		}
		for ( p : o.inOutParameters) args += p.toArgument
		for (cf : o.funcCalledFuncs) calls += cf.toOperation.toFunction

		// s'il y a un paramètre retour => type de la fonction
		if (o.hasReturnParameter)
		{
			type = o.returnParameter.type.toArgType
			multiple = (o.returnParameter.upperBound == -1)
		}
	}

	private def VarDefinition toVarDefinition(Class c, boolean isIn, boolean isOut)
	{
		val it = ModaneFactory::eINSTANCE.createVarDefinition
		name = c.name.separateWithDefault
		multiplicity = c.varMult
		supports += c.varSupport
		type = c.varType
		if (isIn && isOut) direction = Direction::INOUT
		else if (isOut) direction = Direction::OUT
		else direction = Direction::IN
		return it
	}

//	private def VarReference toVarReference(Variable v, boolean isIn, boolean isOut)
//	{
//		val it = ModaneFactory::eINSTANCE.createVarReference
//		if (isIn && isOut) direction = Direction::INOUT
//		else if (isOut) direction = Direction::OUT
//		else direction = Direction::IN
//		variable = v
//		return it
//	}

	private def VarReference toVarReference(Variable v)
	{
		ModaneFactory::eINSTANCE.createVarReference => [
			variable = v
		]
	}

	private def PtyOrArgType toArgType(Type type)
	{
		if (type instanceof PrimitiveType) return type.toArgType
		else
		{
			// c'est une reference
			val t = ModaneFactory::eINSTANCE.createReference
			switch (type)
			{
				org.eclipse.uml2.uml.Enumeration : t.target = type.toEnumeration
				org.eclipse.uml2.uml.Interface : t.target = type.toInterface
				Class case type.appliedStereotypes.contains(profile.legacySt) : t.target = type.toLegacy
				Class : t.target = type.toStruct
			}
			return t
		}
	}

	private def PtyOrArgType toArgType(PrimitiveType type)
	{
		if (type.name == 'Boolean')
		{
			ModaneFactory::eINSTANCE.createSimple => [type = SimpleType::BOOL]
		}
		else if (SimpleType::getByName(type.name) === null)
		{
			if (type.name.endsWith('Group'))
			{
				ModaneFactory::eINSTANCE.createItemGroup => [type = ItemGroupType::getByName(type.name)]
			}
			else
			{
				ModaneFactory::eINSTANCE.createItem => [type = ItemType::getByName(type.name)]
			}
		}
		else
		{
			ModaneFactory::eINSTANCE.createSimple => [type = SimpleType::getByName(type.name)]
		}
	}
}
