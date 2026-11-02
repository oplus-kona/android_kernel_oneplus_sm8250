// SPDX-License-Identifier: GPL-2.0
/*
 * Keep the kernel and bootloader logs on flash, so they survive a reset that
 * takes DRAM with it: a PON shutdown after a long power-button press, an XBL
 * cold reset, a hard power cycle.
 *
 * pstore/ramoops only holds the log until the next cold reset, which is the
 * one a clean install hits when the ROM hangs at boot and the user
 * power-cycles the phone. This writes the same text to a file under persist
 * every interval seconds, so a snapshot at most one interval old is already
 * on flash before anything dies, and exposes it as /proc/last_kmsg after the
 * next boot.
 *
 * Writes happen in a workqueue and never in the panic path: block IO after a
 * panic is unsafe, and the panic path is already covered by ramoops, which
 * survives panic and watchdog resets because those are warm.
 */

#include <linux/crc32.h>
#include <linux/delay.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/kmsg_dump.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/notifier.h>
#include <linux/proc_fs.h>
#include <linux/reboot.h>
#include <linux/sched.h>
#include <linux/slab.h>
#include <linux/stat.h>
#include <linux/string.h>
#include <linux/timekeeping.h>
#include <linux/utsname.h>
#include <linux/workqueue.h>

#define KLOG_DIR		"/mnt/vendor/persist/klog"
#define KLOG_NAME		"last_kmsg"
#define KLOG_MAGIC		0x4B4C4F47	/* "KLOG" */
#define KLOG_VERSION		1
#define KLOG_MAX_TEXT		(1024 * 1024)
#define KLOG_DEFAULT_INTERVAL	20

struct klog_header {
	u32 magic;
	u32 version;
	u32 text_len;
	u32 xbl_len;
	u32 crc;
	u32 reserved;
	u64 real_time;
	u64 mono_time;
	char kernel[64];
};

static char klog_name[64] = KLOG_NAME;
static int klog_interval = KLOG_DEFAULT_INTERVAL;
module_param_string(file, klog_name, sizeof(klog_name), 0644);
MODULE_PARM_DESC(file, "file name under " KLOG_DIR);
module_param_named(interval, klog_interval, int, 0644);
MODULE_PARM_DESC(interval, "seconds between snapshots, 0 disables");

static char klog_path[192];

static struct kmsg_dumper klog_dumper;
static struct delayed_work klog_work;
static DEFINE_MUTEX(klog_lock);

/* Written by the dumper, read by the workqueue. */
static char *klog_text;
static size_t klog_text_len;
static char *klog_xbl;
static size_t klog_xbl_len;
static struct klog_header klog_hdr;

/* Last snapshot, served by /proc/last_kmsg. */
static char *klog_saved;
static size_t klog_saved_len;

static void klog_dump(struct kmsg_dumper *dumper,
		      enum kmsg_dump_reason reason)
{
	size_t len = 0;

	if (reason == KMSG_DUMP_UNDEF)
		return;

	/*
	 * Runs in panic and watchdog context: no allocations, no block IO.
	 * mutex_trylock keeps a tick spinning on the logbuf from stalling a
	 * real dump; the next tick picks it up.
	 */
	if (!mutex_trylock(&klog_lock))
		return;

	if (kmsg_dump_get_buffer(dumper, true, klog_text,
				 KLOG_MAX_TEXT - 1, &len)) {
		klog_text[len] = '\0';
		klog_text_len = len;
		memset(&klog_hdr, 0, sizeof(klog_hdr));
		klog_hdr.magic = KLOG_MAGIC;
		klog_hdr.version = KLOG_VERSION;
		klog_hdr.text_len = len;
		klog_hdr.xbl_len = klog_xbl_len;
		/* Saved for the workqueue, which hashes before it writes. */
		klog_hdr.crc = 0;
		klog_hdr.real_time = ktime_get_real_seconds();
		klog_hdr.mono_time = ktime_get_seconds();
		strlcpy(klog_hdr.kernel, init_uts_ns.name.version,
			sizeof(klog_hdr.kernel));
	}
	mutex_unlock(&klog_lock);
}

/*
 * The dumper only runs on a kmsg_dump, so ask for one on every tick. With
 * printk.always_kmsg_dump=1 (already in the ROM command line) the OOPS
 * reason is accepted.
 */
static void klog_collect(void)
{
	kmsg_dump(KMSG_DUMP_OOPS);
}

/*
 * The bootloader log is read once, after kbootlog has captured it, and kept
 * in memory: it never changes for this boot and proc reads are expensive.
 */
