# Grupo Dantas — Sistema de Incorporação v1.0

Sistema completo de gestão para incorporadoras. Flutter (Android + iOS + Web) + Supabase + Groq IA.

---

## 🗂️ Módulos

| Módulo | O que faz |
|---|---|
| **Dashboard** | KPIs, gráfico financeiro, obras recentes, etapas em progresso |
| **Obras** | Lista, filtros, detalhe com 6 abas (visão geral, etapas, financeiro, diário, materiais, docs) |
| **Viabilidade** | Calculadora VGV + CUB (SINDUSCON 2025) + BDI + margem. Veredito automático |
| **Jurídico** | Checklist interativo pré-obra, durante, pós-obra + contratos (empreitada, CLT, MEI) |
| **RH & Impostos** | Consulta CNPJ (API Receita Federal), calculadora de encargos por tipo, retenções em NF |
| **Checklist de Obra** | 6 etapas com normas ABNT, bloqueio de avanço sem completar obrigatórios, conselho sênior |
| **Financiamento** | Simulador SAC x Price, linhas CEF/BB, como funciona o Plano Empresa |
| **Assistente IA** | Chat com Groq LLaMA 3.3 70B como incorporador sênior com 25 anos de experiência |
| **Notificações** | Realtime via Supabase — cliente e engenheiro notificados ao atualizar etapa |
| **Perfil** | Dados do usuário, logout |

---

## 🚀 Setup rápido

### 1. Supabase
Execute `grupo_dantas_supabase.sql` no SQL Editor do seu projeto.

### 2. Chaves no `lib/main.dart`
```dart
const String groqApiKey      = 'SUA_GROQ_KEY_AQUI';
const String supabaseAnonKey = 'SUA_SUPABASE_ANON_KEY_AQUI';
```

### 3. Rodar
```bash
flutter pub get
flutter run -d chrome     # Web
flutter run -d android    # Android
flutter run               # iOS
```

### 4. Deploy web
```bash
flutter build web --release
# Upload de build/web para o seu domínio .com.br
```

---

## 📱 Navegação

**Web/Tablet (> 900px):** Sidebar fixa com grupos organizados por seção.  
**Mobile:** Bottom nav com 5 atalhos + drawer lateral para todos os módulos.

---

## 🏗️ Arquitetura

```
lib/
├── main.dart                    ← Chaves de API aqui
├── core/
│   ├── theme/app_theme.dart     ← Tema dark premium (preto + dourado)
│   ├── router/app_router.dart   ← Todas as rotas
│   └── shell/app_shell.dart     ← Sidebar web + bottom nav mobile
├── features/
│   ├── auth/                    ← Splash + Login (Supabase Auth)
│   ├── dashboard/               ← KPIs + gráficos
│   ├── obras/                   ← CRUD + 6 abas de detalhe
│   ├── viabilidade/             ← Calculadora VGV/CUB/margem
│   ├── juridico/                ← Checklists jurídicos + tipos de contrato
│   ├── rh/                      ← CNPJ + encargos + retenções NF
│   ├── checklist/               ← Checklist técnico por etapa (ABNT)
│   ├── financiamento/           ← Simulador + linhas CEF/BB
│   └── assistente/              ← Chat IA com Groq
└── shared/widgets/              ← GDCard, StatCard, ObraMiniCard
```

---

## 👥 Roles

| Role | Acesso |
|---|---|
| `admin` | Tudo — cria obras, usuários, vê financeiro |
| `engenheiro` | Obras atribuídas — atualiza etapas, diário, materiais |
| `cliente` | Sua obra — visualização de progresso e financeiro |

---

## 🔔 Realtime

Quando admin/engenheiro atualiza uma etapa → Supabase trigger → notificação automática para cliente e engenheiro.

---

## 📦 Dependências principais

- `supabase_flutter` — banco, auth, storage, realtime
- `go_router` — navegação declarativa
- `flutter_riverpod` — estado
- `fl_chart` — gráficos financeiros
- `flutter_animate` — animações premium
- `http` — chamadas Groq API e CNPJ
