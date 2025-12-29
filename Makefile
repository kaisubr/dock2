
# Use xcrun to find the swift compiler and sdk path
SWIFTC = xcrun -sdk macosx swiftc
FLAGS = -framework AppKit -framework CoreGraphics -framework Foundation

all: clean build

build:
	$(SWIFTC) $(FLAGS) -o MiniBar main.swift AppDelegate.swift TaskbarView.swift WindowItem.swift

clean:
	rm -f MiniBar

run: build
	./MiniBar
