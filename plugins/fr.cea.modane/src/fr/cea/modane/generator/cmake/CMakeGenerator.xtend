/*******************************************************************************
 * Copyright (c) 2022 CEA
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.modane.generator.cmake

import org.eclipse.xtext.generator.IFileSystemAccess

class CMakeGenerator
{
	def generate(IFileSystemAccess fsa, String packageFullyQualifiedName, ModelInfo modelInfo)
	{
		fsa.generateFile('''«packageFullyQualifiedName.path»/__«packageFullyQualifiedName.shortName».cmake''', getContent(packageFullyQualifiedName, modelInfo))
	}

	private def getContent(String packageFullyQualifiedName, ModelInfo modelInfo)
	'''
		#
		# Generated file - Do not overwrite
		#
		«val sources = modelInfo.cppFiles.filter[x | x.startsWith("__") && x.endsWith("Bindings.cc")]»
		«IF !sources.empty»
			target_sources( ${library_name}
				PRIVATE
				«FOR s : modelInfo.cppFiles»
					${CMAKE_CURRENT_LIST_DIR}/«s»
				«ENDFOR»
			)
		«ENDIF»
		«IF !modelInfo.targets.empty»
			target_link_libraries( ${library_name}
				PUBLIC
				«FOR t : modelInfo.targets»
					«t»
				«ENDFOR»
			)
		«ENDIF»
	'''

	private def getShortName(String fullyQualifiedName)
	{ 
		if (fullyQualifiedName.contains('.')) fullyQualifiedName.split("\\.").last
		else fullyQualifiedName
	}

	private def getPath(String fullyQualifiedName) { fullyQualifiedName.replace('.', '/') }
}