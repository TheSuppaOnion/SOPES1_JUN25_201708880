#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/sysinfo.h>
#include <linux/mm.h>

static int show_ram_info(struct seq_file *m, void *v) {
    struct sysinfo si;
    si_meminfo(&si);
    
    // Calcular valores en KB
    unsigned long total = si.totalram * 4;
    unsigned long free = si.freeram * 4;
    unsigned long buffers = si.bufferram * 4;
    
    // Leer /proc/meminfo para obtener valor de caché
    unsigned long cached = 0;
    struct file *f = filp_open("/proc/meminfo", O_RDONLY, 0);
    if (!IS_ERR(f)) {
        char buf[4096];
        loff_t pos = 0;
        ssize_t n = kernel_read(f, buf, sizeof(buf) - 1, &pos);
        if (n > 0) {
            buf[n] = '\0';
            char *cache_line = strstr(buf, "Cached:");
            if (cache_line)
                sscanf(cache_line, "Cached: %lu", &cached);
        }
        filp_close(f, NULL);
    }
    
    // Memoria usada real = total - (free + buffers + cached)
    unsigned long available = free + buffers + cached;
    unsigned long used = (total > available) ? (total - available) : 0;
    
    // Porcentaje de uso real (sin cache/buffers)
    unsigned long pct = total ? used * 100 / total : 0;
    
    seq_printf(m, "{\"total\": %lu, \"libre\": %lu, \"uso\": %lu, \"porcentajeUso\": %lu}",
            total, available, used, pct);
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