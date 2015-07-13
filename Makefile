CC=gcc
CFLAGS=
FC=gfortran
FCFLAGS=-Jbuild -ffree-line-length-none #-fbacktrace -fbounds-check


all: build fplus libfeature.so

# folder object files
build:
	mkdir -p build

# download fplus
fplus:
	wget https://github.com/r5r3/fplus/releases/download/v0.1/fplus.tar.gz
	tar -xzf fplus.tar.gz
	rm fplus.tar.gz
	
# the actual NCL library
libfeature.so: build/ncl_feature.stub build/ncl_feature.f90 build/libfeature_objs.a
	WRAPIT -n libfeature -L build -l feature_objs $^

# rule for files which need fplus preprocessor
build/%.f90: src/%.F90
	./fplus $< -o $@

build/%.f90: src/%.f90
	cp $< $@

build/%.o: build/%.f90
	$(FC) $(FCFLAGS) -c $< -o $@

build/%.o: src/%.c
	$(CC) $(CFLAGS) -c $< -o $@

build/%.stub: src/%.stub
	cp $< $@

build/libfeature_objs.a: build/fplus_object.o build/fplus_iterator.o build/fplus_hashcode.o build/fplus_hashcode_helper.o build/fplus_strings.o build/fplus_fillvalue.o build/fplus_error.o build/fplus_list.o build/mod_feature.o
	ar -rcs $@ $^
	
# clean up
clean:
	rm -rf build
	rm -f libfeature.so
	
# create some test plots
test:
	ncl test-1.ncl
	
