/*******************************************************************************
 * Copyright (c) 2022 CEA
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.modane.headless;

import java.io.File;
import java.lang.ProcessBuilder.Redirect;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.equinox.app.IApplication;
import org.eclipse.equinox.app.IApplicationContext;
import org.eclipse.uml2.uml.Model;
import org.eclipse.xtext.xbase.lib.Procedures.Procedure2;

import fr.cea.modane.generator.ModaneGeneratorMessageDispatcher;
import fr.cea.modane.uml.ModaneModelReader;
import fr.cea.modane.uml.ModaneToCpp;
import fr.cea.modane.uml.UmlToModane;

public class Application implements IApplication {
	/**
	 * Environment variable to get the emf2xmi Magicdraw tool. Depending on the the
	 * Magicdraw installation. Full path is needed.
	 */
	final static String EMF2XMI = "EMF2XMI";

	String cppDir = null;
	String modaneDir = null;
	String umlDir = null;
	String modaneRootDir = null;
	String[] mdzipFiles = null;
	String[] umlFiles = null;
	String[] modaneFiles = null;
	String pkgToGenerate = null;
	boolean generateAll = false;
	boolean obfuscate = false;
	boolean sciHookInstrumentation = false;
	boolean profAccInstrumentation = false;
	boolean writeCMakeListsFiles = false;
	boolean writeCMakeFiles = false;
	boolean writeModaneFiles = false;

	/**
	 * Always return Application.EXIT_OK to avoid an unexpected message dialog
	 * window.
	 */
	@Override
	public Object start(IApplicationContext context) throws Exception {
		// Parse arguments and execute
		final Map<?, ?> args = context.getArguments();
		final String[] appArgs = (String[]) args.get("application.args");
		if (parseArgs(appArgs)) {
			// Arguments are checked
			if (umlDir != null && mdzipFiles != null && mdzipFiles.length > 0) {
				// Step 0: check EMF2XMI_DIR environment variable
				String emf2xmiDir = System.getenv(EMF2XMI);
				if (emf2xmiDir == null) {
					System.out.println(EMF2XMI
							+ " environment variable must be set with the full path to Magicdraw emf2xmi tool.");
					return Application.EXIT_OK;
				}

				// Step 1: ".mdzip" file to ".uml" file
				System.out.println(">>>>> MDZIP --> EMF UML");
				System.out.println("      emf2xmi dir     : " + emf2xmiDir);
				System.out.println("      Destination dir : " + umlDir);

				umlFiles = new String[mdzipFiles.length];
				for (int i = 0; i < mdzipFiles.length; ++i) {
					final String mdzipFile = mdzipFiles[i];
					System.out.println("      Mdzip file      : " + mdzipFile);
					final ProcessBuilder pb = new ProcessBuilder(emf2xmiDir, "project_file=" + mdzipFile,
							"destination_dir=" + umlDir);
					pb.redirectOutput(Redirect.INHERIT);
					pb.redirectError(Redirect.INHERIT);
					final Process p = pb.start();
					p.waitFor();
					final int exitValue = p.exitValue();
					System.out.println("        Exit value : " + exitValue);

					if (exitValue != 0) {
						System.out.println("**    UML generation failed for " + mdzipFile + ". Exiting...");
						return Application.EXIT_OK;
					}

					System.out.println("      UML generation ok for " + mdzipFile);
					File f = new File(mdzipFile);
					umlFiles[i] = umlDir + '/' + f.getName().replace(".mdzip", ".uml");
				}
				System.out.println(">>>>> MDZIP --> EMF UML finished");
			}

			final List<Resource> resourcesToGenerate = new ArrayList<>();

			if (umlFiles != null && umlFiles.length > 0) {
				// C++ generation from a ".uml" file
				final Set<URI> resourceURIs = new HashSet<>();
				for (int i = 0; i < umlFiles.length; ++i) {
					final String umlFile = umlFiles[i];

					System.out.println(">>>>> Loading EMF UML resource: " + umlFile);
					final UmlToModane umlToModane = UmlToModane.createInstance();
					umlToModane.setResourceURICache(resourceURIs);

					final Procedure2<ModaneGeneratorMessageDispatcher.MessageType, String> printConsole = //
							(ModaneGeneratorMessageDispatcher.MessageType type, String msg) -> System.out.println(msg);
					umlToModane.getMessageDispatcher().getTraceListeners().add(printConsole);

					final Model model = umlToModane.readModel(URI.createFileURI(umlFile));
					final String outputDir = cppDir == null ? modaneDir : cppDir;
					if (pkgToGenerate == null) {
						resourcesToGenerate.addAll(umlToModane.generate(model, outputDir, "", writeModaneFiles, obfuscate));
					} else {
						resourcesToGenerate.addAll(umlToModane.generate(model, outputDir, pkgToGenerate, writeModaneFiles, obfuscate));
					}
					resourcesToGenerate.forEach(r -> resourceURIs.add(r.getURI()));
					System.out.println(">>>>> EMF UML resource loaded: " + umlFile);
				}
			} else if (modaneRootDir != null && ((modaneFiles != null && modaneFiles.length > 0) || generateAll)) {
				// C++ generation from a ".m" file
				final List<URI> modaneFileURIs = new ArrayList<>();
				if (!generateAll) {
					modaneFileURIs.addAll(Arrays.stream(modaneFiles)
							.map(s -> URI.createFileURI(new File(s).getAbsolutePath())).collect(Collectors.toList()));
				}

				System.out.println(">>>>> Loading Modane models");
				final ModaneModelReader modaneModelReader = ModaneModelReader.createInstance();

				final List<File> allModaneFiles = gatherModaneFiles(modaneRootDir);
				allModaneFiles.forEach(f -> {
					final URI fileURI = URI.createFileURI(f.getAbsolutePath());
					if (generateAll || modaneFileURIs.stream()
							.anyMatch(uri -> uri.toFileString().equals(fileURI.toFileString()))) {
						resourcesToGenerate.add(modaneModelReader.readModel(fileURI).eResource());
					} else {
						modaneModelReader.readModel(fileURI);
					}
				});
				modaneModelReader.resolveAll();
				System.out.println(">>>>> Modane models loaded");
			}

			if (!resourcesToGenerate.isEmpty() && cppDir != null) {
				System.out.println(">>>>> Starting generation process");
				final ModaneToCpp modaneToCpp = ModaneToCpp.createInstance();
				final Procedure2<ModaneGeneratorMessageDispatcher.MessageType, String> printConsole = //
						(ModaneGeneratorMessageDispatcher.MessageType type, String msg) -> System.out.println(msg);
				modaneToCpp.getMessageDispatcher().getTraceListeners().add(printConsole);

				if (pkgToGenerate == null) {
					modaneToCpp.generate(resourcesToGenerate, cppDir, "", "", profAccInstrumentation,
							sciHookInstrumentation, writeCMakeListsFiles, writeCMakeFiles);
				} else {
					modaneToCpp.generate(resourcesToGenerate, cppDir, "", pkgToGenerate, profAccInstrumentation,
							sciHookInstrumentation, writeCMakeListsFiles, writeCMakeFiles);
				}
				System.out.println(">>>>> Generation process ended successfully");
			}
		}

		return Application.EXIT_OK;
	}

	private List<File> gatherModaneFiles(String directoryName) {
		final File directory = new File(directoryName);
		final File[] fList = directory.listFiles();
		final List<File> result = new ArrayList<>();
		if (fList != null) {
			for (File file : fList) {
				if (file.isFile() && getExtension(file).orElse("").equals("m")) {
					result.add(file);
				} else if (file.isDirectory()) {
					result.addAll(gatherModaneFiles(file.getAbsolutePath()));
				}
			}
		}
		return result;
	}

	public Optional<String> getExtension(File file) {
		final String filename = file.getName();
		return Optional.ofNullable(filename).filter(f -> f.contains("."))
				.map(f -> f.substring(filename.lastIndexOf(".") + 1));
	}

	@Override
	public void stop() {
		// nothing to do
	}

	private void printUsage() {
		System.out.println("Usage (Directories need absolute pathes and package separator is '.': A, A.B, A.B.C...):");
		System.out.println(
				"  Generate from a '.mdzip' model: modane --cpp-dir <AXL_AND_CPP_FILES_OUTPUT_DIR> --uml-dir <UML_FILES_OUTPUT_DIR> --mdzip <MDZIP_MODEL_FILE> [--pkg <PACKAGE_NAME_TO_GENERATE>] [--cmakes] [--scihook] [--profacc]");
		System.out.println(
				"  Generate from a '.uml'   model: modane --cpp-dir <AXL_AND_CPP_FILES_OUTPUT_DIR> --uml <UML_ROOT_MODEL_FILE> [--pkg <PACKAGE_NAME_TO_GENERATE>] [--cmakes] [--scihook] [--profacc]");
		System.out.println("  Note: --mdzip and --uml options accept a list of comma separated files (no space)");
	}

	private boolean parseArgs(String[] appArgs) {
		boolean valid = false;

		for (int i = 0; i < appArgs.length; ++i) {
			switch (appArgs[i]) {
			case "--cpp-dir":
				cppDir = appArgs[++i];
				break;
			case "--uml-dir":
				umlDir = appArgs[++i];
				break;
			case "--mdzip": {
				String arg = appArgs[++i];
				mdzipFiles = arg.split(",");
				break;
			}
			case "--uml": {
				String arg = appArgs[++i];
				umlFiles = arg.split(",");
				break;
			}
			case "--modane-dir":
				modaneDir = appArgs[++i];
				break;
			case "--modane-all":
				generateAll = true;
				break;
			case "--modane-files":
				modaneFiles = appArgs[++i].split(",");
				break;
			case "--modane-files-write":
				writeModaneFiles = true;
				break;
			case "--modane-root":
				modaneRootDir = appArgs[++i];
				break;
			case "--pkg":
				pkgToGenerate = appArgs[++i];
				break;
			case "--scihook":
				sciHookInstrumentation = true;
				break;
			case "--profacc":
				profAccInstrumentation = true;
				break;
			case "--cmakelists":
				writeCMakeListsFiles = true;
				break;
			case "--cmakes":
				writeCMakeFiles = true;
				break;
			case "--obfuscate":
				obfuscate = true;
				writeModaneFiles = true;
				break;
			default: {
				System.out.println("Unknow option: " + appArgs[i]);
				printUsage();
				return false;
			}
			}
		}
		valid = (((writeModaneFiles || obfuscate) || dirOK(cppDir)) && (generateAll || filesOK(modaneFiles, "m")
				|| filesOK(umlFiles, "uml") || (filesOK(mdzipFiles, "mdzip") && dirOK(umlDir))));

		if (!valid)
			printUsage();
		return valid;
	}

	private boolean dirOK(String dir) {
		if (dir != null && dir != "") {
			File d = new File(dir);
			if (d.exists() && d.isDirectory())
				return true;
			System.out.println("Unknow directory: " + dir);
		}
		return false;
	}

	private boolean filesOK(String[] fileNames, String expectedExtension) {
		if (fileNames != null) {
			for (String fileName : fileNames) {
				if (fileName != null && fileName != "") {
					if (fileName.endsWith("." + expectedExtension)) {
						File f = new File(fileName);
						if (f.exists() && f.isFile())
							return true;
						System.out.println("Unknow " + expectedExtension + " file: " + fileName);
					} else
						System.out.println("Unknown file type (expected " + expectedExtension + "): " + fileName);
				}
			}
		}
		return false;
	}
}
