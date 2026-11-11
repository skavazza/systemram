# Especificação Técnica: RAMMap Python (PyRAMMap)

**Data:** 10/11/2026  
**Status:** Aprovado para Planejamento  
**Autor:** Antigravity  

---

## 1. Visão Geral e Objetivos

O projeto **PyRAMMap** é uma implementação em Python com interface gráfica (PyQt6) e CLI da ferramenta Sysinternals **RAMMap**. O aplicativo permite:
1. **Monitoramento e Visualização da Memória Física:** Inspecionar listas de páginas do Windows NT (Ativa, Standby 0-7, Modificada, Livre, Zerada), detalhamento por processos e pools do sistema.
2. **Ações de Esvaziamento de Memória (Memory Flush/Purge):** Esvaziar conjuntos de trabalho (Working Sets), esvaziar cache de arquivos do sistema (System Working Set), descarregar lista de páginas modificadas (Modified Page List) e expurgar a lista de espera (Standby List total e Prioridade 0).
3. **Execução Dupla (GUI e CLI):** Interface gráfica visual completa com abas, além de modo CLI headless para automação por scripts e tarefas agendadas.

---

## 2. Arquitetura e Estrutura de Módulos

```
systemram/
├── core/
│   ├── __init__.py
│   ├── privileges.py         # Verificação e habilitação de privilégios NT (SeProfileSingleProcessPrivilege, etc.)
│   ├── memory_api.py         # Mapeamento ctypes para ntdll.dll, psapi.dll, kernel32.dll, advapi32.dll
│   ├── memory_actions.py     # Funções executáveis de limpeza de memória (Standby, Working Sets, etc.)
│   └── memory_collector.py   # Coleta e cálculo de estatísticas da RAM física e processos
├── gui/
│   ├── __init__.py
│   ├── main_window.py        # Janela principal PyQt6, menus 'File' e 'Empty', atalhos (F5)
│   ├── tab_use_counts.py     # Tabela de categorias de páginas e barra de distribuição gráfica
│   ├── tab_processes.py      # Tabela de processos com ordenação e campo de busca/filtro
│   └── tab_priority.py       # Tabela de detalhamento da lista Standby por prioridade (0 a 7)
├── tests/
│   ├── __init__.py
│   ├── test_privileges.py
│   └── test_memory_api.py
├── cli.py                    # Processamento de argumentos CLI e saída formatada no terminal
├── main.py                   # Ponto de entrada unificado da aplicação
└── requirements.txt          # Dependências do projeto (PyQt6, psutil)
```

---

## 3. Especificação dos Módulos do Sistema (`core/`)

### 3.1. Gerenciamento de Privilégios (`privileges.py`)
- Funções:
  - `is_admin() -> bool`: Verifica se o processo atual possui privilégios de administrador via `IsUserAnAdmin()`.
  - `enable_privilege(privilege_name: str) -> bool`: Habilita privilégios específicos no token do processo via `OpenProcessToken`, `LookupPrivilegeValueW` e `AdjustTokenPrivileges`.
  - Privilégios requeridos para operações de limpeza:
    - `SeProfileSingleProcessPrivilege` (necessário para `NtSetSystemInformation` classe 80 / listas de memória).
    - `SeIncreaseQuotaPrivilege` (necessário para manipulação de limites de cache de arquivo do sistema).
  - `restart_as_admin()`: Relança o script com elevação UAC usando `ShellExecuteExW` com verbo `runas`.

### 3.2. Mapeamento da API do Windows NT (`memory_api.py`)
- DLLs consumidas via `ctypes.WinDLL`:
  - `ntdll.dll`: `NtQuerySystemInformation`, `NtSetSystemInformation`
  - `psapi.dll`: `GetPerformanceInfo`, `EmptyWorkingSet`
  - `kernel32.dll`: `GlobalMemoryStatusEx`, `SetProcessWorkingSetSize`, `GetCurrentProcess`
  - `advapi32.dll`: `OpenProcessToken`, `LookupPrivilegeValueW`, `AdjustTokenPrivileges`
- Estruturas de dados:
  - `SYSTEM_MEMORY_LIST_COMMAND` (enumeração):
    - `MemoryEmptyWorkingSets = 0`
    - `MemoryFlushModifiedList = 1`
    - `MemoryPurgeStandbyList = 2`
    - `MemoryPurgeLowPriorityStandbyList = 3`
    - `MemoryEmptyCombineList = 4`
  - `SYSTEM_MEMORY_LIST_INFORMATION` (classe 80):
    - Contagens de páginas: `ZeroPageCount`, `FreePageCount`, `ModifiedPageCount`, `ModifiedNoWritePageCount`, `BadPageCount`, `PageCountByPriority[8]`.
  - `SYSTEM_FILECACHE_INFORMATION`:
    - Estrutura para `SystemFileCacheInformation` (classe 21) usada para liberar o System Working Set definindo `MinimumWorkingSet = -1` e `MaximumWorkingSet = -1`.
  - `PERFORMANCE_INFORMATION` e `MEMORYSTATUSEX`.

