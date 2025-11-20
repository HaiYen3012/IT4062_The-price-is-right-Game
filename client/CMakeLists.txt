# client/CMakeLists.txt
cmake_minimum_required(VERSION 3.16)
project(HayChonGiaDungClient LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Network)

add_executable(${PROJECT_NAME}
    src/main.cpp
    src/networkmanager.cpp
    src/networkmanager.h
    resources/qml.qrc
)

target_link_libraries(${PROJECT_NAME}
    Qt6::Core
    Qt6::Quick
    Qt6::Network
)
