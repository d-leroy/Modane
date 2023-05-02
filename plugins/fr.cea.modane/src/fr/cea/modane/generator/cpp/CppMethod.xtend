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

import fr.cea.modane.modane.Arg
import fr.cea.modane.modane.ArgDefinition
import fr.cea.modane.modane.EntryPoint
import fr.cea.modane.modane.Function
import fr.cea.modane.modane.FunctionItemType
import fr.cea.modane.modane.OverrideFunction
import fr.cea.modane.modane.PtyOrArgType
import fr.cea.modane.modane.VarDefinition
import java.util.List

import static extension fr.cea.modane.ModaneStringExtensions.*

interface CppMethod 
{
	def String getName()
	def List<String> getDescription()
	def String getContainerName()
	def CppMethodContainer getContainer()
	def Iterable<? extends CppVariable> getAllVars()
	def Iterable<ArgDefinition> getArgDefinitions()
	def Iterable<? extends Arg> getAllArgs()
	def Iterable<Function> getCalls()
	def PtyOrArgType getReturnType()
	def boolean isMultiple()
	def FunctionItemType getSupport()
	def boolean isSequential()
	def boolean isConst()
	def boolean isOverride()
}

class FunctionCppMethod implements CppMethod
{
	Function f
	CppMethodContainer container
	String containerName
	
	new(Function f, CppMethodContainer container, String containerName) 
	{ 
		this.f = f
		this.container = container;
		this.containerName = containerName
	}
	
	override getName() { f.name }
	override getDescription() { f.fromDescription }
	override getContainerName() { containerName }
	override getContainer() { container }
	override getArgDefinitions() { f.args.filter(ArgDefinition) }
	override getAllArgs() { f.args }
	override getCalls() { f.calls.map[c|c.call] }
	override getReturnType() { f.type }
	override isMultiple() { f.multiple }
	override getSupport() { f.support === null ? null : f.support.type }
	override isSequential() { f.sequential }
	override isConst() { f.const }
	override isOverride() { false }	
	
	override getAllVars() 
	{ 
		f.vars.map[v | new CppVarReference(v)] +
		f.args.filter(VarDefinition).map[v | new CppVarDefinition(v)]
	}
}

class OverrideFunctionCppMethod extends FunctionCppMethod
{
	OverrideFunction of
	
	new(OverrideFunction of, CppMethodContainer container, String containerName) 
	{
		super(of.func, container, containerName)
		this.of = of
	}
	
	override getDescription() { of.fromDescription }
	override getCalls() { of.calls.map[c|c.call] }
	override isOverride() { true }	
	
	override getAllVars() 
	{ 
		of.vars.map[v | new CppVarReference(v)] +
		of.func.vars.map[v | new CppVarReference(v)] +
		of.func.args.filter(VarDefinition).map[v | new CppVarDefinition(v)]
	}
}

class EntryPointCppMethod implements CppMethod
{
	EntryPoint ep
	CppMethodContainer container
	String containerName
	
	new(EntryPoint ep, CppMethodContainer container, String containerName) 
	{ 
		this.ep = ep
		this.containerName = containerName
	}

	override getName() { ep.name }
	override getDescription() { ep.fromDescription }
	override getContainerName() { containerName }
	override getContainer() { container }
	override getAllArgs() { newArrayList }
	override getArgDefinitions() { newArrayList }
	override getCalls() { ep.calls.map[c|c.call] }
	override getReturnType() { null }	
	override isMultiple() { false }
	override getSupport() { ep.support === null ? null : ep.support.type }
	override isSequential() { true }
	override isConst() { false }
	override isOverride() { false }	
	
	override getAllVars() {
		ep.vars.map[v | new CppVarReference(v)]
	}
}