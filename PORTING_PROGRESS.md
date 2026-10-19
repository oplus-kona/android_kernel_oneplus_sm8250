# OnePlus SM8250 Kernel Porting Progress Log

> **Target Kernel:** `android_kernel_oneplus_sm8250` (OnePlus 8 / 8 Pro / 8T / 9R)  
> **Source Kernel:** `YumeMichi/kernel_xiaomi_pipa` (Xiaomi Pad 6, Linux 4.19)  
> **Porting Branch:** `port` (branched from clean `origin/lineage-24.0` at `5d98df1d1625`)  
> **Toolchain:** `Neutron-Clang` (with Clang -O3, ThinLTO, and ccache)  
> **Build Script:** `compile.sh`

---

## 📊 Summary of Completed Phases

| Phase | Description | Status | Commits Ported | Build Verification |
| :---: | :--- | :---: | :---: | :---: |
| **Phase 0** | Build Infrastructure, Clang Toolchain & Headers | ✅ **PASSED** | 9 / 9 | Verified via `headers_install` & `scripts` |
| **Phase 1** | Core ARM64 Architecture & Low-Level CPU Routines | ✅ **PASSED** | 14 / 14 | Built `Image`, `dtb`, `dtbo.img` in 1m 54s |
| **Phase 2** | Core Kernel Synchronization, IPC & Android Binder | ✅ **PASSED** | 24 / 24 | ThinLTO build in 3m 03s, AnyKernel3 zip verified |
| **Phase 3** | Qualcomm Kona / SM8250 Common SoC DTSI | ✅ **PASSED** | 2 / 3 (1 skipped) | Built `Image`, `dtb`, `dtbo.img` in 1m 51s |
| **Phase 4** | Storage, Filesystems & Block Layer | ✅ **PASSED** | 13 ported (4 base/prior, 1 skipped, 3 deferred) | Built `Image`, `dtb`, `dtbo.img` in 3m 19s |
| **Phase 5** | Memory Management: Core MM, ION, Allocators & Caches | ✅ **PASSED** | 29 ported (30 base, 8 skipped) | Built `Image`, `dtb`, `dtbo.img` in 3m 11s |
| **Phase 6** | CPU Idle Management & cpuidle Subsystem | ⏳ **PENDING** | 0 / 98 | Ready to start |
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

### Phase 2: Core Kernel Synchronization, IPC & Android Binder (24 Commits)

