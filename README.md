For Rom Devs: IF you want to inline this kernel in your Roms then do this before building ( In kernel root directory ):

curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

Do this Everytime you clone the repo bcz this kernel has the support for Kernel-SU and it needs to be recloned and checkout to latest stable tag.

From AKM
===============================
 defconfig used : alioth_Nethunter_defconfig

 To compile just execute the Neotron_Clang-build.sh
 To compile without KernelSU, run the following command in the root kernel directory.
 ----------------------------------------
 curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s -- --cleanup

 Then:

 Check for KernelSU Modifications: Manually inspect key files like drivers/input/input.c, fs/stat.c, fs/exec.c, fs/read_write.c, and fs/open.c in the kernel source.
 Search for lines mentioning ksu_handle_ (e.g., ksu_handle_input_handle_event), as they are KernelSU-specific.
 Remove KernelSU References: Delete or comment out any lines with ksu_handle_ references in these files.
 Double-check Makefiles and Kconfig Files: Ensure that KernelSU-related flags or objects are removed.
 Recompile the Kernel: After making these edits, retry building the kernel.