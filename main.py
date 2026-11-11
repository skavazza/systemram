import sys
from PyQt6.QtWidgets import QApplication
from PyQt6.QtGui import QIcon
from cli import parse_args, run_cli
from gui.main_window import MainWindow

def main():
    # Se argumentos de linha de comando foram passados (além do nome do script),
    # executa no modo CLI headless sem abrir janela gráfica
    if len(sys.argv) > 1:
        args = parse_args(sys.argv[1:])
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
