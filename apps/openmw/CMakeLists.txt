set(OPENMW_SOURCES
    engine.cpp
    options.cpp
    serversimulationevents.cpp
)

set(OPENMW_RESOURCES
    ${CMAKE_SOURCE_DIR}/files/windows/openmw.rc
    ${CMAKE_SOURCE_DIR}/files/windows/openmw.exe.manifest
)

if(BUILD_TES3MP_CLIENT AND WIN32)
    set(OPENMW_RESOURCES
        ${CMAKE_SOURCE_DIR}/files/tes3mp/tes3mp.rc
        ${CMAKE_SOURCE_DIR}/files/tes3mp/tes3mp.exe.manifest
    )
endif()

set(OPENMW_HEADERS
    doc.hpp
    engine.hpp
    OpenMWApplication.hpp
    options.hpp
    profile.hpp
    serversimulationevents.hpp
)

source_group(apps/openmw FILES main.cpp OpenMWStandaloneMain.cpp androidmain.cpp ${OPENMW_SOURCES} ${OPENMW_HEADERS} ${OPENMW_RESOURCES})

add_openmw_dir (mwrender
    actors objects renderingmanager animation rotatecontroller sky skyutil npcanimation esm4npcanimation vismask
    creatureanimation effectmanager util renderinginterface pathgrid rendermode weaponanimation screenshotmanager
    bulletdebugdraw globalmap characterpreview camera localmap water terrainstorage ripplesimulation
    renderbin actoranimation landmanager navmesh actorspaths recastmesh fogmanager objectpaging groundcover
    postprocessor pingpongcull luminancecalculator pingpongcanvas transparentpass precipitationocclusion ripples
    actorutil distortion animationpriority bonegroup blendmask animblendcontroller
    )

add_openmw_dir (mwinput
    actions actionmanager bindingsmanager controllermanager controlswitch
    inputmanagerimp mousemanager keyboardmanager sensormanager gyromanager
    )

add_openmw_dir (mwgui
    layout textinput widgets race class birth review windowmanagerimp console dialogue
    windowbase statswindow messagebox journalwindow charactercreation
    mapwindow windowpinnablebase tooltips scrollwindow bookwindow resourceskin
    formatting inventorywindow container hud countdialog tradewindow settingswindow
    confirmationdialog alchemywindow referenceinterface spellwindow mainmenu quickkeysmenu
    itemselection spellbuyingwindow loadingscreen levelupdialog waitdialog spellcreationdialog
    enchantingdialog trainingwindow travelwindow exposedwindow cursor spellicons
    merchantrepair repair soulgemdialog companionwindow bookpage journalviewmodel journalbooks
    itemmodel containeritemmodel inventoryitemmodel sortfilteritemmodel itemview
    tradeitemmodel companionitemmodel pickpocketitemmodel controllers savegamedialog
    recharge mode videowidget backgroundimage itemwidget screenfader debugwindow spellmodel spellview
    draganddrop timeadvancer jailscreen itemchargeview keyboardnavigation textcolours statswatcher
    postprocessorhud settings worlditemmodel itemtransfer controllerbuttonsoverlay inventorytabsoverlay
    )

add_openmw_dir (mwdialogue
    dialoguemanagerimp journalimp journalentry quest topic filter selectwrapper keywordsearch scripttest
    )

add_openmw_dir (mwscript
    locals scriptmanagerimp compilercontext interpretercontext cellextensions miscextensions
    guiextensions soundextensions skyextensions statsextensions containerextensions
    aiextensions controlextensions extensions globalscripts ref dialogueextensions
    animationextensions transformationextensions consoleextensions userextensions
    )

add_openmw_dir (mwlua
    luamanagerimp object objectlists userdataserializer luaevents engineevents objectvariant loadscripts contentbindings
    context menuscripts globalscripts localscripts playerscripts luabindings objectbindings cellbindings communitympbindings coremwscriptbindings
    mwscriptbindings camerabindings vfsbindings uibindings soundbindings inputbindings nearbybindings dialoguebindings
    dialogueinfo
    postprocessingbindings stats recordstore debugbindings corebindings worldbindings worker landbindings magicbindings factionbindings
    classbindings itemdata inputprocessor animationbindings birthsignbindings racebindings markupbindings weatherbindings regionbindings
    types/types types/door types/item types/actor types/container types/lockable types/weapon types/npc types/bodypart
    types/creature types/player types/activator types/book types/lockpick types/probe types/apparatus
    types/potion types/ingredient types/misc types/repair types/armor types/light types/static
    types/clothing types/levelledlist types/terminal magictypebindings
    )

add_openmw_dir (mwsound
    soundmanagerimp openaloutput ffmpegdecoder sound soundbuffer sounddecoder soundoutput
    loudness movieaudiofactory alext efx efxpresets regionsoundselector watersoundupdater
    )

