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

import java.util.Collection
import org.eclipse.xtext.generator.IFileSystemAccess

class CMakeListsGenerator
{
	static val FileName = 'CMakeLists.txt'

	def generate(IFileSystemAccess fsa, String packageFullyQualifiedName, Collection<String> subPackageShortNames, ModelInfo modelInfo)
	{
		fsa.generateFile(packageFullyQualifiedName.path + '/' + FileName, getContent(packageFullyQualifiedName, subPackageShortNames, modelInfo))
	}

	private def getContent(String packageFullyQualifiedName, Collection<String> subPackageShortNames, ModelInfo modelInfo)
	'''
		#
		# Generated file - Do not overwrite
		#
		««« On ne garde que les fichiers cc (pas les h)
		«val sources = modelInfo.cppFiles.filter[x | x.endsWith(".cc")] + modelInfo.axlFiles.map[x | x + "_axl.h"]»
		«IF !sources.empty»
			add_library(«packageFullyQualifiedName.shortName»«FOR f : sources»«'\n'»  «f»«ENDFOR»«'\n'»)

			«FOR axlFile : modelInfo.axlFiles AFTER "\n"»
				arcane_generate_axl(«axlFile»)
			«ENDFOR»
			target_link_libraries(«packageFullyQualifiedName.shortName» PRIVATE arcane_full PUBLIC pybind11::embed scihooklib)
			target_include_directories(«packageFullyQualifiedName.shortName» PUBLIC ${CMAKE_SOURCE_DIR} ${CMAKE_BINARY_DIR})
		«ENDIF»

		«/* TODO: Add scihook- and pybind11-specific content. */»

		«FOR subPackageShortName : subPackageShortNames AFTER "\n"»
			add_subdirectory(«subPackageShortName»)
		«ENDFOR»
		if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/Project.cmake)
		include(Project.cmake)
		endif()
	'''

	def generateRoot(IFileSystemAccess fsa, String projectName, String arcaneHome, Collection<String> subPackageShortNames)
	{
		fsa.generateFile(FileName, getContent(projectName, arcaneHome, subPackageShortNames))
	}

	private def getContent(String projectName, String arcaneHome, Collection<String> subPackageShortNames)
	'''
		#
		# Generated file - Do not overwrite
		#
		cmake_minimum_required(VERSION 3.13)
		project(«projectName» LANGUAGES C CXX)

		set(Arcane_ROOT «arcaneHome»)
		include(«arcaneHome»/samples/ArcaneCompilerConfig.cmake)
		find_package(Arcane REQUIRED)

		set(PYBIND11_PYTHON_VERSION 3.8)
		find_package(Python COMPONENTS Interpreter Development REQUIRED)
		set(pybind11_DIR "${Python_SITELIB}/pybind11/share/cmake/pybind11")
		find_package(pybind11 REQUIRED)
		include_directories(${pybind11_INCLUDE_DIRS} ${Python_SITELIB}/scihook/include)
		add_library(scihooklib SHARED IMPORTED)
		set_property(TARGET scihooklib PROPERTY IMPORTED_LOCATION ${Python_SITELIB}/scihook/libscihook.so)

		«FOR subPackageShortName : subPackageShortNames»
		add_subdirectory(«subPackageShortName»)
		«ENDFOR»

		if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/Project.cmake)
		include(Project.cmake)
		endif()
	'''

	private def getShortName(String fullyQualifiedName)
	{ 
		if (fullyQualifiedName.contains('.')) fullyQualifiedName.split("\\.").last
		else fullyQualifiedName
	}

	private def getPath(String fullyQualifiedName) { fullyQualifiedName.replace('.', '/') }
}