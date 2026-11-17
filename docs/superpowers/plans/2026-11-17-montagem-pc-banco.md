# Projeto A3 Banco de Dados — "Montagem de PC" — Plano de Implementação

> **Para quem vai implementar:** este plano é feito para ser executado **pelo grupo com apoio do tutor**, tarefa a tarefa, porque o PDF zera o trabalho se for todo feito por IA e o professor pode pedir alteração de código ao vivo. **Não** despache para um subagente autônomo. Os passos usam checkbox (`- [ ]`) para acompanhamento.

**Goal:** Construir um banco PostgreSQL (Supabase) de montagem de PC, alimentado por scraping de memórias RAM, com API CRUD (FastAPI) e protótipo (Streamlit).

**Architecture:** 5 camadas — Scraping (existente) → Ingestão (Python) → Postgres/Supabase → API FastAPI (SQL explícito via psycopg2) → Protótipo Streamlit. SQL fica visível em arquivos `.sql` e é aplicado no banco via MCP do Supabase; a aplicação conecta via connection string.

**Tech Stack:** PostgreSQL (Supabase), Python 3.11+, FastAPI, psycopg2-binary, Pydantic v2, Streamlit, python-dotenv, Selenium (scraping já existente), pytest.

## Global Constraints

- Banco: **PostgreSQL** (projeto Supabase `hgzrpvnxuqeanlilidod`).
- Nomenclatura de tabelas: prefixo **`tb_`**, snake_case.
- Toda tabela tem **CRUD** (GET/POST/PUT/DELETE) na API. São **13 tabelas**.
- Coluna `tb_produto.origem` ∈ {`'scraping'`, `'ficticio'`} (CHECK).
- Chave natural de produto = `link` (UNIQUE) → ingestão idempotente.
- Segredos (`DATABASE_URL`) em `.env`, **nunca** commitados. `.env.example` sem segredo.
- API usa **SQL explícito (psycopg2)**, sem ORM. Sem usar a API auto-gerada do Supabase.
- Diretório de trabalho raiz do projeto: `Banco de dados/`.

---

## Estrutura de arquivos

```
Banco de dados/
  database/
    schema.sql        # DDL — CREATE TABLE das 13 tabelas + ALTER + índices
    seed.sql          # DML — carga fictícia (categorias, lojas, plataformas, etc.)
    consultas.sql     # DQL — 5 consultas com JOIN/agregação
  ingestao/
    importar_ram.py   # scraping de RAM → banco (idempotente)
  api/
    db.py             # conexão psycopg2 + helpers de query/transação
    repo.py           # repositório genérico (listar/obter/criar/atualizar/excluir)
    modelos.py        # schemas Pydantic por recurso
    rotas_factory.py  # factory que gera routers CRUD padrão
    rotas_especiais.py# routers de tabelas com PK composta/subtipo
    main.py           # app FastAPI, inclui todos os routers
  prototipo/
    app.py            # Streamlit (CRUD data-driven + tela de relatório)
  tests/
    test_api.py       # pytest de caminho-feliz e validação
  docs/
    der.md            # diagrama DER em Mermaid (fonte) + instrução de export
  .env.example
  .gitignore
  requirements.txt
  README.md
```

---

## Fase 0 — Setup

### Task 0.1: Estrutura, dependências e segredos

**Files:**
- Create: `requirements.txt`, `.env.example`, `.gitignore`, `README.md`
- Create (pastas vazias): `database/`, `ingestao/`, `api/`, `prototipo/`, `tests/`, `docs/`

- [ ] **Step 1: Criar `requirements.txt`**

```
fastapi==0.115.*
uvicorn[standard]==0.32.*
psycopg2-binary==2.9.*
pydantic==2.*
python-dotenv==1.*
streamlit==1.40.*
requests==2.*
pytest==8.*
httpx==0.27.*
```
(Selenium já está no `requirements.txt` do projeto de Qualidade; a ingestão o reutiliza.)

- [ ] **Step 2: Criar `.env.example`**

```
# Connection string do Supabase (Project Settings -> Database -> Connection string -> URI)
# Use o "Session pooler" ou "Direct connection".
DATABASE_URL=postgresql://postgres.hgzrpvnxuqeanlilidod:SUA_SENHA@HOST.pooler.supabase.com:5432/postgres
# Base da API para o protótipo
API_BASE=http://localhost:8000
```

- [ ] **Step 3: Criar `.gitignore`**

```
.env
__pycache__/
*.pyc
.pytest_cache/
.venv/
```

- [ ] **Step 4: Criar `README.md`** com seções: visão geral, como rodar (`pip install -r requirements.txt`, criar `.env`, aplicar `database/schema.sql`, `uvicorn api.main:app --reload`, `streamlit run prototipo/app.py`). Escrever em prosa curta própria do grupo.

- [ ] **Step 5: Instalar dependências e verificar**

Run: `pip install -r requirements.txt`
Expected: instala sem erro. `python -c "import fastapi, psycopg2, streamlit; print('ok')"` imprime `ok`.

- [ ] **Step 6: Commit**

```bash
git add "Banco de dados/requirements.txt" "Banco de dados/.env.example" "Banco de dados/.gitignore" "Banco de dados/README.md"
git commit -m "chore: setup do projeto de banco (deps, env, gitignore, readme)"
```

---

## Fase 1 — Banco de dados (DDL, DML, DQL)

> O SQL é escrito nos arquivos `.sql` **e** aplicado no Supabase via MCP (`apply_migration` para DDL, `execute_sql` para seed/consultas). Antes de criar, o tutor roda `list_tables` para confirmar o estado inicial.

### Task 1.1: DDL — schema das 13 tabelas

**Files:**
- Create: `database/schema.sql`

- [ ] **Step 1: Escrever `database/schema.sql`**

