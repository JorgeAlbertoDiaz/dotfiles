FROM ubuntu:22.04

# Actualizar paquetes e instalar dependencias
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    # Agrega cualquier otra dependencia que necesites

# Establecer el directorio de trabajo
WORKDIR /scripts

# Especificar el comando por defecto para ejecutar los scripts (por ejemplo, si es un script de Python)
CMD ["python3", "test.py"]
