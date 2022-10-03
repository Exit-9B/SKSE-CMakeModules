#[=======================================================================[.rst:
SKSEPlugin
----------

Setup an SKSE Plugin.

.. command:: SKSEPlugin_Add

  .. code-block:: cmake

    SKSEPlugin_Add(<target>
                   [SOURCE_DIR <source dir>]
                   [INCLUDE_DIR <include dir>]
                   [SOURCES <sources>]
                   [PRECOMPILE_HEADERS <precompile headers>])

  This command will populate the variables ``SkyrimSE_PATH`` and ``SkyrimVR_PATH``
  with the installed paths of Skyrim Special Edition and Skyrim VR on the host
  system, respectively.

The following variables can be set before calling the function.

``SKSE_COMMONLIBSSE_PATH``
  The path to the CommonLibSSE repository relative to the current source
  directory. Default is ``external/CommonLibSSE``.

``SKSE_USE_XBYAK``
  A boolean variable indicating whether the plugin uses the xbyak library.

``SKSE_SUPPORT_VR``
  A boolean variable indicating whether the project supports Skyrim VR.

``SKSE_NO_INSTALL``
  A boolean variable that can be set to prevent the function from generating an
  install target or setting the default install prefix.

#]=======================================================================]
cmake_minimum_required(VERSION 3.24)