### 3.3. Ações de Esvaziamento (`memory_actions.py`)
- Funções públicas retornando `tuple[bool, str]`:
  - `empty_working_sets()`: Itera pelos processos do sistema e aplica `EmptyWorkingSet`, descarregando páginas para o standby/disco.
  - `empty_system_working_set()`: Dispara `NtSetSystemInformation(SystemFileCacheInformation, ...)` para flush do cache do kernel e sistema de arquivos.
  - `empty_modified_page_list()`: Dispara `NtSetSystemInformation(80, MemoryFlushModifiedList)` para descarregar páginas modificadas para o disco.
  - `empty_standby_list()`: Dispara `NtSetSystemInformation(80, MemoryPurgeStandbyList)` para mover páginas de standby para a lista livre/zerada.
  - `empty_priority0_standby_list()`: Dispara `NtSetSystemInformation(80, MemoryPurgeLowPriorityStandbyList)` para descartar apenas as páginas de menor prioridade de cache.

### 3.4. Coleta de Métricas (`memory_collector.py`)
- `get_memory_summary()`: Retorna métricas globais consolidadas (Total RAM, Em Uso, Disponível, Standby Total, Modificada, Livre, Zerada).
- `get_priority_breakdown()`: Retorna lista com tamanho em MB/GB de cada prioridade de 0 a 7 da lista Standby.
- `get_processes_memory_list()`: Enumera processos ativos coletando PID, Nome, Working Set Total, Private Bytes, Paged Pool e Non-Paged Pool.

---

## 4. Especificação da Interface Gráfica (`gui/`)

### 4.1. Janela Principal (`main_window.py`)
- Título: `PyRAMMap - Análise e Otimização de Memória Física`
- Menu `File`:
  - `Refresh` (Atalho: `F5`)
  - `Separador`
  - `Exit`
- Menu `Empty`:
  - `Empty Working Sets`
  - `Empty System Working Set`
  - `Empty Modified Page List`
  - `Empty Standby List`
  - `Empty Priority 0 Standby List`
- Menu `Help`:
  - `About PyRAMMap`
- Barra de Status:
  - Indicador de Privilégio: Verde `[Administrador: Ativo]` ou Amarelo `[Modo Somente Leitura - Não Elevado]`.
  - Timestamp da última leitura e contador de processos.
- Concorrência: Atualizações de dados pesados executadas em segundo plano (`QThread`), mantendo a interface 100% responsiva.

### 4.2. Abas Detalhadas
- **Aba "Use Counts":**
  - Tabela com colunas: *Tipo de Uso*, *Páginas*, *Total (MB)*, *Total (GB)*, *% do Total*.
  - Categorias: Ativa (Processos/Kernel), Standby (Cache), Modificada, Livre, Zerada, etc.
  - Barra de progresso segmentada/colorida exibindo visualmente a ocupação da RAM física.
- **Aba "Processes":**
  - Campo de busca textual rápida (filtro por nome ou PID).
  - Tabela ordenável por qualquer coluna clicando no cabeçalho.
  - Colunas: *Nome do Processo*, *PID*, *Working Set Total*, *Private Bytes*, *Commit*, *Pool Paginável*, *Pool Não-Paginável*.
- **Aba "Priority Summary":**
  - Tabela exibindo as listas Standby 0 a 7, identificando páginas de baixa prioridade (descartáveis primeiro) até alta prioridade (cache frequente).

---

## 5. Modo de Linha de Comando (`cli.py`)

O script suporta flags para execução rápida sem abrir a janela:
- `-s`, `--status`: Exibe resumo da memória no terminal em formato de tabela.
- `-Ew`, `--empty-working-sets`: Executa esvaziamento dos Working Sets.
- `-Es`, `--empty-standby`: Executa esvaziamento de toda a Standby List.
- `-E0`, `--empty-standby0`: Executa esvaziamento da Standby List Prioridade 0.
- `-Em`, `--empty-modified`: Executa flush da Modified Page List.
- `-Ec`, `--empty-system-cache`: Executa esvaziamento do System Working Set.
- `-Ea`, `--empty-all`: Executa todas as ações de limpeza em sequência.

---

## 6. Tratamento de Erros e Segurança

- Detecção graciosa de permissões insuficientes ao tentar operações do kernel sem Administrador, apresentando mensagem explicativa e botão para elevar via UAC.
- Validação de retorno das chamadas NT (verificando `NTSTATUS == 0` / `STATUS_SUCCESS`).
- Isolamento de falhas em processos individuais durante `empty_working_sets()` (processos protegidos do sistema não quebram o loop).

---

## 7. Estratégia de Testes

1. `test_privileges.py`: Teste unitário de verificação de admin e token privileges.
2. `test_memory_api.py`: Teste das estruturas ctypes e chamadas de leitura `GlobalMemoryStatusEx`, `GetPerformanceInfo` e `NtQuerySystemInformation(80)`.
3. Teste de execução CLI: `--help` e `--status`.
4. Teste de inicialização da GUI em ambiente Windows.
