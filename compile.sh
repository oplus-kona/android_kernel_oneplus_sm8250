#!/usr/bin/env bash
# OnePlus SM8250 (Kona) Production Kernel Compile Script
# Supported Devices:
#   - instantnoodle  (OnePlus 8)
#   - instantnoodlep (OnePlus 8 Pro)
#   - kebab          (OnePlus 8T)
#   - lemonades      (OnePlus 9R)

set -o pipefail

export ARCH=arm64
export SUBARCH=arm64
export TZ=Asia/Jakarta

# Build Metadata Branding
export KBUILD_BUILD_USER="zenzer0s"
export KBUILD_BUILD_HOST="kernel-lab"

# Directories
KERNEL_DIR="$PWD"
BASE_DIR="$PWD/.."
TOOLCHAINS_DIR="$BASE_DIR/toolchains"
OUT_DIR="$KERNEL_DIR/out"
MODULES_OUT="$OUT_DIR/modules"
LOG_FILE="$OUT_DIR/kernel_compile.log"
CHANGELOG_FILE="$BASE_DIR/kernel_changelog.txt"

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "lineage-24.0")
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
KERNEL_VERSION=$(make kernelversion 2>/dev/null || echo "4.19")

# CCache configuration
export CCACHE_EXEC=$(which ccache 2>/dev/null || echo "/usr/bin/ccache")
export USE_CCACHE=1
if [[ -d "$BASE_DIR/ccache" ]]; then
    export CCACHE_DIR="$BASE_DIR/ccache/.kernel-kona"
else
    export CCACHE_DIR="$HOME/.ccache"
fi

# Kernel output paths
K_IMG="$OUT_DIR/arch/arm64/boot/Image"
K_IMG_GZ="$OUT_DIR/arch/arm64/boot/Image.gz"
K_DTBO_DIR="$OUT_DIR/arch/arm64/boot/dts/vendor/oplus"
K_DTB_DIR="$OUT_DIR/arch/arm64/boot/dts/vendor/qcom"

AK3_DIR="$BASE_DIR/AnyKernel3"
[[ ! -d "$AK3_DIR" && -d "$KERNEL_DIR/AnyKernel3" ]] && AK3_DIR="$KERNEL_DIR/AnyKernel3"

# Telegram API setup (Optional)
TELEGRAM_CONFIG="$BASE_DIR/telegram_api"
HAS_TELEGRAM=0
if [[ -f "$TELEGRAM_CONFIG" ]]; then
    source "$TELEGRAM_CONFIG"
    if [[ -n "$BOT_TOKEN" && (-n "$GROUP_ID" || -n "$CHANNEL_ID" || -n "$PRIVATE_ID") ]]; then
        HAS_TELEGRAM=1
    fi
fi

MSGTARGET="private"

for arg in "$@"; do
    case "$arg" in
        weekly) MSGTARGET="channel" ;;
        group)  MSGTARGET="group" ;;
    esac
done

if [[ $HAS_TELEGRAM -eq 1 ]]; then
    case "$MSGTARGET" in
        channel) ID="${CHANNEL_ID:-$PRIVATE_ID}" ;;
        group)   ID="${GROUP_ID:-$PRIVATE_ID}" ;;
        *)       ID="$PRIVATE_ID" ;;
    esac
fi

send_msg() {
    [[ $HAS_TELEGRAM -eq 0 ]] && return 0
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$ID" \
        -d text="$1" \
        -d parse_mode=html >/dev/null
}

send_file() {
    [[ $HAS_TELEGRAM -eq 0 ]] && return 0
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
        -F chat_id="$ID" \
        -F document=@"$1" >/dev/null
}

send_changelog() {
    local FILE="$1"
    [[ $HAS_TELEGRAM -eq 0 ]] && return 0

    if [[ ! -f "$FILE" ]]; then
        echo "--- ! Failed to find changelog at $FILE ! ---"
        return
    fi

    if [[ ! -s "$FILE" ]]; then
        echo "- Upstream kernel and subsystem updates" > "$FILE"
    fi

    local CHANGELOG
    CHANGELOG=$(sed 's/$/%0A/' "$FILE" | tr -d '\n')

    send_msg "<b>Changelog(s):</b>%0A<code>$CHANGELOG</code>"
}

# Auto-Download Toolchain Function
fetch_neutron_clang() {
    local DEST="$TOOLCHAINS_DIR/neutron-clang"
    if [[ ! -f "$DEST/bin/clang" ]]; then
        echo "--- Downloading Neutron Clang toolchain via antman ---"
        mkdir -p "$DEST"
        cd "$DEST" || exit 1
        bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") -S
        bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") --patch=glibc
        cd "$KERNEL_DIR" || exit 1
    fi
}

