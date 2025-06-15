.PHONY: build

build:
	rm -rf build/
	mkdir build/
	cd build && cmake -DCMAKE_BUILD_TYPE=Debug -DBUILD_DEMO=ON ..
	cd build && make