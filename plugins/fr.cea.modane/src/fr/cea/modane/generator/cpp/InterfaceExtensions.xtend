/*******************************************************************************
 * Copyright (c) 2022 CEA
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.modane.generator.cpp

import fr.cea.modane.generator.cmake.ModelInfo
import fr.cea.modane.modane.ArgDefinition
import fr.cea.modane.modane.Interface
import fr.cea.modane.modane.VarDefinition
import org.eclipse.xtext.generator.IFileSystemAccess

import static extension fr.cea.modane.FunctionExtensions.*
import static extension fr.cea.modane.ModaneElementExtensions.*
import static extension fr.cea.modane.ModaneStringExtensions.*
import static extension fr.cea.modane.generator.cpp.CppMethodContainerExtensions.*
import static extension fr.cea.modane.generator.cpp.CppMethodExtensions.*
import static extension fr.cea.modane.generator.cpp.ItemTypeExtensions.*
import static extension fr.cea.modane.generator.cpp.PtyExtensions.*
import static extension fr.cea.modane.generator.cpp.PtyOrArgTypeExtensions.*
import static extension fr.cea.modane.generator.cpp.ReferenceableExtensions.*

class InterfaceExtensions extends fr.cea.modane.InterfaceExtensions
{
	static def compile(Interface it, IFileSystemAccess fsa, boolean profAccInstrumentation, boolean sciHookInstrumentation, ModelInfo modelInfo)
	{
		val context = GenerationContext::Current
		context.newFile(outputPath, referencedFileName, true, component)
		modelInfo.cppFiles += referencedFileName
		context.addContent(interfaceContent)
		context.generate(fsa)
		
		// si l'interface n'a aucune implémentation et qu'elle n'est pas concrete
		// (si elle est concrete, un service par defaut est créé), une classe
		// de base et une classe pour l'utilisateur sont créées
		if (context.generationOptions.defaultService && !hasRealizations && !concrete)
			(new InterfaceCppMethodContainer(it)).compile(fsa, profAccInstrumentation, sciHookInstrumentation, modelInfo)
	}

	static private def getInterfaceContent(Interface it)
	'''
		/*!
		 * \brief Interface «name»
		 «FOR l : fromDescription»
		 * «l»
		 «ENDFOR»
		 */
		class «referencedName»
		«FOR parent : parents BEFORE ': ' SEPARATOR ', '»
		 public «parent.referencedNameWithNs»
		«ENDFOR»
		{
		 public:  // ***** CONSTRUCTEUR & DESTRUCTEUR
		  «referencedName»() {}
		  virtual ~«referencedName»() {}

		 public:  // ***** ACCESSEURS ABSTRAITS
		  virtual const String getImplName() const = 0;
		  «FOR p : properties»
		  «p.abstractGetterContent»
		  «IF p.needHasAccessor»«p.abstractHasAccessorContent»«ENDIF»
		  «ENDFOR»

		 public:  // ***** METHODES ABSTRAITES
		  «FOR f : functions»
		  «IF hasRealizations || !f.description.nullOrEmpty»
		  /*!
		   «IF hasRealizations»
		   * Cette méthode est implémentée dans :
		   «FOR s: allServiceRealisations»
		   * \li «(new ServiceCppMethodContainer(s)).baseClassName»::«f.name»
		   «ENDFOR»
		   «FOR s: allModuleRealisations»
		   * \li «(new ModuleCppMethodContainer(s)).baseClassName»::«f.name»
		   «ENDFOR»
		   «ENDIF»
		   «FOR l : fromDescription»
		   * «l»
		   «ENDFOR»
		   */
		  «ENDIF»
		  virtual «new FunctionCppMethod(f,new InterfaceCppMethodContainer(it), name).callerSignature» = 0;
		  «ENDFOR»
		};
	'''

	static private def isComponent(Interface it)
	{
		if (GenerationContext::Current.generationOptions.alwaysMaterialMng)
			return true
		else 
		{
			for (f : functions)
			{
				if (f.support !== null && f.support.component) return true
				else if (f.vars.exists[v |
					val supports = v.variable.supports
					!supports.empty && supports.get(0).component
				]) return true
				else if (f.args.filter(ArgDefinition).exists[a | a.type.component]) return true
				else if (f.args.filter(VarDefinition).exists[a |
					val supports = a.supports
					!supports.empty && supports.get(0).component
				]) return true
			}
		}
		return false
	}
}