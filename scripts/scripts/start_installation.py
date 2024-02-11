import importlib.util
import os
import pkgutil
import subprocess
from time import sleep


def check_root():
    return os.geteuid() == 0


# Verificar si pip se encuentra instalado en el sistema
def check_pip_installed():
    pip_installed = pkgutil.find_loader('pip') is not None
    return pip_installed


# Instalar pip
def install_pip():
    try:
        update = ['apt', 'update']
        pip = ['apt', 'install', '-y', 'python3-pip']
        if not check_root():
            update.insert(0,'sudo')
            pip.insert(0,'sudo')
        subprocess.check_call(update)
        subprocess.check_call(pip)

        print("Pip se ha instalado correctamente.")
    except subprocess.CalledProcessError:
        print("Ha ocurrido un error al intentar instalar Pip.")


# Verificar si un paquete de python3 esta instalado
def check_package_installed(package_name):
    spec = importlib.util.find_spec(package_name)
    return spec is not None


# Instala el paquete package_name si no lo encuentra en el sistema
def install_package(package_name):
    try:
        subprocess.check_call(['pip', 'install', package_name])
        print(f"El paquete {package_name} se ha instalado correctamente.")
    except subprocess.CalledProcessError:
        print(f"Ha ocurrido un error al intentar instalar el paquete {package_name}.")


def install_mysql():
    try:
        # subprocess.check_call(['pip', 'install', package_name])
        console.print(f"[bold cyan]Se procederá a instalar mysql")

        mysql = ['apt', 'install', '-y', 'mysql-server']

        if not check_root():
            mysql.insert(0,'sudo')

        console.print(f"[bold yellow]{mysql}")
        subprocess.check_call(mysql)

    except subprocess.CalledProcessError:
        print(f"Ha ocurrido un error al intentar instalar mysql")


def install_php():
    try:
        console.print(f"[bold cyan]Se procederá a instalar php y sus dependencias")

        dependencies = ['apt', 'install', '-y', 'lsb-release', 'gnupg2', 'ca-certificates', 'apt-transport-https', 'software-properties-common']
        ppa = ['add-apt-repository', '-y', 'ppa:ondrej/php']
        php = [ 'apt', 'install', '-y', 'php8.2', 'php8.2-bcmath', 'php8.2-fpm', 'php8.2-xml', 'php8.2-mysql', 'php8.2-zip',
               'php8.2-intl', 'php8.2-ldap', 'php8.2-gd', 'php8.2-cli', 'php8.2-bz2', 'php8.2-curl', 'php8.2-mbstring',
               'php8.2-pgsql', 'php8.2-opcache', 'php8.2-soap', 'php8.2-cgi'
               ]
        move_composer_bin = ['mv', 'composer.phar', '/usr/local/bin/composer']

        # Agrego el elemento sudo al comienzo del comando
        if not check_root():
            dependencies.insert(0,'sudo')
            ppa.insert(0,'sudo')
            php.insert(0,'sudo')
            move_composer_bin.insert(0,'sudo')

        console.print(f"[bold yellow]{dependencies}")
        subprocess.check_call(dependencies)

        console.print(f"[bold yellow]{ppa}")
        subprocess.check_call(ppa)

        console.print(f"[bold yellow]{php}")
        subprocess.check_call(php)

        # Instalar Composer
        console.print(f"[bold cyan]Se procederá a instalar Composer")
        expected_checksum = subprocess.run(['php', '-r', f'copy("https://composer.github.io/installer.sig", "php://stdout");'], capture_output=True, text=True).stdout.strip()
        subprocess.run(['php', '-r', f'copy("https://getcomposer.org/installer", "composer-setup.php");'])
        actual_checksum = subprocess.run(['php', '-r', f'echo hash_file("sha384", "composer-setup.php");'], capture_output=True, text=True).stdout.strip()

        console.print(f"esperado: {expected_checksum}")
        console.print(f"actual: {actual_checksum}")
        if expected_checksum != actual_checksum:
            print(f'[bold red]ERROR: El checksum no coincide', file=os.sys.stderr)
            os.remove('composer-setup.php')
            exit(1)

        subprocess.run(['php', 'composer-setup.php', '--quiet'])
        os.remove('composer-setup.php')
        subprocess.run(move_composer_bin)


    except subprocess.CalledProcessError:
        print(f"Ha ocurrido un error al intentar instalar php y sus dependencias")


