#!/bin/bash

#set -e

BUILD_START=$(date +"%s")
blue='\033[1;34m'
yellow='\033[1;33m'
nocol='\033[0m'
green='\033[1;32m'
red='\033[1;31m'
MAKE_MODULE=0      # This flag is used to disable generating modules permanently
KERNELDIR=$PWD
# Speed up build process
MAKE="./makeparallel"


echo -e " $yellow #####|           AOSP-Nethunter_build.sh             |########$nocol "
echo -e " $yellow #####| Choose Correct options as required when asked |##########$nocol "
echo -e " $yellow #####| To use custom clang version, edit this script |######$nocol "
echo -e " $yellow #####|     to export / set  your clang version.      |#####$nocol "
#echo -e " $yellow #####  ###$nocol "
#echo -e " $yellow ##### the root of kernel source folder and anykernel.sh ##$nocol "

# echo -e " $yellow ##### This script requires that proton-clang & AnyKernel3 #####$nocol "
# echo -e " $yellow ##### is copied inside the $KERNELDIR folder ###########$nocol"
# echo -e " $yellow ##### and that the anykernel.sh is configured correctly ########$nocol"

# Installing dependencies
# sudo apt-get update && sudo apt-get install llvm lld lldb clang gcc binutils flex bison build-essential git gcc g++ gcc-aarch64-linux-gnu gcc-arm-linux-gnueabihf gcc-arm-linux-gnueabi

# -----------------------------------------------------------------------------------------------------------------------------------
# ---------------------------- EXPORTS --------------------------------------------------
KERNEL_DEFCONFIG=alioth_Nethunter_defconfig
#KERNEL_DEFCONFIG=akm_alioth-Kali_defconfig
ANYKERNEL3_DIR=$PWD/AnyKernel3/
export ARCH=arm64
export SUBARCH=ARM64

export PATH="/home/akm/Git/Forked/AOSP_clang/Android_14/clang-r487747c/bin:${PATH}"
export LD_LIBRARY_PATH="/home/akm/Git/Forked/AOSP_clang/Android_14/clang-r450784e/lib64:$LD_LIBRARY_PATH"
# Define variables for each toolchain (AOSP Clang)
#CC_CLANG="/home/akm/Git/Forked/Clang/clang14/bin/clang"
#CC_CLANG="/home/akm/Git/Forked/proton-clang/bin/clang"
CC_CLANG=clang

CLANG_TRIPLE="aarch64-linux-gnu-"
#CROSS_COMPILE_ARM64="aarch64-linux-gnu-"
#CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
CROSS_COMPILE_ARM64="/home/akm/Git/Forked/AOSP_clang/AOSP_tools/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-"
CROSS_COMPILE_ARM32="/home/akm/Git/Forked/AOSP_clang/AOSP_tools/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-"

# Define variable to hold the name of the kernel artifact
#ARTIFACT="Image"  # Default to uncompressed kernel image
ARTIFACT="Image.gz-dtb"
# Flag used to skip/build dtbo
BUILD_DTBOIMG="1"   
# Set the DTBO path
DTBO_PATH="vendor/qcom/alioth-sm8250-overlay.dtbo"  # path to dtbo

# Old Obsolete function
initialize() {
    read -rp "Do you want to only compile the Modules? (y or n)" MOD_ONLY
    echo -e "Enter the desired name for the final kernel zip file (<kernel_name>.zip): "
    read -rp "Enter final Kernel name: " FINAL_KERNEL_ZIP

    echo -e "Do you want to build modules? (y/n): "
    read -rp "Build modules? (y/n): " BUILD_MODULES

    if [ "$BUILD_MODULES" == "y" ]; then
        read -rp "Enter the final module zip name: " MODULES_NAME
    fi
}

