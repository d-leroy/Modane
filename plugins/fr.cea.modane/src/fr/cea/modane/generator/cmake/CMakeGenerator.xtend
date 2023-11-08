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
		if (!modelInfo.targets.empty) {
			fsa.generateFile('''«packageFullyQualifiedName.path»/__«packageFullyQualifiedName.shortName».cmake''', getContent(packageFullyQualifiedName, modelInfo))
		}
	}

	private def getContent(String packageFullyQualifiedName, ModelInfo modelInfo)
	'''
		#
		# Generated file - Do not overwrite
		#
		«IF (modelInfo.targets.contains(ModelInfoTarget::SCIHOOK))»
			
			if(«ModelInfoTarget::SCIHOOK.targetVariable»)
			«val sources = modelInfo.cppFiles.filter[x | x.startsWith("__") && x.endsWith("Bindings.cc")]»
			«IF !sources.empty»
				target_sources( ${library_name}
				  PRIVATE
				    «FOR s : sources»
				    ${CMAKE_CURRENT_LIST_DIR}/«s»
				    «ENDFOR»
				)
			«ENDIF»
			
			target_include_directories( ${library_name} PUBLIC ${pybind11_INCLUDE_DIRS} ${SCIHOOK_INCLUDE_DIR} )
			
			target_link_libraries( ${library_name}
			  PUBLIC
			    «ModelInfoTarget::SCIHOOK.targetLibraryName»
			)
			endif()
		«ENDIF»
		«IF modelInfo.targets.contains(ModelInfoTarget::ACCENV)»
			
			target_link_libraries( ${library_name}
			  PUBLIC
			    «ModelInfoTarget::ACCENV.targetLibraryName»
			)
		«ENDIF»
	'''
	
	def getTargetLibraryName(ModelInfoTarget target) {
		switch (target) {
			case ACCENV: {
				"accenv"
			}
			case SCIHOOK: {
				"${SCIHOOK_LIB} pybind11::embed"
			}
		}
	}
	
	def getTargetVariable(ModelInfoTarget target) {
		switch (target) {
			case ACCENV: {
				"NOT PROF_ACC_DISABLED"
			}
			case SCIHOOK: {
				"SCIHOOK_ENABLED"
			}
		}
	}

	private def getShortName(String fullyQualifiedName)
	{ 
		if (fullyQualifiedName.contains('::')) fullyQualifiedName.split("\\.").last
		else fullyQualifiedName
	}

	private def getPath(String fullyQualifiedName) { fullyQualifiedName.replace('::', '/') }
}