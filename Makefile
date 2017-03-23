default: build

.PHONY: build

build:
	crystal build --release sleuth.cr
