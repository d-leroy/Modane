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
import fr.cea.modane.modane.ArgMultiplicity
import fr.cea.modane.modane.Direction
import fr.cea.modane.modane.Enumeration
import fr.cea.modane.modane.FunctionItemType
import fr.cea.modane.modane.Item
import fr.cea.modane.modane.Reference
import fr.cea.modane.modane.Simple
import fr.cea.modane.modane.SimpleType
import fr.cea.modane.modane.VarDefinition
import java.util.ArrayList

import static extension fr.cea.modane.generator.cpp.ArgDefinitionExtensions.*
import static extension fr.cea.modane.generator.cpp.PtyOrArgTypeExtensions.*
import static extension fr.cea.modane.generator.cpp.ReferenceableExtensions.*

class CppMethodExtensions
{
	public static val MeshItemBasicTypes = newArrayList(
			"Vertex", "Line2", "Triangle3", "Quad4", "Pentagon5", 
			"Hexagon6", "Tetraedron4", "Pyramid5", "Pentaedron6", "Hexaedron8", 
			"Heptaedron10", "Octaedron12", "HemiHexa7", "HemiHexa6", "HemiHexa5",
			"AntiWedgeLeft6", "AntiWedgeRight6", "DiTetra5", "DualNode", "DualEdge",
			"DualFace", "DualCell", "Link")

	static def insertDebugMsg()
	'''
		«IF GenerationContext::Current.generationOptions.traceMsg»info() << A_FUNCINFO;«ENDIF»
	'''

	static def getVarClassContent(CppMethod it)
	'''
		//! Classe de variable pour «name»
		struct «varClassName» final
		{
		  «IF allVars.size == 1»explicit «ENDIF»«varClassName»(«FOR v : allVars SEPARATOR ',\n    '»«v.argTypeName» «v.name»«ENDFOR»)
		  «FOR v : allVars BEFORE ':' SEPARATOR '\n,'» «v.fieldName»(«v.name»)«ENDFOR»
		  {}
		«IF allVars.size > 0»«'\n'»«ENDIF»
		  «FOR v : allVars»
		  /*!
		  [«v.direction.literal»] «v.name»
		  «IF !v.description.nullOrEmpty»«v.description»«ENDIF»
		  */
		  «v.argTypeName» «v.fieldName»;
		  «ENDFOR»
		};

	'''

	static def getVarClassName(CppMethod it) { containerName + name.toFirstUpper + 'Vars' }

	static def getVarClassInstance(CppMethod it)
	'''
		«varClassName» vars«IF !allVars.empty»(«allVars.map[v | v.argName].join('\n    , ')»)«ENDIF»;
	'''

	static def getExecutionContextClassContent(CppMethod it)
	'''
		//! Classe de contexte d'exécution pour «name»
		struct «executionContextClassName» final : MoniLogger::MoniLoggerExecutionContext
		{
		  «executionContextClassName»(«FOR a : callerArgs SEPARATOR ',\n    '»«a»«ENDFOR»,
		      «varClassName» *vars,
		      std::string name)
		  : MoniLoggerExecutionContext(name)
		  «IF itemTypeSpecialized || hasSupport», items(items)«ENDIF»
		  «IF allArgs.size > 0», «FOR a : allArgs SEPARATOR '\n, '»«a.name»(«a.name»)«ENDFOR»«ENDIF»
		  , vars(vars)
		  {}

		  «FOR a : callerArgs»
		  «a»;
		  «ENDFOR»
		  const «varClassName» *vars;
		  «IF itemTypeSpecialized || hasSupport»

		  const pybind11::object get_items() const {
		    return pybind11::cast(items);
		  }
  		  «ENDIF»
		  «FOR a : allArgs»

		  const pybind11::object get_«a.name»() const {
		    return pybind11::cast(«a.name»);
		  }
		  «ENDFOR»
		  «FOR v : allVars»

		  const pybind11::object get_«v.fieldName»() const {
		    return pybind11::cast(vars->«v.fieldName»);
		  }
  		  «ENDFOR»
		};

	'''

	static def getExecutionContextClassName(CppMethod it) { containerName + name.toFirstUpper + 'ExecutionContext' }

	static def getExecutionContextArgs(CppMethod it)
	{
		val args = newArrayList
		if (itemTypeSpecialized) args += 'items'
		else if (hasSupport) args += 'items'
		args.addAll(allArgs.map[name])
		if (!allVars.empty) args.add('&vars')
		args.add('''"«name.toFirstUpper + 'ExecutionContext'»"''')
		return args
	}

	static def getExecutionContextClassInstance(CppMethod it)
	'''
		std::shared_ptr<«executionContextClassName»> ctx(
		    new «executionContextClassName»(«executionContextArgs.join('\n    , ')»));
	'''
	
