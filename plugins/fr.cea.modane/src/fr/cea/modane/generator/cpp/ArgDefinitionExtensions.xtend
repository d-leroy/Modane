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

import fr.cea.modane.modane.ArgDefinition
import fr.cea.modane.modane.Direction
import fr.cea.modane.modane.Item
import fr.cea.modane.modane.PtyOrArgType
import fr.cea.modane.modane.Simple

import static extension fr.cea.modane.generator.VariableExtensions.*
import static extension fr.cea.modane.generator.cpp.PtyOrArgTypeExtensions.*
import fr.cea.modane.modane.SimpleType

class ArgDefinitionExtensions 
{
	/**
	 * Retourne le type de l'argument.
	 * +---------------+------+----------------------------+-------------------+
	 * | Type          | Card | In                         | Out               |
	 * +---------------+------+----------------------------+-------------------+
	 * | Simple ou     | 1    | const Real                 | Real&             |
	 * | Enumeration   |      |                            |                   |
	 * | ex: Real      | *    | ConstArrayView<Real>       | Array<Real>&      |
	 * +---------------+------+----------------------------+-------------------+
	 * | Item          | 1    | const Cell                 | Cell&             |
	 * | ex: Cell      | *    | CellVectorView             | CellVector&       |
	 * +---------------+------+----------------------------+-------------------+
	 * | ItemGroup     | 1    | const CellGroup            | CellGroup&        |
	 * | ex: CellGroup | *    | ConstArrayView<CellGroup>  | Array<CellGroup>& |
	 * +---------------+------+----------------------------+-------------------+
	 * | Classe        | 1    | const A*                   | A*                |
	 * | ex: A         | *    | ConstArrayView<A*>         | Array<A*>&        |
	 * +---------------+------+----------------------------+-------------------+
	 */	 
	static def getTypeName(ArgDefinition it)
	{
		switch (it)
		{
			case direction == Direction::IN && !actuallyMultiple: type.inUniqueTypeName
			case direction == Direction::IN &&  actuallyMultiple: type.inMultipleTypeName
			case direction != Direction::IN && !actuallyMultiple: type.outUniqueTypeName
			case direction != Direction::IN &&  actuallyMultiple: type.outMultipleTypeName
		}
	}
	
	private static def isActuallyMultiple(ArgDefinition it)
	{
		return multiple || (type instanceof Simple && (type as Simple).type.multiplicity == 'Array')
	}
	
	private static def getInUniqueTypeName(PtyOrArgType type)
	{ 
		'const ' + type.typeName
	}
	
	private static def getInMultipleTypeName(PtyOrArgType type)
	{
		if (type instanceof Item) {
			type.typeName + 'VectorView'
		} else if (type instanceof Simple) {
			val t = (type as Simple).type.typeName
			if (t == SimpleType::BOOLEAN.getName) {
				'ConstArrayView< bool >'
			} else {
				'ConstArrayView< ' + t + ' >'
			}
		} else {
			'ConstArrayView< ' + type.typeName + ' >'
		}
	}
	
	private static def getOutUniqueTypeName(PtyOrArgType type)
	{ 
		if (type.typeName.endsWith('*')) type.typeName
		else type.typeName + '&'
	}
	
	private static def getOutMultipleTypeName(PtyOrArgType type)
	{
		if (type instanceof Item) {
			type.typeName + 'Vector&'
		} else if (type instanceof Simple) {
			val t = (type as Simple).type.typeName
			if (t == SimpleType::BOOLEAN.getName) {
				'Array< bool >&'
			} else {
				'Array< ' +  t + ' >&'
			}
			
		} else {
			'Array< ' + type.typeName + ' >&'
		}
	}
	
	static def getFieldName(ArgDefinition it) { 'm_' + name }
}