add_openmw_dir (mwworld
    refdata worldimp scene globals class action nullaction actionteleport
    containerstore actiontalk actiontake manualref player cellvisitors failedaction
    worldmodel localscripts customdata inventorystore ptr actionopen actionread actionharvest
    actionequip timestamp actionalchemy cellstore actionapply actioneat
    store esmstore fallback actionrepair actionsoulgem livecellref actiondoor
    contentloader esmloader actiontrap cellreflist cellref weather projectilemanager
    cellpreloader datetimemanager groundcoverstore magiceffects cell ptrregistry
    positioncellgrid
    )

set(MWPHYSICS_JOLT_SOURCES)
if(OPENMW_PHYSICS_BACKEND STREQUAL "jolt")
    set(MWPHYSICS_JOLT_SOURCES
        joltactor joltphysicssystem joltshapeconverter joltragdoll
    )
endif()

add_openmw_dir (mwphysics
    physicssystem trace collisiontype actor convert object heightfield closestnotmerayresultcallback
    contacttestresultcallback stepper movementsolver projectile
    actorconvexcallback raycasting mtphysics contacttestwrapper projectileconvexcallback
    iphysicsactor iphysicsbackend iphysicsobject physicsbackend
    ${MWPHYSICS_JOLT_SOURCES}
    )

add_openmw_dir (mwclass
    classes activator creature npc weapon armor potion apparatus book clothing container door
    ingredient creaturelevlist itemlevlist light lockpick misc probe repair static actor bodypart
    esm4base esm4npc light4
    )

add_openmw_dir (mwmechanics
    mechanicsmanagerimp stat creaturestats magiceffects movement actorutil spelllist
    drawstate spells activespells npcstats aipackage aisequence aipursue alchemy aiwander aitravel aifollow aiavoiddoor aibreathe
    aicast aiescort aiface aiactivate aicombat recharge repair enchanting pathfinding pathgrid security spellcasting spellresistance
    disease pickpocket levelledlist combat steering obstacle autocalcspell difficultyscaling aicombataction summoning
    character actors objects aistate weaponpriority spellpriority weapontype spellutil
    spelleffects resurrect
    )

add_openmw_dir (mwstate
    statemanagerimp charactermanager character quicksavemanager
    )

add_openmw_dir (mwbase
    environment world scriptmanager dialoguemanager journal soundmanager mechanicsmanager
    inputmanager windowmanager statemanager luamanager
    )

if(BUILD_TES3MP_CLIENT)
    add_openmw_dir (mwmp Main Networking LocalSystem LocalPlayer DedicatedPlayer PlayerList LocalActor DedicatedActor ActorList
        ObjectList Worldstate Cell CellController CellIdentity GUIController MechanicsHelper RecordHelper ScriptController
        CommunityMpLuaEventQueue
        )

    add_openmw_dir (mwmp/GUI GUIChat GUICharacterSelect PlayerMarkerCollection GUIDialogList TextInputDialog
        )

    add_openmw_dir(mwmp/processors BaseClientPacketProcessor SystemProcessor PlayerProcessor ObjectProcessor ActorProcessor
        WorldstateProcessor ProcessorInitializer
        )

    add_openmw_dir (mwmp/processors/system ProcessorSystemHandshake
        )

    add_openmw_dir (mwmp/processors/actor ProcessorActorAI ProcessorActorAnimFlags ProcessorActorAnimPlay ProcessorActorAttack
        ProcessorActorAuthority ProcessorActorCast ProcessorActorCellChange ProcessorActorDeath ProcessorActorEquipment
        ProcessorActorList ProcessorActorPosition ProcessorActorSpeech ProcessorActorSpellsActive ProcessorActorStatsDynamic
        ProcessorActorTest
        )

    add_openmw_dir (mwmp/processors/player ProcessorChatMessage ProcessorGUIMessageBox ProcessorUserDisconnected
        ProcessorGameSettings ProcessorPlayerAlly ProcessorPlayerAnimFlags ProcessorPlayerAnimPlay
        ProcessorPlayerAttack ProcessorPlayerAttribute ProcessorPlayerBaseInfo ProcessorPlayerBehavior ProcessorPlayerBook
        ProcessorPlayerBounty ProcessorPlayerCast ProcessorPlayerCellChange ProcessorPlayerCellState ProcessorPlayerCharClass
        ProcessorPlayerCharGen ProcessorPlayerCooldowns ProcessorPlayerDeath ProcessorPlayerDisposition ProcessorPlayerEquipment
        ProcessorPlayerFaction ProcessorPlayerInput ProcessorPlayerInventory ProcessorPlayerItemUse ProcessorPlayerJail
        ProcessorPlayerJournal ProcessorPlayerLevel ProcessorPlayerMiscellaneous ProcessorPlayerMomentum ProcessorPlayerPosition
        ProcessorPlayerQuickKeys ProcessorPlayerReputation ProcessorPlayerRest ProcessorPlayerResurrect ProcessorPlayerShapeshift
        ProcessorPlayerSkill ProcessorPlayerSpeech ProcessorPlayerSpellbook ProcessorPlayerSpellsActive
        ProcessorPlayerStatsDynamic ProcessorPlayerTopic ProcessorPlayerLuaEvent
        )

    add_openmw_dir (mwmp/processors/object BaseObjectProcessor
        ProcessorConsoleCommand ProcessorContainer ProcessorDoorDestination ProcessorDoorState ProcessorMusicPlay
        ProcessorVideoPlay ProcessorObjectActivate ProcessorObjectAnimPlay ProcessorObjectAttach ProcessorObjectDelete
        ProcessorObjectDialogueChoice ProcessorObjectHit ProcessorObjectLock ProcessorObjectMove ProcessorObjectPlace
        ProcessorObjectRestock ProcessorObjectRotate ProcessorObjectScale ProcessorObjectSound ProcessorObjectSpawn
        ProcessorObjectState ProcessorObjectTrap ProcessorClientScriptLocal ProcessorScriptMemberShort
        ProcessorObjectMiscellaneous
        )

    add_openmw_dir (mwmp/processors/worldstate ProcessorCellReset ProcessorClientScriptGlobal ProcessorClientScriptSettings
        ProcessorRecordDynamic ProcessorWorldCollisionOverride ProcessorWorldDestinationOverride ProcessorWorldKillCount
        ProcessorWorldMap ProcessorWorldRegionAuthority ProcessorWorldTime ProcessorWorldWeather
        )
