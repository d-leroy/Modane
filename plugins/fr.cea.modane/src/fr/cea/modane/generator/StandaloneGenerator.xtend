/*******************************************************************************
 * Copyright (c) 2022 CEA
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.modane.generator

import com.google.inject.Inject
import fr.cea.modane.ModaneStandaloneSetupGenerated
import fr.cea.modane.Utils
import fr.cea.modane.generator.ModaneGeneratorMessageDispatcher.MessageType
import fr.cea.modane.generator.axl.AxlGenerator
import fr.cea.modane.generator.cmake.CMakeGenerator
import fr.cea.modane.generator.cmake.CMakeListsGenerator
import fr.cea.modane.generator.cmake.ModelInfo
import fr.cea.modane.generator.cpp.CppGenerator
import fr.cea.modane.generator.cpp.GenerationContext
import fr.cea.modane.generator.xsd.XsdGenerator
import fr.cea.modane.modane.ModaneElement
import fr.cea.modane.modane.ModaneModel
import java.util.ArrayList
import java.util.HashMap
import java.util.List
import java.util.stream.Collectors
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.transaction.RecordingCommand
import org.eclipse.emf.transaction.Transaction
import org.eclipse.emf.transaction.TransactionalCommandStack
import org.eclipse.emf.transaction.util.TransactionUtil
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IFileSystemAccess2

import static fr.cea.modane.generator.cpp.GenerationContext.*

class StandaloneGenerator
{
	@Accessors(PUBLIC_GETTER, PRIVATE_SETTER) @Inject StandaloneFileSystemAccess fsa
	@Inject ResourceSet resourceSet
	@Inject GenerationOptionsUtils goUtils
	@Inject ModelTransformer transformer
	@Inject CppGenerator cppGenerator
	@Inject AxlGenerator axlGenerator
	@Inject XsdGenerator xsdGenerator
	@Inject CMakeListsGenerator cMakeListsGenerator
	@Inject CMakeGenerator cMakeGenerator

	// Utilisé par les tests
	def static createInstance()
	{
		val injector = new ModaneStandaloneSetupGenerated().createInjectorAndDoEMFRegistration
		injector.getInstance(StandaloneGenerator)
	}

	def getMessageDispatcher()
	{
		fsa.messageDispatcher
	}

	/** Génération depuis des fichiers '.m' pour les tests unitaires */
	def generate(URI modaneFileURI, String absoluteOutputDir, String packageToGenerate)
	{
		val r = resourceSet.getResource(modaneFileURI, true)
		generate(#[r], absoluteOutputDir, packageToGenerate, false, false, false, false)
	}

	/** 
	 * Génération depuis des fichiers '.uml' 
	 * Dans le cas d'un fichier uml, les ressources sont créées mais ne persistent pas.
	 */
	def generate(List<Resource> modaneResources, String absoluteOutputPath, String packageToGenerate,
		boolean profAccInstrumentation, boolean sciHookInstrumentation, boolean generateCMakeLists, boolean generateCMake)
	{
		// Positionnement du répertoire de sortie du générateur fourni en paramètre
		fsa.initialize(absoluteOutputPath)

		GenerationContext::Current = null

		// Validation des fichiers et génération C++ et AXL
		// On ne peut pas valider en mode standalone pour des histoires de scope provider
		val models = modaneResources.models
		val modelInfoByModel = new HashMap<ModaneModel, ModelInfo>
		for (model : models) 
		{
			// on ne génère que les éléments dans le package demandé ou ses sous-packages
			if (packageToGenerate.nullOrEmpty || model.name.startsWith(packageToGenerate)) 
			{
				val modelInfo = doGenerate(model, profAccInstrumentation, sciHookInstrumentation, fsa)
				modelInfoByModel.put(model, modelInfo)
				//if (generateCMakeLists) cMakeGenerator.generate(fsa, model.name, model.getSubModelsNames(models), cmakeFiles)
			}
			else
				messageDispatcher.post(MessageType.Start, "Package to generate: " + packageToGenerate + " => nothing to do for " + model.name)
		}

		if (generateCMakeLists || generateCMake)
		{
			for (model : modelInfoByModel.keySet)
			{
				val subModelNames = model.getSubModelsNames(models)
				val modelInfo = modelInfoByModel.get(model)
				if (!modelInfo.empty)
				{
					if (generateCMake)
						cMakeGenerator.generate(fsa, model.name, subModelNames, modelInfo)
					if (generateCMakeLists)
						cMakeListsGenerator.generate(fsa, model.name, subModelNames, modelInfo)
				}
			}
		}

		if (profAccInstrumentation || sciHookInstrumentation)
		{
			if (sciHookInstrumentation)
			{
				val modules = newHashSet()
				modules.addAll(GenerationContext::Current.embeddedModules)
				if (fsa.isFile("modules.txt"))
				{
					modules.addAll(fsa.readTextFile("modules.txt").toString.lines.collect(Collectors::toSet))
				}
				val sortedModules = modules.sort
				fsa.generateFile("modules.txt", '''«FOR m : sortedModules SEPARATOR '\n'»«m»«ENDFOR»''')

				fsa.generateFile("__Bindings.h",
				'''
				#include "scihook/SciHook.h"

				void
				try_import(const char *module_name) {
				  try {
				    pybind11::module_::import(module_name);
				  } catch (pybind11::error_already_set &e) {
				    std::cout << e.what() << '\n';
				  }
				}

				void
				import_modules(pybind11::module_ __attribute__((unused)) m) {
				  «FOR m : sortedModules»
				  try_import("«m»");
				  «ENDFOR»
				}
				''')
			}

			val cmakeVariables = newArrayList()
			if (sciHookInstrumentation)
			{
				val sciHookCMakeVariables = newHashSet()
				sciHookCMakeVariables.addAll(GenerationContext::Current.cmakeVariables.map['''#cmakedefine «it»'''])
				if (fsa.isFile("scihookdefs.h.in"))
				{
					sciHookCMakeVariables.addAll(fsa.readTextFile("scihookdefs.h.in").toString.lines.collect(Collectors::toSet))
				}
				sciHookCMakeVariables.remove("#cmakedefine SCIHOOK_ENABLED")
				cmakeVariables.addAll(sciHookCMakeVariables.sort)
				cmakeVariables.add(0, "#cmakedefine SCIHOOK_ENABLED")
			}

			if (profAccInstrumentation)
			{
				cmakeVariables.add(0, "#cmakedefine PROF_ACC_DISABLED")
			}

			fsa.generateFile("scihookdefs.h.in", '''«FOR v : cmakeVariables SEPARATOR '\n'»«v»«ENDFOR»''')
		}
	}

	def generate(ModaneModel model)
	{
		// FIXME: used for sirius generation only, no instrumentation for now.
		doGenerate(model, false, false, fsa)
	}

	private def getModels(List<Resource> resources)
	{
		val models = new ArrayList<ModaneModel>
		resources.forEach[models += contents.filter(ModaneModel)]
		return models
	}

	private def getSubModelsNames(ModaneModel parentModel, List<ModaneModel> models)
	{
		val subModelNames = new ArrayList<String>
		for (m : models)
		{
			if (m !== parentModel && m.name.startsWith(parentModel.name))
			{
				val subName = m.name.replaceFirst(parentModel.name + '.', "")
				if (!subName.contains('.')) subModelNames += subName 
			}
		}
		return subModelNames
	}

	private def doGenerate(ModaneModel model, boolean profAccInstrumentation, boolean sciHookInstrumentation, IFileSystemAccess2 fsa)
	{
		val modelInfo = new ModelInfo

		val optionsPath = Utils::getAbsolutePath(fsa.getURI('.'))
		val options = goUtils.createGenerationOptionsFor(optionsPath, model)

		val embeddedModules = newArrayList
		val cmakeVariables = newArrayList

		if (GenerationContext::Current !== null) {
			embeddedModules.addAll(GenerationContext::Current.embeddedModules)
			cmakeVariables.addAll(GenerationContext::Current.cmakeVariables)
		}

		cppGenerator.generationOptions = options
		GenerationContext::Current.embeddedModules.addAll(embeddedModules)
		GenerationContext::Current.cmakeVariables.addAll(cmakeVariables)
		xsdGenerator.langFr = options.langFr

		val domain = TransactionUtil::getEditingDomain(model)
		var RecordingCommand cmd = null
		var TransactionalCommandStack stack = null

		if (options.defaultService)
		{
			if (domain === null)
			{
				transformer.insertDefaultService(model)
				transformer.insertDefaultValueForPties(model)
			}
			else
			{
				stack = domain.commandStack as TransactionalCommandStack
				cmd = new RecordingCommand(domain)
				{
					override doExecute()
					{
						transformer.insertDefaultService(model)
						transformer.insertDefaultValueForPties(model)
					}
				}
				stack.execute(cmd, #{Transaction.OPTION_NO_NOTIFICATIONS -> Boolean::TRUE, Transaction.OPTION_NO_TRIGGERS -> Boolean::TRUE})
			}
		}

		for (elt : model.elements) doGenerate(elt, fsa, options, profAccInstrumentation, sciHookInstrumentation, modelInfo)

		if (domain !== null && cmd !== null && stack.undoCommand === cmd) stack.undo()
		return modelInfo
	}

	private def doGenerate(ModaneElement elt, IFileSystemAccess fsa, GenerationOptions options, boolean profAccInstrumentation, boolean sciHookInstrumentation, ModelInfo modelInfo)
	{
		axlGenerator.generateFiles(elt, fsa, modelInfo)
		cppGenerator.generateFiles(elt, fsa, profAccInstrumentation, sciHookInstrumentation, modelInfo)
		if (options.generateXsd) xsdGenerator.generateFiles(elt,fsa)
	}
}