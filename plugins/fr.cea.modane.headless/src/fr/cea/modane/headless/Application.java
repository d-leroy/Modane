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

	String mdzipDir = null;
	String cppDir = null;
	String modaneDir = null;
	String umlDir = null;
	String[] mdzipFiles = null;
	String[] umlFiles = null;
	String[] modaneFiles = null;
	// From mdzip
	boolean generateUml = false;
	// From mdzip or uml
	boolean generateModaneFromMdzip = false;
	boolean generateModaneFromUml = false;
	// From mdzip, uml, or modane
	boolean generateCppFromMdzip = false;
	boolean generateCppFromUml = false;
	boolean generateCppFromModane = false;
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
			final List<URI> allUmlFiles = new ArrayList<>();
			
			if (generateUml || generateModaneFromMdzip || generateCppFromMdzip) {
				// Step 0: check EMF2XMI_DIR environment variable
				String emf2xmiDir = System.getenv(EMF2XMI);
				if (emf2xmiDir == null) {
					System.out.println(EMF2XMI
							+ " environment variable must be set with the full path to Magicdraw emf2xmi tool.");
					return Application.EXIT_OK;
				}
				
				final List<File> allMdzipFiles = dirOK(mdzipDir) ? gatherFiles(mdzipDir, "mdzip") : Arrays.stream(mdzipFiles).map(f -> new File(f)).collect(Collectors.toList());
				
				// Step 1: ".mdzip" file to ".uml" file
				System.out.println(">>>>> MDZIP --> EMF UML");
				System.out.println("      emf2xmi dir     : " + emf2xmiDir);
				for (File f : allMdzipFiles) {
					final String fileName = f.getName();
					final String absolutePath = f.getAbsolutePath();
					final String fileDestination = umlDir + '/' + fileName.replace(".mdzip", "");
					System.out.println("      Destination dir : " + fileDestination);
					new File(fileDestination).mkdirs();
					System.out.println("      Mdzip file      : " + fileName);
					final ProcessBuilder pb = new ProcessBuilder(emf2xmiDir, "project_file=" + absolutePath,
							"destination_dir=" + fileDestination);
					pb.redirectOutput(Redirect.INHERIT);
					pb.redirectError(Redirect.INHERIT);
					final Process p = pb.start();
					p.waitFor();
					final int exitValue = p.exitValue();
					System.out.println("        Exit value : " + exitValue);

					if (exitValue != 0) {
						System.out.println("**    UML generation failed for " + fileName + ". Exiting...");
						return Application.EXIT_OK;
					}

					System.out.println("      UML generation ok for " + fileName);
					allUmlFiles.add(URI.createFileURI(new File(fileDestination + '/' + fileName.replace(".mdzip", ".uml")).getAbsolutePath()));
				};
				System.out.println(">>>>> MDZIP --> EMF UML finished");
			}
			
			final List<Resource> resourcesToGenerate = new ArrayList<>();
			
			if (generateCppFromMdzip || generateCppFromUml || generateModaneFromMdzip || generateModaneFromUml) {
				// Transformation to transient modane resources
				final Set<URI> resourceURIs = new HashSet<>();
				// Gather URIs from uml files provided directly
				if (umlFiles != null) {
					for (int i = 0; i < umlFiles.length; ++i) {
						final String umlFile = umlFiles[i];
						allUmlFiles.add(URI.createFileURI(new File(umlFile).getAbsolutePath()));
					}
				}
				
				for (URI umlFileUri : allUmlFiles) {
					final String umlFile = umlFileUri.lastSegment();

					System.out.println(">>>>> Loading EMF UML resource: " + umlFile);
					final UmlToModane umlToModane = UmlToModane.createInstance();
					umlToModane.setResourceURICache(resourceURIs);

					final Procedure2<ModaneGeneratorMessageDispatcher.MessageType, String> printConsole = //
							(ModaneGeneratorMessageDispatcher.MessageType type, String msg) -> System.out.println(msg);
					umlToModane.getMessageDispatcher().getTraceListeners().add(printConsole);

					final Model model = umlToModane.readModel(umlFileUri);
					final String outputDir = (generateCppFromMdzip || generateCppFromUml) ? cppDir : modaneDir;
					final boolean generateModaneFiles = generateModaneFromMdzip || generateModaneFromUml || writeModaneFiles;
					resourcesToGenerate.addAll(umlToModane.generate(model, outputDir, "", generateModaneFiles, obfuscate));
					resourcesToGenerate.forEach(r -> resourceURIs.add(r.getURI()));
					System.out.println(">>>>> EMF UML resource loaded: " + umlFile);
				}
			} else if (generateCppFromModane) {
				// Transformation to transient modane resources
				final List<URI> modaneFileURIs = new ArrayList<>();
				final boolean generateAllModaneFiles = modaneFiles == null || modaneFiles.length == 0;
				if (!generateAllModaneFiles) {
					modaneFileURIs.addAll(Arrays.stream(modaneFiles)
							.map(s -> URI.createFileURI(new File(s).getAbsolutePath())).collect(Collectors.toList()));
				}

				System.out.println(">>>>> Loading Modane models");
				final ModaneModelReader modaneModelReader = ModaneModelReader.createInstance();

				final List<File> allModaneFiles = gatherFiles(modaneDir, "m");
				allModaneFiles.forEach(f -> {
					final URI fileURI = URI.createFileURI(f.getAbsolutePath());
					if (generateAllModaneFiles || modaneFileURIs.stream()
							.anyMatch(uri -> uri.toFileString().equals(fileURI.toFileString()))) {
						resourcesToGenerate.add(modaneModelReader.readModel(fileURI).eResource());
						
					} else {
						modaneModelReader.readModel(fileURI);
					}
				});
				modaneModelReader.resolveAll();
				System.out.println(">>>>> Modane models loaded");
				System.out.println("    List of models:");
				final URI base = URI.createFileURI(new File(modaneDir).getAbsolutePath());
				resourcesToGenerate.forEach(r -> {
					final URI relative = r.getURI().deresolve(base);
					System.out.println("        - " + relative.path());
				});
			}

			if ((generateCppFromMdzip || generateCppFromUml || generateCppFromModane) && !resourcesToGenerate.isEmpty()) {
				System.out.println(">>>>> Starting generation process");
				final ModaneToCpp modaneToCpp = ModaneToCpp.createInstance();
				final Procedure2<ModaneGeneratorMessageDispatcher.MessageType, String> printConsole = //
						(ModaneGeneratorMessageDispatcher.MessageType type, String msg) -> System.out.println(msg);
				modaneToCpp.getMessageDispatcher().getTraceListeners().add(printConsole);

				modaneToCpp.generate(resourcesToGenerate, cppDir, "", "", profAccInstrumentation,
						sciHookInstrumentation, writeCMakeListsFiles, writeCMakeFiles);
				System.out.println(">>>>> Generation process ended successfully");
			}
		}

		return Application.EXIT_OK;
	}

	private List<File> gatherFiles(String directoryName, String fileExtension) {
		final File directory = new File(directoryName);
		final File[] fList = directory.listFiles();
		final List<File> result = new ArrayList<>();
		if (fList != null) {
			for (File file : fList) {
				if (file.isFile() && getExtension(file).orElse("").equals(fileExtension)) {
					result.add(file);
				} else if (file.isDirectory()) {
					result.addAll(gatherFiles(file.getAbsolutePath(), fileExtension));
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
				" Generate uml files: generate-uml --uml-dir <UML_OUTPUT_DIR> [--mdzip-dir <MDZIP_INPUT_DIR> | --mdzip <MDZIP_INPUT_FILES>]");
		System.out.println(
				" Generate modane files: generate-modane --modane-dir <MODANE_OUTPUT_DIR> [[--mdzip-dir <MDZIP_INPUT_DIR> | --mdzip <MDZIP_INPUT_FILES>] --uml-dir <UML_INPUT_DIR> | [--uml-dir <UML_INPUT_DIR> | --uml <UML_INPUT_FILES>]] [--obfuscate]");
		System.out.println(
				" Generate cpp files: generate-cpp --cpp-dir <CPP_OUTPUT_DIR> [[--mdzip-dir <MDZIP_INPUT_DIR> | --mdzip <MDZIP_INPUT_FILES>] --uml-dir <UML_INPUT_DIR> | [--uml-dir <UML_INPUT_DIR> | --uml <UML_INPUT_FILES>] | [--modane-dir <MODANE_INPUT_DIR> | --modane <MODANE_INPUT_FILES>]] [--write-modane-files [--obfuscate]]");
		System.out.println("  Note: --mdzip, --uml and --modane options accept a list of comma separated files (no space)");
		
	}

	private boolean parseArgs(String[] appArgs) {
		boolean valid = false;

		boolean generateModane = false;
		boolean generateCpp = false;
		
		// The 3 'generate-*' commands are mutually exclusive, and must come first
		switch (appArgs[0]) {
		case "generate-uml": {
			generateUml = true;
			break;
		}
		case "generate-modane": {
			generateModane = true;
			break;
		}
		case "generate-cpp": {
			generateCpp = true;
			break;
		}
		default: {
			printUsage();
			return false;
		}
		}
		
		for (int i = 1; i < appArgs.length; ++i) {
			switch (appArgs[i]) {
			case "--mdzip-dir": {
				mdzipDir = appArgs[++i];
				break;
			}
			case "--mdzip": {
				String arg = appArgs[++i];
				mdzipFiles = arg.split(",");
				break;
			}
			case "--uml-dir": {
				umlDir = appArgs[++i];
				break;
			}
			case "--uml": {
				String arg = appArgs[++i];
				umlFiles = arg.split(",");
				break;
			}
			case "--modane-dir": {
				modaneDir = appArgs[++i];
				break;
			}
			case "--modane": {
				String arg = appArgs[++i];
				modaneFiles = arg.split(",");
				break;
			}
			case "--write-modane-files": {
				writeModaneFiles = true;
				break;
			}
			case "--obfuscate": {
				obfuscate = true;
				break;
			}
			case "--cpp-dir": {
				cppDir = appArgs[++i];
				break;
			}
			case "--scihook": {
				sciHookInstrumentation = true;
				break;
			}
			case "--profacc": {
				profAccInstrumentation = true;
				break;
			}
			case "--cmakes": {
				writeCMakeFiles = true;
				break;
			}
			case "--cmakelists": {
				writeCMakeListsFiles = true;
				break;
			}
			default: {
				System.out.println("Unknow option: " + appArgs[i]);
				printUsage();
				return false;
			}
			}
		}
		
		if (generateUml) {
			valid =
					// Output dir
					dirOK(umlDir) &&
					// Source files
					(
						// From mdzip
						(dirOK(mdzipDir) || filesOK(mdzipFiles, "mdzip"))
					) &&
					// Options for other commands
					!(umlFiles != null || modaneDir != null || modaneFiles != null || writeModaneFiles ||
					  obfuscate || cppDir != null || sciHookInstrumentation || profAccInstrumentation ||
					  writeCMakeFiles || writeCMakeListsFiles);
		} else if (generateModane) {
			final boolean fromMdzip = (dirOK(mdzipDir) || filesOK(mdzipFiles, "mdzip")) && dirOK(umlDir);
			final boolean fromUml = (dirOK(umlDir) || filesOK(umlFiles, "uml"));
			if (fromMdzip && !fromUml) {
				generateModaneFromMdzip = true;
			} else if (!fromMdzip && fromUml) {
				generateModaneFromUml = true;
			}
			valid =
					// Output dir
					dirOK(modaneDir) &&
					// Source files
					(generateModaneFromMdzip || generateModaneFromUml) &&
					// Options for other commands
					!(modaneFiles != null || writeModaneFiles || cppDir != null || sciHookInstrumentation ||
					  profAccInstrumentation || writeCMakeFiles || writeCMakeListsFiles);
		} else if (generateCpp) {
			final boolean fromMdzip = (dirOK(mdzipDir) || filesOK(mdzipFiles, "mdzip")) && dirOK(umlDir);
			final boolean fromUml = (dirOK(umlDir) || filesOK(umlFiles, "uml"));
			final boolean fromModane = (dirOK(modaneDir) || filesOK(modaneFiles, "m"));
			if (fromMdzip && !fromUml && !fromModane) {
				generateCppFromMdzip = true;
			} else if (!fromMdzip && fromUml && !fromModane) {
				generateCppFromUml = true;
			} else if (!fromMdzip && !fromUml && fromModane) {
				generateCppFromModane = true;
			}
			valid =
					// Output dir
					dirOK(cppDir) &&
					// Source files
					(generateCppFromMdzip || generateCppFromUml || generateCppFromModane) &&
					// Can't obfuscate without writing modane files
					(writeModaneFiles || !obfuscate);
		}
		
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
