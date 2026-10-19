# OnePlus SM8250 Kernel Porting Progress Log

> **Target Kernel:** `android_kernel_oneplus_sm8250` (OnePlus 8 / 8 Pro / 8T / 9R)  
> **Source Kernel:** `YumeMichi/kernel_xiaomi_pipa` (Xiaomi Pad 6, Linux 4.19)  
> **Porting Branch:** `port` (branched from clean `origin/lineage-24.0` at `5d98df1d1625`)  
> **Toolchain:** `Neutron-Clang` (with Clang -O3, LTO, and ccache)  
> **Build Script:** `compile.sh`

---

## 📊 Summary of Completed Phases

| Phase | Description | Status | Commits Ported | Build Verification |
| :---: | :--- | :---: | :---: | :---: |
| **Phase 0** | Build Infrastructure, Clang Toolchain & Headers | ✅ **PASSED** | 9 / 9 | Verified via `headers_install` & `scripts` |
| **Phase 1** | Core ARM64 Architecture & Low-Level CPU Routines | ✅ **PASSED** | 14 / 14 | Built `Image`, `dtb`, `dtbo.img` in 1m 54s |
| **Phase 2** | Core Kernel Synchronization, IPC & Android Binder | ⏳ **PENDING** | 0 / 23 | Ready to start |
| **Phase 3** | Qualcomm Kona / SM8250 Common SoC DTSI | ⏳ **PENDING** | 0 / 3 | Pending |
| **Phase 4** | Storage, Filesystems & Block Layer | ⏳ **PENDING** | 0 / 20 | Pending |
| **Phase 5** | Memory Management: Core MM, ION, Allocators & Caches | ⏳ **PENDING** | 0 / 67 | Pending |
| **Phase 6** | CPU Idle Management & cpuidle Subsystem | ⏳ **PENDING** | 0 / 98 | Pending |
| **Phase 7** | Scheduler (WALT / UCLAMP / Fair / RT) & CPU Frequency | ⏳ **PENDING** | 0 / 46 | Pending |
| **Phase 8** | Display & Graphics (DRM / SDE / KGSL / Panels) | ⏳ **PENDING** | 0 / 23 | Pending |
| **Phase 9** | Multimedia, Audio & Networking | ⏳ **PENDING** | 0 / 7 | Pending |
| **Phase 10**| Simple LMK & ZRAM Swap Compression Stack | ⏳ **PENDING** | 0 / 111| Pending |
| **Phase 11**| Peripheral Drivers, USB Gadget & Hardening | ⏳ **PENDING** | 0 / 20 | Pending |

---

## 🛠️ Detailed Log of Applied Commits

### Phase 0: Build Infrastructure, Clang Toolchain & Headers (9 Commits)

| Target Commit SHA | Source SHA | Category | Author | Subject | Resolution / Notes |
| :--- | :---: | :--- | :--- | :--- | :--- |
| `8a1cac10eb8f` | `04f92ef01` | Build / Blueprint | Yuan Si | Revert "headers_lib: rename Android.bp" | Resolved `.gitignore` conflict to track `Android.bp` while preserving `out/`. |
| `e87de3525635` | `881005123` | Build / Makefile | Rashed Abdel-Tawab | Makefile: Set correct techpack header install directory. | Clean cherry-pick. |
| `4f9e5a5dfe63` | `24730c423` | Toolchain / Scripts | Arnd Bergmann | scripts/unifdef: avoid constexpr keyword | Fixes C23 standard collision with `constexpr`. |
| `9ab594a2b53a` | `004c5209e` | Toolchain / Scripts | Sean Du | scripts/sortextable: Declare w2 and w8 with unused attribute | Clean cherry-pick. |
| `70adc97c9d26` | `25303caf5` | UAPI Headers | Simao Gomes Viana | scripts: headers_install: Rename sigaction definition | Prevents collision with Bionic `sigaction`. |
| `4be39b10d1f5` | `3f7862b08` | Core Kernel | Jan Beulich | kallsyms: reduce size a little on 64-bit | Reduces symbol table size on 64-bit. |
| `d520cf188852` | `ac671781e` | Android Blueprint | Omkar Chandorkar | Android.bp: Allow system to use generated kernel headers | Clean cherry-pick. |
| `446afa48fcc6` | `5f441397f` | Toolchain Optimization| Adam W. Willis | Makefile: Use O3 for Clang | Enables Clang `-O3` level kernel optimization. |
| `a09f923208cc` | `6306de9ed` | Architecture CFLAGS | Adam W. Willis | arm64: Makefile: Optimize for Kryo 585 | Passes target Kryo 585 microarchitecture tuning. |

