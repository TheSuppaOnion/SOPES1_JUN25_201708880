# Monitor de servicios Linux - Compilacion de modulos en Ubuntu 22.04

### Instalación
```bash
sudo apt update
sudo apt install linux-headers-$(uname -r) build-essential
```

### Compilación
```bash
cd Modulos/
make
```

### Carga de Módulos
```bash
sudo insmod cpu_201708880.ko
sudo insmod ram_201708880.ko
```

### Verificación
```bash
lsmod | grep 201708880
```

### Uso
```bash
cat /proc/cpu_201708880
cat /proc/ram_201708880
```

### Descarga de Módulos
```bash
sudo rmmod cpu_201708880
sudo rmmod ram_201708880
make clean
```
