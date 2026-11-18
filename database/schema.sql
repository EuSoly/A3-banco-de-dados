-- =========================================================
-- Projeto A3 — Banco de Dados — "Montagem de PC"
-- DDL (Data Definition Language)
-- Banco: PostgreSQL (Supabase)
-- =========================================================
-- Para recriar do zero, descomente o DROP abaixo:
-- DROP TABLE IF EXISTS tb_item_build, tb_build, tb_usuario, tb_coleta, tb_loja,
--   tb_compatibilidade, tb_plataforma, tb_placa_de_video, tb_processador,
--   tb_memoria_ram, tb_produto, tb_categoria, tb_marca CASCADE;

-- Marcas de componentes (Kingston, AMD, NVIDIA, ...)
CREATE TABLE tb_marca (
  id_marca   SERIAL PRIMARY KEY,
  nome       VARCHAR(80) NOT NULL UNIQUE
);

-- Categorias de componentes (Memória RAM, Processador, ...)
CREATE TABLE tb_categoria (
  id_categoria SERIAL PRIMARY KEY,
  nome         VARCHAR(60) NOT NULL UNIQUE
);

-- Produto: entidade central. 'origem' separa dado de scraping de dado fictício.
CREATE TABLE tb_produto (
  id_produto   SERIAL PRIMARY KEY,
  nome         VARCHAR(255) NOT NULL,
  preco        NUMERIC(10,2),
  link         VARCHAR(500) UNIQUE,                 -- chave natural (idempotência da ingestão)
  origem       VARCHAR(10) NOT NULL DEFAULT 'ficticio'
               CHECK (origem IN ('scraping','ficticio')),
  id_categoria INT NOT NULL REFERENCES tb_categoria(id_categoria),
  id_marca     INT REFERENCES tb_marca(id_marca),
  criado_em    TIMESTAMP NOT NULL DEFAULT now()
);

-- ---- Especialização 1–1 (subtipos de produto) ----
-- A PK É a FK para tb_produto => garante no máximo 1 linha de specs por produto.
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

-- ---- Compatibilidade (N–N) ----
CREATE TABLE tb_plataforma (
  id_plataforma SERIAL PRIMARY KEY,
  nome          VARCHAR(80) NOT NULL,
  socket        VARCHAR(20),
  tipo_ram      VARCHAR(10)
);

CREATE TABLE tb_compatibilidade (
  id_produto    INT NOT NULL REFERENCES tb_produto(id_produto) ON DELETE CASCADE,
  id_plataforma INT NOT NULL REFERENCES tb_plataforma(id_plataforma) ON DELETE CASCADE,
  PRIMARY KEY (id_produto, id_plataforma)             -- PK composta: par único
);

-- ---- Histórico de preços ----
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

-- ---- Builds (N–N com produto) ----
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
  PRIMARY KEY (id_build, id_produto)                  -- PK composta: par único
);

-- Demonstração de ALTER TABLE (exigido no PDF): coluna de status lógico
ALTER TABLE tb_produto ADD COLUMN ativo BOOLEAN NOT NULL DEFAULT true;

-- Índices para consultas/relatórios frequentes
CREATE INDEX idx_produto_categoria ON tb_produto(id_categoria);
CREATE INDEX idx_coleta_produto    ON tb_coleta(id_produto);

-- =========================================================
-- Segurança: Row Level Security (RLS)
-- Habilitado em todas as tabelas. As policies por usuário
-- serão criadas junto com o login (fase de autenticação).
-- =========================================================
ALTER TABLE tb_marca            ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_categoria        ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_produto          ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_memoria_ram      ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_processador      ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_placa_de_video   ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_plataforma       ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_compatibilidade  ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_loja             ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_coleta           ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_usuario          ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_build            ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_item_build       ENABLE ROW LEVEL SECURITY;
