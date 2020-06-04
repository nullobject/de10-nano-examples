# DE10 Nano Video

A simple video example written in VHDL for DE10 Nano.

Compiling:

    $ make compile

Programming:

    $ make program

Generate MIF files:

    $ srec_cat cpu_8k.bin -binary -o cpu_8k.mif -mif