initializeTest() {
    # Prompt for module-only compilation
    while true; do
        read -rp "Do you want to only compile the Modules? (y or n): " MOD_ONLY
        case $MOD_ONLY in
        [Yy]*)
            BUILD_MODULES="y"
            FINAL_KERNEL_ZIP=null
            read -rp "Enter the final module zip name: " MODULES_NAME
            break
            ;;
        [Nn]*)
            BUILD_MODULES="n"
            break
            ;;
        *)
            echo "Please enter 'y' or 'n'."
            ;;
        esac
    done

    # Prompt for the final kernel zip name
    while [ "$MOD_ONLY" != "y" ]; do
        read -rp "Enter the desired name for the final kernel zip file (<kernel_name>.zip): " FINAL_KERNEL_ZIP
        if [ -z "$FINAL_KERNEL_ZIP" ]; then
            echo "Please enter a valid name for the final kernel zip file."
        else
            break
        fi
    done

    # Prompt for building modules if not MOD_ONLY
    if [ "$MOD_ONLY" != "y" ]; then
        while true; do
            read -rp "Do you want to build modules? (y/n): " BUILD_MODULES
            case $BUILD_MODULES in
            [Yy]*)
                # Prompt for the final module zip name
                while true; do
                    read -rp "Enter the final module zip name: " MODULES_NAME
                    if [ -z "$MODULES_NAME" ]; then
                        echo "Please enter a valid name for the final module zip file."
                    else
                        break
                    fi
                done
                break
                ;;
            [Nn]*)
                MODULES_NAME=null
                break
                ;;
            *)
                echo "Please enter 'y' or 'n'."
                ;;
            esac
        done
    fi
}

