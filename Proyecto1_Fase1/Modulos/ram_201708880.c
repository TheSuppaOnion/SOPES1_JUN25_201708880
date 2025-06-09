#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/sysinfo.h>

static int show_ram_info(struct seq_file *m, void *v) {
    struct sysinfo si;
    si_meminfo(&si);
    seq_printf(m, "{\"total\": %lu, \"free\": %lu, \"used\": %lu}", 
               si.totalram, si.freeram, si.totalram - si.freeram);
    return 0;
}

static int ram_open(struct inode *inode, struct file *file) {
    return single_open(file, show_ram_info, NULL);
}

static const struct proc_ops ram_fops = {
    .proc_open = ram_open,
    .proc_read = seq_read,
    .proc_lseek = seq_lseek,
    .proc_release = single_release,
};

static int __init ram_init(void) {
    proc_create("ram_201708880", 0, NULL, &ram_fops);
    return 0;
}

static void __exit ram_exit(void) {
    remove_proc_entry("ram_201708880", NULL);
}

module_init(ram_init);
module_exit(ram_exit);
MODULE_LICENSE("GPL");