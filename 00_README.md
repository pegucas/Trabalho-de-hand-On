# Eurofarma — App B2B2C — Estrutura de Banco de Dados

Modelagem em PostgreSQL para o app descrito no pitch: assinatura de tratamento
contínuo, assistente de reabastecimento, farmácias parceiras como hubs de
distribuição, e o painel "Mente Leve" de fitoterápicos.

## Como executar

Os arquivos são numerados e devem ser aplicados **nessa ordem**, pois há
dependências de chave estrangeira entre eles (ex.: `catalog.products` precisa
existir antes de `partners.pharmacy_inventory`).

```
01_extensions_types.sql
02_security_auth.sql
03_pii_patients.sql
04_addresses.sql
05_catalog_products.sql
06_pharmacies_partners.sql
07_prescriptions.sql
08_subscriptions.sql
09_orders_delivery.sql
10_payments.sql
11_notifications_ai.sql
12_security_rls_views.sql
13_audit_triggers.sql
```

## Organização por schema (não por "tudo numa pasta só")

| Schema       | Conteúdo                                              | Por quê separado |
|--------------|--------------------------------------------------------|-------------------|
| `auth`       | login, senha, sessões, papéis, log de login             | Isolar credenciais permite revogar acesso a esse schema sem tocar no resto |
| `pii`        | pacientes, CPF/RG, endereços, consentimento LGPD         | Dado pessoal sensível — schema com `GRANT` mais restrito que qualquer outro |
| `clinical`   | prescrições médicas                                      | Dado de saúde é "dado sensível" pela LGPD (art. 5º, II) |
| `catalog`    | produtos, categorias, interações medicamentosas          | Catálogo é público/semi-público, não precisa do mesmo nível de restrição |
| `partners`   | farmácias, estoque, colaboradores                         | Domínio operacional dos parceiros |
| `commerce`   | assinaturas, pedidos, entregas, pagamentos                 | Núcleo transacional |
| `engagement` | notificações, log do assistente de IA                     | Onde mora a defesa contra *prompt injection* |
| `audit`      | trilha de auditoria genérica                               | Log imutável, sem lógica de negócio misturada |

Separar por schema (em vez de só por arquivo) permite fazer
`REVOKE ALL ... FROM PUBLIC` e liberar acesso tabela por tabela — é o que
torna a segurança **de fato** aplicada no banco, e não só uma convenção de
nomenclatura.

## Dados sensíveis e como cada um é protegido

| Dado                  | Tabela                          | Proteção aplicada |
|------------------------|----------------------------------|---------------------|
| Senha de login          | `auth.users.password_hash`       | Nunca chega ao banco em texto puro. Hash Argon2id calculado na aplicação; o banco só compara hashes. |
| E-mail                  | `auth.users.email_encrypted`     | Criptografado (`pgp_sym_encrypt`) + coluna `email_lookup_hash` (HMAC) para permitir busca de login sem expor o valor em claro em índice. |
| CPF / RG                | `pii.patient_documents`          | Tabela separada da tabela principal de pacientes, criptografada, com hash determinístico só para checar duplicidade. |
| Endereço                | `pii.addresses`                  | Rua/número criptografados; CEP em claro (necessário para roteamento logístico, risco isolado baixo). |
| Prescrição médica       | `clinical.prescriptions`         | Arquivo real fica em storage externo criptografado (S3 + KMS, por ex.); o banco guarda só a referência, nunca o binário. |
| Dados de cartão         | `commerce.payment_methods`       | Nunca armazenamos PAN/CVV — só o token do gateway de pagamento (compatível com PCI-DSS) e os 4 últimos dígitos para exibição. |

Em todos os casos, a chave de criptografia (`pgp_sym_encrypt`) deve vir de um
KMS/Vault gerenciado externamente — **nunca hardcoded no schema ou na
aplicação**.

## SQL Injection vs. Prompt Injection — são ataques diferentes

Você pediu proteção contra "prompt injection nas tabelas". Vale separar os
dois conceitos porque a defesa é diferente:

**SQL Injection** (ataque clássico contra bancos de dados): acontece quando
input do usuário é concatenado diretamente numa query SQL. A defesa não é uma
coluna ou tabela — é arquitetural:
- A aplicação deve **sempre** usar queries parametrizadas / prepared
  statements (nunca montar SQL por concatenação de string).
- As roles de banco (`app_readonly`, `app_write`, `app_admin`, criadas em
  `12_security_rls_views.sql`) seguem o princípio do menor privilégio, então
  mesmo que uma injeção aconteça, o dano é limitado ao que aquela role pode
  fazer.

**Prompt Injection** (ataque específico contra sistemas com LLM): acontece
quando texto digitado por um usuário (ou vindo de um campo de produto, por
exemplo) é interpretado como *instrução* por um modelo de IA em vez de como
*dado*. Isso é relevante aqui porque o pitch descreve um "assistente ativo
guiado por algoritmo" — se esse algoritmo for um LLM, ele está exposto a esse
risco. As defesas modeladas no schema (`11_notifications_ai.sql`):
- `engagement.notification_templates` usa placeholders nomeados
  (`{{first_name}}`) preenchidos por *bind* de parâmetro — nunca por
  concatenação de texto livre dentro de um prompt.
- `engagement.ai_assistant_interactions` guarda o input já sanitizado e tem
  um campo `flagged_injection_attempt` para sinalizar tentativas suspeitas
  para revisão humana.
- Regra de aplicação (fora do banco, mas que o schema pressupõe): qualquer
  ação real sugerida pela IA (ex.: "reabastecer automaticamente") deve passar
  pelas regras de negócio normais antes de gerar um pedido de verdade — o
  output do modelo nunca deve executar uma ação diretamente.

## Duas decisões de modelagem que valem destacar

1. **`commerce.subscription_events` com `cancellation_reason`** — o pitch
   fala em "taxa de evasão nula". Modelei o cancelamento como algo que
   acontece e é registrado (com motivo), não como algo que o sistema
   simplesmente não permite. Isso dá dado real de churn em vez de mascarar o
   número.
2. **`catalog.product_interactions`** — como o "Mente Leve" vende
   fitoterápicos ao lado de medicamentos de prescrição, essa tabela permite o
   sistema checar/alertar sobre interações (ex.: erva x anticoagulante) antes
   de fechar uma assinatura ou pedido combinando os dois.

## Compliance LGPD

- `pii.consent_records` guarda a base legal e a versão do termo aceito para
  tratamento de dado de saúde (obrigatório pelo art. 11 da LGPD).
- Todas as tabelas de dado sensível têm `deleted_at` (soft delete) para
  suportar o direito ao esquecimento sem quebrar histórico de pedidos/notas
  fiscais que precisam ser mantidos por obrigação fiscal.
- `audit.audit_log` dá rastreabilidade de quem acessou/alterou o quê — exigido
  para demonstrar conformidade em caso de fiscalização ou incidente.