# OnePlus SM8250 Device Mapping
# Target format: <TARGET_NAME>:<DEFCONFIG_FRAGMENTS>:<DTBO_NAME>
declare -A DEVICE_MAP=(
    ["instantnoodle"]="OP8:vendor/kona-perf_defconfig vendor/oplus.config:kona-instantnoodle-overlay.dtbo"
    ["instantnoodlep"]="OP8P:vendor/kona-perf_defconfig vendor/oplus.config:kona-instantnoodlep-overlay.dtbo"
    ["kebab"]="OP8T:vendor/kona-perf_defconfig vendor/oplus.config:kona-kebab-overlay.dtbo"
    ["lemonades"]="OP9R:vendor/kona-perf_defconfig vendor/oplus.config:kona-lemonades-overlay.dtbo"
    ["oneplus8"]="OP8:vendor/kona-perf_defconfig vendor/oplus.config:kona-instantnoodle-overlay.dtbo"
    ["oneplus8pro"]="OP8P:vendor/kona-perf_defconfig vendor/oplus.config:kona-instantnoodlep-overlay.dtbo"
    ["oneplus8t"]="OP8T:vendor/kona-perf_defconfig vendor/oplus.config:kona-kebab-overlay.dtbo"
    ["oneplus9r"]="OP9R:vendor/kona-perf_defconfig vendor/oplus.config:kona-lemonades-overlay.dtbo"
    ["kona"]="KONA:vendor/kona-perf_defconfig vendor/oplus.config:all"
)

declare -A DEVICE_NAME_MAP=(
    ["instantnoodle"]="OnePlus8"
    ["instantnoodlep"]="OnePlus8Pro"
    ["kebab"]="OnePlus8T"
    ["lemonades"]="OnePlus9R"
    ["oneplus8"]="OnePlus8"
    ["oneplus8pro"]="OnePlus8Pro"
    ["oneplus8t"]="OnePlus8T"
    ["oneplus9r"]="OnePlus9R"
    ["kona"]="OnePlus-SM8250"
)

# Toolchain selection & auto-fetch
if [[ "$*" == *neutron* ]]; then
    fetch_neutron_clang
    export PATH="$TOOLCHAINS_DIR/neutron-clang/bin:$PATH"
    TC="Neutron-Clang"
elif [[ "$*" == *aosp* && -d "$TOOLCHAINS_DIR/aosp-clang" ]]; then
    export PATH="$TOOLCHAINS_DIR/aosp-clang/bin:$PATH"
    TC="AOSP-Clang"
elif [[ "$*" == *llvm* && -d "$TOOLCHAINS_DIR/llvm-clang" ]]; then
    export PATH="$TOOLCHAINS_DIR/llvm-clang/bin:$PATH"
    TC="LLVM-Clang"
elif [[ "$*" == *lilium* && -d "$TOOLCHAINS_DIR/lilium-clang" ]]; then
    export PATH="$TOOLCHAINS_DIR/lilium-clang/bin:$PATH"
    TC="Lilium-Clang"
elif [[ -d "$TOOLCHAINS_DIR/clang" ]]; then
    export PATH="$TOOLCHAINS_DIR/clang/bin:$PATH"
    TC="Clang"
elif [[ -d "$TOOLCHAINS_DIR/neutron-clang" ]]; then
    export PATH="$TOOLCHAINS_DIR/neutron-clang/bin:$PATH"
    TC="Neutron-Clang"
elif which clang >/dev/null 2>&1; then
    CLANG_VER=$(clang --version | head -n 1 | awk '{print $1,$2,$3,$4}')
    TC="Host-Clang (${CLANG_VER})"
else
    echo "--- ! No toolchain found, auto-fetching Neutron Clang... ! ---"
    fetch_neutron_clang
    export PATH="$TOOLCHAINS_DIR/neutron-clang/bin:$PATH"
    TC="Neutron-Clang"
fi

TARGETS=()
DEFCONFIGS=()
DEVICES=()
DTBOS=()
ZIPS=()

# Parse target devices from CLI args
for arg in "$@"; do
    for device in "${!DEVICE_MAP[@]}"; do
        if [[ "$arg" == "$device" ]]; then
            IFS=':' read -r TARGET DEFCONFIG DTBO <<< "${DEVICE_MAP[$device]}"
            TARGETS+=("$TARGET")
            DEFCONFIGS+=("$DEFCONFIG")
            DTBOS+=("$DTBO")
            DEVICES+=("$device")
        fi
    done
done

