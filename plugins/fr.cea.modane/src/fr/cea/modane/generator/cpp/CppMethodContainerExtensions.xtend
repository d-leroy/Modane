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

import fr.cea.modane.generator.cmake.ModelInfo
import fr.cea.modane.modane.Direction
import fr.cea.modane.modane.Function
import fr.cea.modane.modane.Interface
import fr.cea.modane.modane.ModaneElement
import fr.cea.modane.modane.Module
import fr.cea.modane.modane.Pty
import fr.cea.modane.modane.Reference
import fr.cea.modane.modane.Service
import org.eclipse.xtext.generator.IFileSystemAccess

import static extension fr.cea.modane.ModaneElementExtensions.*
import static extension fr.cea.modane.ModaneStringExtensions.*
import static extension fr.cea.modane.PtyExtensions.*
import static extension fr.cea.modane.generator.cpp.CppMethodExtensions.*
import static extension fr.cea.modane.generator.cpp.ItemTypeExtensions.*
import static extension fr.cea.modane.generator.cpp.PtyExtensions.*
import static extension fr.cea.modane.generator.cpp.PtyOrArgTypeExtensions.*
import static extension fr.cea.modane.generator.cpp.ReferenceableExtensions.*

class CppMethodContainerExtensions
{
	static def compile(CppMethodContainer it, IFileSystemAccess fsa, boolean profAccInstrumentation, boolean sciHookInstrumentation, ModelInfo modelInfo)
	{
		val context = GenerationContext::Current

		val instrument = sciHookInstrumentation && !methodsToOverwrite.empty

		//
		// le fichier avec les classes de variables
		//
		if (context.generationOptions.variableAsArgs)
		{
			// le fichier contenant les structures des variables
			context.newFile(outputPath, varClassFileName, true, component)
			modelInfo.cppFiles += varClassFileName
			for (m  : allMethods)
			{
				context.addContent(m.varClassContent)
			}
			context.generate(fsa)
		}

		//
		// le fichier avec les contextes d'exécution SciHook
		//
		if (instrument) {
			context.newFile(outputPath, contextsClassFileName, true, component)
			modelInfo.cppFiles += contextsClassFileName
			for (m  : methodsToOverwrite)
			{
				// We only generate a dedicated execution context struct if it would contain variables
				if (m.executionContextArgs.length > 1) context.addContent(m.executionContextClassContent)
			}
			context.addInclude("scihook/SciHook.h")
			context.generate(fsa)
		}

		//
		// le fichier avec les bindings SciHook
		//
		if (instrument && methodsToOverwrite.exists[executionContextArgs.size > 1]) {
			context.newFile(outputPath, bindingsClassFileName, true, component)
			modelInfo.cppFiles += bindingsClassFileName
			modelInfo.targets += "scihook"
			for (i : interfaces) context.addInclude(i.outputPath, i.referencedFileName)

			// fonctions itemTypeSpecialized
			for (m  : allMethods.filter[ m | m.itemTypeSpecialized]) context.addInclude(outputPath, m.itemTypeSpecializedClassHeaderFileName)

			if (allMethods.exists[m | m.itemTypeSpecialized])
				context.addInclude("arcane/utils/NotImplementedException.h")
			if (allMethods.exists[m | m.hasParallelLoops &&  m.support.component])
				context.addInclude("arcane/materials/MatConcurrency.h")
			else if (allMethods.exists[m | m.hasParallelLoops])
				context.addInclude("arcane/Concurrency.h")

			if (context.generationOptions.variableAsArgs) context.addInclude(outputPath, varClassFileName)
			context.addInclude(outputPath, contextsClassFileName)

			//FIXME: get missing includes by side-effect
			getBaseClassContent(profAccInstrumentation, sciHookInstrumentation)
			context.addInclude("scihook/scihookdefs.h")
			context.addContent(bindingsClassContent)
			if (hasAxl)
			{
				val axlHFileName = shortName + '_axl.h'
				context.addInclude(outputPath, axlHFileName)
				modelInfo.cppFiles += axlHFileName
			}
			else // classe d'implémentation qui n'est pas un service
			{
				context.addInclude("arcane/IMesh.h")
				context.addInclude("arcane/MeshAccessor.h")
				context.addInclude("arcane/utils/TraceAccessor.h")
			}
			context.generate(fsa)
		}

		//
		// le fichier avec la classe de base
		//
		context.newFile(outputPath, baseClassFileName, true, component)
		modelInfo.cppFiles += baseClassFileName
		for (i : interfaces) context.addInclude(i.outputPath, i.referencedFileName)

		// include de la classe des variables
		if (context.generationOptions.variableAsArgs) context.addInclude(outputPath, varClassFileName)
		// include de la classe des contextes d'exécution
		if (instrument) {
			context.addInclude("scihook/scihookdefs.h")
			context.addFlaggedInclude(outputPath, contextsClassFileName, sciHookIfDefContent)
		}

		// fonctions itemTypeSpecialized
		for (m  : allMethods.filter[ m | m.itemTypeSpecialized]) context.addInclude(outputPath, m.itemTypeSpecializedClassHeaderFileName)

		if (allMethods.exists[m | m.itemTypeSpecialized])
			context.addInclude("arcane/utils/NotImplementedException.h")
		if (allMethods.exists[m | m.hasParallelLoops &&  m.support.component])
			context.addInclude("arcane/materials/MatConcurrency.h")
		else if (allMethods.exists[m | m.hasParallelLoops])
			context.addInclude("arcane/Concurrency.h")
		if (profAccInstrumentation && allMethods.exists[m | m.profAcc])
		{
			modelInfo.targets += "accenv"
			context.addInclude("accenv/ProfAcc.h")
		}

		// Contenu de la classe de base
		context.addContent(getBaseClassContent(profAccInstrumentation, sciHookInstrumentation))
		if (hasAxl) 
		{
			val axlHFileName = shortName + '_axl.h'
			context.addInclude(outputPath, axlHFileName)
			modelInfo.cppFiles += axlHFileName
		}
		else // classe d'implémentation qui n'est pas un service
		{
			context.addInclude("arcane/IMesh.h")
			context.addInclude("arcane/MeshAccessor.h")
			context.addInclude("arcane/utils/TraceAccessor.h")
		}
		context.generate(fsa)

		//
		// les fichiers .h et .cc d'implémentation (sont générés s'ils n'existent pas)
		//
		// le .h
		context.newFile(outputPath, developerHeaderFileName, false, component)
		modelInfo.cppFiles += developerHeaderFileName
		context.addInclude(outputPath, baseClassFileName)
		context.addContent(developerHeaderContent)
		context.generateIfNotExist(fsa)	

		// le .cc
		context.newFile(outputPath, developerBodyFileName, false, component)
		modelInfo.cppFiles += developerBodyFileName
		context.addInclude(outputPath, developerHeaderFileName)
		context.addContent(developerBodyContent)
		context.generateIfNotExist(fsa)

		// les classes pour les fonctions ItemTypeSpecialized
		for (m : allMethods.filter[x | x.itemTypeSpecialized])
		{
			// le .h (pas de .cc)
			val hFileName = m.itemTypeSpecializedClassHeaderFileName
			context.newFile(outputPath, hFileName, false, false)
			modelInfo.cppFiles += hFileName
			context.addInclude("arcane/AbstractItemOperationByBasicType.h")
			context.addInclude("arcane/Item.h")
			context.addUsedNs("Arcane")
			if (context.generationOptions.variableAsArgs) context.addInclude(outputPath, varClassFileName)
			context.addContent(m.itemTypeSpecializedHeaderContent)
			context.generate(fsa)
		}
	}

