# client/CMakeLists.txt
cmake_minimum_required(VERSION 3.16)
project(HayChonGiaDungClient LANGUAGES C CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Use Qt5 instead of Qt6 (available on Ubuntu)
find_package(Qt5 REQUIRED COMPONENTS Core Quick)

add_executable(${PROJECT_NAME}
    src/main.cpp
    src/BackEnd.cpp
    src/Utils.c
    headers/BackEnd.h
    headers/Utils.h
    resources/qml.qrc
)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/headers
)

target_link_libraries(${PROJECT_NAME}
    Qt5::Core
    Qt5::Quick
    pthread
)
