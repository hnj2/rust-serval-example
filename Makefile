
# Debugging setup (run make V=1 for verbosity)
V ?= 0
ifeq ($(V),0)
Q = @
CARGO_FLAGS += -q
endif

# Give an error when cargo is not found
ifeq "$(shell whereis -b cargo)" "cargo:"
$(error "Cargo/Rust doesn't seem to be installed! Please install from: https://www.rust-lang.org/tools/install")
endif

CRATE = serval_example

test: build
	@echo "\tTEST test.rkt"
	$(Q)raco test test.rkt

build: o/$(CRATE).ll.rkt o/$(CRATE).globals.rkt o/$(CRATE).map.rkt

# We have to do clean to make sure .../crate_name-*.(o|ll) only matches one file
# Thats why we have to call cargo clean all the time
target/release/lib$(CRATE).rlib: Cargo.toml $(shell find src -type f)
	@echo "\tCARGO $^"
	$(Q)cargo clean && \
	cargo rustc $(CARGO_FLAGS) --release -- --emit llvm-ir,obj

o/%.ll.rkt: o/%.ll
	@echo "\tSERVAL-LLVM $^"
	$(Q)racket serval-llvm.rkt < $^ > $@~
	$(Q)mv $@~ $@

o/%.map.rkt: o/%.o
	@echo "\tSERVAL-NM $^"
	$(Q)echo "#lang reader serval/lang/nm" > $@~
	$(Q)nm --print-size --numeric-sort $^ >> $@~
	$(Q)mv $@~ $@

o/%.globals.rkt: o/%.o
	@echo "\tSERVAL-DWARF $^"
	$(Q)echo "#lang reader serval/lang/dwarf" > $@~
	$(Q)objdump --dwarf=info $^ >> $@~
	$(Q)mv $@~ $@

o/%.o: target/release/lib%.rlib | o
	$(Q)cp target/release/deps/$*-*.o $@

o/%.ll: target/release/lib%.rlib | o
	$(Q)cp target/release/deps/$*-*.ll $@

# Directory for build artifacts
o:
	$(Q)mkdir -p o

clean:
	$(Q)cargo clean
	$(Q)rm -rf o

.PRECIOUS: o/%.o o/%.ll o/%.ll.rkt o/%.map.rkt o/%.globals.rkt
