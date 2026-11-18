-- =========================================================
-- Projeto A3 — Banco de Dados — "Montagem de PC"
-- DML (Data Manipulation Language) — carga inicial
-- Rode DEPOIS de schema.sql, em um banco limpo.
-- =========================================================

-- ---- Tabelas independentes (sem FK) ----

-- 9 categorias de componentes
INSERT INTO tb_categoria (nome) VALUES
 ('Processador'), ('Placa Mãe'), ('Memória RAM'), ('Placa de Vídeo'),
 ('Armazenamento'), ('Fonte'), ('Gabinete'), ('Cooler'), ('Fans');

-- Marcas (componentes internos + alguns periféricos)
INSERT INTO tb_marca (nome) VALUES
 ('Kingston'), ('Corsair'), ('XPG'), ('AMD'), ('NVIDIA'), ('Gigabyte'),
 ('Cooler Master'), ('Redragon'), ('Aula'), ('Logitech'), ('SteelSeries'),
 ('Mchose'), ('Attack Shark'), ('Glorious');

-- Loja (fonte do scraping)
INSERT INTO tb_loja (nome, url) VALUES
 ('Kabum', 'https://www.kabum.com.br/');

-- Plataformas (socket + tipo de RAM) — base do teste de compatibilidade
INSERT INTO tb_plataforma (nome, socket, tipo_ram) VALUES
 ('AMD AM4',        'AM4',     'DDR4'),
 ('AMD AM5',        'AM5',     'DDR5'),
 ('Intel LGA 1700', 'LGA1700', 'DDR5'),
 ('Intel LGA 1851', 'LGA1851', 'DDR5'),
 ('Intel LGA 1151', 'LGA1151', 'DDR4');

-- ---- Produtos fictícios + especialização (1–1) ----
-- Observação: as memórias RAM NÃO entram aqui — vêm do scraping
-- (ingestao/importar_ram.py), com origem='scraping'.

-- Placa de vídeo
INSERT INTO tb_produto (nome, preco, id_categoria, id_marca)
VALUES ('Placa de Vídeo NVIDIA RTX 4060', 2659.99,
        (SELECT id_categoria FROM tb_categoria WHERE nome = 'Placa de Vídeo'),
        (SELECT id_marca     FROM tb_marca     WHERE nome = 'NVIDIA'));
INSERT INTO tb_placa_de_video (id_produto, vram_gb, tdp_watts)
VALUES ((SELECT id_produto FROM tb_produto WHERE nome = 'Placa de Vídeo NVIDIA RTX 4060'),
        8, 115);

-- Processador
INSERT INTO tb_produto (nome, preco, id_categoria, id_marca)
VALUES ('Processador AMD Ryzen 5 5600', 899.90,
        (SELECT id_categoria FROM tb_categoria WHERE nome = 'Processador'),
        (SELECT id_marca     FROM tb_marca     WHERE nome = 'AMD'));
INSERT INTO tb_processador (id_produto, socket, nucleos, clock_ghz)
VALUES ((SELECT id_produto FROM tb_produto WHERE nome = 'Processador AMD Ryzen 5 5600'),
        'AM4', 6, 3.50);

-- Compatibilidade: o Ryzen (AM4) encaixa na plataforma AMD AM4
INSERT INTO tb_compatibilidade (id_produto, id_plataforma)
VALUES ((SELECT id_produto    FROM tb_produto    WHERE nome = 'Processador AMD Ryzen 5 5600'),
        (SELECT id_plataforma FROM tb_plataforma WHERE socket = 'AM4'));

-- ---- Demonstração de UPDATE / DELETE (exigido no PDF) ----
-- Exemplo de UPDATE: ajuste de preço
-- UPDATE tb_produto SET preco = 849.90 WHERE nome = 'Processador AMD Ryzen 5 5600';
-- Exemplo de DELETE (comentado para não apagar dado de demonstração):
-- DELETE FROM tb_produto WHERE id_produto = 999;

-- ---- EM CONSTRUÇÃO (fazendo em sala, passo a passo) ----
-- tb_usuario, tb_build, tb_item_build  (cadeia das builds, N–N)
-- tb_coleta (histórico de preços; a da RAM vem do scraping)
