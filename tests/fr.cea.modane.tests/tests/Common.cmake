# Il faut avoir recopié le fichier 'samples/ArcaneCompilerConfig.cmake'
# depuis le répertoire d'installation de Arcane pour que cela fonctionne
# TODO tester existance du fichier 'ArcaneCompilerConfig.cmake'
if(EXISTS ${CMAKE_CURRENT_LIST_DIR}/ArcaneCompilerConfig.cmake)
  include(${CMAKE_CURRENT_LIST_DIR}/ArcaneCompilerConfig.cmake)
else()
  message(FATAL_ERROR "File 'ArcaneCompilerConfig.cmake' is missing."
    " You need to copy from Arcane installation root the file"
    " samples/ArcaneCompilerConfig.cmake in this directory: '${CMAKE_CURRENT_LIST_DIR}'")
endif()

# NB : Replace makefile clean target by clean.sh

# TODO: ajouter cible pour doxygen
#       doxygen Doxyfile
