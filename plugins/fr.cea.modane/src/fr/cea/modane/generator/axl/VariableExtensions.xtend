/*******************************************************************************
 * Copyright (c) 2022 CEA
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.modane.generator.axl

import com.google.inject.Inject
import fr.cea.modane.modane.ItemType
import fr.cea.modane.modane.SimpleType
import fr.cea.modane.modane.Variable

import static extension fr.cea.modane.generator.VariableExtensions.*

class VariableExtensions
{
	@Inject extension DescriptionUtils

//	def getContent(Variable it)
//	'''
//		<variable field-name="«name.separateWithDefault»" name="«name»" data-type="«typeName»" item-kind="«itemKindName»"«IF family !== null» family-name="«family.name»"«ENDIF» dim="«dim»" dump="«isDump»" need-sync="«isNeedSync»" restore="«isRestore»" execution-depend="«isExecutionDepend»"«componentExtension»>
//			«description.formatDescription»
//		</variable>
//	'''
	def getContent(Variable it)
	'''
		<variable field-name="«name»" name="«axlName»" data-type="«typeName»" item-kind="«itemKindName»"«IF family !== null» family-name="«family.name»"«ENDIF» dim="«dim»" dump="«isDump»" need-sync="«isNeedSync»" restore="«isRestore»" execution-depend="«isExecutionDepend»"«componentExtension»>
			«description.formatDescription»
		</variable>
	'''

	private def getTypeName(Variable it)
	{
		switch (type.typeName)
		{
			case SimpleType::BOOLEAN.getName: 'bool'
			default: type.typeName.toLowerCase
		}
	}

	private def getItemKindName(Variable it)
	{
		if (supports.empty)
		{
			'none'
		}
		else
		{
			val firstSupport = supports.get(0)
			switch firstSupport.type
			{
				case ItemType::MAT_CELL : 'cell'
				case ItemType::ENV_CELL : 'cell'
				default : firstSupport.type.getName.toLowerCase
			}
		}
	}

	private def getDim(Variable it) {
		switch (multiplicity)
		{
			case 'Scalar':
				return 0
			case 'Array':
				return 1
			case 'Array2':
				return 2
		}
	}
	
	private def getComponentExtension(Variable it)
	{
		if (supports.empty)
		{
			''
		}
		else
		{
			val firstSupport = supports.get(0)
			switch firstSupport.type
			{
				case ItemType::MAT_CELL : ' material="true"'
				case ItemType::ENV_CELL : ' environment="true"'
				default : ''
			}
		}
	}
}