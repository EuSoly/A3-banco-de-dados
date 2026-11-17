# A3 — Banco de Dados — Montagem de PC

Projeto semestral da UC de **Banco de Dados** (2026/2) — 4º semestre de Ciências da
Computação, Unicuritiba.

## Contexto

Sistema de **montagem de PCs** que cataloga componentes de hardware e permite montar
*builds*, verificando compatibilidade entre peças e acompanhando preços. O catálogo começa
com **memórias RAM reais**, coletadas do site Kabum via *web scraping* (reaproveitando o
projeto da A3 de Qualidade de Software); os demais componentes entram como carga fictícia.

## Status

Fase de documentação concluída. Implementação segue o plano abaixo.

- 📄 **Spec de design:** [`docs/superpowers/specs/2026-11-17-montagem-pc-banco-design.md`](docs/superpowers/specs/2026-11-17-montagem-pc-banco-design.md)
- 🗺️ **Plano de implementação:** [`docs/superpowers/plans/2026-11-17-montagem-pc-banco.md`](docs/superpowers/plans/2026-11-17-montagem-pc-banco.md)

## Arquitetura (planejada)

```
Scraping (existente) → Ingestão (Python) → PostgreSQL/Supabase → API FastAPI → Protótipo Streamlit
```

## Stack

PostgreSQL (Supabase) · Python · FastAPI · psycopg2 · Pydantic · Streamlit · pytest

## Como rodar (após a implementação)

```bash
pip install -r requirements.txt
cp .env.example .env   # preencher DATABASE_URL do Supabase
# aplicar database/schema.sql e database/seed.sql
uvicorn api.main:app --reload
streamlit run prototipo/app.py
```