| Target Commit SHA | Source SHA | Author | Subject | Resolution / Notes |
| :--- | :---: | :--- | :--- | :--- |
| `cbb6a0edfb01` | `174619aa7` | Sultanxda | printk: Add sleep time to timestamps | Monotonic kmsg timestamps include suspend time. |
| `c745df35847f` | `5ee3be9b16d` | Danny Lin | printk: Add sleep time offset to all timestamps | Clean cherry-pick. |
| `3d5a4647c5a1` | `463319c80` | Park Ju Hyung | trace: add a CONFIG_DISABLE_TRACE_PRINTK option | Exposes trace_printk disabling option. |
| `66ae7d77610a` | `0fe4ace19` | Yaroslav Furman | techpack: audio: pinctrl-lpi: Initialise at late_initcall | Fixes NULL dereference when audio techpack modules are built-in. |
| `136d349a4c59` | `4da1a385e` | Tyler Nijmeh | net: Allow BPF JIT to compile without module support | Clean cherry-pick. |
| `c6a57ce06eb4` | `ce82c91bd` | Tyler Nijmeh | selinux: Allow audit to be disabled | Decouples SELinux from CONFIG_AUDIT in Kconfig. |
| `3b9a93f1a88e` | `b2dd15bd6` | Sean Du | bpf: lsm: Compile out tracing | Clean cherry-pick. |
| `ef72a3181ff8` | `47ec1acda` | Sultan Alsawaf | PM / devfreq: Make the monitor workqueue high priority | Reduces devfreq sampling jitter. |
| `a279d245c671` | `09d390c79` | Sultan Alsawaf | cpumask: Add cpumasks for big, LITTLE, and prime CPU clusters | Adds cluster topology masks. |
| `5440c81203fd` | `28cf4d7c9` | Sultan Alsawaf | msm: kgsl: Affine kgsl_3d0_irq and worker kthread to the big CPU cluster | Accelerates GPU command completion and dispatch. |
| `2ec9cfd9ff68` | `ecc0cd171` | Sultan Alsawaf | drm: Affine IRQ to the prime CPU cluster | Places display VSYNC interrupt on prime core. |
| `bd8d85544e11` | `6ab6e02e2` | Sultan Alsawaf | workqueue: Affine unbound workqueues to little CPUs by default | Battery saving: background tasks remain on silver cores. |
| `c7b7f910742c` | `50e5743a0` | Sultan Alsawaf | rcu: Run nocb kthreads on little CPUs | Moves RCU callback offloads to little cores. |
| `a9ad547494f4` | `43f60431b` | Jaskaran Singh | ANDROID: Configure out the macros in android_kabi and android_vendor | Adds CONFIG_ANDROID_KABI_RESERVE. |
| `ea60a70bf657` | `f39729602` | Danny Lin | profiling: Implement a simple task exit notifier when disabled | Lightweight fallback for task exit hooks. |
| `d973569cca1d` | `87c792a54` | NeilBrown | BACKPORT: cred: add get_cred_rcu() | Clean cherry-pick. |
| `36fafa305898` | `6a1e1c8ea` | Sean Du | binder: Checkout to android13-5.10-lts | Android 13 5.10-LTS modern Binder IPC core. |
| `1e0f41b03d1d` | `47174f3d8` | Sean Du | binderfs: Adapt fs parser API for 4.19 | Compatible filesystem parser for Linux 4.19. |
| `a432c4b88c29` | `467b56c82` | Sean Du | binder: Drop unported vendor hooks | Drops unneeded vendor hook traces. |
| `2bbebf3d8550` | `3efdacc07` | Carlos Llamas | BACKPORT: binder: use bitmap for faster descriptor lookup | Replaces linear descriptor scans with `dbitmap`. |
| `1f58b96da92b` | `475355165` | Carlos Llamas | UPSTREAM: binder: fix descriptor lookup for context manager | Context manager descriptor fix. |
| `04206788ea62` | `e4b85ae9a` | Carlos Llamas | FROMGIT: binder: fix double-free in dbitmap | Fixes potential double free bug in dbitmap. |
| `00795a1a8a03` | `37333c601` | zenzer0s | kernel: Add FAKE_UNAME support and enable CONFIG_FAKE_UNAME_5_10 | Spoofs 5.10 for Apex/Mainline modules. |
| `0f0ef40af8a4` | `fbdf3211d` | Sultan Alsawaf | kernel: Add tri-cluster API to affine IRQs and kthreads to fast CPUs | Foundational IRQ and kthread affinity API. |
| `da695ad3afa0` | `6f6502559` | Sultan Alsawaf | kernel: Extend the perf-critical API to little CPUs | Extends affinity API to `cpu_lp_mask`. |

---

### Phase 3: Qualcomm Kona / SM8250 Common SoC DTSI (3 Commits)

| Target Commit SHA | Source SHA | Author | Subject | Resolution / Notes |
| :--- | :---: | :--- | :--- | :--- |
| `639576444b0d` | `734fc07b1` | Yumi Yukimura | ARM: dts: msm: kona: Ignore SSR failure for modem | Clean cherry-pick. Prevents reboot loops on non-fatal modem subsystem restarts. |
| `12e6746f28f5` | `8c9275c3a` | Danny Lin | arm64: dts: sm8250: Disable broken IRQ detection | Adds `noirqdebug` to chosen bootargs to eliminate redundant interrupt handling overhead. |
| *Skipped* | `e7a16c5e3` | Sebastiano Barezzi | Revert "arm64: dts: vendor: qcom: Remove unused conflicting disp_rdump_memory region" | **Skipped**: In OnePlus DTS, address `0x9c000000` is already reserved for `cont_splash_region@9c000000`. Re-adding `disp_rdump_region@9c000000` creates memory collision. |