	private static def getBaseClassContent(CppMethodContainer it, boolean profAccInstrumentation, boolean sciHookInstrumentation)
	'''
		/*!
		 * \brief «modaneElement.eClass.name» «modaneElement.name» : classe de base. 
		 * «FOR l : modaneElement.fromDescription SEPARATOR '\n'»«l»«ENDFOR»
		 */
		template<class T>
		class «baseClassName»
		«IF modaneElement instanceof Interface»
		: public «(modaneElement as Interface).referencedName»
		, public TraceAccessor
		, public MeshAccessor
		«ELSE»
		: public Arcane«shortName»Object
		«ENDIF»
		{
		 «IF sciHookInstrumentation»
		 #if «sciHookIfDefContent»
		 private:
		  «FOR m : methodsToOverwrite»
		  «val baseEventName = m.name.toUpperCase»
		  size_t «baseEventName»_BEFORE;
«««		  size_t «baseEventName»_REPLACE;
		  size_t «baseEventName»_AFTER;
		  «ENDFOR»
		 #endif
		 «ENDIF»
		 public:  // ***** CONSTRUCTEUR & DESTRUCTEUR
		  «IF modaneElement instanceof Interface»
		  explicit «baseClassName»(IMesh* mesh) 
		  : TraceAccessor(mesh->traceMng())
		  , MeshAccessor(mesh)
		  «ELSE»
		  explicit «baseClassName»(const «classNameSuffix»BuildInfo& bi)
		  : Arcane«shortName»Object(bi)
		  «ENDIF»
		  «IF component», m_mesh_material_mng(IMeshMaterialMng::getReference(«modaneElement.meshInstanceInCtsr»))«ENDIF»
		  «FOR p : allProperties.filter(x | !x.concrete)»
		  , «p.fieldName»(new ::«p.interface.nsName»::«p.interface.developerClassNameAndAddInclude»(«modaneElement.meshInstanceInCtsr»))
		  «ENDFOR»
		  {
		    «insertDebugMsg»
		    «IF sciHookInstrumentation»
		    #if «sciHookIfDefContent»
		    «FOR m : methodsToOverwrite»
		    «m.name.toUpperCase»_BEFORE = SciHook::register_base_event("«baseClassName + "." + m.name.toFirstUpper».Before");
«««		    «m.name.toUpperCase»_REPLACE = SciHook::register_base_event("«baseClassName + "." + m.name.toFirstUpper».Replace");
		    «m.name.toUpperCase»_AFTER = SciHook::register_base_event("«baseClassName + "." + m.name.toFirstUpper».After");
		    «ENDFOR»
		    #endif
		    «ENDIF»
		  }

		  virtual ~«baseClassName»()
		  {
		    «insertDebugMsg»
		    «FOR p : allProperties.filter(x | !x.concrete)»
		    delete «p.fieldName»;
		    «ENDFOR»
		  }

		 public:  // ***** ACCESSEURS
		  «FOR p : allProperties»
		  «IF p.concrete»
		  «p.getGetterContent('''return options()->«p.getterName»();''', false)»
		  «IF p.needHasAccessor»«p.getHasAccessorContent('''return options()->«p.hasName»();''', false)»«ENDIF»
		  «ELSE»
		  «p.getGetterContent('''return «p.fieldName»;''', false)»
		  «IF p.needHasAccessor»«p.getHasAccessorContent('''return true;''', false)»«ENDIF»
		  «ENDIF»
		  «ENDFOR»
		  «IF modaneElement instanceof Module»
		  VersionInfo versionInfo() const { return VersionInfo("1.0"); }
		  «ENDIF»
		  «IF !interfaces.empty»
		  const String getImplName() const { return "«developerClassName»"; }
		  «ENDIF»
		  «IF component»
		  IMeshMaterialMng* getMeshMaterialMng() const { return m_mesh_material_mng; }
		  «ENDIF»

		 public:  // ***** METHODES CONCRETES
		  «FOR m : methodsToOverwrite» «/* Ne pas utiliser 'SEPARATOR '\n' car il y a des espaces en trop...*/»
		  /*!
		   «IF m.needDotGraph»«m.dotGraph»«ENDIF»
		   «FOR l : m.description SEPARATOR '\n'»«l»«ENDFOR»
		   Cette méthode construit les variables et appelle «developerClassName»::«m.name».
		  */
		  «m.getBaseClassBody(debugVar, profAccInstrumentation, sciHookInstrumentation)»

		  «ENDFOR»

		 public:  // ***** METHODES ABSTRAITES
		  «FOR m : allMethods»
		  «IF m.itemTypeSpecialized»
		  «FOR t : CppMethodExtensions::MeshItemBasicTypes»
		  virtual «m.getHeaderDeveloperSignature(t)» { throw NotImplementedException(A_FUNCINFO); }
		  «ENDFOR»
		  «ELSE»
		  virtual «m.headerDeveloperSignature» = 0;
		  «ENDIF»
		  «ENDFOR»

		 protected:  // ***** ATTRIBUTS
		  «IF component»IMeshMaterialMng* m_mesh_material_mng;«ENDIF»
		  «FOR p : allProperties.filter(x | !x.concrete)»
		  «p.attrTypeName» «p.fieldName»;
		  «ENDFOR»
		};
	'''

