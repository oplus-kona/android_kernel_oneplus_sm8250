// SPDX-License-Identifier: GPL-2.0
/*
 * Expose the bootloader (XBL UEFI / ABL) log as /proc/bootloader_log.
 *
 * The firmware leaves its text log in a DDR buffer next to the end of the
 * UEFI region. The DT already reserves that area (node "kboot_uboot_logmem",
 * compatible "oplus,xbl_uefi_kbootlog") and gives the offset of the buffer
 * inside it ("xbluefi-offset"). The firmware memory map lists the buffer as
 * "Log Buffer", 0x8000 bytes.
 *
 * The buffer is copied once at init, right after the firmware hands over, so
 * it is the log of the boot that just started. Copying on every open() would
 * show the firmware's output of the next boot when the previous one hung.
 * The file is root only because the log can carry device identifiers.
 */

#include <linux/ctype.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/proc_fs.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/uaccess.h>

#define KBOOTLOG_MAX_SIZE	0x8000

static char *kbootlog_text;
static size_t kbootlog_len;
static phys_addr_t kbootlog_base;
static size_t kbootlog_size;
static DEFINE_MUTEX(kbootlog_lock);

static ssize_t kbootlog_read(struct file *file, char __user *buf,
			     size_t count, loff_t *ppos)
{
	ssize_t ret;

	mutex_lock(&kbootlog_lock);
	ret = simple_read_from_buffer(buf, count, ppos, kbootlog_text,
				      kbootlog_len);
	mutex_unlock(&kbootlog_lock);

	return ret;
}

static const struct file_operations kbootlog_fops = {
	.owner		= THIS_MODULE,
	.read		= kbootlog_read,
	.llseek		= default_llseek,
};

static void __init kbootlog_capture(void)
{
	void __iomem *va;
	char *raw;
	size_t i, n, len;

	raw = kmalloc(kbootlog_size, GFP_KERNEL);
	if (!raw)
		return;

	va = ioremap(kbootlog_base, kbootlog_size);
	if (!va) {
		kfree(raw);
		return;
	}
	memcpy_fromio(raw, va, kbootlog_size);
	iounmap(va);

	/* Text log: stop at the first NUL, drop CR, hide other control bytes. */
	len = strnlen(raw, kbootlog_size);
	for (i = 0, n = 0; i < len; i++) {
		unsigned char c = raw[i];

		if (c == '\r')
			continue;
		raw[n++] = (isprint(c) || c == '\n' || c == '\t') ? c : '?';
	}

	mutex_lock(&kbootlog_lock);
	kbootlog_text = raw;
	kbootlog_len = n;
	mutex_unlock(&kbootlog_lock);
}

static int __init kbootlog_init(void)
{
	struct device_node *np;
	struct resource res;
	u32 off;
	int ret;

	np = of_find_compatible_node(NULL, NULL, "oplus,xbl_uefi_kbootlog");
	if (!np)
		return -ENODEV;

	ret = of_address_to_resource(np, 0, &res);
	if (ret) {
		pr_err("kbootlog: no reg in DT node\n");
		goto out;
	}

	ret = of_property_read_u32(np, "xbluefi-offset", &off);
	if (ret) {
		pr_err("kbootlog: no xbluefi-offset in DT node\n");
		goto out;
	}

	if (off >= resource_size(&res)) {
		pr_err("kbootlog: offset 0x%x outside region\n", off);
		ret = -EINVAL;
		goto out;
	}

	kbootlog_base = res.start + off;
	kbootlog_size = min_t(size_t, KBOOTLOG_MAX_SIZE,
				    resource_size(&res) - off);

	if (!proc_create("bootloader_log", 0444, NULL, &kbootlog_fops)) {
		ret = -ENOMEM;
		goto out;
	}

	kbootlog_capture();

	pr_info("kbootlog: %zu bytes at %pa captured as /proc/bootloader_log\n",
		kbootlog_len, &kbootlog_base);
	ret = 0;
out:
	of_node_put(np);
	return ret;
}
late_initcall(kbootlog_init);
