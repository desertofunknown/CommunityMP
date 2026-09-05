set(COMMUNITYMP_SOURCES
    main.cpp
    OpenMwServerSimulationHost.cpp
    OpenMwServerSimulationHost.hpp
)

openmw_add_executable(communitymp ${COMMUNITYMP_SOURCES})

target_link_libraries(communitymp PRIVATE openmw-client-core tes3mp-server-core)

set_target_properties(communitymp PROPERTIES
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
)

if (WIN32)
    target_sources(communitymp PRIVATE ${CMAKE_SOURCE_DIR}/files/windows/other-apps.manifest)
endif()

set(COMMUNITYMP_LAUNCH_SHORTCUTS
    "${CMAKE_SOURCE_DIR}/files/communitymp/CommunityMP Client.cmd"
    "${CMAKE_SOURCE_DIR}/files/communitymp/CommunityMP Dedicated Server.cmd"
    "${CMAKE_SOURCE_DIR}/files/communitymp/communitymp-client.sh"
    "${CMAKE_SOURCE_DIR}/files/communitymp/communitymp-dedicated-server.sh"
    "${CMAKE_SOURCE_DIR}/files/communitymp/CommunityMP Client.command"
    "${CMAKE_SOURCE_DIR}/files/communitymp/CommunityMP Dedicated Server.command"
)

foreach(shortcut ${COMMUNITYMP_LAUNCH_SHORTCUTS})
    get_filename_component(shortcutName "${shortcut}" NAME)
    add_custom_command(TARGET communitymp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${shortcut}"
            "$<TARGET_FILE_DIR:communitymp>/${shortcutName}"
    )
endforeach()

if (WIN32)
    install(TARGETS communitymp RUNTIME DESTINATION ".")
    install(FILES ${COMMUNITYMP_LAUNCH_SHORTCUTS} DESTINATION ".")
elseif (APPLE)
    # BINDIR and DATAROOTDIR are only defined in the elseif(UNIX) branch of the
    # top-level CMakeLists, so on macOS these install() calls would be given an
    # empty DESTINATION and fail to configure. Nothing is needed here anyway:
    # CMAKE_RUNTIME_OUTPUT_DIRECTORY already points inside the app bundle, so
    # the executable and its launch scripts are picked up by the bundle.
else()
    install(TARGETS communitymp RUNTIME DESTINATION "${BINDIR}")
    install(PROGRAMS
        "${CMAKE_SOURCE_DIR}/files/communitymp/communitymp-client.sh"
        "${CMAKE_SOURCE_DIR}/files/communitymp/communitymp-dedicated-server.sh"
        "${CMAKE_SOURCE_DIR}/files/communitymp/CommunityMP Client.command"
        "${CMAKE_SOURCE_DIR}/files/communitymp/CommunityMP Dedicated Server.command"
        DESTINATION "${BINDIR}"
    )
    install(FILES
        "${CMAKE_SOURCE_DIR}/files/communitymp/communitymp-client.desktop"
        "${CMAKE_SOURCE_DIR}/files/communitymp/communitymp-dedicated-server.desktop"
        DESTINATION "${DATAROOTDIR}/applications"
    )
endif()
