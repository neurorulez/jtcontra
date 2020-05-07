# KONAMI 007121 Arcades Conversion to FPGA by Jotego

Konami developed a graphic chip called 007121. This was used in several games.
This project aims to accurately replicate those games in modern electronics,
namely FPGA systems.

# Arcade Titles

Name            |  Main CPU    | Sound CPU   | K007121 units | Audio
----------------|--------------|-------------|---------------|-----------------
Contra          |  HD63C09EP   | 68B09EP     | x2            | YM2151
Combat School   |  6309        | Z80         | x2            | YM2203 + UPD7759
MX5000          |  6309        | Z80         | x1            | YM2151 + K007232
Haunted Castle  |  KONAMI      | Z80         | x2            | YM3812 + K051649
Fast Lane       |  6309        | -           | x1 + K051733  | K007232 x 2
Labyrinth Runner|  6309        | -           | x1 + K051733  | YM2203 x 2

# Supported FPGA Platforms

Binary RBF files for MiST, MiSTer and SiDi will be provided for in 
https://github.com/jotego/jtbin

# Compiling

You need to have Quartus installed in a linux machine. Clone this repository and
its submodules following standard git instructions. Go to the root folder and
type `source setprj.sh`. Now you can compile the core with `jtcore contra -mist`
Use `-mister` or `-sidi` if appropriate.

# ROM file

Use the mra file in rom/mra for MiSTer. For MiST/SiDi, convert the mra to a rom
file using the mra tool.

# External Modules Used

Name          | Purpose           | Author  | URL
--------------|-------------------|---------|---------------------------------
JT51          | YM2151 sound      | jotego  | https://github.com/jotego/jt51
JTFRAME       | FPGA framework    | jotego  | https://github.com/jotego/jtframe

# Support

The *jotego* nickname had already been used by other people so on some networks
you will find me as *topapate*.

Contact via:
    https://twitter.com/topapate
    https://github.com/discord

You can show your appreciation through
* Patreon: https://patreon.com/topapate
* Paypal: https://paypal.me/topapate