```sql
-- =========================================================
-- Projeto A3 Banco de Dados — Montagem de PC — DDL
-- =========================================================

DROP TABLE IF EXISTS tb_item_build, tb_build, tb_usuario, tb_coleta, tb_loja,
  tb_compatibilidade, tb_plataforma, tb_placa_de_video, tb_processador,
  tb_memoria_ram, tb_produto, tb_categoria, tb_marca CASCADE;

CREATE TABLE tb_marca (
  id_marca   SERIAL PRIMARY KEY,
  nome       VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE tb_categoria (
  id_categoria SERIAL PRIMARY KEY,
  nome         VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE tb_produto (
  id_produto   SERIAL PRIMARY KEY,
  nome         VARCHAR(255) NOT NULL,
  preco        NUMERIC(10,2),
  link         VARCHAR(500) UNIQUE,
  origem       VARCHAR(10) NOT NULL DEFAULT 'ficticio'
               CHECK (origem IN ('scraping','ficticio')),
  id_categoria INT NOT NULL REFERENCES tb_categoria(id_categoria),
  id_marca     INT REFERENCES tb_marca(id_marca),
  criado_em    TIMESTAMP NOT NULL DEFAULT now()
);

-- Especialização 1–1 (subtipos de produto)
CREATE TABLE tb_memoria_ram (
  id_produto     INT PRIMARY KEY REFERENCES tb_produto(id_produto) ON DELETE CASCADE,
  capacidade_gb  INT,
  frequencia_mhz INT,
  tipo_ddr       VARCHAR(10),
  para_notebook  BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE tb_processador (
  id_produto INT PRIMARY KEY REFERENCES tb_produto(id_produto) ON DELETE CASCADE,
  socket     VARCHAR(20),
  nucleos    INT,
  clock_ghz  NUMERIC(4,2)
);

CREATE TABLE tb_placa_de_video (
  id_produto INT PRIMARY KEY REFERENCES tb_produto(id_produto) ON DELETE CASCADE,
  vram_gb    INT,
  tdp_watts  INT
);

-- Compatibilidade (N–N)
CREATE TABLE tb_plataforma (
  id_plataforma SERIAL PRIMARY KEY,
  nome          VARCHAR(80) NOT NULL,
  socket        VARCHAR(20),
  tipo_ram      VARCHAR(10)
);

CREATE TABLE tb_compatibilidade (
  id_produto    INT NOT NULL REFERENCES tb_produto(id_produto) ON DELETE CASCADE,
  id_plataforma INT NOT NULL REFERENCES tb_plataforma(id_plataforma) ON DELETE CASCADE,
  PRIMARY KEY (id_produto, id_plataforma)
);

-- Histórico de preços
CREATE TABLE tb_loja (
  id_loja SERIAL PRIMARY KEY,
  nome    VARCHAR(80) NOT NULL,
  url     VARCHAR(255)
);

CREATE TABLE tb_coleta (
  id_coleta   SERIAL PRIMARY KEY,
  id_produto  INT NOT NULL REFERENCES tb_produto(id_produto) ON DELETE CASCADE,
  id_loja     INT NOT NULL REFERENCES tb_loja(id_loja),
  preco       NUMERIC(10,2) NOT NULL,
  coletado_em TIMESTAMP NOT NULL DEFAULT now()
);

-- Builds (N–N com produto)
CREATE TABLE tb_usuario (
  id_usuario SERIAL PRIMARY KEY,
  nome       VARCHAR(120) NOT NULL,
  email      VARCHAR(160) NOT NULL UNIQUE
);

CREATE TABLE tb_build (
  id_build   SERIAL PRIMARY KEY,
  nome       VARCHAR(120) NOT NULL,
  id_usuario INT NOT NULL REFERENCES tb_usuario(id_usuario) ON DELETE CASCADE,
  criado_em  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE tb_item_build (
  id_build   INT NOT NULL REFERENCES tb_build(id_build) ON DELETE CASCADE,
  id_produto INT NOT NULL REFERENCES tb_produto(id_produto),
  quantidade INT NOT NULL DEFAULT 1 CHECK (quantidade > 0),
  PRIMARY KEY (id_build, id_produto)
);

-- Demonstração de ALTER TABLE (exigido no PDF): coluna de status lógico
ALTER TABLE tb_produto ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT true;

-- Índices para consultas frequentes
CREATE INDEX idx_produto_categoria ON tb_produto(id_categoria);
CREATE INDEX idx_coleta_produto    ON tb_coleta(id_produto);
```

- [ ] **Step 2: Aplicar no Supabase via MCP**

O tutor executa `mcp__supabase__apply_migration` com `name="schema_inicial"` e o conteúdo do `schema.sql`.
Expected: sucesso sem erro.

- [ ] **Step 3: Verificar tabelas criadas**

O tutor executa `mcp__supabase__list_tables` (schema `public`).
Expected: as 13 tabelas `tb_*` aparecem, com PKs e FKs.

- [ ] **Step 4: Nota sobre RLS (Row Level Security)**

`mcp__supabase__get_advisors(type="security")` provavelmente alertará RLS desabilitada. Para este protótipo acadêmico que conecta via connection string direta, isso é aceitável. Documentar no relatório: "RLS fora de escopo; acesso controlado pela aplicação." (Opcional: habilitar policies permissivas — fora de escopo.)

- [ ] **Step 5: Commit**

```bash
git add "Banco de dados/database/schema.sql"
git commit -m "feat(db): DDL do schema de montagem de PC (13 tabelas)"
```

### Task 1.2: DML — carga fictícia (seed)

**Files:**
- Create: `database/seed.sql`

**Interfaces:**
- Produces: dados base (9 categorias, lojas, plataformas, marcas, componentes fictícios, usuários, builds) de que a API, as consultas e o protótipo dependem para demonstração.

- [ ] **Step 1: Escrever `database/seed.sql`**

