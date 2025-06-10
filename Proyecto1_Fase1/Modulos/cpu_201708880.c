#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/sched.h>

static int show_cpu_info(struct seq_file *m, void *v) {
    unsigned long cpu_usage = 0;
    struct task_struct *task;
    for_each_process(task) {
        cpu_usage += task->stime + task->utime;
    }
    seq_printf(m, "{\"porcentajeUso\": %lu}", cpu_usage);
    return 0;
}

static int cpu_open(struct inode *inode, struct file *file) {
    return single_open(file, show_cpu_info, NULL);
}

static const struct proc_ops cpu_fops = {
    .proc_open    = cpu_open,
    .proc_read    = seq_read,
    .proc_lseek   = seq_lseek,
    .proc_release = single_release,
};

static int __init cpu_vacas_init(void) {
    proc_create("cpu_201708880", 0, NULL, &cpu_fops);
    return 0;
}

static void __exit cpu_vacas_exit(void) {
    remove_proc_entry("cpu_201708880", NULL);
}

module_init(cpu_vacas_init);
module_exit(cpu_vacas_exit);
MODULE_LICENSE("GPL");