static void klog_read_bootloader(void)
{
	struct file *f;
	loff_t pos = 0;
	ssize_t n;

	if (klog_xbl_len)
		return;

	f = filp_open("/proc/bootloader_log", O_RDONLY, 0);
	if (IS_ERR(f))
		return;

	n = kernel_read(f, klog_xbl, KLOG_MAX_TEXT / 4 - 1, &pos);
	filp_close(f, NULL);

	if (n <= 0)
		return;

	klog_xbl[n] = '\0';
	klog_xbl_len = n;
}

static ssize_t klog_write_all(struct file *f, loff_t pos,
			      const char *buf, size_t len)
{
	ssize_t done = 0;

	while (done < len) {
		ssize_t ret = kernel_write(f, buf + done, len - done, &pos);

		if (ret < 0)
			return ret;
		done += ret;
	}

	return done;
}

static void klog_flush(struct work_struct *work)
{
	struct klog_header hdr;
	struct file *f;
	char *text;
	size_t len, xbl_len;
	int ret;

	if (!klog_interval)
		return;

	text = kmalloc(KLOG_MAX_TEXT, GFP_KERNEL);
	if (!text)
		goto requeue;

	mutex_lock(&klog_lock);
	memcpy(&hdr, &klog_hdr, sizeof(hdr));
	len = klog_text_len;
	if (len) {
		memcpy(text, klog_text, len);
		hdr.crc = crc32(0, text, len);
	}
	xbl_len = klog_xbl_len;
	mutex_unlock(&klog_lock);

	if (!len || hdr.magic != KLOG_MAGIC) {
		kfree(text);
		goto requeue;
	}

	f = filp_open(klog_path, O_WRONLY | O_CREAT | O_TRUNC,
		      S_IRUSR | S_IWUSR);
	if (IS_ERR(f))
		goto out;

	ret = klog_write_all(f, 0, (const char *)&hdr, sizeof(hdr));
	if (ret == sizeof(hdr))
		ret = klog_write_all(f, ret, text, len);
	if (ret == sizeof(hdr) + len && xbl_len)
		klog_write_all(f, ret, klog_xbl, xbl_len);
	vfs_fsync(f, 0);
	filp_close(f, NULL);

	mutex_lock(&klog_lock);
	klog_saved_len = len;
	memcpy(klog_saved, text, len);
	mutex_unlock(&klog_lock);

out:
	kfree(text);
requeue:
	schedule_delayed_work(&klog_work, klog_interval * HZ);
}

static int klog_reboot_notifier(struct notifier_block *nb,
				unsigned long action, void *data)
{
	/*
	 * Last chance on a software restart or poweroff; the pstore path also
	 * dumps here, but this file is what survives a PON shutdown.
	 */
	if (action != SYS_RESTART && action != SYS_POWER_OFF &&
	    action != SYS_HALT)
		return NOTIFY_DONE;

	cancel_delayed_work_sync(&klog_work);
	klog_collect();
	klog_flush(&klog_work.work);
	cancel_delayed_work_sync(&klog_work);

	return NOTIFY_DONE;
}

static struct notifier_block klog_nb = {
	.notifier_call = klog_reboot_notifier,
};

static ssize_t klog_proc_read(struct file *file, char __user *buf,
			      size_t count, loff_t *ppos)
{
	return simple_read_from_buffer(buf, count, ppos,
				       klog_saved, klog_saved_len);
}

static int klog_proc_open(struct inode *inode, struct file *file)
{
	if (!klog_saved_len)
		return -ENODATA;

	return 0;
}

static const struct file_operations klog_proc_fops = {
	.owner	= THIS_MODULE,
	.open	= klog_proc_open,
	.read	= klog_proc_read,
	.llseek	= default_llseek,
};

static int __init klog_flush_init(void)
{
	klog_text = kzalloc(KLOG_MAX_TEXT, GFP_KERNEL);
	klog_saved = kzalloc(KLOG_MAX_TEXT, GFP_KERNEL);
	klog_xbl = kzalloc(KLOG_MAX_TEXT / 4, GFP_KERNEL);
	if (!klog_text || !klog_saved || !klog_xbl) {
		kfree(klog_text);
		kfree(klog_saved);
		kfree(klog_xbl);
		return -ENOMEM;
	}

	snprintf(klog_path, sizeof(klog_path), "%s/%s", KLOG_DIR, klog_name);

	klog_read_bootloader();

	klog_dumper.dump = klog_dump;
	if (kmsg_dump_register(&klog_dumper)) {
		pr_err("klog: failed to register dumper\n");
		return -EBUSY;
	}

	INIT_DELAYED_WORK(&klog_work, klog_flush);
	register_reboot_notifier(&klog_nb);
	proc_create("last_kmsg", S_IRUGO, NULL, &klog_proc_fops);

	pr_info("klog: flushing logs to %s every %d seconds\n",
		klog_path, klog_interval);

	/* First snapshot shortly after init, before userspace is up. */
	schedule_delayed_work(&klog_work, klog_interval * HZ);
	return 0;
}
late_initcall(klog_flush_init);
