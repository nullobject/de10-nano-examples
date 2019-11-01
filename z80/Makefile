.PHONY: program clean

build:
	quartus_sh --flow compile z80

program:
	quartus_pgm -m jtag -c 1 -o "p;output_files/z80.sof@2"

clean:
	rm -rf db incremental_db output_files