# Default to kebab if no device specified
if [[ ${#TARGETS[@]} -eq 0 ]]; then
    IFS=':' read -r TARGET DEFCONFIG DTBO <<< "${DEVICE_MAP[kebab]}"
    TARGETS+=("$TARGET")
    DEFCONFIGS+=("$DEFCONFIG")
    DTBOS+=("$DTBO")
    DEVICES+=("kebab")
fi

compilebuild() {
    # Build Image, DTBOs, and DTBs
    make -j$(nproc) O=out \
        ARCH=arm64 \
        SUBARCH=arm64 \
        CC="ccache clang" \
        LD=ld.lld \
        AR=llvm-ar \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
        LLVM=1 LLVM_IAS=1 \
        Image dtbs \
        2>&1 | tee -a "$LOG_FILE"

    # Build proper Android DTBO table image using mkdtboimg.py
    if [[ -f "scripts/mkdtboimg.py" && -d "$K_DTBO_DIR" ]]; then
        echo "--- Creating Android DTBO table image ---"
        python3 scripts/mkdtboimg.py create "$OUT_DIR/arch/arm64/boot/dtbo.img" --page_size=4096 \
            "$K_DTBO_DIR/kona-instantnoodle-overlay.dtbo" \
            "$K_DTBO_DIR/kona-instantnoodlep-overlay.dtbo" \
            "$K_DTBO_DIR/kona-kebab-overlay.dtbo" \
            "$K_DTBO_DIR/kona-lemonades-overlay.dtbo" 2>&1 | tee -a "$LOG_FILE" || true
    fi

    # Build and install modules if any are enabled as =m
    if grep -q "=m" out/.config; then
        make -j$(nproc) O=out \
            ARCH=arm64 \
            SUBARCH=arm64 \
            CC="ccache clang" \
            LD=ld.lld \
            AR=llvm-ar \
            NM=llvm-nm \
            OBJCOPY=llvm-objcopy \
            OBJDUMP=llvm-objdump \
            STRIP=llvm-strip \
            CROSS_COMPILE=aarch64-linux-gnu- \
            CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
            LLVM=1 LLVM_IAS=1 \
            INSTALL_MOD_PATH="$MODULES_OUT" \
            INSTALL_MOD_STRIP=1 \
            modules modules_install \
            2>&1 | tee -a "$LOG_FILE" || true
    fi
}

zipbuild() {
    local TARGET="$1"
    local DEVICE="$2"
    local DTBO="$3"

    if [[ ! -d "$AK3_DIR" ]]; then
        echo "--- AnyKernel3 directory not found at $AK3_DIR. Skipping zip packaging. ---"
        return 0
    fi

    cd "$AK3_DIR"

    DEVICE_NAME="${DEVICE_NAME_MAP[$DEVICE]:-$DEVICE}"
    ZIP_NAME="Kernel-${DEVICE_NAME}-${BRANCH}-${COMMIT_HASH}-$(date "+%y%m%d-%H%M").zip"

    # Clean old artifacts in AK3
    rm -rf Image Image.gz dtb dtbo.img modules/vendor/lib/modules/*.ko "${TARGET}"*

    # Copy Kernel Image (SM8250 / Kona bootloader requires uncompressed Image)
    if [[ -f "$K_IMG" ]]; then
        cp "$K_IMG" "$AK3_DIR/Image"
    elif [[ -f "$K_IMG_GZ" ]]; then
        cp "$K_IMG_GZ" "$AK3_DIR/Image.gz"
    fi

    # Copy DTB (Snapdragon 865 Kona Base DTB)
    if [[ -f "$OUT_DIR/arch/arm64/boot/dts/vendor/oplus/kona-v2.1.dtb" ]]; then
        cp "$OUT_DIR/arch/arm64/boot/dts/vendor/oplus/kona-v2.1.dtb" "$AK3_DIR/dtb"
    elif [[ -f "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/kona-v2.1.dtb" ]]; then
        cp "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/kona-v2.1.dtb" "$AK3_DIR/dtb"
    elif [[ -f "$OUT_DIR/arch/arm64/boot/dts/vendor/oplus/kona.dtb" ]]; then
        cp "$OUT_DIR/arch/arm64/boot/dts/vendor/oplus/kona.dtb" "$AK3_DIR/dtb"
    elif [[ -f "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/kona.dtb" ]]; then
        cp "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/kona.dtb" "$AK3_DIR/dtb"
    fi

    # Copy Target DTBO (Proper Android DTBO image)
    if [[ -f "$OUT_DIR/arch/arm64/boot/dtbo.img" ]]; then
        cp "$OUT_DIR/arch/arm64/boot/dtbo.img" "$AK3_DIR/dtbo.img"
    elif [[ -f "$K_DTBO_DIR/$DTBO" ]]; then
        python3 "$KERNEL_DIR/scripts/mkdtboimg.py" create "$AK3_DIR/dtbo.img" --page_size=4096 "$K_DTBO_DIR/$DTBO" 2>/dev/null || true
    fi

    # Copy Kernel Modules if any exist
    if [[ -d "$MODULES_OUT/lib/modules" ]]; then
        mkdir -p "$AK3_DIR/modules/vendor/lib/modules"
        find "$MODULES_OUT/lib/modules" -name "*.ko" -exec cp {} "$AK3_DIR/modules/vendor/lib/modules/" \;
    fi

    # Update AnyKernel3 device name
    sed -i "/devicename=/c\devicename=${DEVICE}" "$AK3_DIR/anykernel.sh" 2>/dev/null || true

    zip -r9 "$OUT_DIR/$ZIP_NAME" * -x "*.git*" "README.md" "*.zip" 2>/dev/null || true
    cd "$KERNEL_DIR"
    ZIPS+=("$OUT_DIR/$ZIP_NAME")
}

build_device() {
    local TARGET="$1"
    local DEFCONFIG="$2"
    local DTBO="$3"
    local DEVICE="$4"

    echo "========================================================"
    echo "  Building OnePlus SM8250 Kernel: $TARGET ($DEVICE)"
    echo "  Version:   Linux $KERNEL_VERSION"
    echo "  Toolchain: $TC"
    echo "  Branch:    $BRANCH ($COMMIT_HASH)"
    echo "========================================================"

    rm -rf out/arch/arm64/boot "$MODULES_OUT"

    # Configure defconfig fragments using kernel's merge_config.sh
    echo "--- Merging defconfig fragments: $DEFCONFIG ---"
    CONFIG_PATHS=()
    for cfg in $DEFCONFIG; do
        if [[ -f "arch/arm64/configs/$cfg" ]]; then
            CONFIG_PATHS+=("arch/arm64/configs/$cfg")
        elif [[ -f "$cfg" ]]; then
            CONFIG_PATHS+=("$cfg")
        fi
    done

    ARCH=arm64 ./scripts/kconfig/merge_config.sh -m -O out "${CONFIG_PATHS[@]}" 2>&1 | tee -a "$LOG_FILE"
    make -j$(nproc) O=out \
        ARCH=arm64 \
        SUBARCH=arm64 \
        CC="ccache clang" \
        LD=ld.lld \
        AR=llvm-ar \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
        LLVM=1 LLVM_IAS=1 \
        olddefconfig 2>&1 | tee -a "$LOG_FILE"

    # Compile kernel and DTBs
    compilebuild

    if [[ ! -f "$K_IMG" && ! -f "$K_IMG_GZ" ]]; then
        echo "--- ! Kernel Image compilation failed ! ---"
        return 1
    fi

    echo "--- Kernel Image successfully built ---"

    zipbuild "$TARGET" "$DEVICE" "$DTBO"
    return 0
}

# Main Execution
mkdir -p "$OUT_DIR"
rm -f "$LOG_FILE"

FAIL=0
START_TIME=$(date +%s)

for i in "${!TARGETS[@]}"; do
    if ! build_device "${TARGETS[$i]}" "${DEFCONFIGS[$i]}" "${DTBOS[$i]}" "${DEVICES[$i]}"; then
        send_msg "<b>OnePlus SM8250 Build Failed</b>%0A<b>Branch:</b> <code>$BRANCH</code>%0A<b>Device:</b> <code>${DEVICES[$i]}</code>"
        send_file "$LOG_FILE"
        echo "--- ! Failed to build ${TARGETS[$i]} kernel ! ---"
        FAIL=1
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [[ $FAIL -eq 0 ]]; then
    echo "========================================================"
    echo "  Build completed successfully in $((DURATION / 60))m $((DURATION % 60))s"
    echo "========================================================"
    
    for zip in "${ZIPS[@]}"; do
        if [[ -f "$zip" ]]; then
            MD5_SUM=$(md5sum "$zip" | awk '{print $1}')
            ZIP_BASENAME=$(basename "$zip")
            echo "--- Packaged: $ZIP_BASENAME (MD5: $MD5_SUM) ---"

            MSG="<b>OnePlus SM8250 Kernel Build Success</b>%0A"
            MSG+="<b>Device:</b> <code>$BRANCH</code>%0A"
            MSG+="<b>Kernel:</b> <code>$KERNEL_VERSION</code>%0A"
            MSG+="<b>Toolchain:</b> <code>$TC</code>%0A"
            MSG+="<b>Commit:</b> <code>$COMMIT_HASH</code>%0A"
            MSG+="<b>Time:</b> $((DURATION / 60))m $((DURATION % 60))s%0A"
            MSG+="<b>MD5:</b> <code>$MD5_SUM</code>"
            send_msg "$MSG"
            send_file "$zip"
        fi
    done

    if [[ "$*" == *changelog* ]]; then
        send_changelog "$CHANGELOG_FILE"
    fi
fi

if which ccache >/dev/null 2>&1; then
    echo "======== CCache Stats =========="
    ccache -s 2>/dev/null || true
    echo "================================"
fi

exit $FAIL