	/** 
	 *  Il ne faut pas surcharger les méthodes si elles n'ont pas de support, qu'elles ne sont pas itemTypeSpecialized
	 *  et que 'variableAsArgs=false'. Car dans ce cas, la signature de la méthode dans la classe de base est la même
	 *  que celle dans l'interface.
	 */
	private static def getMethodsToOverwrite(CppMethodContainer it)
	{
		allMethods.filter[x | GenerationContext::Current.generationOptions.variableAsArgs || x.hasSupport || x.itemTypeSpecialized]
	}

	private static def getDeveloperHeaderContent(CppMethodContainer it)
	'''
		/*!
		 * \brief «modaneElement.eClass.name» «modaneElement.name» : implémentation
		 * «FOR l : modaneElement.fromDescription SEPARATOR '\n'»«l»«ENDFOR»
		 */
		class «developerClassName»
		: public «baseClassName»<«developerClassName»>
		{
		 public:
		  «IF modaneElement instanceof Interface»
		  explicit «developerClassName»(IMesh* mesh);
		  «ELSE»
		  explicit «developerClassName»(const «classNameSuffix»BuildInfo& bi);
		  «ENDIF»
		  ~«developerClassName»();

		 public:
		  «FOR m : allMethods»
		  «IF m.itemTypeSpecialized»
		  «FOR t : CppMethodExtensions::MeshItemBasicTypes»
		  //«m.getHeaderDeveloperSignature(t)» override;
		  «ENDFOR»
		  «ELSE»
		  «m.headerDeveloperSignature» override;
		  «ENDIF»
		  «ENDFOR»
		  «FOR m : unitTestMethodNames»
		  void «m»() override;
		  «ENDFOR»
		};
	'''

