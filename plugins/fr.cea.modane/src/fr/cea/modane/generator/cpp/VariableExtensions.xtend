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

import fr.cea.modane.modane.Item
import fr.cea.modane.modane.ItemType
import fr.cea.modane.modane.SimpleType
import fr.cea.modane.modane.Variable
import java.util.List

import static extension fr.cea.modane.ModaneStringExtensions.*
import static extension fr.cea.modane.generator.VariableExtensions.*

class VariableExtensions 
{	
	static def getFieldName(Variable it) { 'm_' + name.separateWithDefault }
	
	static def getTypeName(Variable it) { getTypeName(type, supports) }

	static def getTypeName(SimpleType varType, List<Item> supports) 
	{
		val typeName = switch (varType.typeName)
		{
			case SimpleType::BOOLEAN.getName: 'Byte'
			default: varType.typeName
		}
		
		var result = ''

		if (supports.empty) {
			result = 'Variable'
		} else {
			val support = supports.get(0)
			switch support.type
			{
				case ItemType::MAT_CELL : result = 'MaterialVariableCell'
				case ItemType::ENV_CELL : result = 'EnvironmentVariableCell'
				default : result = 'Variable' + support.type.getName
			}
		}
		
		val multName = varType.multiplicity

		if (multName === 'Scalar') {
			result += supports.empty ? multName + typeName : typeName
		} else {
			result += multName + typeName
		}

		return result;
	}
}