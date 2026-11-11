# PyRAMMap

Recriação em Python puro e PyQt6 da renomada ferramenta de análise e otimização de memória do Windows **Sysinternals RAMMap** da Microsoft.

O **PyRAMMap** permite inspecionar detalhadamente como o kernel do Windows gerencia a memória física (RAM), além de disponibilizar as ações nativas do menu **Empty** para liberação de cache e conjuntos de trabalho.

---

## Recursos

- **Camada Nativa Windows NT:**
  - Consulta direta a `ntdll.dll`, `kernel32.dll`, `psapi.dll` e `advapi32.dll` via `ctypes`.
  - Leitura das contagens de páginas da classe de sistema `SystemMemoryListInformation` (classe 80) e cache de arquivos (`SystemFileCacheInformation`, classe 21).
  - Elevação e ajuste de privilégios de token do processo (`SeProfileSingleProcessPrivilege` e `SeIncreaseQuotaPrivilege`).
- **Ações do Menu Empty (Liberação de Memória):**
  - **Empty Working Sets:** Esvazia os conjuntos de trabalho de todos os processos ativos, descarregando páginas para a Standby List.
  - **Empty System Working Set:** Limpa o working set do cache de arquivos do sistema de arquivos e do kernel.
  - **Empty Modified Page List:** Grava as páginas modificadas pendentes no disco e esvazia a lista.
  - **Empty Standby List:** Expulsa todas as páginas em espera (Standby 0-7), movendo-as para as listas livre/zerada.
  - **Empty Priority 0 Standby List:** Expulsa apenas as páginas de menor prioridade da Standby List.
- **Interface Gráfica Desktop (PyQt6):**
  - **Aba Use Counts:** Tabela detalhada de tipos de alocação de RAM e barra visual segmentada de distribuição física.
  - **Aba Processes:** Lista ordenada de processos ativos com consumo de Working Set, Private Bytes, Commit e Pools, além de campo de busca/filtro instantâneo.
  - **Aba Priority Summary:** Detalhamento do volume e porcentagem de cada um dos 8 níveis de prioridade da Standby List (0 a 7).
  - **Execução Assíncrona:** Ações pesadas executadas em `QThread` mantendo a interface reativa sem congelamentos.
- **Linha de Comando (CLI Headless):**
  - Execução rápida por flags para automações e tarefas agendadas no Windows.

---

## Requisitos e Instalação

- Windows 10 ou Windows 11 (64-bit)
- Python 3.10 ou superior (testado no Python 3.13)
- Dependências Python:

```powershell
pip install -r requirements.txt
```

---

## Como Usar

### 1. Interface Gráfica (GUI)

Inicie a interface desktop:

```powershell
python main.py
```

> **Nota de Privilégios:** Para executar as ações do menu **Empty**, inicie o terminal ou PowerShell como **Administrador** ou utilize o atalho dentro do aplicativo em **File -> Reiniciar como Administrador (UAC)...**.

### 2. Linha de Comando (CLI)

O aplicativo detecta parâmetros de linha de comando automaticamente:

```powershell
# Exibir status completo da memória física no console:
python main.py --status

# Esvaziar toda a Standby List:
python main.py -Es

# Esvaziar apenas a Standby List de Prioridade 0:
python main.py -E0

# Esvaziar conjuntos de trabalho de todos os processos:
python main.py -Ew

# Esvaziar o System Working Set (cache de arquivos):
python main.py -Ec

# Descarregar a lista de páginas modificadas:
python main.py -Em

# Executar todas as opções de limpeza em sequência:
python main.py -Ea
```

---

## Testes Automatizados

A suíte de testes utiliza `pytest` e valida desde chamadas de kernel em baixo nível até a interface gráfica:

```powershell
python -m pytest -v
```

---

## Gerando Executável Independente (.exe)

Você pode compilar o PyRAMMap em um único arquivo `.exe` executável utilizando o `pyinstaller`:

```powershell
pyinstaller --noconsole --onefile --name PyRAMMap --uac-admin main.py
```

O binário final será gerado no diretório `dist/PyRAMMap.exe` com solicitação automática de elevação UAC.