	static def isItemTypeSpecialized(CppMethod it)	{ support == FunctionItemType::ITEM_TYPE_SPECIALIZED }
	static def hasSupport(CppMethod it) { support != FunctionItemType::NO_ITEM && !isItemTypeSpecialized }
	static def hasParallelLoops(CppMethod it) { GenerationContext::Current.generationOptions.parallelLoops && !sequential && hasSupport }
	static def getCallerSignature(CppMethod it) '''«returnTypeName» «name»(«callerArgs.join(', ')»)«IF const» const«ENDIF»'''
	static def getItemTypeSpecializedClassName(CppMethod it) { containerName + name.toFirstUpper }
	static def getItemTypeSpecializedClassHeaderFileName(CppMethod it) { GenerationContext::GenFilePrefix + itemTypeSpecializedClassName + GenerationContext::HeaderExtension }
	static def getParallelLoopClassName(CppMethod it) { containerName + name.toFirstUpper + 'T' }

	static def getHeaderDeveloperSignature(CppMethod it) '''«returnTypeName» «name»(«getDeveloperArgs(true).join(', ')»)«IF const» const«ENDIF»'''
	static def getHeaderDeveloperSignature(CppMethod it, String meshItemBasicType) '''void «name»«meshItemBasicType»(«getDeveloperArgs(true,'ItemVectorView items').map(x | '[[maybe_unused]] ' + x).join(', ')»)'''
	static def getBodyDeveloperSignature(CppMethod it, String className) 
	'''
		«returnTypeName» «className»::
		«name»(«getDeveloperArgs(false).join(', ')»)«IF const» const«ENDIF»
	'''
	// sur une ligne car c'est commenté au départ
	static def getBodyDeveloperSignature(CppMethod it, String className, String meshItemBasicType) 
	'''void «className»::«name»«meshItemBasicType»(«getDeveloperArgs(false, 'ItemVectorView items').join(', ')»)'''


	/**
	 * Retourne le type de retour.
	 * +---------------+------+------------------------+
	 * | Simple        | 1    | Real                   |
	 * | ex: Real      | *    | SharedArray<Real>      |
	 * +---------------+------+------------------------+
	 * | Item          | 1    | Cell                   |
	 * | ex: Cell      | *    | CellVector             |
	 * +---------------+------+------------------------+
	 * | ItemGroup     | 1    | CellGroup              |
	 * | ex: CellGroup | *    | SharedArray<CellGroup> |
	 * +---------------+------+------------------------+
	 * | Classe        | 1    | A*                     |
	 * | ex: A         | *    | SharedArray<A*>        |
	 * +---------------+------+------------------------+
	 */
	static def getReturnTypeName(CppMethod it) 
	{ 
		if (returnType === null) 'void' 
		else 
		{
			if (multiple)
			{
				if (returnType instanceof Item) returnType.typeName + 'Vector'
				else 'SharedArray< ' +  returnType.typeName + ' >'
			}
			else
			{
				returnType.typeName	
			}
		}
	}

	static def getPrefixedCallerSignature(CppMethod it, String prefix) 
	'''
		«returnTypeName» «prefix»::
		«name»(«callerArgs.join(', ')»)«IF const» const«ENDIF»
	'''

	static def getBaseClassBody(CppMethod it)
	'''
		«/* TODO: Insert monilogger embeddings (before, replace, after). */»
		«callerSignature»«IF override» override«ENDIF»
		{
		  «insertDebugMsg»
		  «IF GenerationContext::Current.generationOptions.variableAsArgs»«varClassInstance»«ENDIF»
		  «executionContextClassInstance»
		  «IF itemTypeSpecialized»
		  T* t = static_cast<T*>(this);
		  «itemTypeSpecializedClassName»<T> fclass(«getArgSequence('t').join(', ')»);
		  «wrapMethodContentWithMoniloggerInstrumentation(name.toUpperCase, '''items.applyOperation(&fclass);''')»
		  «ELSEIF hasParallelLoops»
		  T* t = static_cast<T*>(this);
		  «wrapMethodContentWithMoniloggerInstrumentation(name.toUpperCase,
		'''
		  arcaneParallelForeach(items, [&](«support.literal»VectorView sub_items)
		  {
		    ENUMERATE_«support.literal.toUpperCase» (iitem, sub_items) {
		      const «support.literal» item = *iitem;
		      t->«name»(«getArgSequence('item').join(', ')»);
		    }
		  });
		''')»
		  «ELSEIF hasSupport»
		  T* t = static_cast<T*>(this);
		  «wrapMethodContentWithMoniloggerInstrumentation(name.toUpperCase,
		'''
		  ENUMERATE_«support.literal.toUpperCase» (iitem, items) {
		    const «support.literal» item = *iitem;
		    t->«name»(«getArgSequence('item').join(', ')»);
		  }
		''')»
		  «ELSE»
		  «IF returnType !== null»
		  «returnType.typeName» result;
		  «wrapMethodContentWithMoniloggerInstrumentation(name.toUpperCase,'''result = this->«name»(«argSequence.join(', ')»);''')»
		  return result;
		  «ELSE»
		  «wrapMethodContentWithMoniloggerInstrumentation(name.toUpperCase,'''this->«name»(«argSequence.join(', ')»);''')»
		  «ENDIF»
		  «ENDIF»
		}
	'''

