COPY /b BASIC + KERNAL + dos1541 std_C64.ROM
bin2hex 0x00 std_C64.ROM filename.hex
hex2coe
rename filename.coe std_C64.coe
