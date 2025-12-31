
SWIFTC = xcrun -sdk macosx swiftc
FLAGS = -framework AppKit -framework CoreGraphics -framework Foundation -framework ApplicationServices
SOURCES = $(shell find Sources -name "*.swift")

all: clean build

build:
	mkdir -p dist
	$(SWIFTC) $(FLAGS) -o dist/Dock2 $(SOURCES)

clean:
	rm -rf dist

run: build
	./dist/Dock2
