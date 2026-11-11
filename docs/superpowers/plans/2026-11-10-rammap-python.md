# PyRAMMap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar uma versão em Python (PyRAMMap) da ferramenta Sysinternals RAMMap, com interface gráfica PyQt6 e linha de comando CLI, capaz de inspecionar a memória física do Windows e executar operações de esvaziamento (Standby list, Working sets, Modified page list, System cache).

**Architecture:** Módulos em Python puro com `ctypes` para invocar APIs nativas do Windows (`ntdll.dll`, `kernel32.dll`, `psapi.dll`, `advapi32.dll`) gerenciando privilégios de token NT e classes de sistema; `psutil` para enumeração detalhada de processos; interface em PyQt6 com abas reativas e `QThread` para evitar travamentos de interface.

**Tech Stack:** Python 3.13, ctypes, PyQt6, psutil, pytest.

**Spec:** `docs/superpowers/specs/2026-11-10-rammap-python-design.md`

## Global Constraints

- Plataforma: Windows 10/11 (64-bit).
- Sem binários C compilados externos; utilizar `ctypes` puro para integração com o kernel.
- Se o processo não estiver elevado como Administrador, o app deve funcionar em modo somente leitura e informar adequadamente ao tentar ações de esvaziamento.
- Tratamento gracioso para processos de sistema protegidos ao esvaziar working sets.

## Review Focus

1. **Tentativa de esvaziamento de memória sem privilégios de Administrador:** deve retornar `(False, "Privilégio insuficiente")` de forma clara sem crashar.
2. **Processos protegidos durante `empty_working_sets`:** falha de acesso (`ACCESS_DENIED`) em processos individuais não deve interromper o loop de esvaziamento dos demais processos.
3. **Leitura de listas de prioridade em sistemas com alta carga:** `SYSTEM_MEMORY_LIST_INFORMATION` deve calcular corretamente todas as 8 prioridades sem estourar buffer.
4. **Execução de ações pesadas na GUI:** chamada de esvaziamento ou atualização pesada deve rodar em background worker sem congelar a janela PyQt6.
5. **Comportamento CLI quando executado com flags:** retorno limpo com exit code 0 e exibição de resumo ou status das ações.

---

### Task 1: Project Setup and Windows Privileges

**Files:**
- Create: `requirements.txt`
- Create: `core/__init__.py`
- Create: `core/privileges.py`
- Test: `tests/test_privileges.py`

**Interfaces:**
- Produces:
  - `is_admin() -> bool`
  - `enable_privilege(privilege_name: str) -> bool`
  - `enable_required_privileges() -> tuple[bool, list[str]]`
  - `restart_as_admin() -> None`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_privileges.py
from core.privileges import is_admin, enable_privilege, enable_required_privileges

def test_is_admin_returns_bool():
    res = is_admin()
    assert isinstance(res, bool)

def test_enable_privilege_structure():
    # Attempting to check a standard privilege name
    res = enable_privilege("SeProfileSingleProcessPrivilege")
    assert isinstance(res, bool)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_privileges.py -v`  
Expected: FAIL with "ModuleNotFoundError: No module named 'core'"

- [ ] **Step 3: Implement `core/privileges.py`**

Implementar verificação com `shell32.IsUserAnAdmin()`, manipulação de token com `advapi32.OpenProcessToken`, `advapi32.LookupPrivilegeValueW`, e `advapi32.AdjustTokenPrivileges` para `SeProfileSingleProcessPrivilege` e `SeIncreaseQuotaPrivilege`. Implementar também `restart_as_admin()` via `shell32.ShellExecuteW` (`runas`).

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_privileges.py -v`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add requirements.txt core/__init__.py core/privileges.py tests/test_privileges.py
git commit -m "feat(core): implement windows privileges check and elevation"
```

---

### Task 2: Windows NT API Structures & Wrappers via ctypes

**Files:**
- Create: `core/memory_api.py`
- Test: `tests/test_memory_api.py`

**Interfaces:**
- Consumes: `core/privileges.py`
- Produces:
  - Enums: `SYSTEM_MEMORY_LIST_COMMAND` (MemoryEmptyWorkingSets, MemoryFlushModifiedList, MemoryPurgeStandbyList, MemoryPurgeLowPriorityStandbyList, MemoryEmptyCombineList)
  - Structs: `SYSTEM_MEMORY_LIST_INFORMATION`, `SYSTEM_FILECACHE_INFORMATION`, `MEMORYSTATUSEX`, `PERFORMANCE_INFORMATION`
  - Functions:
    - `query_system_memory_list_info() -> SYSTEM_MEMORY_LIST_INFORMATION`
    - `query_performance_info() -> PERFORMANCE_INFORMATION`
    - `query_global_memory_status() -> MEMORYSTATUSEX`
    - `set_system_memory_list(command: int) -> int`
    - `set_system_filecache(flush: bool) -> int`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_memory_api.py
from core.memory_api import (
    query_global_memory_status,
    query_performance_info,
    query_system_memory_list_info,
    SYSTEM_MEMORY_LIST_COMMAND
)

def test_query_global_memory_status():
    mem = query_global_memory_status()
    assert mem.ullTotalPhys > 0
    assert mem.ullAvailPhys > 0
    assert 0 <= mem.dwMemoryLoad <= 100

def test_query_performance_info():
    perf = query_performance_info()
    assert perf.PhysicalTotal > 0
    assert perf.PageSize > 0

def test_query_system_memory_list_info():
    info = query_system_memory_list_info()
    # Sum of counts or page counts should be non-negative
    assert info.ZeroPageCount >= 0
    assert info.FreePageCount >= 0
    assert len(info.PageCountByPriority) == 8
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_memory_api.py -v`  
Expected: FAIL with "No module named 'core.memory_api'"