clean_kernel() {
    cd $KERNELDIR
    # Always do clean build lol
    echo -e "$yellow**** Cleaning / Removing 'out' folder ****$nocol"
    # make clean             # Can cause issues
    # make mrproper  # Can cause issues
    rm -rf out
    mkdir -p out
    # make O=out clean       # Unnecessary after running rm -rf out
    # make O=out mrproper    # Unnecessary

    echo -e "$yellow**** Removing 'Mod' and 'libufdt' folders ****$nocol"
    rm -rf Mod
    rm -rf "$KERNELDIR/scripts/ufdt/libufdt"

    echo -e "$yellow**** Cleaning 'AnyKernel3' folder / any previous builds ****$nocol"
    rm -f "$ANYKERNEL3_DIR"/*.zip
    rm -rf $ANYKERNEL3_DIR/$ARTIFACT
    rm -rf $ANYKERNEL3_DIR/dtbo.img
}

build_kernel() {
    cd $KERNELDIR
    # ----------------------Toolchain Info ----------------------------------
    echo -e "$green*** Using this Clang Version to compile kernel *** $nocol"
    $CC_CLANG --version
    echo -e "$green*** ARM64 Cross-Compiler Version: *** $nocol"
    aarch64-linux-gnu-gcc --version
    echo -e "$green*** ARM64 Cross-Compiler Version: *** $nocol"
    arm-linux-gnueabi-gcc --version

    #-----------------------Defconfig stuff-----------------------------------
    echo -e "$yellow**** Kernel defconfig is set to $KERNEL_DEFCONFIG ****$nocol"
    echo -e "$blue***********************************************"
    echo "       NOW MAKING _defconfig : $KERNEL_DEFCONFIG        "
    echo -e "***********************************************$nocol"
    make O=out  CC="$CC_CLANG" AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf OBJSIZE=llvm-size STRIP=llvm-strip HOSTCC=clang HOSTCXX=clang++  $KERNEL_DEFCONFIG

    #------------------------Kernel Stuff-------------------------------------
    echo -e "$blue***********************************************"
    echo "         NOW COMPILING KERNEL!                  "
    echo -e "***********************************************$nocol"

    make O=out \
        CC="$CC_CLANG" \
        CROSS_COMPILE="$CROSS_COMPILE_ARM64" \
        CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
        CLANG_TRIPLE="$CLANG_TRIPLE" \
        AR=llvm-ar \
        OBJCOPY=llvm-objcopy \
        STRIP=llvm-strip \
        OBJDUMP=llvm-objdump \
        NM=llvm-nm \
        LLVM=1 \
        LLVM_IAS=1 \
        READELF=llvm-readelf \
        OBJSIZE=llvm-size \
        HOSTCC=clang \
        HOSTCXX=clang++ \
        -j$(nproc) 2>&1 | tee build.log

        # ----------Other optional compiling options --------------------------
        #AR=llvm-ar \
        #OBJCOPY=llvm-objcopy \
        #STRIP=llvm-strip \
        #OBJDUMP=llvm-objdump \
        #NM=llvm-nm \
        #LLVM=1 \
        #LLVM_IAS=1 \
        #CROSS_COMPILE_COMPAT="$CROSS_COMPILE_ARM32" \
     #   CLANG_TRIPLE="$CLANG_TRIPLE" \
    #    CROSS_COMPILE=aarch64-linux-gnu- \
    #    CROSS_COMPILE_ARM32=arm-linux-gnueabi \
    #    CC=clang \
    #    -j$(nproc) 2>&1 | tee build.log

    # $(nproc)

    ### Other options that could be used if using proton clamg for example..

    # CROSS_COMPILE=aarch64-linux-gnu- \
    # CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    # CC=clang \
    # AR=llvm-ar \
    # OBJDUMP=llvm-objdump \
    # STRIP=llvm-strip \
    # CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
    # NM=llvm-nm \
    # OBJCOPY=llvm-objcopy \

    #---------------------------Build Summary------------------------------------
    BUILD_MID=$(date +"%s")
    MID_DIFF=$(($BUILD_MID - $BUILD_START))
    echo -e "$yellow Kernel Compiled in $(($MID_DIFF / 60)) minute(s) and $(($MID_DIFF % 60)) seconds.$nocol"
}

build_modules() {
    cd $KERNELDIR
    # Build modules if selected by the user
    if [ "$BUILD_MODULES" == "y" ]; then

        #echo -e "|| Cloning Neternels-modules ||"
        #git clone --depth 1 https://github.com/neternels/neternels-modules.git Mod
        #echo -e "|| Copying NetErnel_modules ||"
        #cp $KERNELDIR/NetErnel_modules $KERNELDIR/Mod

        echo -e "|| Copying NetErnel_modules folder From $KERNELDIR ||"
        
        if [ -d "$KERNELDIR/NetErnel_modules" ]; then
            cp -r "$KERNELDIR/NetErnel_modules" "$KERNELDIR/Mod" || {
                echo -e "$red**** Error: Failed to copy 'NetErnel_modules' to 'Mod' folder. ****$nocol"
                exit 1
            }
        else
            echo -e "$red**** Error: 'NetErnel_modules' folder not found in the kernel root directory. ****$nocol"
            exit 1
        fi

        if [ "$MAKE_MODULE" == "0" ]; then
            echo -e "$blue***********************************************"
            echo "         NOW Compiling Modules!                 "
            echo -e "***********************************************$nocol"

            echo -e "$green*** Using this Clang Version to compile module*** $nocol"
            $CC_CLANG --version
            echo -e "$yellow**** Kernel defconfig is set to $KERNEL_DEFCONFIG ****$nocol"
            echo -e "$blue***********************************************"
            echo "       NOW MAKING _defconfig : $KERNEL_DEFCONFIG        "
            echo -e "***********************************************$nocol"
            make O=out  CC="$CC_CLANG" AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf OBJSIZE=llvm-size STRIP=llvm-strip HOSTCC=clang HOSTCXX=clang++  $KERNEL_DEFCONFIG

            echo -e "$yellow**** Preparing Modules ****$nocol"
            make O=out \
                CC="$CC_CLANG" \
                CROSS_COMPILE="$CROSS_COMPILE_ARM64" \
                CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
                CLANG_TRIPLE="$CLANG_TRIPLE" \
                AR=llvm-ar \
                OBJCOPY=llvm-objcopy \
                STRIP=llvm-strip \
                OBJDUMP=llvm-objdump \
                NM=llvm-nm \
                LLVM=1 \
                LLVM_IAS=1 \
                READELF=llvm-readelf \
                OBJSIZE=llvm-size \
                HOSTCC=clang \
                HOSTCXX=clang++ \
                modules_prepare || {
                echo "Error preparing modules"
                exit 1
            }

            echo -e "$yellow**** Building Modules ****$nocol"
            make O=out \
                CC="$CC_CLANG" \
                CROSS_COMPILE="$CROSS_COMPILE_ARM64" \
                CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
                CLANG_TRIPLE="$CLANG_TRIPLE" \
                AR=llvm-ar \
                OBJCOPY=llvm-objcopy \
                STRIP=llvm-strip \
                OBJDUMP=llvm-objdump \
                NM=llvm-nm \
                LLVM=1 \
                LLVM_IAS=1 \
                READELF=llvm-readelf \
                OBJSIZE=llvm-size \
                HOSTCC=clang \
                HOSTCXX=clang++ \
                modules INSTALL_MOD_PATH="$KERNELDIR"/out/modules || {
                echo "Error building modules"
                exit 1
            }
            echo -e "$yellow**** Installing Modules ****$nocol"

            make O=out \
                CC="$CC_CLANG" \
                CROSS_COMPILE="$CROSS_COMPILE_ARM64" \
                CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
                CLANG_TRIPLE="$CLANG_TRIPLE" \
                AR=llvm-ar \
                OBJCOPY=llvm-objcopy \
                STRIP=llvm-strip \
                OBJDUMP=llvm-objdump \
                NM=llvm-nm \
                LLVM=1 \
                LLVM_IAS=1 \
                READELF=llvm-readelf \
                OBJSIZE=llvm-size \
                HOSTCC=clang \
                HOSTCXX=clang++ \
                modules_install INSTALL_MOD_PATH="$KERNELDIR"/out/modules || {
                echo "Error installing modules"
                exit 1
            }
        fi

        echo -e "$blue***********************************************"
        echo "         Zipping Modules!                  "
        echo -e "***********************************************$nocol"

        if [ ! -d "Mod" ]; then
            echo -e "$red**** Error: 'Mod' folder not found. Make sure the build_modules step was executed correctly. ****$nocol"
            exit 1
        fi

        # Generate today's date and time in the format YYYYMMDD_HHMMSS
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

        # Append timestamp to the module zip file name
        MODULES_NAME_WITH_TIMESTAMP="${MODULES_NAME%.*}_${TIMESTAMP}.zip"

        find "$KERNELDIR"/out/modules -type f -iname '*.ko' -exec cp {} Mod/system/lib/modules/ \; || {
            echo "Error copying modules"
            exit 1
        }
        cd $KERNELDIR
        cd Mod

        rm -rf system/lib/modules/placeholder
        zip -r9 $MODULES_NAME_WITH_TIMESTAMP . -x ".git*" -x "LICENSE.md" -x "*.zip"
        MOD_NAME="$MODULES_NAME_WITH_TIMESTAMP"
        # Print a message indicating success
        echo -e "$green**** Module.zip created successfully ****$nocol"

        # Output the location of the generated module.zip file
        echo -e "$green**** Generated Module Zip File Location: $KERNELDIR/Mod/$MOD_NAME ****$nocol"

        cd $KERNELDIR

        MODULES_MID=$(date +"%s")
        MODULES_DIFF=$(($MODULES_MID - $BUILD_START))
        echo -e "$yellow Modules Compiled in $(($MODULES_DIFF / 60)) minute(s) and $(($MODULES_DIFF % 60)) seconds.$nocol"

    else
        echo -e "$yellow**** Skipping building modules as per user choice ****$nocol"
    fi
}

zip_kernel() {
    cd $KERNELDIR
    echo -e "$blue***********************************************"
    echo "   COMPILING FINISHED! NOW MAKING IT INTO FLASHABLE ZIP "
    echo -e "***********************************************$nocol"

    echo -e "$yellow**** Verify that $ARTIFACT is produced ****$nocol"
    ls $PWD/out/arch/arm64/boot/$ARTIFACT

    echo -e "$yellow**** Verifying AnyKernel3 Directory ****$nocol"
    ls $ANYKERNEL3_DIR

    echo -e "$yellow**** Removing leftovers from anykernel3 folder ****$nocol"
    rm -rf "$ANYKERNEL3_DIR/$ARTIFACT"
    rm -rf "$ANYKERNEL3_DIR"/*.zip
    rm -rf "$ANYKERNEL3_DIR"/dtbo.img   # Warning: this will remove any zip in Anykernel3 folder!

    # Generate today's date and time in the format YYYYMMDD_HHMMSS
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

    # Append timestamp to the final kernel zip file name
    FINAL_KERNEL_ZIP_WITH_TIMESTAMP="${FINAL_KERNEL_ZIP%.*}_${TIMESTAMP}.zip"

    echo -e "$yellow**** Copying $ARTIFACT to anykernel 3 folder ****$nocol"
    cp "$KERNELDIR/out/arch/arm64/boot/$ARTIFACT" "$ANYKERNEL3_DIR/"
    
    if [ "$BUILD_DTBOIMG" = "1" ] || [ "$BUILD_DTBOIMG" = "2" ]; then
        echo -e "$yellow**** Copying dtbo.img to anykernel 3 folder ****$nocol"
        cp "$KERNELDIR"/out/arch/arm64/boot/dtbo.img $ANYKERNEL3_DIR/dtbo.img
    fi

    echo -e "$green**** Time to zip up! ****$nocol"
    cd $ANYKERNEL3_DIR/
    zip -r9 $FINAL_KERNEL_ZIP_WITH_TIMESTAMP * -x README $FINAL_KERNEL_ZIP_WITH_TIMESTAMP
    #cp $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP_WITH_TIMESTAMP $KERNELDIR/$FINAL_KERNEL_ZIP_WITH_TIMESTAMP

    echo -e "$green**** Done, generated flashable zip successfully ****$nocol"

    # Output the location of the generated zip file
    echo -e "$green**** Generated Zip File Location: $KERNELDIR/Anykernel3/$FINAL_KERNEL_ZIP_WITH_TIMESTAMP ****$nocol"

    cd ..
}

summary() {
    echo -e "$blue***********************************************"
            echo "         Summary for the Entire Build                 "
            echo -e "***********************************************$nocol"

    echo -e "$green**** Done, here is your checksum and other info ****$nocol"
    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))
    echo -e "$green Full Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"
    echo -e "$green**** Generated Zip File Location: $KERNELDIR/Anykernel3/$FINAL_KERNEL_ZIP_WITH_TIMESTAMP ****$nocol"
    echo -e "$green**** Checksum for kernel zip ****$nocol"
    sha1sum "$KERNELDIR/Anykernel3/$FINAL_KERNEL_ZIP_WITH_TIMESTAMP"

    [ -n "$MOD_NAME" ] && echo -e "$green**** Checksum for Module zip ****$nocol" && sha1sum "$KERNELDIR/Mod/$MOD_NAME" && echo -e "$green**** Generated Module Zip File Location: $KERNELDIR/Mod/$MOD_NAME ****$nocol"
}


build_dtbo() {
    echo "Building DTBO..."

    # Clone libufdt repository if not already present
    if [ ! -d "$KERNELDIR/scripts/ufdt/libufdt" ]; then
        git clone https://android.googlesource.com/platform/system/libufdt "$KERNELDIR/scripts/ufdt/libufdt"
    fi

    # Build DTBO
    python2 "$KERNELDIR/scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
        create "$KERNELDIR/out/arch/arm64/boot/dtbo.img" --page_size=4096 "$KERNELDIR/out/arch/arm64/boot/dts/$DTBO_PATH"

    echo "DTBO image created: $KERNELDIR/out/arch/arm64/boot/dtbo.img"
}

# Call and test functions as needed

# initialize
initializeTest
clean_kernel
if [ "$MOD_ONLY" == "n" ]; then
    build_kernel
    if [ "$BUILD_DTBOIMG" == "2" ]; then
        build_dtbo
    fi
    zip_kernel
fi
build_modules
summary

# Remove The out folder after the script gets executed

#if [ "$PWD" == "$KERNELDIR" ]; then
#    rm -rf out/
#fi


