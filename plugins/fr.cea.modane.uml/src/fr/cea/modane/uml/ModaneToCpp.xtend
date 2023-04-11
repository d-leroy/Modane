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
import fr.cea.modane.generator.ModaneGeneratorMessageDispatcher.MessageType
import fr.cea.modane.generator.StandaloneGenerator
import java.util.List
import org.eclipse.emf.ecore.resource.Resource

/**
 * Cette classe est utilisée par les tests unitaires et l'IHM.
 * Les tests génèrent le C++ à partir d'un nom de fichier.
 * L'IHM a besoin de décomposer les étapes pour initialiser une boite de dialogue. 
 */
class ModaneToCpp
{
	@Inject StandaloneGenerator generator
	
	def static createInstance()
	{
		val injector = new ModaneStandaloneSetupGenerated().createInjectorAndDoEMFRegistration
		injector.getInstance(ModaneToCpp)
	}

	def getMessageDispatcher()
	{
		generator.messageDispatcher
	}

	def generate(List<Resource> resourcesToGenerate, String absoluteOutputPath, String packagePrefix, String packageToGenerate,
			boolean profAccInstrumentation, boolean sciHookInstrumentation, boolean generateCMakeLists, boolean generateCMake)
	{
		val startTime = System.currentTimeMillis
		
		messageDispatcher.post(MessageType.Exec, "Starting code generation")
		generator.generate(resourcesToGenerate, absoluteOutputPath, packageToGenerate, profAccInstrumentation, sciHookInstrumentation, generateCMakeLists, generateCMake)
		val afterGenerationTime = System.currentTimeMillis
		messageDispatcher.post(MessageType.Exec, "Code generation ended in " + (afterGenerationTime-startTime)/1000.0 + "s");
	}
}