---

### Phase 4: Storage, Filesystems & Block Layer (20 Commits)

| Target Commit SHA | Source SHA | Author | Subject | Resolution / Notes |
| :--- | :---: | :--- | :--- | :--- |
| `1692baa509e5` | `0ac596d7e` | kdrag0n | block: Disable I/O stats accounting by default. | Disables overhead for unused block devices. |
| `51c108d8d01b` | `d26d11500` | celtare21 | block,cfq: Disable logging if trace is not enabled | Reduces logspam in CFQ I/O scheduler. |
| `55335dd90a25` | `d8701f7e9` | mrsrimar22 | scsi: ufs: Squash revert product changes | Reverts single_release in debugfs, restores clock scaling, removes highprio gating. |
| `6ff2ea8f92e4` | `08c3a6e42` | Sean Du | scsi: ufs: Compile out tracing | Eliminates trace overhead in UFS driver. |
| `ff094a0cfe98` | `34d9aef30` | NeilBrown | VFS: use synchronize_rcu_expedited() in namespace_unlock() | 200x speedup in unmounting filesystems during shutdown. |
| `51dc8c226f30` | `fe112b941` | Sultan Alsawaf | mbcache: Speed up cache entry creation | Eliminates hash-list scan contention in ext4 mbcache. |
| `37b72ec647af` | `681cc6913` | Christoph Hellwig | BACKPORT: fs: refactor ksys_umount | Factors out path_umount helper. |
| `c8114a91f1a8` | `fb171a761` | Christoph Hellwig | BACKPORT: fs: fix a struct path leak in path_umount | Fixes dentry and vfsmnt leaks in error cases. |
| `74bd72f598a6` | `4f7dbaf72` | Al Viro | BACKPORT: umount(2): move the flag validity checks first | Restores userspace UMOUNT_NOFOLLOW check compatibility. |
| `b1e5b3e2955e` | `07551352b` | Sultan Alsawaf | mm: Micro-optimize PID map reads for arm64 while retaining output format | 20x speedup in PID map reads for app GC. |
| `98ca9304ccf9` | `b46f748b4` | Sultan Alsawaf | mm: Fix truncated major/minor output in PID maps | Extends major/minor hex formatting precision. |
| `39998ee86c29` | `30494d998` | Sultan Alsawaf | sched: Add API to migrate the current process to a given cpumask | Ported from Phase 7 as dependency for PID map little core affinity. |
| `31701b8d5918` | `f08ced31e` | Sultan Alsawaf | mm: Perform PID map reads on the little CPU cluster | Offloads heavy procfs map formatting to little cores. |
| *Upstreamed* | `f27e49ee9` | Bart Van Assche | ANDROID: block: Improve shared tag set performance | Already in LineageOS base (`18722b1cac9f`). Skipped duplicate. |
| *Upstreamed* | `7ecf3eec0` | Yu Zhao | FROMLIST: mm: multi-gen LRU: groundwork | Already in LineageOS base (`6da1a2795d60`). Skipped duplicate. |
| *Upstreamed* | `eef128a05` | Sebastian Siewior | BACKPORT: mm: multi-gen LRU: move lru_gen_add_mm() out of IRQ-off region | Already in LineageOS base (`987e52cda24b`). Skipped duplicate. |
| *Ported Phase 2*| `6a1e1c8ea`| Sean Du | binder: Checkout to android13-5.10-lts | Already ported in Phase 2 as `36fafa305898`. |
| *Skipped* | `456df243d` | Sean Du | pstore: Reserve ramoops space for crash records | **Skipped**: Depends on hardcoded Xiaomi RAM address `0xB0000000`. OnePlus configures ramoops via devicetree. |
| *Deferred* | `8e50cab1c` | Sultan Alsawaf | kernel: Boost DDR bus for a short amount of time when zygote forks | **Deferred to Phase 7**: Depends on `devfreq_boost.h` (`51e719e82e59`). |
| *Deferred* | `5bd9a3fd7` | Sultan Alsawaf | kernel: Affine hwcomposer to big CPUs | **Deferred to Phase 7/8**: Follows zygote / devfreq boost stack. |
| *Deferred* | `53afd5ad9` | Yuan Si | kernel: Affine surfaceflinger to perf cluster | **Deferred to Phase 7/8**: Follows hwcomposer affinity stack. |