	static def wrapMethodContentWithMoniloggerInstrumentation(String baseEventName, String content)
	'''
		MoniLogger::trigger(«baseEventName»_BEFORE, ctx);
		if (MoniLogger::has_registered_moniloggers(«baseEventName»_REPLACE))
		{
		  MoniLogger::trigger(«baseEventName»_REPLACE, ctx);
		} else {
		  «content»
		}
		MoniLogger::trigger(«baseEventName»_AFTER, ctx);
	'''

	static def getItemTypeSpecializedHeaderContent(CppMethod it)
	'''
		//! Classe portant le code de l'opération «name» spécialisée par type d'item.
		template <class T>
		class «itemTypeSpecializedClassName»
		: public AbstractItemOperationByBasicType
		{
		  public:
		    explicit «itemTypeSpecializedClassName»(«getDeveloperArgs(true, 'T* srv').join(', ')»)
			«FOR a : getConstructorInitializationArgs('m_srv(srv)') BEFORE ': ' SEPARATOR '\n, '»«a»«ENDFOR»
			{
			}
		    ~«itemTypeSpecializedClassName»() {};

		  public:
		    «FOR t : MeshItemBasicTypes»
		    void apply«t»(ItemVectorView items) override { m_srv->«name»«t»(«getArgSequence('items').join(', m_')»); }
		    «ENDFOR»
		
		  private:
		    T* m_srv;
		    «IF GenerationContext::Current.generationOptions.variableAsArgs»«varClassName» m_vars;«ENDIF»
		    «FOR a : argDefinitions»
		    «a.typeName» «a.fieldName»;
		    «ENDFOR» 
		};
	'''

	private static def getConstructorInitializationArgs(CppMethod it, String prefix)
	{
		val l = new ArrayList<String>
		if (!prefix.nullOrEmpty) l+= prefix
		if (GenerationContext::Current.generationOptions.variableAsArgs) l += 'm_vars(vars)'
		l += argDefinitions.map[a | a.fieldName + '(' + a.name + ')'].toList
		return l
	}

	private static def getArgSequence(CppMethod it) { getArgSequence(it, null) }
	private static def getArgSequence(CppMethod it, String prefix)
	{
		val l = new ArrayList<String>
		if (!prefix.nullOrEmpty) l+= prefix
		if (GenerationContext::Current.generationOptions.variableAsArgs) l += 'vars'
		argDefinitions.forEach[a | l += a.name]
		return l
	}

	private static def getCallerArgs(CppMethod it)
	{
		val l = new ArrayList<String>

		if (itemTypeSpecialized) l += 'const ItemGroup& items'
		else if (hasSupport) l += 'const ' + support.literal + 'VectorView items'
		l += allArgs.argsWithDefaultValue
		return l
	}

	private static def getDeveloperArgs(CppMethod it, boolean withDefaultValue) { getDeveloperArgs(it, withDefaultValue, null) }
	private static def getDeveloperArgs(CppMethod it, boolean withDefaultValue, String prefix)
	{
		val l = new ArrayList<String>
		if (!prefix.nullOrEmpty) l+= prefix
		if (hasSupport) l += 'const ' + support.literal + ' ' + support.literal.toLowerCase
		if (GenerationContext::Current.generationOptions.variableAsArgs) l += varClassName + '& vars'
		if (withDefaultValue) l += argDefinitions.argsWithDefaultValue
		else argDefinitions.forEach[x | l += x.typeName + ' ' + x.name]
		return l
	}

	private static def getArgsWithDefaultValue(Iterable<? extends Arg> args)
	{
		val argStrings = new ArrayList<String>
		if (args !== null && !args.empty)
		{
			var lastDefaultVal = true
			for (i : args.size..1) 
			{
				val a = args.get(i-1)
				switch a 
				{
					ArgDefinition :
					{
						var s = a.typeName + ' ' + a.name
						if (a.multiplicity == ArgMultiplicity::SCALAR && a.direction == Direction::IN && lastDefaultVal && !a.defaultValue.nullOrEmpty) s += '=' + a.formatDefaultValue
						else lastDefaultVal = false
						argStrings.add(0, s)
					}

					VarDefinition :
					{
						val cppVariable = new CppVarDefinition(a)
						argStrings.add(0, cppVariable.argTypeName + ' ' + cppVariable.name)
					}
				}
			}
		}
		return argStrings
	}

	private static def formatDefaultValue(ArgDefinition a)
	{
		if ( a.type instanceof Simple && ((a.type as Simple).type == SimpleType::STRING) )
			return '"' + a.defaultValue + '"'
		else if (a.type instanceof Reference && (a.type as Reference).target instanceof Enumeration)
		{
			val enum = (a.type as Reference).target as Enumeration
			return enum.referencedNameWithNs + "::" + a.defaultValue
		}
		else
			return a.defaultValue
	}
}