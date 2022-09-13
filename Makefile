default: lib

CC      := gcc
CXX 	:= g++
CFLAGS  := -g -Wall -fPIC -DSM64_LIB_EXPORT -DVERSION_US -DNO_SEGMENTED_MEMORY -DGBI_FLOATS
LDFLAGS := -lm -shared -lpthread
ENDFLAGS := -fPIC

DIST_DIR  := dist
LIB_FILE  := $(DIST_DIR)/libsm64.so

ifeq ($(OS),Windows_NT)
LIB_FILE  := $(DIST_DIR)/sm64.dll
LDFLAGS := $(LDFLAGS) -mwindows
ENDFLAGS := -static -lole32 -lstdc++

else ifeq ($(shell uname -s),Darwin)
LIB_FILE  := $(DIST_DIR)/libsm64.dylib
CFLAGS := $(CFLAGS) -DUSE_SDL2
ENDFLAGS := -undefined dynamic_lookup -lSDL2

else
CFLAGS := $(CFLAGS) -DUSE_ALSA -DUSE_PULSEAUDIO
LDFLAGS := $(LDFLAGS) -lasound -lpulse
endif

SRC_DIRS  := src src/decomp src/decomp/engine src/decomp/include/PR src/decomp/game src/decomp/pc src/decomp/pc/audio src/decomp/mario src/decomp/tools src/decomp/audio
BUILD_DIR := build
ALL_DIRS  := $(addprefix $(BUILD_DIR)/,$(SRC_DIRS))

LIB_H_FILE := $(DIST_DIR)/include/libsm64.h
TEST_FILE  := run-test

C_IMPORTED := src/decomp/mario/geo.inc.c src/decomp/mario/model.inc.c
H_IMPORTED := $(C_IMPORTED:.c=.h)
IMPORTED   := $(C_IMPORTED) $(H_IMPORTED)

C_FILES   := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.c)) $(C_IMPORTED)
CXX_FILES := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.cpp))
O_FILES   := $(foreach file,$(C_FILES),$(BUILD_DIR)/$(file:.c=.o)) $(foreach file,$(CXX_FILES),$(BUILD_DIR)/$(file:.cpp=.o))
DEP_FILES := $(O_FILES:.o=.d)

TEST_SRCS := test/main.c test/context.c test/level.c
TEST_OBJS := $(foreach file,$(TEST_SRCS),$(BUILD_DIR)/$(file:.c=.o))

ifeq ($(OS),Windows_NT)
  TEST_FILE := $(DIST_DIR)/$(TEST_FILE)
endif

DUMMY != mkdir -p $(ALL_DIRS) build/test src/decomp/mario $(DIST_DIR)/include 


$(filter-out src/decomp/mario/geo.inc.c,$(IMPORTED)): src/decomp/mario/geo.inc.c
src/decomp/mario/geo.inc.c: ./import-mario-geo.py
	./import-mario-geo.py

$(BUILD_DIR)/%.o: %.c $(IMPORTED)
	@mkdir -p $(@D)
	@$(CC) $(CFLAGS) -MM -MP -MT $@ -MF $(BUILD_DIR)/$*.d $<
	$(CC) -c $(CFLAGS) -isystem src/decomp/include -o $@ $<

$(BUILD_DIR)/%.o: %.cpp $(IMPORTED)
	@mkdir -p $(@D)
	@$(CXX) $(CFLAGS) -MM -MP -MT $@ -MF $(BUILD_DIR)/$*.d $<
	$(CXX) -c $(CFLAGS) -isystem src/decomp/include -o $@ $<

$(LIB_FILE): $(O_FILES)
	@mkdir $(DIST_DIR)
	$(CC) $(LDFLAGS) -o $@ $^ $(ENDFLAGS)

$(LIB_H_FILE): src/libsm64.h
	@mkdir -p $(DIST_DIR)/include
	cp -f $< $@


test/level.c test/level.h: ./import-test-collision.py
	./import-test-collision.py

test/main.c: test/level.h

$(BUILD_DIR)/test/%.o: test/%.c
	@$(CC) $(CFLAGS) -MM -MP -MT $@ -MF $(BUILD_DIR)/test/$*.d $<
ifeq ($(OS),Windows_NT)
	$(CC) -c $(CFLAGS) -I/mingw64/include/SDL2 -I/mingw64/include/GL -o $@ $<
else
	$(CC) -c $(CFLAGS) -o $@ $<
endif

$(TEST_FILE): $(LIB_FILE) $(TEST_OBJS)
ifeq ($(OS),Windows_NT)
	$(CC) -o $@ $(TEST_OBJS) $(LIB_FILE) `sdl2-config --cflags --libs` -lglew32 -lglu32 -lopengl32 -lSDL2 -lSDL2main -lm
else
	$(CC) -o $@ $(TEST_OBJS) $(LIB_FILE) -lGLEW -lGL -lSDL2 -lSDL2main -lm
endif


lib: $(LIB_FILE) $(LIB_H_FILE)

test: $(TEST_FILE) $(LIB_H_FILE)

run: test
	./$(TEST_FILE)

clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR) test/level.? $(TEST_FILE)

-include $(DEP_FILES)