def install_texlive():
    try:
        console.print(f"[bold cyan]Se procederá a instalar texlive y sus dependencias")
        tex = ['apt', 'install', '-y', 'texlive-latex-extra']

        if not check_root():
            tex.insert(0,'sudo')

        console.print(f"[bold yellow]{tex}")
        subprocess.check_call(tex)

    except subprocess.CalledProcessError:
        print(f"Ha ocurrido un error al intentar instalar texlive y sus dependencias")


def install_node():
    try:
        package_name = "requests"
        if not check_package_installed(package_name):
            print(f"El paquete {package_name} no está instalado en tu sistema. Se procederá a instalarlo.")
            install_package(package_name)

        import requests
        console.print(f"[bold cyan]Se procederá a instalar node y sus dependencias")

        response = requests.get('https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh')
        install_script = response.text

        # Ejecutar el script de instalación como un script de shell
        subprocess.run(['bash', '-c', install_script])

    except subprocess.CalledProcessError:
        print(f"Ha ocurrido un error al intentar instalar node y sus dependencias")


def install_plantuml():
    try:
        console.print(f"[bold cyan]Se procederá a instalar plantuml y sus dependencias")
        puml = ['apt', 'install', '-y', 'graphviz', 'plantuml']

        if not check_root():
            puml.insert(0,'sudo')

        console.print(f"[bold yellow]{puml}")
        subprocess.check_call(puml)

    except subprocess.CalledProcessError:
        print(f"Ha ocurrido un error al intentar instalar plantuml y sus dependencias")


def install_python():
    try:
        console.print(f"[bold cyan]Se procederá a instalar python3 y sus dependencias")
        python = ['apt', 'install', '-y', 'python3', 'python3-all', 'python3-neovim', 'python3-venv', 'python3-django']

        if not check_root():
            python.insert(0,'sudo')

        console.print(f"[bold yellow]{python}")
        subprocess.check_call(python)

    except subprocess.CalledProcessError:
        print(f"Ha ocurrido un error al intentar instalar python3 y sus dependencias")


# Se ejecuta solo si este script es el principal
if __name__ == "__main__":
    if not check_pip_installed():
        print("Pip no está instalado en tu sistema. Se procederá a instalarlo.")
        install_pip()

    package_name = "rich"
    if not check_package_installed(package_name):
        print(f"El paquete {package_name} no está instalado en tu sistema. Se procederá a instalarlo.")
        install_package(package_name)

    package_name = "inquirer"
    if not check_package_installed(package_name):
        print(f"El paquete {package_name} no está instalado en tu sistema. Se procederá a instalarlo.")
        install_package(package_name)

    from rich.console import Console
    import inquirer

    subprocess.check_call(['clear'])
    console = Console()
    questions = [
        inquirer.Checkbox(
            "instalar",
            message="¿Qué es lo que deseas instalar en tu sistema? (para seleccionar presionando la tecla ESPACIO y confirmar con la tecla ENTER)",
            choices=[
                "mysql",
                "node",
                "php",
                "plantuml",
                "python",
                "texlive",
            ],
            default=["php", "python", "mysql"],
        ),
    ]

    answers = inquirer.prompt(questions)
    if answers:
        tasks_environment = answers['instalar']
        # console.print(tasks_environment)
    else:
        tasks_environment = []

    with console.status("[bold green]Trabajando en las tareas seleccionadas...", spinner='monkey') as status:
        while tasks_environment:
            enviroment = tasks_environment.pop(0)

            if(enviroment == 'mysql'):
                install_mysql()

            if(enviroment == 'node'):
                install_node()

            if(enviroment == 'php'):
                install_php()

            if(enviroment == 'plantuml'):
                install_plantuml()

            if(enviroment == 'python'):
                install_python()

            if(enviroment == 'texlive'):
                install_texlive()
