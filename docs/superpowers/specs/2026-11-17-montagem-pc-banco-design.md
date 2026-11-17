# Projeto A3 — Banco de Dados: "Montagem de PC"

**Data:** 2026-11-17
**UC:** Banco de Dados — 2026/2
**Entrega:** 28/11/2026 · **Apresentação:** 01/12/2026

---

## 1. Contexto

Um sistema de **montagem de PCs** que cataloga componentes de hardware e permite que
usuários montem *builds*, verificando compatibilidade entre peças e acompanhando a
evolução de preços no varejo.

O catálogo começa com **memórias RAM reais**, coletadas do site Kabum via *web scraping*
(reaproveitando o projeto da A3 de Qualidade de Software). Os demais componentes entram
como carga fictícia de homologação. Uma coluna `origem` em cada produto distingue dados
**coletados por scraping** (`'scraping'`) de dados **fictícios** (`'ficticio'`), permitindo
ampliar o catálogo com novos scrapings no futuro.

### Nota sobre autoria (crítico)

O PDF do projeto determina: *"Caso seja identificado que todo o trabalho tenha sido feito
por IA, a avaliação A3 será totalmente ZERADA."* Além disso, o critério *"Conhecimento sobre
o projeto"* prevê que o professor fará perguntas e **poderá pedir alterações no código-fonte
ao vivo** durante a apresentação.

Por isso este projeto é conduzido em modelo **tutor/arquiteto + aluno**: o design, a
explicação de conceitos e a revisão são colaborativos, mas o grupo escreve e compreende o
código a ponto de **defendê-lo e modificá-lo ao vivo**. Decisões de modelagem foram tomadas
pelo grupo (domínio, especialização, nomenclatura `tb_`, escopo 3/6).

---

## 2. Modelo de dados (modelagem conceitual)

### 2.1 Entidades

| Tabela | Atributos | Observação |
|---|---|---|
| `tb_marca` | `id_marca` (PK), `nome` | Kingston, Corsair, Intel, AMD… |
| `tb_categoria` | `id_categoria` (PK), `nome` | 9 categorias (dados, não tabelas) |
| `tb_produto` | `id_produto` (PK), `nome`, `preco`, `link`, `origem`, `id_categoria` (FK), `id_marca` (FK), `criado_em` | entidade central |
| `tb_memoria_ram` | `id_produto` (PK+FK), `capacidade_gb`, `frequencia_mhz`, `tipo_ddr`, `para_notebook` | especialização 1–1 (dados reais) |
| `tb_processador` | `id_produto` (PK+FK), `socket`, `nucleos`, `clock_ghz` | especialização 1–1 (fictício) |
| `tb_placa_de_video` | `id_produto` (PK+FK), `vram_gb`, `tdp_watts` | especialização 1–1 (fictício) |
| `tb_plataforma` | `id_plataforma` (PK), `nome`, `socket`, `tipo_ram` | ex.: AMD AM5 / AM5 / DDR5 |
| `tb_compatibilidade` | `id_produto` (FK), `id_plataforma` (FK) | associativa N–N |
| `tb_loja` | `id_loja` (PK), `nome`, `url` | fonte do scraping (Kabum) |
| `tb_coleta` | `id_coleta` (PK), `id_produto` (FK), `id_loja` (FK), `preco`, `coletado_em` | histórico de preços |
| `tb_usuario` | `id_usuario` (PK), `nome`, `email` | dono das builds |
| `tb_build` | `id_build` (PK), `nome`, `id_usuario` (FK), `criado_em` | uma montagem |
| `tb_item_build` | `id_build` (FK), `id_produto` (FK), `quantidade` | associativa N–N |

**Categorias (linhas em `tb_categoria`):** Gabinete, Placa-mãe, Memória RAM, Placa de vídeo,
Cooler, Processador, Armazenamento, Fonte, Fans.

**Especialização (3/6):** apenas Memória RAM, Processador e Placa de vídeo têm tabela de
specs própria agora. As outras 6 categorias existem como `tb_produto` genérico; o padrão de
especialização fica demonstrado e pode ser estendido com novos scrapings.

### 2.2 Relacionamentos e cardinalidades

```
tb_marca      1 ──< N  tb_produto
tb_categoria  1 ──< N  tb_produto
tb_produto    1 ──1    tb_memoria_ram / tb_processador / tb_placa_de_video   (especialização)
tb_produto    N >──< N tb_plataforma   via tb_compatibilidade
tb_produto    1 ──< N  tb_coleta  >── N 1  tb_loja                            (histórico de preço)
tb_usuario    1 ──< N  tb_build
tb_build      N >──< N tb_produto      via tb_item_build
```

Conceitos de BD demonstrados: **1–N**, **1–1 (especialização)**, **dois N–N com tabela
associativa**, **histórico/fato** (coleta de preços), **restrições de integridade** (PK, FK,
UNIQUE, CHECK, NOT NULL).

### 2.3 Regras de negócio relevantes

- `tb_produto.origem` aceita somente `'scraping'` ou `'ficticio'` (CHECK).
- `tb_produto.link` é único (chave natural usada para idempotência na ingestão).
- Uma **build é compatível** se todos os seus componentes compartilham ao menos uma
  plataforma em comum (verificado via DQL, não por constraint).
- Reexecutar o scraping **não duplica** produtos: atualiza o existente (match por `link`) e
  registra uma nova linha em `tb_coleta` com o preço do momento.