---

### Phase 5: Core Memory Management (SLUB, Page Allocator & ION Heaps) (67 Commits)

| Target Commit SHA | Source SHA | Author | Subject | Resolution / Notes |
| :--- | :---: | :--- | :--- | :--- |
| `846e8e015005` | `7231e26c4` | Isaac J. Manjarres | ion: msm: Relocate MSM ION header directly to include/uapi/linux | Relocates UAPI header cleanly. |
| `66decb3244a8` | `1c10d2fdc` | freak07 | Revert "bdi: Do not use freezable workqueue" | Clean cherry-pick. |
| `81a876cfbd65` | `344d490d1` | Minchan Kim | Revert "mm: oom: enable the sysctl_reap_mem_on_sigkill by default" | Prevents memory corruptions during SIGKILL oom reaping. |
| `4da45db06275` | `a97951b62` | Sultan Alsawaf | mm: Stop kswapd early when nothing's waiting for it to free pages | Saves CPU cycles by stopping redundant kswapd spinning. |
| `d1f26682e5d9` | `1c7fecb53` | Vinayak Menon | mm: vmpressure: scale pressure based on reclaim context | Reclaim context pressure scaling. |
| `26e091c53936` | `b469d8583` | Vinayak Menon | mm: vmpressure: account allocstalls only on higher pressures | Suppresses spurious pressure notifications on low allocations. |
| `3f2d3366c24f` | `644234741` | Sultan Alsawaf | mm: vmpressure: Don't exclude any allocation types | Includes all allocation types for accurate memory pressure signaling. |
| `441039d5274c` | `20fdc53d7` | Sultan Alsawaf | mm: vmpressure: Interpret zero scanned pages as 100% pressure | Fixes unhandled stall conditions. |
| `68e91a4d889c` | `62d3c34e0` | Sultan Alsawaf | mm: vmpressure: Don't cache the window size | Simplifies window sizing. |
| `1f45b9902b57` | `d6b1a8a7b` | Sultan Alsawaf | mm: Don't warn on page allocation failures for OOM-killed processes | Suppresses warning noise during process termination. |
| `4e0a818b1b7c` | `c44f97b53` | Sultan Alsawaf | mm: vmpressure: Ignore allocation orders above PAGE_ALLOC_COSTLY_ORDER | Prevents spurious pressure spikes from high-order allocations. |
| `2ab3d53a2863` | `936cf5e84` | Sultan Alsawaf | mm: Don't stop kswapd on a per-node basis when there are no waiters | Global kswapd wait accounting. |
| `9c6d080b5fde` | `07a9bfdd6` | Sultan Alsawaf | mm: vmpressure: Don't export tunables to userspace | Locks internal vmpressure tuning. |
| `d5a7cac80022` | `b70f88f26` | Sultan Alsawaf | mm: vmpressure: Ignore costly-order allocations for direct reclaim too | Consistently ignores costly orders across reclaim paths. |
| `e3045e51995a` | `3bbd03965` | Sultan Alsawaf | mm: vmpressure: Fix a race that would erroneously clear accumulated data | Fixes data clearing race condition. |
| `d23bdf5e9ac6` | `1185a9243` | Sultan Alsawaf | mm: vmpressure: Fix rampant inaccuracies caused by stale data usage | Restricts vmpressure tracking to active slowpath allocation failures. |
| `bb8ee4662ec1` | `2df81dc43` | Sultan Alsawaf | mm: Increment kswapd_waiters for throttled direct reclaimers | Wakes up kswapd properly when direct reclaimers are throttled. |
| `74820c663150` | `05d4ba63e` | Sultan Alsawaf | mm: Disable watermark boosting by default | Eliminates random frame drops and background app thrashing. |
| `314381d5d9c4` | `248be1868` | Anshuman Khandual | mm/tlbbatch: introduce arch_tlbbatch_should_defer() | TLB batch deferral helper. |
| `7460f3b906aa` | `d068ab9f5` | Sultan Alsawaf | mm: Move slab shrinkers into a dedicated thread called kshrinkd | Eliminates direct-reclaim slab shrinking latency from UI threads. |
| `a5620e9b8ffe` | `c8071f2d0` | Sultan Alsawaf | iommu: msm: Rewrite to improve clarity and performance | Overhauls MSM IOMMU locking, removes lock hold times. |
| `dbb21cd6ffe8` | `cd4727cfc` | Sultan Alsawaf | ion: Rewrite to improve clarity and performance | Eliminates debug locks, fine-grained locking & lockless DMA cache. |
| `56c2698a34b3` | `b633de505` | Sultan Alsawaf | ion: Remove unneeded rwsem for the heap priority list | Eliminates heap priority list rwsem lock contention. |
| `f5c6b755ce1f` | `30a8a5e0e` | Sultan Alsawaf | ion: Further optimize ioctl handler | Micro-optimizes fastpath ioctl commands. |
| `c2ca2259fac7` | `df25e5c14` | Sultan Alsawaf | ion: Restore ION_IOC_HEAP_QUERY ioctl command | Restores userspace heap query compatibility. |
| `f077bc6f1579` | `12189688a` | Sultan Alsawaf | ion: Fix partial cache maintenance operations | Fixes partial buffer range flush handling. |
| `4cc96879e565` | `7f0647e96` | Sultan Alsawaf | ashmem: Rewrite to improve clarity and performance | Strips dead debug code, replaces bloated locks with fast mutexes. |
| `b3563d87f1a6` | `eba9fbaf6` | Sean Du | usb: gadget: uvc: Avoid NULL pointer dereference after unbind | Fixes potential crash on unbind. |
| `ede349c4a891` | `342ee9dd6` | Sean Du | usb: gadget: uvc: Fix potential UAF during unbind | Fixes UAF vulnerability in USB gadget driver. |
| *Upstreamed* | `67b18e30f` – `b53ba6670` (30 commits) | Various | Multi-Gen LRU (MGLRU) full core suite & TLB batching | Already integrated in LineageOS 24.0 base. Skipped duplicate. |
| *Skipped* | `0f7697e26` | Yu Zhao | mm:vmscan:Update the page scan prioritiy | Already present in LineageOS base. Skipped duplicate. |
| *Skipped* | `fa3b2821f` – `6cc2e26c7` (7 commits) | Sean Du | Experimental MGLRU v15 refresh & followups | Skipped to preserve LineageOS's verified stable MGLRU implementation. |