- [ ] **Step 3: Implement `core/memory_api.py`**

Definir ctypes structs com `_fields_`, carregar `ntdll.dll`, `psapi.dll`, `kernel32.dll` e implementar wrappers seguros com checagem de erros.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_memory_api.py -v`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add core/memory_api.py tests/test_memory_api.py
git commit -m "feat(core): implement windows memory api ctypes bindings"
```

---

### Task 3: Memory Flushing & Purging Actions

**Files:**
- Create: `core/memory_actions.py`
- Test: `tests/test_memory_actions.py`

**Interfaces:**
- Consumes: `core/privileges.py`, `core/memory_api.py`
- Produces:
  - `empty_working_sets() -> tuple[bool, str, int]` (success, message, count_flushed)
  - `empty_system_working_set() -> tuple[bool, str]`
  - `empty_modified_page_list() -> tuple[bool, str]`
  - `empty_standby_list(priority0_only: bool = False) -> tuple[bool, str]`
  - `empty_all() -> dict[str, tuple[bool, str]]`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_memory_actions.py
from core.memory_actions import (
    empty_working_sets,
    empty_system_working_set,
    empty_modified_page_list,
    empty_standby_list,
    empty_all
)
from core.privileges import is_admin

def test_memory_actions_signatures_and_dry_run():
    # If not admin, functions must return graceful failure message, not crash
    success, msg, count = empty_working_sets()
    assert isinstance(success, bool)
    assert isinstance(msg, str)
    assert isinstance(count, int)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_memory_actions.py -v`  
Expected: FAIL with "No module named 'core.memory_actions'"

- [ ] **Step 3: Implement `core/memory_actions.py`**

Implementar as 5 ações do RAMMap. Garantir elevação dos privilégios necessários antes de disparar `NtSetSystemInformation`. Em `empty_working_sets`, iterar pelos processos (usando `psutil` ou `EnumProcesses`) e aplicar `EmptyWorkingSet`, capturando exceções por processo para ignorar protegidos sem abortar.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_memory_actions.py -v`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add core/memory_actions.py tests/test_memory_actions.py
git commit -m "feat(core): implement memory flushing and purge actions"
```

---

### Task 4: Memory Statistics & Process Collector

**Files:**
- Create: `core/memory_collector.py`
- Test: `tests/test_memory_collector.py`

**Interfaces:**
- Consumes: `core/memory_api.py`, `psutil`
- Produces:
  - `MemorySummary`: dataclass contendo total_bytes, in_use_bytes, standby_bytes, modified_bytes, free_bytes, zeroed_bytes, etc.
  - `ProcessMemoryInfo`: dataclass contendo pid, name, working_set, private_bytes, commit_bytes, paged_pool, nonpaged_pool.
  - `get_memory_summary() -> MemorySummary`
  - `get_priority_breakdown() -> list[dict[str, Any]]`
  - `get_processes_memory_list() -> list[ProcessMemoryInfo]`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_memory_collector.py
from core.memory_collector import (
    get_memory_summary,
    get_priority_breakdown,
    get_processes_memory_list
)

def test_get_memory_summary():
    summary = get_memory_summary()
    assert summary.total_bytes > 0
    assert summary.in_use_bytes > 0
    assert summary.free_bytes >= 0

def test_get_priority_breakdown():
    breakdown = get_priority_breakdown()
    assert len(breakdown) == 8
    assert breakdown[0]["priority"] == 0

def test_get_processes_memory_list():
    procs = get_processes_memory_list()
    assert len(procs) > 0
    first = procs[0]
    assert hasattr(first, "pid")
    assert hasattr(first, "name")
    assert hasattr(first, "working_set")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_memory_collector.py -v`  
Expected: FAIL with "No module named 'core.memory_collector'"

- [ ] **Step 3: Implement `core/memory_collector.py`**

Extrair métricas precisas combinando `SYSTEM_MEMORY_LIST_INFORMATION` (multiplicando contagem de páginas por tamanho de página do sistema, ex: 4096 bytes), `GlobalMemoryStatusEx` e `psutil.process_iter`.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_memory_collector.py -v`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add core/memory_collector.py tests/test_memory_collector.py
git commit -m "feat(core): implement memory and process statistics collector"
```

---

### Task 5: Command Line Interface (CLI)

