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

import fr.cea.modane.ModaneOutputConfigurationProvider
import fr.cea.modane.generator.GenerationOptions
import java.util.List
import java.util.Map
import java.util.Set
import org.eclipse.xtext.generator.IFileSystemAccess

class GenerationContext
{
	public static val GenFilePrefix = "__"
	public static val HeaderExtension = ".h"
	public static val BodyExtension = ".cc"
	public static val Separator = 
	'''
		
		/*---------------------------------------------------------------------------*/
		/*---------------------------------------------------------------------------*/
		
	'''

	public static GenerationContext Current = null
	public val GenerationOptions generationOptions

	String path
	String name
	String content
	List<String> includes
	List<String> arcaneIncludes
	Map<String, List<String>> flaggedArcaneIncludes
	Map<String, List<String>> flaggedIncludes
	List<String> usedNs

	public Set<String> embeddedModules = newHashSet
	public Set<String> cmakeVariables = newHashSet

	new(GenerationOptions options)
	{
		this.generationOptions = options
		Current = this
	}

	def newFile(String path, String name, boolean withIncludes, boolean withComponent)
	{
		this.path = path
		this.name = name
		this.content = ""
		this.arcaneIncludes = newArrayList
		this.flaggedArcaneIncludes = newHashMap
		this.includes = newArrayList
		this.flaggedIncludes = newHashMap
		this.usedNs = newArrayList

		if (withIncludes)
		{
			addInclude("arcane/ArcaneTypes.h")
			addInclude("arcane/ItemTypes.h")
			addInclude("arcane/Item.h")
			addInclude("arcane/ItemVector.h")
			addInclude("arcane/ItemVectorView.h")
			addInclude("arcane/VariableTypes.h")
			addInclude("arcane/utils/Array.h")	
		}

		if (withIncludes && withComponent)
		{
			addInclude("arcane/materials/ComponentItemVector.h")
			addInclude("arcane/materials/ComponentItemVectorView.h")
			addInclude("arcane/materials/MeshEnvironmentVariableRef.h")
			addInclude("arcane/materials/MeshMaterialVariableRef.h")
			addInclude("arcane/materials/IMeshMaterialMng.h")
		}

		if (withIncludes) addUsedNs("Arcane")
		if (withIncludes && withComponent) addUsedNs("Arcane::Materials")
	}

	def getName() { name }
	def getFullName() { path + '/' + name }
	def addContent(CharSequence c) { content = content.concat(c.toString) }
	def getNsName() { path.split("/").map[s | s.toFirstUpper].join }
	def isAUsedNs(String ns) { usedNs.contains(ns) }

	def addInclude(String path, String file)
	{
		if (path.nullOrEmpty) addInclude(file)
		else addInclude(path + '/' + file)
	}

	def addInclude(String include)
	{
		if (include.startsWith('arcane/'))
		{
			if (!arcaneIncludes.contains(include))
				arcaneIncludes += include
		}
		else
		{
			if (!includes.contains(include) && include != fullName)
				includes += include
		}
	}

	def addFlaggedInclude(String path, String file, String flag)
	{
		if (path.nullOrEmpty) addFlaggedInclude(file, flag)
		else addFlaggedInclude(path + '/' + file, flag)
	}

	def addFlaggedInclude(String include, String flag)
	{
		if (include.startsWith('arcane/'))
		{
			val arcaneIncludes = flaggedArcaneIncludes.computeIfAbsent(flag, [newArrayList])
			if (!arcaneIncludes.contains(include))
				arcaneIncludes += include
		}
		else
		{
			val includes = flaggedIncludes.computeIfAbsent(flag, [newArrayList])
			if (!includes.contains(include) && include != fullName)
				includes += include
		}
	}

	def addUsedNs(String value)
	{
		if (nsName != value && !usedNs.contains(value))
			usedNs += value
	}

	def generate(IFileSystemAccess fsa)
	{
		generate(fsa, IFileSystemAccess::DEFAULT_OUTPUT)
	}

	def generateIfNotExist(IFileSystemAccess fsa)
	{
		generate(fsa, ModaneOutputConfigurationProvider::GEN_ONCE_OUTPUT)
	}

	private def generate(IFileSystemAccess fsa, String outputConfigurationName)
	{
		if (name.endsWith(HeaderExtension)) fsa.generateFile(fullName, outputConfigurationName, dumpH)
		else if (name.endsWith(BodyExtension)) fsa.generateFile(fullName, outputConfigurationName, dumpCC)
		else throw new RuntimeException("Invalid file extension: " + fullName)
	}

	/**
	 * Squelette du fichier .h 
	 */
	private def dumpH()
	'''
		#ifndef «ifndefTag»
		#define «ifndefTag»
		«Separator»
		«FOR i : arcaneIncludes»
			#include "«i»"
		«ENDFOR»
		«FOR e : flaggedArcaneIncludes.entrySet»
			#if «e.key»
			«FOR i : e.value»
			#include "«i»"
			«ENDFOR»
			#endif
		«ENDFOR»
		«FOR i : includes»
			#include "«i»"
		«ENDFOR»
		«FOR e : flaggedIncludes.entrySet»
			#if «e.key»
			«FOR i : e.value»
			#include "«i»"
			«ENDFOR»
			#endif
		«ENDFOR»
		«Separator»
		«FOR i : usedNs»
			using namespace «i»;
		«ENDFOR»
		«IF !path.empty»namespace «nsName» {«ENDIF»
		«Separator»
		«content»
		«IF !path.empty»
			«Separator»
			}  // namespace «nsName»
		«ENDIF»
		«Separator»
		#endif  // «ifndefTag»
	'''

	/**
	 * Squelette du fichier .cc 
	 */
	private def dumpCC()
	'''
		«FOR i : arcaneIncludes + includes»
		#include "«i»"
		«ENDFOR»
		«Separator»
		«FOR i : usedNs»
		using namespace «i»;
		«ENDFOR»
		«IF !path.empty»namespace «nsName» {«ENDIF»
		«Separator»
		«content»
		«IF !path.empty»
		«Separator»
		}  // namespace «nsName»
		«ENDIF»
	'''

	/**
	 * Retourne l'étiquette à mettre dans le #ifndef en début de fichier
	 */
	private def getIfndefTag() 
	{ 
		fullName.replace("/", "_").replace(".", "_").toUpperCase
	}
}