---

## 3. Modelagem física e SQL

Banco: **PostgreSQL** (Supabase). Entregáveis SQL executáveis:

- `database/schema.sql` — **DDL**: `CREATE TABLE` das 13 tabelas com tipos adequados,
  PK/FK, `CHECK (origem IN (...))`, `UNIQUE (link)`, `NOT NULL`. `ALTER TABLE` para
  demonstrar o comando quando aplicável.
- `database/seed.sql` — **DML**: carga inicial fictícia (categorias, lojas, plataformas,
  componentes não-RAM fictícios, usuários, builds de exemplo) + exemplos de `UPDATE`/`DELETE`.
- `database/consultas.sql` — **DQL**: consultas estratégicas com `JOIN`, por exemplo:
  1. Build completa de um usuário (itens, marca, categoria, preço total) — múltiplos JOINs.
  2. Histórico de preço de um produto (mín/máx/médio) por período.
  3. Produtos compatíveis com uma dada plataforma.
  4. Verificação de compatibilidade de uma build (plataforma comum a todos os itens).
  5. Ranking de marcas por nº de produtos / preço médio (GROUP BY + agregação).

O schema é criado e populado via **MCP do Supabase** (DDL/DML/DQL), e o mesmo SQL fica
salvo nos arquivos `.sql` para a entrega.

---

## 4. Arquitetura da aplicação

```
[1] Scraping (existente)  →  [2] Ingestão  →  [3] Supabase/Postgres  →  [4] API  →  [5] Protótipo
    busca_page.py             importar_ram.py   tb_* (schema)            FastAPI     Streamlit
```

### 4.1 Camadas

- **[2] Ingestão** (`ingestao/importar_ram.py`): reaproveita `busca_page.py`, coleta
  anúncios de RAM, resolve `tb_marca`, insere/atualiza `tb_produto` (`origem='scraping'`) +
  `tb_memoria_ram`, e grava `tb_coleta`. Idempotente por `link`.
- **[3] Banco**: Supabase PostgreSQL. Schema via MCP; aplicação conecta via **connection
  string** (`DATABASE_URL`) com `psycopg2`.
- **[4] API** (`api/`): **FastAPI** com **SQL explícito via psycopg2** (sem ORM — SQL
  visível e defensável). CRUD (GET/POST/PUT/DELETE) para **todas as 13 tabelas**. Validação
  Pydantic. Swagger automático em `/docs` serve de interface de teste e base para exportar a
  *collection* (OpenAPI → Postman).
  - *Decisão:* NÃO usar a API REST auto-gerada do Supabase — o PDF exige "desenvolver API".
- **[5] Protótipo** (`prototipo/app.py`): **Streamlit** consumindo a API. Telas de
  listar/criar/editar/excluir por recurso + uma tela de **Relatório** que dispara as DQL
  (JOINs).

### 4.2 Estrutura de pastas

```
Banco de dados/
  database/     schema.sql · seed.sql · consultas.sql
  ingestao/     importar_ram.py
  api/          main.py · db.py · modelos.py · rotas/ (produtos.py, builds.py, ...)
  prototipo/    app.py
  docs/         der.png · der.md
  .env.example  (DATABASE_URL — segredo real fora do git)
  requirements.txt · README.md
```

---

## 5. Tratamento de erros

- **API:** validação Pydantic → `400`; id inexistente → `404`; violação de FK/UNIQUE →
  `409`; erros inesperados → `500` com mensagem tratada. Operações de escrita em
  **transação** (`commit`/`rollback`) no psycopg2.
- **Ingestão:** idempotente (match por `link`); falha de rede/scraping não corrompe o banco
  (transação por produto).
- **Segredos:** `DATABASE_URL` em `.env` (no `.gitignore`); `.env.example` versionado sem
  segredo.

---

## 6. Testes

`pytest` leve (a infra de pytest já existe no repositório):

- CRUD caminho-feliz de ao menos os recursos centrais (`tb_produto`, `tb_build`,
  `tb_item_build`): criar → ler → atualizar → excluir.
- Erros de validação (payload inválido → 400; id inexistente → 404).
- *Smoke test* das DQL principais (retornam linhas sem erro).

Foco pragmático: o critério de avaliação valoriza o **protótipo funcionando**, não cobertura
exaustiva.

---

## 7. Mapa de entregas (PDF → artefato)

| Entrega exigida | Artefato |
|---|---|
| Script `.sql` (DDL+DML+DQL executável) | `database/schema.sql`, `seed.sql`, `consultas.sql` |
| Diagramas conceitual + lógico | `docs/der.png` (+ fonte Mermaid) |
| Collection da API + código-fonte | OpenAPI/Postman export + `api/` |
| Protótipo funcional | app Streamlit (`prototipo/app.py`) |
| Relatório técnico + PPT | redigido pelo grupo (estrutura apoiada pelo tutor) |

---

## 8. Fora de escopo (por ora)

- Tabelas de specs para as 6 categorias genéricas (Gabinete, Placa-mãe, Cooler,
  Armazenamento, Fonte, Fans) — extensão futura via scraping.
- Autenticação/login real de usuários (usuário é apenas dono de build).
- Compatibilidade por constraint no banco (fica em DQL, por decisão de escopo).
- Deploy em produção — protótipo roda localmente.