---

### Configuration & Toolchain Adaptations

| Target Commit SHA | Subject | Description |
| :--- | :--- | :--- |
| `5f346a2d3705` | arm64: configs: Set LITTLE, BIG, and PRIME CPU masks for Kona | Configures `CONFIG_LITTLE_CPU_MASK=15`, `CONFIG_BIG_CPU_MASK=112`, `CONFIG_PRIME_CPU_MASK=128`. |
| `fc586bf5d61d` | msm: kgsl: Cast KGSL_DMA_BIT_MASK to unsigned int in dma_set_max_seg_size | Fixes Clang -O3 constant-conversion warning. |
| `9d613a3056f4` | arm64: configs: Enable CONFIG_THINLTO=y in oplus.config | Enables ThinLTO for 3-minute link times across 192 cores. |

---

## 📦 Verified Build Artifacts

* **Target Device:** OnePlus 8T (`kebab`)
* **Branch:** `port` (`ede349c4a891`)
* **Compile Script:** `bash compile.sh`
* **Build Time:** 3m 11s (ThinLTO enabled)
* **Status:** `Image`, `dtb`, and `dtbo.img` compiled cleanly without warnings.
* **Packaged Flashable Zip:** `zenkernel-oplus-sm8250-261020-0440.zip`
  * **MD5 Checksum:** `39097d3951a6d8c19b6d1c2876dcf76d`
