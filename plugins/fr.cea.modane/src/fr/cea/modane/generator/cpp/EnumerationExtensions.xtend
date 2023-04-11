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
import fr.cea.modane.modane.Enumeration
import org.eclipse.xtext.generator.IFileSystemAccess

import static extension fr.cea.modane.ModaneElementExtensions.*
import static extension fr.cea.modane.ModaneStringExtensions.*
import static extension fr.cea.modane.generator.cpp.ReferenceableExtensions.*

class EnumerationExtensions
{
	static def compile(Enumeration it, IFileSystemAccess fsa, ModelInfo modelInfo)
	{
		val context = GenerationContext::Current
		context.newFile(outputPath, referencedFileName, false, false)
		modelInfo.cppFiles += referencedFileName
		context.addContent(content)
		context.generate(fsa)
	}

	private static def getContent(Enumeration it)
	'''
		/*!
		 * \brief Classe représentant l'énumération «name»
		 * «FOR l : fromDescription SEPARATOR '\n'»«l»«ENDFOR»
		 */
		enum class «name»
		{
		  «FOR l : literals SEPARATOR ','»
		  «l.name.toFirstUpper»«IF l.valueProvided» = «l.value»«ENDIF»
		  «ENDFOR»
		};
	'''
}