	private static def getDeveloperBodyContent(CppMethodContainer it)
	'''
		«developerClassName»::
		«IF modaneElement instanceof Interface»
		«developerClassName»(IMesh* mesh)
		: «baseClassName»<«developerClassName»>(mesh)
		«ELSE»
		«developerClassName»(const «classNameSuffix»BuildInfo& bi)
		: «baseClassName»<«developerClassName»>(bi)
		«ENDIF»
		{
		}
		«GenerationContext::Separator»
		«developerClassName»::
		~«developerClassName»()
		{
		}
			
		«FOR m : allMethods»
		«GenerationContext::Separator»
		«IF m.itemTypeSpecialized»
			«FOR t : CppMethodExtensions::MeshItemBasicTypes»
			//«m.getBodyDeveloperSignature(developerClassName, t)» {}
			«ENDFOR»		
		«ELSE»
		«m.getBodyDeveloperSignature(developerClassName)»
		{
		}
	  	«ENDIF»
		«ENDFOR»
		«FOR m : unitTestMethodNames»
		«GenerationContext::Separator»
		void «developerClassName»::
		«m»()
		{
		}
		«ENDFOR»
		«GenerationContext::Separator»
		«IF modaneElement instanceof Module»
		ARCANE_REGISTER_MODULE_«shortName.toUpperCase»(«developerClassName»);
		«ELSEIF modaneElement instanceof Service»
		ARCANE_REGISTER_SERVICE_«shortName.toUpperCase»(«shortName», «developerClassName»);
		«ENDIF»
	'''

