#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

int main() {
    pid_t child_pid;
    child_pid = fork();
    if (child_pid > 0) {
        // Proceso padre: duerme 60 segundos sin esperar al hijo
        sleep(60);
    } else {
        // Proceso hijo: termina inmediatamente
        exit(0);
    }
    return 0;
}