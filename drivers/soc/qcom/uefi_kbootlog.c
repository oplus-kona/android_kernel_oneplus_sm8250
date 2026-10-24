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
 * The buffer is only mapped while /proc/bootloader_log is open and is copied
 * into a private snapshot, so nothing touches the firmware memory at boot.
 * The file is root only because the log can carry device identifiers.
 */

#include <linux/ctype.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/proc_fs.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/uaccess.h>

#define KBOOTLOG_MAX_SIZE	0x8000

struct kbootlog_snapshot {
	size_t len;
	char data[];
};

static phys_addr_t kbootlog_base;
static size_t kbootlog_size;

static int kbootlog_open(struct inode *inode, struct file *file)
{
	struct kbootlog_snapshot *snap;
	void __iomem *va;
	char *raw;
	size_t i, n, len;

	raw = kmalloc(kbootlog_size, GFP_KERNEL);
	if (!raw)
		return -ENOMEM;

	snap = kzalloc(sizeof(*snap) + kbootlog_size, GFP_KERNEL);
	if (!snap) {
		kfree(raw);
		return -ENOMEM;
	}

	va = ioremap(kbootlog_base, kbootlog_size);
	if (!va) {
		kfree(snap);
		kfree(raw);
		return -ENOMEM;
	}
	memcpy_fromio(raw, va, kbootlog_size);
	iounmap(va);

	/* Text log: stop at the first NUL, drop CR, hide other control bytes. */
	len = strnlen(raw, kbootlog_size);
	for (i = 0, n = 0; i < len; i++) {
		unsigned char c = raw[i];

		if (c == '\r')
			continue;
		snap->data[n++] = (isprint(c) || c == '\n' || c == '\t') ?
				  c : '?';
	}
	snap->len = n;
	kfree(raw);

	file->private_data = snap;
	return 0;
}

static ssize_t kbootlog_read(struct file *file, char __user *buf,
			     size_t count, loff_t *ppos)
{
	struct kbootlog_snapshot *snap = file->private_data;

	return simple_read_from_buffer(buf, count, ppos, snap->data, snap->len);
}

static int kbootlog_release(struct inode *inode, struct file *file)
{
	kfree(file->private_data);
	return 0;
}

static const struct file_operations kbootlog_fops = {
	.owner		= THIS_MODULE,
	.open		= kbootlog_open,
	.read		= kbootlog_read,
	.llseek		= default_llseek,
	.release	= kbootlog_release,
};

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

	if (!proc_create("bootloader_log", 0400, NULL, &kbootlog_fops)) {
		ret = -ENOMEM;
		goto out;
	}

	pr_info("kbootlog: %zu bytes at %pa exposed as /proc/bootloader_log\n",
		kbootlog_size, &kbootlog_base);
	ret = 0;
out:
	of_node_put(np);
	return ret;
}
late_initcall(kbootlog_init);