```sql
-- Categorias (as 9 do domínio)
INSERT INTO tb_categoria (nome) VALUES
 ('Gabinete'), ('Placa-mãe'), ('Memória RAM'), ('Placa de vídeo'),
 ('Cooler'), ('Processador'), ('Armazenamento'), ('Fonte'), ('Fans');

-- Marcas
INSERT INTO tb_marca (nome) VALUES
 ('Kingston'), ('Corsair'), ('XPG'), ('AMD'), ('Intel'),
 ('NVIDIA'), ('Gigabyte'), ('Cooler Master');

-- Lojas
INSERT INTO tb_loja (nome, url) VALUES
 ('Kabum', 'https://www.kabum.com.br');

-- Plataformas (socket + tipo de RAM)
INSERT INTO tb_plataforma (nome, socket, tipo_ram) VALUES
 ('AMD AM4', 'AM4', 'DDR4'),
 ('AMD AM5', 'AM5', 'DDR5'),
 ('Intel LGA1700', 'LGA1700', 'DDR5');

-- Usuários
INSERT INTO tb_usuario (nome, email) VALUES
 ('Ana Souza', 'ana@exemplo.com'),
 ('Bruno Lima', 'bruno@exemplo.com');

-- Produtos fictícios (origem padrão = 'ficticio'); RAM real virá da ingestão
-- Um processador:
INSERT INTO tb_produto (nome, preco, id_categoria, id_marca)
 VALUES ('Processador AMD Ryzen 5 5600', 899.90,
   (SELECT id_categoria FROM tb_categoria WHERE nome='Processador'),
   (SELECT id_marca FROM tb_marca WHERE nome='AMD'));
INSERT INTO tb_processador (id_produto, socket, nucleos, clock_ghz)
 VALUES ((SELECT id_produto FROM tb_produto WHERE nome='Processador AMD Ryzen 5 5600'),
   'AM4', 6, 3.50);

-- Uma placa de vídeo:
INSERT INTO tb_produto (nome, preco, id_categoria, id_marca)
 VALUES ('Placa de Vídeo NVIDIA RTX 4060', 2199.00,
   (SELECT id_categoria FROM tb_categoria WHERE nome='Placa de vídeo'),
   (SELECT id_marca FROM tb_marca WHERE nome='NVIDIA'));
INSERT INTO tb_placa_de_video (id_produto, vram_gb, tdp_watts)
 VALUES ((SELECT id_produto FROM tb_produto WHERE nome='Placa de Vídeo NVIDIA RTX 4060'),
   8, 115);

-- Compatibilidade do processador AM4 com a plataforma AM4
INSERT INTO tb_compatibilidade (id_produto, id_plataforma)
 VALUES ((SELECT id_produto FROM tb_produto WHERE nome='Processador AMD Ryzen 5 5600'),
         (SELECT id_plataforma FROM tb_plataforma WHERE socket='AM4'));

-- Uma build de exemplo com os itens fictícios
INSERT INTO tb_build (nome, id_usuario)
 VALUES ('PC Gamer da Ana', (SELECT id_usuario FROM tb_usuario WHERE email='ana@exemplo.com'));
INSERT INTO tb_item_build (id_build, id_produto, quantidade) VALUES
 ((SELECT id_build FROM tb_build WHERE nome='PC Gamer da Ana'),
  (SELECT id_produto FROM tb_produto WHERE nome='Processador AMD Ryzen 5 5600'), 1),
 ((SELECT id_build FROM tb_build WHERE nome='PC Gamer da Ana'),
  (SELECT id_produto FROM tb_produto WHERE nome='Placa de Vídeo NVIDIA RTX 4060'), 1);

-- Demonstração de UPDATE e DELETE (exigido no PDF)
UPDATE tb_produto SET preco = 849.90
 WHERE nome = 'Processador AMD Ryzen 5 5600';
-- (exemplo de DELETE comentado para não apagar dado de demo)
-- DELETE FROM tb_produto WHERE id_produto = 999;
```

- [ ] **Step 2: Aplicar via MCP** (`mcp__supabase__execute_sql` com o conteúdo do seed).
Expected: linhas inseridas sem erro de FK/CHECK.

- [ ] **Step 3: Verificar** — `execute_sql`: `SELECT nome FROM tb_categoria;` retorna 9 linhas.

- [ ] **Step 4: Commit**

```bash
git add "Banco de dados/database/seed.sql"
git commit -m "feat(db): carga fictícia de homologação (seed)"
```

### Task 1.3: DQL — consultas estratégicas

**Files:**
- Create: `database/consultas.sql`

- [ ] **Step 1: Escrever `database/consultas.sql`**

```sql
-- 1) Build completa de um usuário: itens, categoria, marca e preço total
SELECT u.nome AS usuario, b.nome AS build, c.nome AS categoria,
       m.nome AS marca, p.nome AS produto, ib.quantidade,
       p.preco, (ib.quantidade * p.preco) AS subtotal
FROM tb_build b
JOIN tb_usuario u   ON u.id_usuario = b.id_usuario
JOIN tb_item_build ib ON ib.id_build = b.id_build
JOIN tb_produto p   ON p.id_produto = ib.id_produto
JOIN tb_categoria c ON c.id_categoria = p.id_categoria
LEFT JOIN tb_marca m ON m.id_marca = p.id_marca
WHERE u.email = 'ana@exemplo.com'
ORDER BY b.nome, c.nome;

-- 2) Preço total por build (agregação)
SELECT b.nome AS build, SUM(ib.quantidade * p.preco) AS total
FROM tb_build b
JOIN tb_item_build ib ON ib.id_build = b.id_build
JOIN tb_produto p ON p.id_produto = ib.id_produto
GROUP BY b.nome
ORDER BY total DESC;

-- 3) Histórico de preço de um produto (mín/máx/médio) num período
SELECT p.nome, MIN(co.preco) AS menor, MAX(co.preco) AS maior,
       ROUND(AVG(co.preco),2) AS medio, COUNT(*) AS n_coletas
FROM tb_coleta co
JOIN tb_produto p ON p.id_produto = co.id_produto
WHERE co.coletado_em >= now() - INTERVAL '90 days'
GROUP BY p.nome
ORDER BY medio DESC;

-- 4) Produtos compatíveis com uma plataforma
SELECT pl.nome AS plataforma, p.nome AS produto, cat.nome AS categoria
FROM tb_compatibilidade comp
JOIN tb_plataforma pl ON pl.id_plataforma = comp.id_plataforma
JOIN tb_produto p ON p.id_produto = comp.id_produto
JOIN tb_categoria cat ON cat.id_categoria = p.id_categoria
WHERE pl.socket = 'AM4'
ORDER BY cat.nome;

-- 5) Ranking de marcas por nº de produtos e preço médio
SELECT m.nome AS marca, COUNT(p.id_produto) AS qtd_produtos,
       ROUND(AVG(p.preco),2) AS preco_medio
FROM tb_marca m
LEFT JOIN tb_produto p ON p.id_marca = m.id_marca
GROUP BY m.nome
ORDER BY qtd_produtos DESC, preco_medio DESC;
```

- [ ] **Step 2: Rodar cada consulta via MCP** (`execute_sql`) e conferir que retornam sem erro.
Expected: consulta 1 e 2 retornam a build da Ana; consulta 5 lista marcas.

- [ ] **Step 3: Commit**

```bash
git add "Banco de dados/database/consultas.sql"
git commit -m "feat(db): consultas estratégicas (DQL com JOINs)"
```

---

## Fase 2 — Ingestão (scraping → banco)

### Task 2.1: Script de importação de RAM

**Files:**
- Create: `ingestao/importar_ram.py`
- Depende de: `pages/busca_page.py` (projeto de Qualidade) e `tb_*` já criadas.

**Interfaces:**
- Consumes: `Pagina_inicial.Pesquisar(termo)` e `.Listar(max_paginas)` → lista de dicts com `titulo, preco, link, marca, capacidade, frequencia, tipo, notebook`.
- Produces: linhas em `tb_produto` (origem='scraping'), `tb_memoria_ram`, `tb_coleta`.

- [ ] **Step 1: Escrever `ingestao/importar_ram.py`**

