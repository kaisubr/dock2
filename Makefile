
# Use xcrun to find the swift compiler and sdk path
SWIFTC = xcrun -sdk macosx swiftc
FLAGS = -framework AppKit -framework CoreGraphics -framework Foundation -framework ApplicationServices
SOURCES = src/main.swift src/AppDelegate.swift src/TaskbarView.swift src/WindowItem.swift

all: clean build

build:
	mkdir -p dist
	$(SWIFTC) $(FLAGS) -o dist/dock2 $(SOURCES)

clean:
	rm -rf dist

run: build
	./dist/dock2
