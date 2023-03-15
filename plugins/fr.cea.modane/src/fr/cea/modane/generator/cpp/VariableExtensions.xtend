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
import fr.cea.modane.modane.VariableMultiplicity
import fr.cea.modane.modane.VariableMultiplicityType
import java.util.List

import static extension fr.cea.modane.ModaneStringExtensions.*

class VariableExtensions 
{	
	static def getFieldName(Variable it) { 'm_' + name.separateWith('_') }
	
	static def getTypeName(Variable it) { getTypeName(type, supports, multiplicity) }	

	static def getTypeName(SimpleType varType, List<Item> supports, VariableMultiplicity mult) 
	{
		var tname = if (varType == SimpleType::BOOL) 'Byte' else varType.getName
		var result = ''

		if (supports.empty) {
			result = 'Variable'
		} else {
			val support = supports.get(0)
			switch support
			{
				case ItemType::MAT_CELL : result = 'MaterialVariableCell'
				case ItemType::ENV_CELL : result = 'EnvironmentVariableCell'
				default : result = 'Variable' + support.type.getName
			}
		}
		

		if (mult === null) {
			result += supports.empty ? 'Scalar' + tname : tname
		} else {
			switch mult.type
			{
				case VariableMultiplicityType::ARRAY: result += 'Array' + tname
				case VariableMultiplicityType::ARRAY2: result += 'Array2' + tname
			}
		}

		return result;
	}
}