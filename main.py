import sys
from PyQt6.QtWidgets import QApplication
from PyQt6.QtGui import QIcon
from cli import parse_args, run_cli
from gui.main_window import MainWindow

def main():
    # Filtra argumentos vazios que possam vir de scripts de inicialização
    clean_args = [arg for arg in sys.argv[1:] if arg.strip()]

    # Se flags de linha de comando foram passadas, executa modo CLI headless
    if clean_args:
        args = parse_args(clean_args)
        sys.exit(run_cli(args))

    # Caso contrário, inicia a interface gráfica PyQt6
    app = QApplication(sys.argv)
    app.setApplicationName("PyRAMMap")
    app.setStyle("Fusion")

    window = MainWindow()
    window.show()

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