function(SKSEPlugin_Add TARGET)
	set(options "")
	set(oneValueArgs SOURCE_DIR INCLUDE_DIR)
	set(multiValueArgs SOURCES PRECOMPILE_HEADERS)
	cmake_parse_arguments(SKSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	include(CMakeDependentOption)

	cmake_host_system_information(
		RESULT SkyrimSE_PATH
		QUERY WINDOWS_REGISTRY "HKLM/SOFTWARE/Bethesda Softworks/Skyrim Special Edition"
		VALUE "installed path"
		VIEW 32
	)

	set(SkyrimSE_PATH ${SkyrimSE_PATH} CACHE PATH "Installed path of Skyrim Special Edition.")

	cmake_host_system_information(
		RESULT SkyrimVR_PATH
		QUERY WINDOWS_REGISTRY "HKLM/SOFTWARE/Bethesda Softworks/Skyrim VR"
		VALUE "installed path"
		VIEW 32
	)

	set(SkyrimVR_PATH ${SkyrimVR_PATH} CACHE PATH "Installed path of Skyrim VR.")

	cmake_dependent_option(BUILD_SKYRIMVR "Build for Skyrim VR." OFF SKSE_SUPPORT_VR OFF)

	if(BUILD_SKYRIMVR)
		add_compile_definitions(SKYRIMVR)
		set(GAME_DIR ${SkyrimVR_PATH})
	else()
		set(GAME_DIR ${SkyrimSE_PATH})
	endif()

	add_library("${TARGET}" SHARED)

	if(SKSE_INCLUDE_DIR)
		cmake_path(IS_RELATIVE SKSE_INCLUDE_DIR SKSE_INCLUDE_DIR_IS_RELATIVE)
		if(SKSE_INCLUDE_DIR_IS_RELATIVE)
			cmake_path(ABSOLUTE_PATH SKSE_INCLUDE_DIR BASE_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
		endif()

		file(GLOB_RECURSE INCLUDE_FILES
			LIST_DIRECTORIES false
			CONFIGURE_DEPENDS
			"${SKSE_INCLUDE_DIR}/*.h"
			"${SKSE_INCLUDE_DIR}/*.hpp"
			"${SKSE_INCLUDE_DIR}/*.hxx"
			"${SKSE_INCLUDE_DIR}/*.inl"
		)

		source_group(
			TREE ${SKSE_INCLUDE_DIR}
			PREFIX "Header Files"
			FILES ${INCLUDE_FILES}
		)

		target_sources("${TARGET}" PUBLIC ${INCLUDE_FILES})
	endif()

	if(SKSE_SOURCE_DIR)
		cmake_path(IS_RELATIVE SKSE_SOURCE_DIR SKSE_SOURCE_DIR_IS_RELATIVE)
		if(SKSE_SOURCE_DIR_IS_RELATIVE)
			cmake_path(ABSOLUTE_PATH SKSE_SOURCE_DIR BASE_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
		endif()

		file(GLOB_RECURSE HEADER_FILES
			LIST_DIRECTORIES false
			CONFIGURE_DEPENDS
			"${SKSE_SOURCE_DIR}/*.h"
			"${SKSE_SOURCE_DIR}/*.hpp"
			"${SKSE_SOURCE_DIR}/*.hxx"
			"${SKSE_SOURCE_DIR}/*.inl"
		)

		source_group(
			TREE ${SKSE_SOURCE_DIR}
			PREFIX "Header Files"
			FILES ${HEADER_FILES}
		)

		target_sources("${TARGET}" PRIVATE ${HEADER_FILES})

		file(GLOB_RECURSE SOURCE_FILES
			LIST_DIRECTORIES false
			CONFIGURE_DEPENDS
			"${SKSE_SOURCE_DIR}/*.cpp"
			"${SKSE_SOURCE_DIR}/*.cxx"
		)

		source_group(
			TREE ${SKSE_SOURCE_DIR}
			PREFIX "Source Files"
			FILES ${SOURCE_FILES}
		)

		target_sources("${TARGET}" PRIVATE ${SOURCE_FILES})
	endif()

	if(SKSE_SOURCES)
		target_sources("${TARGET}" PRIVATE ${SKSE_SOURCES})
	endif()

	if(SKSE_PRECOMPILE_HEADERS)
		target_precompile_headers("${TARGET}" PRIVATE ${SKSE_PRECOMPILE_HEADERS})
	endif()

	configure_file(
		${CMAKE_CURRENT_FUNCTION_LIST_DIR}/Plugin.h.in
		${CMAKE_CURRENT_BINARY_DIR}/src/Plugin.h
		@ONLY
	)

	configure_file(
		${CMAKE_CURRENT_FUNCTION_LIST_DIR}/version.rc.in
		${CMAKE_CURRENT_BINARY_DIR}/version.rc
		@ONLY
	)

	target_sources(
		"${TARGET}"
		PRIVATE
			${CMAKE_CURRENT_BINARY_DIR}/version.rc
	)

	target_include_directories(
		"${TARGET}"
		PRIVATE
			${CMAKE_CURRENT_BINARY_DIR}/src
			${SKSE_INCLUDE_DIR}
			${SKSE_SOURCE_DIR}
	)

	if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
		target_compile_options(
			"${TARGET}"
			PRIVATE
				"/sdl"             # Enable Additional Security Checks
				"/utf-8"           # Set Source and Executable character sets to UTF-8
				"/Zi"              # Debug Information Format

				"/permissive-"     # Standards conformance
				"/Zc:preprocessor" # Enable preprocessor conformance mode

				"/wd4200"          # nonstandard extension used : zero-sized array in struct/union

				"$<$<CONFIG:DEBUG>:>"
				"$<$<CONFIG:RELEASE>:/Zc:inline;/JMC-;/Ob3>"
		)

		target_link_options(
			"${TARGET}"
			PRIVATE
				"$<$<CONFIG:DEBUG>:/INCREMENTAL;/OPT:NOREF;/OPT:NOICF>"
				"$<$<CONFIG:RELEASE>:/INCREMENTAL:NO;/OPT:REF;/OPT:ICF;/DEBUG:FULL>"
		)
	endif()

	if(SKSE_USE_XBYAK)
		find_package(xbyak CONFIG REQUIRED)
		target_link_libraries("${TARGET}" PRIVATE xbyak::xbyak)
		set(SKSE_SUPPORT_XBYAK ON CACHE INTERNAL "Enables trampoline support for Xbyak." FORCE)
	else()
		set(SKSE_SUPPORT_XBYAK OFF CACHE INTERNAL "Enables trampoline support for Xbyak." FORCE)
	endif()

	if(NOT SKSE_COMMONLIBSSE_PATH)
		set(SKSE_COMMONLIBSSE_PATH "external/CommonLibSSE")
	endif()

	add_subdirectory(${SKSE_COMMONLIBSSE_PATH} CommonLibSSE EXCLUDE_FROM_ALL)

	find_package(spdlog CONFIG REQUIRED)

	target_link_libraries(
		"${TARGET}"
		PRIVATE
			CommonLibSSE::CommonLibSSE
			spdlog::spdlog
	)

	if(NOT SKSE_NO_INSTALL)
		if(CMAKE_GENERATOR MATCHES "Visual Studio")
			option(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD "Include INSTALL target to default build." OFF)
		endif()

		if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
			set(CMAKE_INSTALL_PREFIX "${GAME_DIR}/Data" CACHE PATH
				"Install path prefix (e.g. Skyrim Data directory or Mod Organizer virtual directory)."
				FORCE
			)
		endif()

		install(
			FILES
				"$<TARGET_FILE:${PROJECT_NAME}>"
				"$<TARGET_PDB_FILE:${PROJECT_NAME}>"
			DESTINATION "SKSE/Plugins"
			COMPONENT SKSEPlugin
		)
	endif()

endfunction()