	static def getDeveloperClassName(CppMethodContainer it) { shortName + classNameSuffix }
	static def getBaseClassName(CppMethodContainer it) { developerClassName + 'Base' }
	static def getDeveloperHeaderFileName(CppMethodContainer it) { developerClassName + GenerationContext::HeaderExtension }
	static def getDeveloperBodyFileName(CppMethodContainer it) { developerClassName + GenerationContext::BodyExtension }

	private static def getBaseClassFileName(CppMethodContainer it) { GenerationContext::GenFilePrefix + baseClassName + GenerationContext::HeaderExtension }
	private static def getOutputPath(CppMethodContainer it) { modaneElement.outputPath }

	private static def getVarClassFileName(CppMethodContainer it)
	{ 
		GenerationContext::GenFilePrefix + developerClassName + 'Vars' + GenerationContext::HeaderExtension
	}

	private static def getContextsClassFileName(CppMethodContainer it)
	{
		GenerationContext::GenFilePrefix + developerClassName + 'Contexts' + GenerationContext::HeaderExtension
	}

	private static def getBindingsClassFileName(CppMethodContainer it)
	{
		GenerationContext::GenFilePrefix + developerClassName + 'Bindings' + GenerationContext::BodyExtension
	}

	private static def String getSciHookIfDefContent(CppMethodContainer it)
	{
		'''defined(SCIHOOK_ENABLED) && not defined(SCIHOOK_«debugVar»_DISABLED)'''
	}

	private static def String getDebugVar(CppMethodContainer it)
	{
		val context = GenerationContext::Current
		val result = modaneElement.model.name.replace('.', '_').toUpperCase
		context.cmakeVariables += '''SCIHOOK_«result»_DISABLED'''
		return result
	}

	private static def getEmbeddedModuleName(CppMethodContainer it)
	{
		val context = GenerationContext::Current
		val result = '''«context.nsName.toLowerCase»_«shortName.toLowerCase»'''
		context.embeddedModules += result
		return result
	}

	private static def getBindingsClassContent(CppMethodContainer it)
	'''
		#if «sciHookIfDefContent»
		«val context = GenerationContext::Current»
		PYBIND11_EMBEDDED_MODULE(«embeddedModuleName», m)
		{
		  «FOR m : methodsToOverwrite»
		  «IF m.executionContextArgs.length > 1»
		  pybind11::class_<«context.nsName»::«m.executionContextClassName», std::shared_ptr<«context.nsName»::«m.executionContextClassName»>, SciHook::SciHookExecutionContext>(m, "«m.executionContextClassName»")
		    «IF m.itemTypeSpecialized || m.hasSupport».def_property_readonly("items", &«context.nsName»::«m.executionContextClassName»::get_items)«ENDIF»
		    «FOR a : m.argDefinitions SEPARATOR '\n'».def_property_readonly("«a.name»", &«context.nsName»::«m.executionContextClassName»::get_«a.name»)«ENDFOR»
		    «FOR v : m.allVars SEPARATOR '\n'».def_property_readonly("«v.name»", &«context.nsName»::«m.executionContextClassName»::get_«v.fieldName»)«ENDFOR»
		    .def("__str__", [](«context.nsName»::«m.executionContextClassName» &self)
		    {
		      std::ostringstream oss;
		      oss << "[" << self.name << "]";
		      return oss.str();
		    })
		    .def("__repr__", [](«context.nsName»::«m.executionContextClassName» &self)
		    {
		      std::ostringstream oss;
		      oss << "[" << self.name << "]";
		      return oss.str();
		    });
		  «ENDIF»
		  «ENDFOR»
		}
		#endif
	'''

