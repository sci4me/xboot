# xboot
xboot is a simple "bootloader" which downloads a file via a serial port/UART (65C51 ACIA, in my case) using the XMODEM/CRC protocol. It isn't a 100% conformant implementation of XMODEM but it gets the job done.

The XMODEM implementation is nearly identical to the one found [here](http://www.6502.org/source/io/xmodem/xmodem.htm).

NOTE: You'll have to modify the Makefile if you're not using `minipro` to burn your ROMs.