#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/sched.h>
#include <linux/sched/signal.h>

static int show_process_info(struct seq_file *m, void *v) {
    struct task_struct *task;
    unsigned long total_processes = 0;
    unsigned long running_processes = 0;
    unsigned long sleeping_processes = 0;
    unsigned long zombie_processes = 0;
    unsigned long stopped_processes = 0;
    
    rcu_read_lock();
    for_each_process(task) {
        total_processes++;
        
        // Verificar si es zombie usando exit_state
        if (task->exit_state == EXIT_ZOMBIE || task->exit_state == EXIT_DEAD) {
            zombie_processes++;
        } else {
            // Solo verificar __state si no es zombie
            switch (task->__state) {
                case TASK_RUNNING:
                    running_processes++;
                    break;
                case TASK_INTERRUPTIBLE:
                case TASK_UNINTERRUPTIBLE:
                    sleeping_processes++;
                    break;
                case TASK_STOPPED:
                case TASK_TRACED:
                    stopped_processes++;
                    break;
                default:
                    sleeping_processes++;
                    break;
            }
        }
    }
    rcu_read_unlock();
    
    seq_printf(m, "{\"procesos_corriendo\": %lu, \"total_processos\": %lu, \"procesos_durmiendo\": %lu, \"procesos_zombie\": %lu, \"procesos_parados\": %lu}",
            running_processes, total_processes, sleeping_processes, zombie_processes, stopped_processes);
    
    return 0;
}

static int procesos_open(struct inode *inode, struct file *file) {
    return single_open(file, show_process_info, NULL);
}

static const struct proc_ops procesos_fops = {
    .proc_open = procesos_open,
    .proc_read = seq_read,
    .proc_lseek = seq_lseek,
    .proc_release = single_release,
};

static int __init procesos_init(void) {
    proc_create("procesos_201708880", 0, NULL, &procesos_fops);
    printk(KERN_INFO "Modulo procesos_201708880 cargado\n");
    return 0;
}

static void __exit procesos_exit(void) {
    remove_proc_entry("procesos_201708880", NULL);
    printk(KERN_INFO "Modulo procesos_201708880 descargado\n");
}

module_init(procesos_init);
module_exit(procesos_exit);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Bismarck Romero");
MODULE_DESCRIPTION("Modulo para obtener informacion de procesos del sistema");
MODULE_VERSION("1.0");