endif()

# Main executable

add_library(openmw-lib STATIC
    ${OPENMW_FILES}
    ${OPENMW_SOURCES}
)

add_library(openmw-client-core STATIC
    main.cpp
    OpenMWApplication.hpp
)

target_link_libraries(openmw-client-core PUBLIC openmw-lib)

set_target_properties(openmw-client-core PROPERTIES
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
)

if (MSVC)
    # these TUs take a lot of memory for codegen
    # in CI, they often go over the 8GB memory limit if another cl.exe is running at the same time
    # this option (make sure you're not looking at the docs for the identically-named linker option) stops four codegen threads being spun off
    # it hurts build time ~33% to enable this unnecessarily, though, so target it to the hungriest boys
    set_source_files_properties(
        mwlua/dialoguebindings.cpp
        mwlua/magicbindings.cpp
        mwlua/objectbindings
        mwlua/stats.cpp
        mwworld/esmstore.cpp
        PROPERTIES
        COMPILE_OPTIONS /cgthreads1
    )
endif()

if(BUILD_OPENMW)
    if (ANDROID)
        add_library(openmw SHARED
            OpenMWStandaloneMain.cpp
            androidmain.cpp
        )
    else()
        openmw_add_executable(openmw
            ${APPLE_BUNDLE_RESOURCES}
            ${OPENMW_RESOURCES}
            OpenMWStandaloneMain.cpp
        )
    endif()

    target_link_libraries(openmw openmw-client-core)

    if(BUILD_TES3MP_CLIENT)
        set_target_properties(openmw PROPERTIES OUTPUT_NAME ${OPENMW_GAME_EXECUTABLE_NAME})
        if(WIN32)
            set(OPENMW_MP_LEGACY_CLIENT_EXECUTABLE "tes3mp.exe")
        else()
            set(OPENMW_MP_LEGACY_CLIENT_EXECUTABLE "tes3mp")
        endif()
        add_custom_command(TARGET openmw POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E rm -f
                "$<TARGET_FILE_DIR:openmw>/${OPENMW_MP_LEGACY_CLIENT_EXECUTABLE}")
    endif()

    # Workaround necessary to ensure osgAnimation::MatrixLinearSampler dynamic casts work under Clang
    # NOTE: it's unclear whether the broken behavior is spec-compliant
    if (CMAKE_CXX_COMPILER_ID STREQUAL Clang)
        set_target_properties(openmw PROPERTIES ENABLE_EXPORTS ON)
    endif()
endif()

# Sound stuff - here so CMake doesn't stupidly recompile EVERYTHING
# when we change the backend.
include_directories(
    ${FFmpeg_INCLUDE_DIRS}
)