```python
"""Coleta memórias RAM do Kabum (scraping) e grava no banco de forma idempotente.
Regra: produto é identificado por `link` (UNIQUE). Reexecutar não duplica produto,
apenas atualiza preço e adiciona nova linha de histórico em tb_coleta.
"""
import os, re, sys
from pathlib import Path
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from selenium import webdriver

# permite importar o scraping do projeto de Qualidade
sys.path.append(str(Path(__file__).resolve().parents[2] / "Qualidade de software"))
from pages.busca_page import Pagina_inicial  # noqa: E402

load_dotenv()

def preco_para_numero(texto):
    """'R$ 199,90' -> 199.90 ; retorna None se não der para converter."""
    if not texto:
        return None
    limpo = re.sub(r"[^\d,]", "", texto).replace(",", ".")
    try:
        return float(limpo)
    except ValueError:
        return None

def id_categoria_ram(cur):
    cur.execute("SELECT id_categoria FROM tb_categoria WHERE nome = 'Memória RAM'")
    row = cur.fetchone()
    return row["id_categoria"]

def upsert_marca(cur, nome):
    if not nome:
        return None
    cur.execute(
        "INSERT INTO tb_marca (nome) VALUES (%s) "
        "ON CONFLICT (nome) DO UPDATE SET nome = EXCLUDED.nome "
        "RETURNING id_marca", (nome,))
    return cur.fetchone()["id_marca"]

def upsert_produto(cur, anuncio, id_categoria, id_marca):
    preco = preco_para_numero(anuncio.get("preco"))
    cur.execute(
        """
        INSERT INTO tb_produto (nome, preco, link, origem, id_categoria, id_marca)
        VALUES (%s, %s, %s, 'scraping', %s, %s)
        ON CONFLICT (link) DO UPDATE SET preco = EXCLUDED.preco, nome = EXCLUDED.nome
        RETURNING id_produto
        """,
        (anuncio["titulo"], preco, anuncio.get("link"), id_categoria, id_marca))
    return cur.fetchone()["id_produto"], preco

def upsert_memoria(cur, id_produto, anuncio):
    cap = int(anuncio["capacidade"]) if anuncio.get("capacidade") else None
    freq = int(anuncio["frequencia"]) if anuncio.get("frequencia") else None
    cur.execute(
        """
        INSERT INTO tb_memoria_ram (id_produto, capacidade_gb, frequencia_mhz, tipo_ddr, para_notebook)
        VALUES (%s, %s, %s, %s, %s)
        ON CONFLICT (id_produto) DO UPDATE SET
          capacidade_gb = EXCLUDED.capacidade_gb,
          frequencia_mhz = EXCLUDED.frequencia_mhz,
          tipo_ddr = EXCLUDED.tipo_ddr,
          para_notebook = EXCLUDED.para_notebook
        """,
        (id_produto, cap, freq, anuncio.get("tipo"), bool(anuncio.get("notebook"))))

def registrar_coleta(cur, id_produto, id_loja, preco):
    if preco is None:
        return
    cur.execute(
        "INSERT INTO tb_coleta (id_produto, id_loja, preco) VALUES (%s, %s, %s)",
        (id_produto, id_loja, preco))

def main(termo="Memoria ram", paginas=1):
    conn = psycopg2.connect(os.environ["DATABASE_URL"], cursor_factory=RealDictCursor)
    options = webdriver.ChromeOptions()
    options.add_argument("--disable-notifications")
    driver = webdriver.Chrome(options=options)
    inseridos = 0
    try:
        pagina = Pagina_inicial(driver)
        pagina.Pesquisar(termo)
        anuncios = pagina.Listar(paginas)
        with conn:                      # transação única
            with conn.cursor() as cur:
                id_cat = id_categoria_ram(cur)
                cur.execute("SELECT id_loja FROM tb_loja WHERE nome = 'Kabum'")
                id_loja = cur.fetchone()["id_loja"]
                for a in anuncios:
                    if not a.get("link") or not a.get("titulo"):
                        continue
                    id_marca = upsert_marca(cur, a.get("marca"))
                    id_prod, preco = upsert_produto(cur, a, id_cat, id_marca)
                    upsert_memoria(cur, id_prod, a)
                    registrar_coleta(cur, id_prod, id_loja, preco)
                    inseridos += 1
        print(f"Importados/atualizados: {inseridos} produtos de RAM")
    finally:
        driver.quit()
        conn.close()

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Rodar a ingestão**

Run: `python ingestao/importar_ram.py`
Expected: imprime "Importados/atualizados: N produtos de RAM" (N > 0).

- [ ] **Step 3: Verificar idempotência**

Rodar o script **de novo**. Depois, via MCP `execute_sql`:
`SELECT COUNT(*) FROM tb_produto WHERE origem='scraping';` → contagem **não dobra**.
`SELECT COUNT(*) FROM tb_coleta;` → **aumenta** (histórico cresce a cada execução).

- [ ] **Step 4: Commit**

```bash
git add "Banco de dados/ingestao/importar_ram.py"
git commit -m "feat(ingestao): importa RAM do scraping para o banco (idempotente)"
```

---

## Fase 3 — API (FastAPI, CRUD de todas as tabelas)

### Task 3.1: Conexão e repositório genérico

**Files:**
- Create: `api/db.py`, `api/repo.py`

**Interfaces:**
- Produces:
  - `api/db.py`: `get_conn()` → conexão psycopg2 (RealDictCursor); `query(sql, params=()) -> list[dict]`; `exec_write(sql, params=()) -> dict|None` (com commit/rollback).
  - `api/repo.py`: funções genéricas `listar(tabela) -> list[dict]`, `obter(tabela, pk, valor) -> dict|None`, `criar(tabela, dados: dict) -> dict`, `atualizar(tabela, pk, valor, dados: dict) -> dict|None`, `excluir(tabela, pk, valor) -> bool`.

- [ ] **Step 1: Escrever `api/db.py`**

```python
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()

def get_conn():
    return psycopg2.connect(os.environ["DATABASE_URL"], cursor_factory=RealDictCursor)

def query(sql, params=()):
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()

