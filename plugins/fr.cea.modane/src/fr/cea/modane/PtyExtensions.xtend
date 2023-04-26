/*******************************************************************************
 * Copyright (c) 2022 CEA
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.modane

import fr.cea.modane.modane.Interface
import fr.cea.modane.modane.Pty
import fr.cea.modane.modane.Reference
import fr.cea.modane.modane.Simple

import static extension fr.cea.modane.InterfaceExtensions.*

class PtyExtensions 
{
	/**
	 * La propriété est concrète si :
	 *   - elle est multiple
	 *   - elle n'est pas de type Reference
	 *   - la cible de la référence n'est pas une interface
	 *   - la cible de la référence est une interface concrete
	 */
	static def isConcrete(Pty it) 
	{ 
		if (actuallyMultiple) return true
		else if (!(type instanceof Reference)) return true
		else
		{
			val ref = type as Reference
			if (!(ref.target instanceof Interface)) return true
			else  if ((ref.target as Interface).concrete) return true
		}
		return false
	}
	
	static def isActuallyMultiple(Pty it)
	{
		if (type instanceof Simple) {
			switch ((type as Simple).type) {
				case ARRAY_BOOLEAN,
				case ARRAY_INT32,
				case ARRAY_INT64,
				case ARRAY_INTEGER,
				case ARRAY_REAL,
				case ARRAY_REAL2,
				case ARRAY_REAL2X2,
				case ARRAY_REAL3,
				case ARRAY_REAL3X3,
				case ARRAY_STRING: {
					return true
				}
				default: {
					return false
				}
			}
		} else {
			multiple
		}
	}
}