# server/Makefile

CC      = gcc
SRC_DIR = src
INC_DIR = include
BIN_DIR = bin

SRCS    = $(SRC_DIR)/main.c \
          $(SRC_DIR)/server.c \
          $(SRC_DIR)/database.c

TARGET  = $(BIN_DIR)/server

CFLAGS  = -I$(INC_DIR) -Wall -Wextra -O2
LDLIBS  = -lmysqlclient

all: $(TARGET)

$(TARGET): $(SRCS)
	mkdir -p $(BIN_DIR)
	$(CC) $(SRCS) -o $(TARGET) $(CFLAGS) $(LDLIBS)

run: all
	./$(TARGET)

clean:
	rm -rf $(BIN_DIR)

.PHONY: all run clean
