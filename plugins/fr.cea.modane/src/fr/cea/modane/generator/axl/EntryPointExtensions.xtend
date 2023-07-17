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

import fr.cea.modane.modane.EntryPoint
import fr.cea.modane.modane.EntryPointAutoLoadValue

import static extension fr.cea.modane.ModaneStringExtensions.*

class EntryPointExtensions 
{
	static def getContent(EntryPoint it)
	'''
		<entry-point 
		method-name="«name»" 
		name="«name.toFirstUpper»"
		where="«location.literal.replace('@', '').separateWith('-')»"
		property="«autoLoad.propertyString»"/>
	'''
	
	private static def getPropertyString(EntryPointAutoLoadValue epal)
	{
		if (epal === null) {
			return 'none'
		} else {
			switch epal.value
			{
				case AUTO_LOAD_BEGIN : 'auto-load-begin'
				case AUTO_LOAD_END : 'auto-load-end'
				case NO_AUTO_LOAD : 'none'
			}
		}
		
	}
}