target_link_libraries(openmw-lib
    # CMake's built-in OSG finder does not use pkgconfig, so we have to
    # manually ensure the order is correct for inter-library dependencies.
    # This only makes a difference with `-DOPENMW_USE_SYSTEM_OSG=ON -DOSG_STATIC=ON`.
    # https://gitlab.kitware.com/cmake/cmake/-/issues/21701
    ${OSGPARTICLE_LIBRARIES}
    ${OSGVIEWER_LIBRARIES}
    ${OSGGA_LIBRARIES}
    ${OSGSHADOW_LIBRARIES}
    ${OSGDB_LIBRARIES}
    ${OSGUTIL_LIBRARIES}
    ${OSG_LIBRARIES}
    Boost::program_options
    ${OPENAL_LIBRARY}
    ${FFmpeg_LIBRARIES}
    ${MyGUI_LIBRARIES}
    SDL2::SDL2
    ${RecastNavigation_LIBRARIES}
    osg-ffmpeg-videoplayer
    oics
    components
)

if(OPENMW_PHYSICS_BACKEND STREQUAL "jolt")
    target_include_directories(openmw-lib SYSTEM PRIVATE ${JOLT_INCLUDE_DIR})
    target_link_libraries(openmw-lib Jolt)
endif()

if(BUILD_TES3MP_CLIENT)
    target_link_libraries(openmw-lib Boost::filesystem GameNetworkingSockets::GameNetworkingSockets)
    target_compile_definitions(openmw-lib PUBLIC BUILD_TES3MP_CLIENT)
endif()

if (MSVC AND PRECOMPILE_HEADERS_WITH_MSVC)
    target_precompile_headers(openmw-lib PRIVATE
        <boost/program_options/options_description.hpp>

        <sol/sol.hpp>

        <osg/StateSet>
        <osg/Node>
        <osg/Drawable>
        <osg/Camera>

        <osgViewer/Viewer>

        <MyGUI_Widget.h>

        <algorithm>
        <filesystem>
        <fstream>
        <functional>
        <memory>
        <string>
        <string_view>
        <vector>
    )
endif()

if (ANDROID)
    target_link_libraries(openmw-lib EGL android log z)
endif (ANDROID)

if (USE_SYSTEM_TINYXML)
    target_link_libraries(openmw-lib ${TinyXML_LIBRARIES})
endif()

if (NOT UNIX)
    target_link_libraries(openmw-lib ${SDL2MAIN_LIBRARY})
endif()

# Fix for not visible pthreads functions for linker with glibc 2.15
if (UNIX AND NOT APPLE)
    target_link_libraries(openmw-lib ${CMAKE_THREAD_LIBS_INIT})
endif()

if(APPLE AND BUILD_OPENMW)
    set(BUNDLE_RESOURCES_DIR "${APP_BUNDLE_DIR}/Contents/Resources")

    set(OPENMW_RESOURCES_ROOT ${BUNDLE_RESOURCES_DIR})

    add_subdirectory(../../files/ ${CMAKE_CURRENT_BINARY_DIR}/files)

    configure_file("${OpenMW_BINARY_DIR}/defaults.bin" ${BUNDLE_RESOURCES_DIR} COPYONLY)
    configure_file("${OpenMW_BINARY_DIR}/openmw.cfg" ${BUNDLE_RESOURCES_DIR} COPYONLY)
    configure_file("${OpenMW_BINARY_DIR}/gamecontrollerdb.txt" ${BUNDLE_RESOURCES_DIR} COPYONLY)

    add_custom_command(TARGET openmw
        POST_BUILD
        COMMAND cp "${OpenMW_BINARY_DIR}/resources/version" "${BUNDLE_RESOURCES_DIR}/resources")

    find_library(COCOA_FRAMEWORK Cocoa)
    find_library(IOKIT_FRAMEWORK IOKit)
    target_link_libraries(openmw ${COCOA_FRAMEWORK} ${IOKIT_FRAMEWORK})

    if (FFmpeg_FOUND)
        target_link_options(openmw PRIVATE "LINKER:SHELL:-framework CoreVideo"
                                           "LINKER:SHELL:-framework CoreMedia"
                                           "LINKER:SHELL:-framework VideoToolbox"
                                           "LINKER:SHELL:-framework AudioToolbox"
                                           "LINKER:SHELL:-framework VideoDecodeAcceleration")
    endif()
endif()

if (BUILD_WITH_CODE_COVERAGE)
    target_compile_options(openmw-lib PRIVATE --coverage)
    target_link_libraries(openmw-lib gcov)
    if (NOT ANDROID AND BUILD_OPENMW)
        target_compile_options(openmw PRIVATE --coverage)
        target_link_libraries(openmw gcov)
    endif()
endif()

if (WIN32 AND BUILD_OPENMW)
    if (BUILD_TES3MP_CLIENT)
        tes3mp_copy_runtime_dlls(openmw)
    endif()

    INSTALL(TARGETS openmw RUNTIME DESTINATION ".")
endif()