**Files:**
- Create: `cli.py`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `core/memory_actions.py`, `core/memory_collector.py`, `core/privileges.py`
- Produces:
  - `parse_args(args: list[str]) -> argparse.Namespace`
  - `run_cli(args: argparse.Namespace) -> int`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_cli.py
from cli import parse_args, run_cli

def test_cli_parsing():
    args = parse_args(["--status"])
    assert args.status is True

def test_cli_status_run(capsys):
    args = parse_args(["--status"])
    code = run_cli(args)
    captured = capsys.readouterr()
    assert code == 0
    assert "Memória Física" in captured.out or "Total RAM" in captured.out
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_cli.py -v`  
Expected: FAIL with "No module named 'cli'"

- [ ] **Step 3: Implement `cli.py`**

Adicionar suporte com `argparse` para `-s/--status`, `-Ew/--empty-working-sets`, `-Es/--empty-standby`, `-E0/--empty-standby0`, `-Em/--empty-modified`, `-Ec/--empty-system-cache`, `-Ea/--empty-all`. Imprimir tabela formatada com totais em MB/GB.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_cli.py -v`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add cli.py tests/test_cli.py
git commit -m "feat(cli): implement command line interface and memory actions"
```

---

### Task 6: PyQt6 GUI Components (Tabs)

**Files:**
- Create: `gui/__init__.py`
- Create: `gui/tab_use_counts.py`
- Create: `gui/tab_processes.py`
- Create: `gui/tab_priority.py`
- Test: `tests/test_gui_tabs.py`

**Interfaces:**
- Consumes: `core/memory_collector.py`, `PyQt6.QtWidgets`
- Produces:
  - `TabUseCounts(QWidget)`: `update_data(summary: MemorySummary)`
  - `TabProcesses(QWidget)`: `update_data(processes: list[ProcessMemoryInfo])`
  - `TabPriority(QWidget)`: `update_data(priorities: list[dict[str, Any]])`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_gui_tabs.py
import pytest
from PyQt6.QtWidgets import QApplication
from gui.tab_use_counts import TabUseCounts
from gui.tab_processes import TabProcesses
from gui.tab_priority import TabPriority

@pytest.fixture(scope="session")
def qapp():
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    return app

def test_tabs_initialization(qapp):
    t1 = TabUseCounts()
    t2 = TabProcesses()
    t3 = TabPriority()
    assert t1 is not None
    assert t2 is not None
    assert t3 is not None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_gui_tabs.py -v`  
Expected: FAIL with "No module named 'gui'"

- [ ] **Step 3: Implement `gui/tab_use_counts.py`, `gui/tab_processes.py`, and `gui/tab_priority.py`**

- `tab_use_counts.py`: Barra de uso com gradiente/cores por tipo de memória e `QTableWidget` com totais (MB, GB, %).
- `tab_processes.py`: `QLineEdit` para filtro de pesquisa instantâneo, `QTableWidget` ordenável por colunas numéricas (usando itens com ordenação por valor bruto).
- `tab_priority.py`: Tabela das 8 prioridades (0 a 7) com status e volume em MB.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_gui_tabs.py -v`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add gui/__init__.py gui/tab_use_counts.py gui/tab_processes.py gui/tab_priority.py tests/test_gui_tabs.py
git commit -m "feat(gui): implement tabs for use counts, processes and priority summary"
```

---

### Task 7: Main Window Integration, Menu Actions & Application Entry Point

**Files:**
- Create: `gui/main_window.py`
- Create: `main.py`
- Test: `tests/test_main_window.py`

**Interfaces:**
- Consumes: `gui/tab_use_counts.py`, `gui/tab_processes.py`, `gui/tab_priority.py`, `core/memory_actions.py`, `core/memory_collector.py`, `core/privileges.py`, `cli.py`
- Produces:
  - `MainWindow(QMainWindow)`
  - `main()`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_main_window.py
import pytest
from PyQt6.QtWidgets import QApplication
from gui.main_window import MainWindow

@pytest.fixture(scope="session")
def qapp():
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    return app

def test_main_window_creation(qapp):
    win = MainWindow()
    assert win.windowTitle().startswith("PyRAMMap")
    assert win.tab_widget.count() == 3
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_main_window.py -v`  
Expected: FAIL with "No module named 'gui.main_window'"

- [ ] **Step 3: Implement `gui/main_window.py` and `main.py`**

- `main_window.py`: Menu bar com `File` (Refresh F5, Exit), `Empty` (Empty Working Sets, Empty System Working Set, Empty Modified Page List, Empty Standby List, Empty Priority 0 Standby List) e `Help` (About). QThread Worker para atualizações assíncronas. Diálogos informativos para resultado das ações e verificação de privilégios admin.
- `main.py`: Detecta argumentos de linha de comando; se houver flags aciona `run_cli`, caso contrário inicia a GUI `MainWindow`.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_main_window.py -v`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add gui/main_window.py main.py tests/test_main_window.py
git commit -m "feat(app): implement main window with empty actions menu and entry point"
```