	private static def isComponent(CppMethodContainer it)
	{
		if (GenerationContext::Current.generationOptions.alwaysMaterialMng)
			return true
		else
		{
			for (m : allMethods)
			{
				if (m.support.component) return true
				else if (m.allVars.exists[v | v.component]) return true
				else if (m.argDefinitions.exists[a | a.type.component]) return true
			}
		}
		return false
	}

	/**
	 * Extrait l'interface de la propriété non concrète 
	 * qui, par définition, est de type Referenceable sur une Interface
	 */
	private static def getInterface(Pty p) { (p.type as Reference).target as Interface }

	private static def dispatch getMeshInstanceInCtsr(Module it) '''bi.mesh()'''
	private static def dispatch getMeshInstanceInCtsr(Service it) '''bi.mesh()'''
	private static def dispatch getMeshInstanceInCtsr(Interface it) '''mesh'''

	private static def getDeveloperClassNameAndAddInclude(Interface i) 
	{ 
		val _i = new InterfaceCppMethodContainer(i)
		GenerationContext::Current.addInclude(_i.outputPath, _i.developerHeaderFileName)
		_i.developerClassName
	}

	// Fonctions utilitaires pour le graphe DOT
	
	private static def needDotGraph(CppMethod m)
	{
		!(m.allVars.empty && m.calls.empty)
	}

	private static def getDotGraph(CppMethod m)
	'''
	\dot
	  digraph «m.name»Graph
	  {
	    compound="true";
	    edge [arrowsize="0.5", fontsize="8"];
	    node [shape="box", fontname="Arial", fontsize="10"];
	    {
	      rank=same;
	      «m.name» [style="rounded, filled", fillcolor="gray"];
	      «IF m.allVars.exists(x | x.direction == Direction::IN || x.direction == Direction::INOUT)»
	      inVars [shape="record", label="«FOR v : m.allVars.filter(x | x.direction == Direction::IN || x.direction == Direction::INOUT) SEPARATOR " | "»«v.name»«ENDFOR»"];
	      inVars -> «m.name»;
	      «ENDIF»
	      «IF m.allVars.exists(x | x.direction == Direction::OUT || x.direction == Direction::INOUT)»
	      outVars [shape="record", label="«FOR v : m.allVars.filter(x | x.direction == Direction::OUT || x.direction == Direction::INOUT) SEPARATOR " | "»«v.name»«ENDFOR»"];
	      «m.name» -> outVars;
	      «ENDIF»
	    }

	    «IF !m.calls.empty»
	    subgraph clusterCalledFuncs
	    {
	      center="true";
	      color="navy";
	      «FOR cf : m.calls»
	      «cf.containerClassName»_«cf.name» [label="«cf.name»", color="navy", fontcolor="navy", style="rounded", URL="\ref «cf.container.nsName»::«cf.containerClassName»::«cf.name»"];
	      «ENDFOR»
	    }
	    «m.name» -> «m.calls.last.containerClassName»_«m.calls.last.name» [lhead="clusterCalledFuncs", style="dashed", label=" call"];
	    «ENDIF»
	  }
	\enddot
	'''

	private static def getContainer(Function f) { f.eContainer as ModaneElement }
	private static def getContainerClassName(Function f) { (f.eContainer as ModaneElement).containerName }
	private static def dispatch getContainerName(Module m) { new ModuleCppMethodContainer(m).baseClassName }
	private static def dispatch getContainerName(Service s) { new ServiceCppMethodContainer(s).baseClassName }
	private static def dispatch getContainerName(Interface i) { i.referencedName }
}
