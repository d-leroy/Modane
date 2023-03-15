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
import fr.cea.modane.modane.Direction
import fr.cea.modane.modane.Enumeration
import fr.cea.modane.modane.FunctionItemType
import fr.cea.modane.modane.Item
import fr.cea.modane.modane.Reference
import fr.cea.modane.modane.Simple
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
		   * [«v.direction.literal»] «v.name»
		   «IF v.description !== null»
		   «FOR l : v.description»
		   * «l»
		   «ENDFOR»
		   «ENDIF»
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

	private static def getExecutionContextConstructorArgs(CppMethod it)
	{
		val l = new ArrayList<String>

		if (itemTypeSpecialized) l += 'const ItemGroup& items'
		else if (hasSupport) l += 'const ' + support.literal + 'VectorView items'
		l += argDefinitions.argsWithDefaultValue
		return l
	}

	static def getExecutionContextClassContent(CppMethod it)
	'''
		«val varsAsArgs = GenerationContext::Current.generationOptions.variableAsArgs»
		//! Classe de contexte d'exécution pour «name»
		struct «executionContextClassName» final : SciHook::SciHookExecutionContext
		{
		  «executionContextClassName»(std::string execution_context_name«IF !allVars.empty && varsAsArgs»,«'\n'»    «varClassName» *vars«ENDIF»«FOR a : executionContextConstructorArgs»,«'\n'»    «a»«ENDFOR»)
		  : SciHookExecutionContext(execution_context_name)
		  «IF itemTypeSpecialized || hasSupport», items(items)«ENDIF»
		  «IF !argDefinitions.empty», «FOR a : argDefinitions SEPARATOR '\n, '»«a.name»(«a.name»)«ENDFOR»«ENDIF»
		  «IF !allVars.empty», vars(vars)«ENDIF»
		  {}
		  «IF !executionContextConstructorArgs.empty || !allVars.empty»«'\n'»«ENDIF»
		  «FOR a : executionContextConstructorArgs»
		  «a»;
		  «ENDFOR»
		  «IF !allVars.empty && GenerationContext::Current.generationOptions.variableAsArgs»const «varClassName» *vars;«ENDIF»
		  «IF itemTypeSpecialized || hasSupport»

		  const pybind11::object get_items() const {
		    return pybind11::cast(items);
		  }
		  «ENDIF»
		  «FOR a : argDefinitions»

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
		args.add('''"«name.toFirstUpper + 'ExecutionContext'»"''')
		if (!allVars.empty && GenerationContext::Current.generationOptions.variableAsArgs) args.add('&vars')
		if (itemTypeSpecialized) args += 'items'
		else if (hasSupport) args += 'items'
		args.addAll(argDefinitions.map[name])
		return args
	}

	static def getExecutionContextClassInstance(CppMethod it, String ifDefContent)
	'''
		#if «ifDefContent»
		«val args = executionContextArgs»
		«IF args.length == 1»
		std::shared_ptr<SciHook::SciHookExecutionContext> ctx(
		    new SciHook::SciHookExecutionContext(«args.get(0)»));
		«ELSE»
		std::shared_ptr<«executionContextClassName»> ctx(
		    new «executionContextClassName»(«args.join('\n    , ')»));
		«ENDIF»
		#endif
	'''
	
	static def isItemTypeSpecialized(CppMethod it)	{ support == FunctionItemType::ITEM_TYPE_SPECIALIZED }
	static def hasSupport(CppMethod it) { support !== null && !isItemTypeSpecialized }
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

	static def getProfAcc(CppMethod it)
	{
		val to_instrument = (it instanceof EntryPointCppMethod || it instanceof OverrideFunctionCppMethod)
		if (itemTypeSpecialized)
		{
			to_instrument
		}
		else if (hasParallelLoops)
		{
			to_instrument
		}
		else if (hasSupport)
		{
			to_instrument
		}
		else if (returnType === null)
		{
			to_instrument
		}
		else
		{
			false
		}
	}
	
	static dispatch def getInstrumentationType(EntryPointCppMethod it) '''EP'''
	
	static dispatch def getInstrumentationType(OverrideFunctionCppMethod it) '''OF'''
	
	private static def String getSciHookIfDef(CppMethod it, String containerIfDefString)
	{
		'''defined(SCIHOOK_ENABLED) && not defined(SCIHOOK_«containerIfDefString»_DISABLED) && not defined(«getDebugVar(containerIfDefString)»)'''
	}

	private static def String getDebugVar(CppMethod it, String containerIfDefString)
	{
		val context = GenerationContext::Current
		val result = '''SCIHOOK_«containerIfDefString»_«name.toUpperCase»_DISABLED'''
		context.cmakeVariables += result
		return result
	}
	
	static def getBaseClassBody(CppMethod it, String containerIfDefString, boolean profAccInstrumentation, boolean sciHookInstrumentation)
	{
		val methodIfDefContent = getSciHookIfDef(containerIfDefString)
		val baseEventName = name.toUpperCase
		'''
			«callerSignature»«IF override» override«ENDIF»
			{
			  «insertDebugMsg»
			  «IF profAccInstrumentation && profAcc»
			  #if not defined(PROF_ACC_DISABLED)
			  prof_acc_begin("[«instrumentationType»]«containerName»::«name»");
			  #endif
			  
			  «ENDIF»
			  «IF GenerationContext::Current.generationOptions.variableAsArgs»«varClassInstance»«ENDIF»
			  «IF sciHookInstrumentation»
			  «getExecutionContextClassInstance(methodIfDefContent)»
			  «ENDIF»
			  «IF itemTypeSpecialized»
			  T* t = static_cast<T*>(this);
			  «itemTypeSpecializedClassName»<T> fclass(«getArgSequence('t').join(', ')»);
			  «wrapMethodContentWithSciHookInstrumentation(sciHookInstrumentation, methodIfDefContent, baseEventName, '''items.applyOperation(&fclass);''')»
			  «ELSEIF hasParallelLoops»
			  T* t = static_cast<T*>(this);
			  «wrapMethodContentWithSciHookInstrumentation(sciHookInstrumentation, methodIfDefContent, baseEventName,
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
			  «wrapMethodContentWithSciHookInstrumentation(sciHookInstrumentation, methodIfDefContent, baseEventName,
			'''
			  ENUMERATE_«support.literal.toUpperCase» (iitem, items) {
			    const «support.literal» item = *iitem;
			    t->«name»(«getArgSequence('item').join(', ')»);
			  }
			''')»
			  «ELSE»
			  «IF returnType !== null»
			  «returnTypeName» result;
			  «wrapMethodContentWithSciHookInstrumentation(sciHookInstrumentation, methodIfDefContent, baseEventName,'''result = this->«name»(«argSequence.join(', ')»);''')»
			  return result;
			  «ELSE»
			  «wrapMethodContentWithSciHookInstrumentation(sciHookInstrumentation, methodIfDefContent, baseEventName,'''this->«name»(«argSequence.join(', ')»);''')»
			  «ENDIF»
			  «ENDIF»
			  «IF profAccInstrumentation && profAcc»
			  #if not defined(PROF_ACC_DISABLED)
			  prof_acc_end("[«instrumentationType»]«containerName»::«name»");
			  #endif
			  «ENDIF»
			}
		'''
	}
	

	static def wrapMethodContentWithSciHookInstrumentation(boolean instrument, String ifDefContent, String baseEventName, String content)
	'''
		«IF instrument»
		#if «ifDefContent»
		SciHook::trigger(«baseEventName»_BEFORE, ctx);
		«content»
		SciHook::trigger(«baseEventName»_AFTER, ctx);
		#else
		«ENDIF»
		«content»
		«IF instrument»
		#endif
		«ENDIF»
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
						if (!a.multiple && a.direction == Direction::IN && lastDefaultVal && !a.defaultValue.nullOrEmpty) s += '=' + a.formatDefaultValue
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
		if ( a.type instanceof Simple && ((a.type as Simple).type == 'string') )
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