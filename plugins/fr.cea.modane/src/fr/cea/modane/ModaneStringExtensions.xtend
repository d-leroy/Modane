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

import fr.cea.modane.modane.Comment
import fr.cea.modane.modane.EntryPoint
import fr.cea.modane.modane.Function
import fr.cea.modane.modane.ModaneElement
import fr.cea.modane.modane.OverrideFunction
import fr.cea.modane.modane.Pty
import java.util.List

class ModaneStringExtensions
{
	static val LowerCaseSeparator = '_'

	/**
	 * Prend une chaine utilisant les majuscules comme séparateur et retourne une chaine
	 * utilisant separator comme séparateur. La chaine retournée est en minuscules.
	 */ 
	static def separateWith(String it, String separator) 
	{ 
		if (contains('_'))
			// chaine de la forme mon_nom 
			replace('_', separator).toLowerCase
		else 
			// chaine de la forme monNom
			Character::toLowerCase(charAt(0)) + toCharArray.tail.map[c | if (Character::isUpperCase(c)) separator + Character::toLowerCase(c) else c  ].join
	}

	static def separateWithDefault(String it) { separateWith(LowerCaseSeparator) }

	/**
	 * Prend une chaine utilisant LowerCaseSeparator comme séparateur et retourne une chaine utilisant les majuscules.
	 * Ex: si separator vaut '_', my_pty_name devient MyPtyName
	 */
	static def separateWithUpperCase(String it) 
	{
		split(LowerCaseSeparator).map[t | t.toFirstUpper].join
	}

	static def boolean isNullOrEmpty(Comment comment)
	{
		return comment === null || comment.comment.isNullOrEmpty
	}

	private static def List<String> formatDescription(Comment comment)
	{
		if (comment.isNullOrEmpty) return #[]
		else {
			val result = comment.comment.replaceFirst('/\\*!', ' * ')
				.replaceFirst('\\*/', '').split('\n')
				.map[l|l.replaceFirst('\\*', '').strip]
			return result
		}
	}

	static dispatch def fromDescription(EntryPoint element) { formatDescription(element.description) }
	static dispatch def fromDescription(Pty element) { formatDescription(element.description) }
	static dispatch def fromDescription(ModaneElement element) { formatDescription(element.description) }
	static dispatch def fromDescription(Function element) { formatDescription(element.description) }
	static dispatch def fromDescription(OverrideFunction element) { formatDescription(element.description) }

	static def startByUc(String it) { Character::isUpperCase(charAt(0)) }
	static def containsSeparator(String it) { contains(LowerCaseSeparator) }
	static def containsUC(String it) { toCharArray.exists(c | Character::isUpperCase(c)) }
}