---

### Phase 1: Core ARM64 Architecture & Low-Level CPU Routines (14 Commits)

| Target Commit SHA | Source SHA | Author | Subject | Resolution / Notes |
| :--- | :---: | :--- | :--- | :--- |
| `c6fd57cc4c00` | `416839b02` | Alexander Winkowski | arm64: cache: Set ARCH_DMA_MINALIGN to L1_CACHE_BYTES | Set alignment to 128 bytes, eliminating cache line bouncing. |
| `56ccb9dbefe4` | `e11d694c8` | Will Deacon | arm64: debug: Separate debug hooks based on target exception level | Clean cherry-pick. |
| *Upstreamed* | `a2929ff84` | Jia He | UPSTREAM: arm64: cpufeature: introduce helper cpu_has_hw_af() | Already merged in `lineage-24.0` (`fd2a90eae6db`). Skipped duplicate. |
| *Upstreamed* | `a6d350c5d` | Yu Zhao | FROMLIST: mm: x86, arm64: add arch_has_hw_pte_young() | Already merged in `lineage-24.0` via MGLRU (`ac21b7241ee5`). Skipped duplicate. |
| `a4a505c44d65` | `78520919b` | Barry Song | arm64: support batched/deferred tlb shootdown during page reclamation/migration | Batched TLB shootdown engine for arm64. |
| `acb26d1f2451` | `92e7a619d` | Yicong Yang | arm64: tlbflush: add some comments for TLB batched flushing | Clean cherry-pick. |
| `8080b3ef85a1` | `63545d887` | Ryan Roberts | arm64/mm: Close theoretical race where stale TLB entry remains valid | Clean cherry-pick. |
| `1b2754fac8a9` | `a3ec64f8e` | Ryan Roberts | mm: remove arch_flush_tlb_batched_pending() arch helper | Clean cherry-pick. |
| `2785c7c8ab3a` | `c7ea7ae5a` | Sultan Alsawaf | cpuidle: lpm-levels: Remove idle prediction feature | Resolved conflict in `lpm-levels.c`: safely stripped Qualcomm legacy idle prediction while preserving OnePlus `KLPMDEBUG` minidump recording. |
| `4fae85fdeab0` | `f529ace3e` | Sultan Alsawaf | arm64: Disable place-relative 32-bit relocations for DCE | Clean cherry-pick. |
| `c23ef36a8609` | `db2e86947` | Sultan Alsawaf | arm64: Keep alternative-instruction sections | Clean cherry-pick. |
| `cc3e2459feb5` | `c3c7b008a` | Sultan Alsawaf | arm64: Allow LD_DEAD_CODE_DATA_ELIMINATION to be selected | Exposes DCE option in Kconfig. |
| `9a1d84862c59` | `661b898cf` | Adam W. Willis | arm64: vdso: Compile vDSO at O3 with Clang | Clean cherry-pick. |
| `d1c5ab854653` | `e52426ea8` | Yuan Si | arm64: topology: Export CPU cluster ID in sysfs | Clean cherry-pick. |

---

### Additional Prerequisite & Integration Patches

| Target Commit SHA | Author | Subject | Resolution / Notes |
| :--- | :--- | :--- | :--- |
| `661ef52ee840` | Barry Song | mm/tlbbatch: rename and extend some functions | Required prerequisite for batched TLB shootdown in `mm/rmap.c`. |
| `811c405f1ffe` | Yicong Yang | mm/tlbbatch: Introduce arch_flush_tlb_batched_pending() | Required prerequisite for batched TLB shootdown. |
| `36324465e33a` | Pair Programmer | mm/rmap: Use flush_tlb_mm directly in flush_tlb_batched_pending | Resolved build conflict to align with Ryan Roberts' upstream simplification. |

---

## 📦 Verified Build Artifacts

* **Target Device:** OnePlus 8T (`kebab`)
* **Branch:** `port` (`36324465e33a`)
* **Compile Script:** `bash compile.sh`
* **Build Time:** 1m 54s (with ccache)
* **Status:** `Image`, `dtb`, and `dtbo.img` compiled cleanly without warnings.
* **Packaged Flashable Zip:** `zenkernel-oplus-sm8250-261020-0318.zip`
  * **MD5 Checksum:** `9cfe6e82ae70e23220f30cd3a9459ce0`
