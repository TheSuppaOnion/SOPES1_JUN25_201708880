#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/sched.h>

/* Variables para mantener los valores anteriores */
static unsigned long prev_idle = 0;
static unsigned long prev_total = 0;

static int show_cpu_info(struct seq_file *m, void *v) {
    unsigned long idle = 0, total = 0;
    unsigned long delta_idle, delta_total, pct;
    
    /* Leer /proc/stat para obtener valores reales de CPU */
    struct file *f = filp_open("/proc/stat", O_RDONLY, 0);
    if (!IS_ERR(f)) {
        char buf[256];
        loff_t pos = 0;
        ssize_t n = kernel_read(f, buf, sizeof(buf) - 1, &pos);
        if (n > 0) {
            buf[n] = '\0';
            unsigned long user, nice, system, idle_time, iowait, irq, softirq, steal;
            sscanf(buf, "cpu %lu %lu %lu %lu %lu %lu %lu %lu", 
                   &user, &nice, &system, &idle_time, &iowait, &irq, &softirq, &steal);
            
            idle = idle_time + iowait;
            total = user + nice + system + idle + irq + softirq + steal;
        }
        filp_close(f, NULL);
    }
    
    /* Calcular delta entre la última lectura y ésta */
    delta_idle = idle - prev_idle;
    delta_total = total - prev_total;
    
    /* Actualizar para próxima lectura */
    prev_idle = idle;
    prev_total = total;
    
    /* Si es primera lectura, no hay delta previo */
    if (delta_total == 0)
        pct = 0;
    else
        pct = 100 - (100 * delta_idle / delta_total);
    
    seq_printf(m, "{\"porcentajeUso\": %lu}", pct);
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