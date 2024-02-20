# Patch for "The Servant" ROM for Commodore 128

This project patches the original "The Servant V4.84" ROM with new functionality, aimed for users with SD2IEC devices and owners of C128s expanded to 256K RAM.

To make it distinct from the original "The Servant" release I changed the version number to 4.85.

## For very impatient

Download [servant.bin](servant.bin) or the archive from Releases, flash to a 32K EEPROM and plug into U36 socket.
Use `XI1` command on your SD2IEC to list disk images as folders and just use directory browser (menu option 4) with `RETURN` and `/` to go through folders and disk images.

- The patched version of The Servant uses `HELP` key to start the menu.
- SD2IEC folders and disk images can be entered/exited from the directory browser
- RAM bank 3 can be used as 64K Quick Brown Box (QBB) (256K C128 only)
- RAM bank 2 can be used as an additional C64 mode area (256K C128 only)

## New Features

The patched version of The Servant uses `HELP` key to start the menu.

If you want to copy settings (colors, function key assignments) from your current Servant ROM then replace first $0123 bytes in provided `servant.bin` by data copied from your ROM.
Read below how to patch the whole ROM instead.

New features needed some extra space. Because of that two functions were disabled:

- `CTRL`+`+` to save configured `SERVANT.MOD` file from RAM
- `SHIFT`+`+` to reset prefs to defaults

### SD2IEC directory and disk image navigation

Option '4' (file browser) will now recognize `DIR` filetype as a directory that you can enter.

- use `RETURN` to enter a folder; equivalent to `CD<name>` DOS command
- use `/` to go up one level; equivalent to `CD<leftarrow>` DOS command

To enter disk images (d64, d71, d81) SD2IEC must be configured first to list them as `DIR` files.

Use one of these DOS commands from Servant (`@` key):

- `XI0` to list disk images only as `PRG` files (not recommended)
- `XI1` to list disk images only as `DIR` files (recommended)
- `XI2` to list disk images as `DIR` files and again as `PRG` files
- `XW` to save this setting to EEPROM

The original functionality of entering/exiting 1581 partitions (`CBM` filetype) still works.

### Quick Brown Box emulation for 256K C128

If your C128 has 256K of memory (4 banks) you can use QBB functions of The Servant to store some files in bank 3 instead of QBB.
This will be lost after you power off the computer but it may be handy to load often used programs quickly.

Follow the original manual for explanations about QBB integration. There is no more QBB code, but the functions are exactly the same.

After powerup press `^` key to format bank 3 RAM as QBB area. Servant will ask for number of (16K) banks - answer '4'.

New options will appear on the bottom of the main menu. The manual explains them but I found `F3` to copy some files from disk to QBB area a bit confusing.

After selecting `F3` you will see the file browser (the same as after choosing option '4' from main menu).
Here you need to select one file and use one of the function keys to choose how it should be executed when loaded from QBB.
For example `F7` means that this file will run in C64 mode. You can load as many files as you need and then use `ESC` key to go back to main menu.

Now there will be even more information on the screen - a list of files within QBB that you can choose to load and execute via letter keys.

### Two different C64 environments

The original manual explains how option '9' (GO 64) differs from `GO64` command from BASIC.

The stock `GO64` command runs C64 mode in RAM bank 0.

The Servant will run C64 mode in RAM bank 1 so that most of it will stay intact after reset.
There is more: if you hit `SHIFT`+9 from the main menu The Servant will enter C64 mode in bank 1 through warm reset and the BASIC program will be still there.

If your C128 has 256K of memory (4 banks) you can have two different such C64 enviroments.
Right after pressing 9 (or `SHIFT`+9) the Servant will ask to press `RETURN` for confirmation.

If you press `RETURN` here then the computer will enter C64 mode using bank 1 as C64 RAM, just like the manual explains.

If you press `C=`+`RETURN` instead then bank 2 will be used.

Here is an example of a workflow after C128 powerup:

1. use option 9 then press `RETURN` to initialize C64 mode in bank 1
2. use option 9 then press `C=`+`RETURN` to initialize C64 mode in bank 2
3. write some BASIC code, it will stay in bank 2
4. reset machine, go back to C128 mode and Servant menu
5. use option `SHIFT`+`9` then press `RETURN` to warm restart C64 in bank 1
6. write some different basic program, it will stay in bank 1
7. reset machine, go back to C128 mode and Servant menu
8. use option `SHIFT`+`9` then press `C=`+`RETURN` to warm restart C64 in bank 2
9. your first BASIC program is still there!
10. reset machine, go back to C128 mode and Servant menu
11. use option `SHIFT`+`9` then press `RETURN` to warm restart C64 in bank 1
12. your second BASIC program is still there!

Note that switching to RAM bank 2 works only for option '9' confirmed with `C=`+`RETURN`. Functions like `Run 64` and `Load"*",64` will still use bank 1.

## Original features

Here is a short list of original features of The Servant that are easily overlooked in the manual:

### Modifiers to select disk device

Boot/Run/Run64/directory/DOS command (`@`) options will use device 8 by default.

You can choose a different device by holding a modifier key before choosing the option:

- device 9: `SHIFT`
- device 10: `C=`
- device 11: `CTRL`
- device 12: `ALT`

### DOS commands `@`

- `SHIFT`+`RETURN` recall last command
- `UI` warm reset
- `UJ` cold reset
- `#<number>` change (or swap if it already exists on the bus) device number to `<number>`; for example `CTRL`+`@` followed by `#9` makes drives 9 and 11 swap their device numbers

For 1571

- `U0>M0` enter 1541 mode
- `U0>M1` enter 1571 mode
- `U0>H0` (in 1541 mode only) select head 0 (default)
- `U0>H1` (in 1541 mode only) select head 1 (this is not like flipping the disk, it spins the wrong way)
- `U0>V0` turn off write verify
- `U0>V1` turn on write verify

For 1581

- `/0:<name>` change to `<name>` partition
- `/` go back to root folder

For SD2IEC

- `CD<name>` change to `<name>` folder or enter disk image
- `CD<leftarrow>` go to parent folder or exit disk image

# Configuration and assembly

(Note: if you want to try it out **now** just download the [servant.bin](servant.bin) file from repository or releases on the right)

You need [KickAss](http://www.theweb.dk/KickAssembler/Main.html#frontpage) to assemble this code.

There is only one file here: [servantpatch.asm](servantpatch.asm). It reads [servant.mod](servant.mod) ROM dump as an input, applies patches and saves the result as [servant.bin](servant.bin).
You can provide your own ROM dump here. Just rename it to `servant.mod` or change that name in the `servantpatch.asm`.

On the top of the [servantpatch.asm](servantpatch.asm) you can configure the colors for 40- and 80-column screen and the key used to recall Servant. Disable that patch if you use your own ROM dump.

Assemble the file to get patched ROM as a result. Just type

```sh
make
```

or simply

```sh
java -jar <path-to-KickAss>/KickAss.jar servantpatch.asm
```

Flash the result onto a 32K EEPROM, put into U36 socket and try it out.