def exec_write(sql, params=()):
    """Executa INSERT/UPDATE/DELETE. Faz commit; em erro, rollback e relança."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            row = cur.fetchone() if cur.description else None
        conn.commit()
        return row
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
```

- [ ] **Step 2: Escrever `api/repo.py`**

```python
"""Repositório genérico. Monta SQL parametrizado a partir do nome da tabela,
da chave primária e de um dict de dados. Nomes de coluna vêm do código (Pydantic),
nunca do usuário final — então a interpolação de identificadores é segura."""
from api import db

def listar(tabela):
    return db.query(f"SELECT * FROM {tabela} ORDER BY 1")

def obter(tabela, pk, valor):
    rows = db.query(f"SELECT * FROM {tabela} WHERE {pk} = %s", (valor,))
    return rows[0] if rows else None

def criar(tabela, dados: dict):
    colunas = ", ".join(dados.keys())
    marcadores = ", ".join(["%s"] * len(dados))
    sql = f"INSERT INTO {tabela} ({colunas}) VALUES ({marcadores}) RETURNING *"
    return db.exec_write(sql, tuple(dados.values()))

def atualizar(tabela, pk, valor, dados: dict):
    sets = ", ".join(f"{c} = %s" for c in dados)
    sql = f"UPDATE {tabela} SET {sets} WHERE {pk} = %s RETURNING *"
    return db.exec_write(sql, (*dados.values(), valor))

def excluir(tabela, pk, valor):
    row = db.exec_write(f"DELETE FROM {tabela} WHERE {pk} = %s RETURNING {pk}", (valor,))
    return row is not None
```

- [ ] **Step 3: Teste manual rápido**

Run: `python -c "from api import repo; print(repo.listar('tb_categoria')[:2])"`
Expected: imprime 2 categorias (precisa do `.env` e do seed aplicado).

- [ ] **Step 4: Commit**

```bash
git add "Banco de dados/api/db.py" "Banco de dados/api/repo.py"
git commit -m "feat(api): conexão psycopg2 e repositório genérico"
```

### Task 3.2: Modelos Pydantic

**Files:**
- Create: `api/modelos.py`

**Interfaces:**
- Produces: um par de modelos `*Criar` / `*Atualizar` por recurso. `*Criar` tem os campos obrigatórios; `*Atualizar` os deixa opcionais. A factory (Task 3.3) usa esses modelos para validar payloads.

- [ ] **Step 1: Escrever `api/modelos.py`**

```python
from typing import Optional
from pydantic import BaseModel, EmailStr, Field

# --- Marca ---
class MarcaCriar(BaseModel):
    nome: str = Field(min_length=1, max_length=80)
class MarcaAtualizar(BaseModel):
    nome: Optional[str] = Field(default=None, max_length=80)

# --- Categoria ---
class CategoriaCriar(BaseModel):
    nome: str = Field(min_length=1, max_length=60)
class CategoriaAtualizar(BaseModel):
    nome: Optional[str] = None

# --- Produto ---
class ProdutoCriar(BaseModel):
    nome: str
    preco: Optional[float] = None
    link: Optional[str] = None
    origem: str = Field(default="ficticio", pattern="^(scraping|ficticio)$")
    id_categoria: int
    id_marca: Optional[int] = None
class ProdutoAtualizar(BaseModel):
    nome: Optional[str] = None
    preco: Optional[float] = None
    link: Optional[str] = None
    origem: Optional[str] = Field(default=None, pattern="^(scraping|ficticio)$")
    id_categoria: Optional[int] = None
    id_marca: Optional[int] = None
    ativo: Optional[bool] = None

# --- Subtipos ---
class MemoriaRamCriar(BaseModel):
    id_produto: int
    capacidade_gb: Optional[int] = None
    frequencia_mhz: Optional[int] = None
    tipo_ddr: Optional[str] = None
    para_notebook: bool = False
class MemoriaRamAtualizar(BaseModel):
    capacidade_gb: Optional[int] = None
    frequencia_mhz: Optional[int] = None
    tipo_ddr: Optional[str] = None
    para_notebook: Optional[bool] = None

class ProcessadorCriar(BaseModel):
    id_produto: int
    socket: Optional[str] = None
    nucleos: Optional[int] = None
    clock_ghz: Optional[float] = None
class ProcessadorAtualizar(BaseModel):
    socket: Optional[str] = None
    nucleos: Optional[int] = None
    clock_ghz: Optional[float] = None

class PlacaVideoCriar(BaseModel):
    id_produto: int
    vram_gb: Optional[int] = None
    tdp_watts: Optional[int] = None
class PlacaVideoAtualizar(BaseModel):
    vram_gb: Optional[int] = None
    tdp_watts: Optional[int] = None

# --- Plataforma / Loja / Usuario / Build ---
class PlataformaCriar(BaseModel):
    nome: str
    socket: Optional[str] = None
    tipo_ram: Optional[str] = None
class PlataformaAtualizar(BaseModel):
    nome: Optional[str] = None
    socket: Optional[str] = None
    tipo_ram: Optional[str] = None

class LojaCriar(BaseModel):
    nome: str
    url: Optional[str] = None
class LojaAtualizar(BaseModel):
    nome: Optional[str] = None
    url: Optional[str] = None

class UsuarioCriar(BaseModel):
    nome: str
    email: EmailStr
class UsuarioAtualizar(BaseModel):
    nome: Optional[str] = None
    email: Optional[EmailStr] = None

class BuildCriar(BaseModel):
    nome: str
    id_usuario: int
class BuildAtualizar(BaseModel):
    nome: Optional[str] = None
    id_usuario: Optional[int] = None

class ColetaCriar(BaseModel):
    id_produto: int
    id_loja: int
    preco: float
class ColetaAtualizar(BaseModel):
    preco: Optional[float] = None

# --- Associativas (PK composta) ---
class CompatibilidadeCriar(BaseModel):
    id_produto: int
    id_plataforma: int

class ItemBuildCriar(BaseModel):
    id_build: int
    id_produto: int
    quantidade: int = Field(default=1, gt=0)
class ItemBuildAtualizar(BaseModel):
    quantidade: int = Field(gt=0)
```

(`EmailStr` exige `pydantic[email]` — já coberto por `pydantic==2.*` + `email-validator`; adicione `email-validator` ao `requirements.txt` se faltar.)

- [ ] **Step 2: Verificar import**

Run: `python -c "import api.modelos; print('ok')"`
Expected: `ok` (se faltar email-validator: `pip install email-validator`, e acrescente ao requirements).

- [ ] **Step 3: Commit**

```bash
git add "Banco de dados/api/modelos.py" "Banco de dados/requirements.txt"
git commit -m "feat(api): modelos Pydantic de validação por recurso"
```

### Task 3.3: Factory de routers CRUD + recursos de PK simples

**Files:**
- Create: `api/rotas_factory.py`

**Interfaces:**
- Consumes: `api.repo`, modelos de `api.modelos`.
- Produces: `criar_router_crud(prefixo, tabela, pk, ModeloCriar, ModeloAtualizar) -> APIRouter` com GET (lista), GET/{id}, POST, PUT/{id}, DELETE/{id}, tratando 404/409.

- [ ] **Step 1: Escrever `api/rotas_factory.py`**

```python
from fastapi import APIRouter, HTTPException
import psycopg2
from api import repo

def _traduz_erro(e: Exception):
    """Violação de integridade -> 409; demais -> 500."""
    if isinstance(e, psycopg2.errors.UniqueViolation):
        return HTTPException(409, "Registro já existe (valor único duplicado).")
    if isinstance(e, psycopg2.errors.ForeignKeyViolation):
        return HTTPException(409, "Referência inválida (chave estrangeira).")
    if isinstance(e, psycopg2.errors.CheckViolation):
        return HTTPException(409, "Valor viola uma restrição (CHECK).")
    return HTTPException(500, f"Erro no banco: {e.__class__.__name__}")

def criar_router_crud(prefixo, tabela, pk, ModeloCriar, ModeloAtualizar):
    router = APIRouter(prefix=prefixo, tags=[prefixo.strip("/")])

    @router.get("")
    def listar():
        return repo.listar(tabela)

    @router.get("/{item_id}")
    def obter(item_id: int):
        item = repo.obter(tabela, pk, item_id)
        if not item:
            raise HTTPException(404, "Não encontrado.")
        return item

    @router.post("", status_code=201)
    def criar(payload: ModeloCriar):
        try:
            return repo.criar(tabela, payload.model_dump(exclude_unset=True))
        except psycopg2.Error as e:
            raise _traduz_erro(e)

    @router.put("/{item_id}")
    def atualizar(item_id: int, payload: ModeloAtualizar):
        dados = payload.model_dump(exclude_unset=True)
        if not dados:
            raise HTTPException(400, "Nada para atualizar.")
        try:
            item = repo.atualizar(tabela, pk, item_id, dados)
        except psycopg2.Error as e:
            raise _traduz_erro(e)
        if not item:
            raise HTTPException(404, "Não encontrado.")
        return item

    @router.delete("/{item_id}", status_code=204)
    def excluir(item_id: int):
        if not repo.excluir(tabela, pk, item_id):
            raise HTTPException(404, "Não encontrado.")
        return None

    return router
```

- [ ] **Step 2: Commit**

```bash
git add "Banco de dados/api/rotas_factory.py"
git commit -m "feat(api): factory de routers CRUD com tratamento de erros"
```

### Task 3.4: Routers de tabelas especiais (subtipos e PK composta)

**Files:**
- Create: `api/rotas_especiais.py`

**Interfaces:**
- Consumes: `api.repo`, `api.db`, modelos das associativas e subtipos.
- Produces: `router_memoria`, `router_processador`, `router_placa_video` (PK = `id_produto`), `router_compatibilidade`, `router_item_build` (PK composta). Incluídos no `main`.

- [ ] **Step 1: Escrever `api/rotas_especiais.py`**

```python
from fastapi import APIRouter, HTTPException
import psycopg2
from api import repo, db
from api.rotas_factory import criar_router_crud, _traduz_erro
from api import modelos as m

# Subtipos: PK = id_produto -> dá pra usar a factory (pk='id_produto')
router_memoria = criar_router_crud("/memorias", "tb_memoria_ram", "id_produto",
                                   m.MemoriaRamCriar, m.MemoriaRamAtualizar)
router_processador = criar_router_crud("/processadores", "tb_processador", "id_produto",
                                       m.ProcessadorCriar, m.ProcessadorAtualizar)
router_placa_video = criar_router_crud("/placas-video", "tb_placa_de_video", "id_produto",
                                       m.PlacaVideoCriar, m.PlacaVideoAtualizar)

# Compatibilidade: PK composta (id_produto, id_plataforma) -> sem UPDATE
router_compatibilidade = APIRouter(prefix="/compatibilidades", tags=["compatibilidades"])

@router_compatibilidade.get("")
def listar_compat():
    return repo.listar("tb_compatibilidade")

@router_compatibilidade.post("", status_code=201)
def criar_compat(payload: m.CompatibilidadeCriar):
    try:
        return repo.criar("tb_compatibilidade", payload.model_dump())
    except psycopg2.Error as e:
        raise _traduz_erro(e)

@router_compatibilidade.delete("/{id_produto}/{id_plataforma}", status_code=204)
def excluir_compat(id_produto: int, id_plataforma: int):
    row = db.exec_write(
        "DELETE FROM tb_compatibilidade WHERE id_produto=%s AND id_plataforma=%s RETURNING id_produto",
        (id_produto, id_plataforma))
    if row is None:
        raise HTTPException(404, "Não encontrado.")
    return None

# ItemBuild: PK composta (id_build, id_produto) + UPDATE de quantidade
router_item_build = APIRouter(prefix="/itens-build", tags=["itens-build"])

@router_item_build.get("")
def listar_itens():
    return repo.listar("tb_item_build")

@router_item_build.post("", status_code=201)
def criar_item(payload: m.ItemBuildCriar):
    try:
        return repo.criar("tb_item_build", payload.model_dump())
    except psycopg2.Error as e:
        raise _traduz_erro(e)

@router_item_build.put("/{id_build}/{id_produto}")
def atualizar_item(id_build: int, id_produto: int, payload: m.ItemBuildAtualizar):
    row = db.exec_write(
        "UPDATE tb_item_build SET quantidade=%s WHERE id_build=%s AND id_produto=%s RETURNING *",
        (payload.quantidade, id_build, id_produto))
    if row is None:
        raise HTTPException(404, "Não encontrado.")
    return row

@router_item_build.delete("/{id_build}/{id_produto}", status_code=204)
def excluir_item(id_build: int, id_produto: int):
    row = db.exec_write(
        "DELETE FROM tb_item_build WHERE id_build=%s AND id_produto=%s RETURNING id_build",
        (id_build, id_produto))
    if row is None:
        raise HTTPException(404, "Não encontrado.")
    return None
```

- [ ] **Step 2: Commit**

```bash
git add "Banco de dados/api/rotas_especiais.py"
git commit -m "feat(api): routers de subtipos e tabelas associativas"
```

### Task 3.5: App principal + endpoint de relatório (DQL)

**Files:**
- Create: `api/main.py`

**Interfaces:**
- Consumes: factory + routers especiais.
- Produces: app FastAPI servindo CRUD de todas as 13 tabelas + `GET /relatorios/build/{id_build}` (JOINs).

- [ ] **Step 1: Escrever `api/main.py`**

```python
from fastapi import FastAPI, HTTPException
from api.rotas_factory import criar_router_crud
from api import rotas_especiais as esp
from api import modelos as m
from api import db

app = FastAPI(title="API Montagem de PC — A3 Banco de Dados")

# CRUD de PK simples (factory)
simples = [
    ("/marcas", "tb_marca", "id_marca", m.MarcaCriar, m.MarcaAtualizar),
    ("/categorias", "tb_categoria", "id_categoria", m.CategoriaCriar, m.CategoriaAtualizar),
    ("/produtos", "tb_produto", "id_produto", m.ProdutoCriar, m.ProdutoAtualizar),
    ("/plataformas", "tb_plataforma", "id_plataforma", m.PlataformaCriar, m.PlataformaAtualizar),
    ("/lojas", "tb_loja", "id_loja", m.LojaCriar, m.LojaAtualizar),
    ("/coletas", "tb_coleta", "id_coleta", m.ColetaCriar, m.ColetaAtualizar),
    ("/usuarios", "tb_usuario", "id_usuario", m.UsuarioCriar, m.UsuarioAtualizar),
    ("/builds", "tb_build", "id_build", m.BuildCriar, m.BuildAtualizar),
]
for args in simples:
    app.include_router(criar_router_crud(*args))

# CRUD especiais
for r in (esp.router_memoria, esp.router_processador, esp.router_placa_video,
          esp.router_compatibilidade, esp.router_item_build):
    app.include_router(r)

@app.get("/relatorios/build/{id_build}", tags=["relatorios"])
def relatorio_build(id_build: int):
    linhas = db.query(
        """
        SELECT c.nome AS categoria, m.nome AS marca, p.nome AS produto,
               ib.quantidade, p.preco, (ib.quantidade * p.preco) AS subtotal
        FROM tb_item_build ib
        JOIN tb_produto p ON p.id_produto = ib.id_produto
        JOIN tb_categoria c ON c.id_categoria = p.id_categoria
        LEFT JOIN tb_marca m ON m.id_marca = p.id_marca
        WHERE ib.id_build = %s
        ORDER BY c.nome
        """, (id_build,))
    if not linhas:
        raise HTTPException(404, "Build sem itens ou inexistente.")
    total = sum(float(l["subtotal"]) for l in linhas if l["subtotal"] is not None)
    return {"id_build": id_build, "itens": linhas, "total": total}

@app.get("/")
def raiz():
    return {"status": "ok", "docs": "/docs"}
```

- [ ] **Step 2: Subir a API**

Run: `uvicorn api.main:app --reload`
Expected: sobe em `http://localhost:8000`. Abrir `/docs` mostra todos os recursos.

- [ ] **Step 3: Teste de fumaça manual (outra aba de terminal)**

Run:
```bash
curl -s localhost:8000/categorias | head
curl -s -X POST localhost:8000/marcas -H "Content-Type: application/json" -d "{\"nome\":\"Teste SA\"}"
curl -s localhost:8000/relatorios/build/1
```
Expected: lista categorias; cria marca (201 com id); relatório da build 1 com `total`.

- [ ] **Step 4: Commit**

```bash
git add "Banco de dados/api/main.py"
git commit -m "feat(api): app principal com CRUD de 13 tabelas e relatório DQL"
```

### Task 3.6: Testes automatizados da API

**Files:**
- Create: `tests/test_api.py`

- [ ] **Step 1: Escrever `tests/test_api.py`**

```python
"""Testes de caminho-feliz e de erro usando o TestClient do FastAPI.
Requer .env com DATABASE_URL e o seed aplicado."""
from fastapi.testclient import TestClient
from api.main import app

cliente = TestClient(app)

def test_listar_categorias_retorna_as_nove():
    r = cliente.get("/categorias")
    assert r.status_code == 200
    assert len(r.json()) >= 9

def test_crud_marca_completo():
    criada = cliente.post("/marcas", json={"nome": "MarcaTesteCRUD"})
    assert criada.status_code == 201
    id_marca = criada.json()["id_marca"]

    assert cliente.get(f"/marcas/{id_marca}").status_code == 200

    alterada = cliente.put(f"/marcas/{id_marca}", json={"nome": "MarcaRenomeada"})
    assert alterada.status_code == 200
    assert alterada.json()["nome"] == "MarcaRenomeada"

    assert cliente.delete(f"/marcas/{id_marca}").status_code == 204
    assert cliente.get(f"/marcas/{id_marca}").status_code == 404

def test_obter_inexistente_404():
    assert cliente.get("/produtos/99999999").status_code == 404

def test_payload_invalido_422():
    # 'nome' ausente -> erro de validação do Pydantic
    assert cliente.post("/marcas", json={}).status_code == 422

def test_relatorio_build_tem_total():
    r = cliente.get("/relatorios/build/1")
    assert r.status_code in (200, 404)  # 200 se o seed da build existe
    if r.status_code == 200:
        assert "total" in r.json()
```

- [ ] **Step 2: Rodar os testes**

Run: `pytest tests/test_api.py -v`
Expected: todos PASS (API não precisa estar rodando — o TestClient sobe o app em memória; mas o banco precisa estar acessível via `.env`).

- [ ] **Step 3: Commit**

```bash
git add "Banco de dados/tests/test_api.py"
git commit -m "test(api): CRUD de marca, 404, validação e relatório"
```

---

## Fase 4 — Protótipo (Streamlit)

### Task 4.1: Interface CRUD + relatório

**Files:**
- Create: `prototipo/app.py`

**Interfaces:**
- Consumes: a API em `API_BASE` (`.env`).
- Produces: UI com seletor de recurso (listar/criar/excluir) + aba de relatório de build.

- [ ] **Step 1: Escrever `prototipo/app.py`**

```python
"""Protótipo Streamlit que consome a API. Objetivo: simular o CRUD (critério do PDF).
Cobre os recursos de PK simples de forma data-driven; relatório de build à parte."""
import os
import requests
import streamlit as st
from dotenv import load_dotenv

load_dotenv()
API = os.environ.get("API_BASE", "http://localhost:8000")

# recurso -> (rota, pk, campos do formulário de criação)
RECURSOS = {
    "Marcas":      ("/marcas", "id_marca", ["nome"]),
    "Categorias":  ("/categorias", "id_categoria", ["nome"]),
    "Produtos":    ("/produtos", "id_produto", ["nome", "preco", "id_categoria", "id_marca", "origem"]),
    "Plataformas": ("/plataformas", "id_plataforma", ["nome", "socket", "tipo_ram"]),
    "Lojas":       ("/lojas", "id_loja", ["nome", "url"]),
    "Usuários":    ("/usuarios", "id_usuario", ["nome", "email"]),
    "Builds":      ("/builds", "id_build", ["nome", "id_usuario"]),
}

st.set_page_config(page_title="Montagem de PC — A3 BD", layout="wide")
st.title("🖥️ Montagem de PC — Protótipo")

aba_crud, aba_rel = st.tabs(["CRUD", "Relatório de build"])

with aba_crud:
    nome_recurso = st.selectbox("Recurso", list(RECURSOS.keys()))
    rota, pk, campos = RECURSOS[nome_recurso]

    st.subheader(f"Lista — {nome_recurso}")
    try:
        dados = requests.get(f"{API}{rota}", timeout=10).json()
        st.dataframe(dados, use_container_width=True)
    except Exception as e:
        st.error(f"Falha ao listar: {e}")

    st.subheader("Criar")
    with st.form("criar"):
        valores = {c: st.text_input(c) for c in campos}
        if st.form_submit_button("Criar"):
            payload = {k: v for k, v in valores.items() if v != ""}
            # converte numéricos simples
            for num in ("preco", "id_categoria", "id_marca", "id_usuario"):
                if num in payload:
                    payload[num] = float(payload[num]) if num == "preco" else int(payload[num])
            r = requests.post(f"{API}{rota}", json=payload, timeout=10)
            if r.status_code == 201:
                st.success("Criado!"); st.rerun()
            else:
                st.error(f"{r.status_code}: {r.text}")

    st.subheader("Excluir")
    id_excluir = st.number_input("ID para excluir", min_value=1, step=1)
    if st.button("Excluir"):
        r = requests.delete(f"{API}{rota}/{int(id_excluir)}", timeout=10)
        if r.status_code == 204:
            st.success("Excluído!"); st.rerun()
        else:
            st.error(f"{r.status_code}: {r.text}")

with aba_rel:
    st.subheader("Relatório de build (JOINs)")
    id_build = st.number_input("ID da build", min_value=1, step=1, key="rel")
    if st.button("Gerar relatório"):
        r = requests.get(f"{API}/relatorios/build/{int(id_build)}", timeout=10)
        if r.status_code == 200:
            dados = r.json()
            st.dataframe(dados["itens"], use_container_width=True)
            st.metric("Total da build (R$)", f'{dados["total"]:.2f}')
        else:
            st.error(f"{r.status_code}: {r.text}")
```

- [ ] **Step 2: Rodar o protótipo (com a API no ar)**

Run (terminal 1): `uvicorn api.main:app --reload`
Run (terminal 2): `streamlit run prototipo/app.py`
Expected: abre no navegador; aba CRUD lista/cria/exclui; aba Relatório mostra itens + total da build 1.

- [ ] **Step 3: Commit**

```bash
git add "Banco de dados/prototipo/app.py"
git commit -m "feat(prototipo): Streamlit com CRUD e relatório de build"
```

---

## Fase 5 — Entregáveis (diagrama, collection, revisão final)

### Task 5.1: Diagrama DER

**Files:**
- Create: `docs/der.md`

- [ ] **Step 1: Escrever `docs/der.md`** com o diagrama em Mermaid (`erDiagram`) refletindo as 13 tabelas e relacionamentos da spec (§2). Renderizar (VS Code Mermaid, ou mermaid.live) e exportar `docs/der.png` para o relatório.

```
erDiagram
  tb_marca ||--o{ tb_produto : possui
  tb_categoria ||--o{ tb_produto : classifica
  tb_produto ||--|| tb_memoria_ram : "é (RAM)"
  tb_produto ||--|| tb_processador : "é (CPU)"
  tb_produto ||--|| tb_placa_de_video : "é (GPU)"
  tb_produto ||--o{ tb_compatibilidade : tem
  tb_plataforma ||--o{ tb_compatibilidade : aceita
  tb_produto ||--o{ tb_coleta : "tem preço"
  tb_loja ||--o{ tb_coleta : registra
  tb_usuario ||--o{ tb_build : monta
  tb_build ||--o{ tb_item_build : contém
  tb_produto ||--o{ tb_item_build : aparece
```

- [ ] **Step 2: Commit**

```bash
git add "Banco de dados/docs/der.md" "Banco de dados/docs/der.png"
git commit -m "docs: diagrama DER (Mermaid + PNG)"
```

### Task 5.2: Collection da API

**Files:**
- Create: `docs/openapi.json`

- [ ] **Step 1: Exportar o OpenAPI** (com a API no ar):

Run: `curl -s localhost:8000/openapi.json -o "docs/openapi.json"`
Expected: arquivo gerado. Documentar no README que ele importa no Postman/Insomnia (File → Import).

- [ ] **Step 2: Commit**

```bash
git add "Banco de dados/docs/openapi.json"
git commit -m "docs: collection da API (OpenAPI export)"
```

### Task 5.3: Revisão final e checklist de entrega

- [ ] **Step 1: Rodar a suíte completa** — `pytest tests/ -v` → tudo PASS.
- [ ] **Step 2: Conferir o mapa de entregas da spec (§7)**: `schema.sql`, `seed.sql`, `consultas.sql`, código `api/`, protótipo, `openapi.json`, `der.png` presentes.
- [ ] **Step 3: Conferir que `.env` NÃO foi commitado** — `git log --stat | grep -i env` não deve listar `.env` (só `.env.example`).
- [ ] **Step 4: Atualizar README** com instruções finais de execução e divisão de autoria do grupo (para o critério "Participação").

---

## Self-Review (cobertura da spec)

- **§2 Modelo de dados** → Task 1.1 (DDL 13 tabelas, specs 3/6, 2× N–N, CHECK/UNIQUE/FK). ✅
- **§2.3 Regras** → `origem` CHECK (1.1), idempotência por `link` (2.1), compatibilidade por DQL (1.3). ✅
- **§3 SQL (DDL/DML/DQL + ALTER)** → Tasks 1.1 (inclui ALTER), 1.2, 1.3. ✅
- **§4 Arquitetura** → Ingestão (2.1), API psycopg2 sem ORM (3.1–3.5), Streamlit (4.1). ✅
- **§4 CRUD todas as tabelas** → factory (3.3) + especiais (3.4) + main (3.5) cobrem as 13. ✅
- **§5 Tratamento de erros** → `_traduz_erro` 404/409, transações em `exec_write`. ✅
- **§6 Testes** → Task 3.6. ✅
- **§7 Entregáveis** → Fase 5. ✅

**Consistência de nomes:** `get_conn/query/exec_write` (db) e `listar/obter/criar/atualizar/excluir` (repo) usados consistentemente nas Tasks 3.1→3.5. Modelos `*Criar/*Atualizar` batem entre 3.2 e 3.3/3.5.

**Observação de execução:** vários passos exigem **Chrome/Selenium** (ingestão) e **acesso ao Supabase** (`.env`) — ambientes que o grupo roda localmente. Os passos de MCP (DDL/DML/DQL) são executados pelo tutor.
