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
    seq_printf(m, "{\"usage\": %lu}", cpu_usage);
    return 0;
}