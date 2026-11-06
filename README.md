# Budget do Fábio — finanças pessoais para iPhone

App nativa de finanças pessoais em **Swift/SwiftUI**, para uso pessoal, **100% offline** e sem backend. A interface, as datas e a moeda (EUR) estão em português europeu.

- iOS 17.0+, SwiftUI, SwiftData, Swift Charts, App Intents e LocalAuthentication.
- Zero dependências de terceiros.
- Projeto Xcode gerado com [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir de `project.yml`. Pode ser escrito em Windows e é gerado no CI.
- Um único target, sem extensões e sem capabilities pagas. Pode ser instalado com um Apple ID gratuito via Sideloadly (ver [SIDELOAD.md](SIDELOAD.md)).
- Nome no ecrã principal: **Budget do Fábio**, com ícone próprio (`App/Assets.xcassets/AppIcon`). O bundle ID continua a ser `pt.fabio.orcamento` (alterá-lo fazia perder os dados nas reinstalações) e o ficheiro gerado continua a chamar-se `Orcamento.ipa`.
- Todos os valores monetários são guardados como **inteiros em cêntimos** (`Int`), nunca como `Double`. O `Double` só aparece na conversão para os eixos dos gráficos (`MoneyFormat.chartValue`).

## Módulos

| Módulo | Pasta | Onde está na app |
| --- | --- | --- |
| Painel (saldo à ordem, fluxo do mês, despesas por categoria) | `App/Dashboard` | Separador **Início** |
| Registo de transações (criar, editar, eliminar) | `App/Transactions` | Botão **+** no Início e no Histórico |
| Categorias (cor, ícone, arquivo, conjunto inicial em PT) | `App/Categories` | **Mais → Categorias** |
| Orçamentos (global e por categoria, com estados) | `App/Budgets` | Separador **Orçamentos** |
| Histórico/Ledger (agrupado por dia, pesquisa, filtros, total) | `App/Ledger` | Separador **Histórico** |
| Cofre (transferências saldo ↔ cofre, que não são despesa) | `App/Vault` | Separador **Cofre** |
| Objetivos (afetação do cofre, progresso, data alvo) | `App/Goals` | Separador **Cofre** e **Mais → Objetivos** |
| Recorrentes (diárias/semanais/mensais/anuais, catch-up, notificações) | `App/Recurring` | **Mais → Recorrentes** |
| Divisão de despesas (grupos, partes, dívidas mínimas) | `App/SplitExpenses` | **Mais → Divisão de despesas** |
| Análise (património, taxa de poupança, mês a mês) | `App/Analytics` | **Mais → Análise** |
| Importar/Exportar (CSV, PDF mensal, cópia de segurança JSON) | `App/ImportExport` | **Mais → Importar e exportar** |
| Captura Apple Pay (App Intent + ajuda + fila "por rever") | `App/Intents` | **Mais → Captura Apple Pay** / **Por rever**, e app Atalhos |
| Extras (Face ID, previsão de fim de mês) | `App/Extras` | **Mais** e **Início** |

## Design

A interface segue os 11 ecrãs desenhados no Stitch ("Minimalist iOS Finance App"), guardados como referência em `design/stitch/` (PNG + HTML). O sistema de design está em `App/Shared/Theme.swift` e `App/Shared/Components.swift`:

- **Cores** do Stitch: fundo `#F9F9F7`, cartões brancos com contorno subtil, primária `#3B3BF5`, e estados verde, laranja e vermelho. Cada cor tem uma variante para modo escuro. A aparência pode ser escolhida em *Mais → Aparência* (Automático, Claro ou Escuro).
- **Componentes**: cartões com raio de 24 pt, rótulos em maiúsculas (`Eyebrow`), valores grandes (`HeroAmount`), chips de filtro, badges de estado, barras e anéis de progresso, botões primários e em cápsula, avatares com iniciais e um teclado numérico para o montante.
- **Tipografia**: o Stitch usa Hanken Grotesk. A app usa a fonte do sistema (SF Pro), que é parecida e mantém o Dynamic Type sem embutir ficheiros de fontes de terceiros.
- **Ícones**: o Stitch usa Material Symbols. A app usa os equivalentes em SF Symbols.

Alguns elementos do Stitch foram adaptados para não mostrar dados inventados nem funcionalidades que a app não tem. A app não tem rendimento (TANB) no cofre, cópia de segurança no iCloud, perfil com email nem configuração automática do atalho. Nos sítios onde o Stitch os mostra, a app apresenta informação real: o saldo à ordem, a cópia de segurança em JSON, o nome da app e um botão que abre a app Atalhos.

## Arquitetura

SwiftUI + SwiftData com MVVM leve. As views leem os dados com `@Query` e delegam todos os cálculos a tipos de domínio puros: `enum`s e `struct`s sem SwiftUI nem SwiftData, que trabalham sobre valores imutáveis (`TxSnapshot`, `SplitRecord`, `RecurrenceSchedule`, `CSVRow`).

```
App/
├── OrcamentoApp.swift        # @main, contentor SwiftData, ciclo de vida (seed, catch-up, notificações)
├── RootView.swift            # TabView: Início · Histórico · Orçamentos · Cofre · Mais (+ AppRouter)
├── Assets.xcassets           # Ícone da app, logótipo e cor de destaque
├── Shared/                   # Modelos SwiftData, tipos de domínio, formatação pt-PT, AmountParser, helpers de UI
├── Dashboard/  BalanceCalculator.swift (puro) + DashboardView
├── Budgets/    BudgetCalculator.swift (puro) + BudgetsView
├── Ledger/     LedgerFilter.swift (puro) + LedgerView
├── Recurring/  RecurrenceEngine.swift (puro) + RecurringService (catch-up/notificações) + views
├── SplitExpenses/ DebtSimplifier.swift (puro: partes iguais, saldos, dívidas mínimas) + views
├── Vault/      VaultCalculator.swift (puro) + VaultIntegrity + VaultView
├── Analytics/  AnalyticsCalculator.swift (puro) + AnalyticsView
├── ImportExport/ CSVCodec.swift (puro) + Backup (JSON) + PDFReport + ImportExportView
├── Intents/    RegisterExpenseIntent (AppIntent + AppShortcutsProvider), MerchantMatcher (puro), ajuda e fila de revisão
├── Categories/, Transactions/, Goals/, Settings/, Extras/
Tests/                        # XCTest para toda a lógica de domínio
```

### Decisões principais

- **Cêntimos em `Int`.** O `AmountParser` lê "12,50 €", "€12.50", "EUR 1.234,56", "1,234.56" ou ",50" diretamente para inteiros, sem passar por vírgula flutuante. Quando há os dois separadores, o último é o decimal. Quando há só um, é decimal se tiver 1–2 casas e separador de milhares se tiver 3.
- **Cofre.** As transferências são transações do tipo `vaultDeposit`/`vaultWithdrawal`. Movem dinheiro entre o saldo à ordem e o cofre e são excluídas do fluxo de caixa, dos orçamentos e da taxa de poupança. Os objetivos guardam a parte do cofre que lhes está afeta. O `VaultCalculator` valida cada afetação e cada levantamento, e o `VaultIntegrity` corrige as afetações se o cofre diminuir (por exemplo, quando se elimina um depósito). Assim, a soma dos objetivos nunca excede o saldo do cofre.
- **Recorrentes.** O iOS não garante execução em segundo plano. Por isso, sempre que a app fica ativa, `RecurringService.catchUp` gera as ocorrências em atraso a partir de `lastGeneratedDate`, sem duplicar. Cada ocorrência é calculada a partir da data de início (`início + n × intervalo`), o que evita a deriva de fim de mês (31 jan → 28 fev → 31 mar). As notificações locais da próxima ocorrência são reagendadas na mesma altura.
- **Divisão de despesas.** O saldo de cada pessoa é o que pagou menos a parte que lhe cabe. O `DebtSimplifier` calcula o **mínimo** de transferências: o mínimo é *n − (número máximo de subgrupos de soma zero)*, encontrado por programação dinâmica sobre subconjuntos até 16 pessoas com saldo (acima disso usa o algoritmo guloso). Dentro de cada subgrupo, emparelha o maior credor com o maior devedor. Só a parte do utilizador ("Eu") é registada como despesa pessoal. Os pagamentos entre participantes ficam registados no grupo e não contam como despesa.
- **Captura Apple Pay.** `RegisterExpenseIntent` (`openAppWhenRun = false`) usa o mesmo `ModelContainer` da app. As transações capturadas ficam `needsReview = true`. A categoria é escolhida por esta ordem: categoria indicada no atalho, depois regra aprendida comerciante→categoria (`MerchantRule`, com chave normalizada e correspondência por prefixo). A regra é aprendida quando o utilizador confirma ou edita a transação.
- **CSV** com `;` e valores "1234,50" (abre bem no Excel em pt-PT), aspas RFC 4180 e BOM UTF-8. A importação valida cada linha e mostra um relatório com o número da linha e o motivo antes de importar.
- **Cópia de segurança JSON** com todas as entidades e definições. O restauro substitui tudo, após confirmação.
- **Acessibilidade.** Funciona em modo escuro (cores do sistema) e com Dynamic Type (estilos de texto do sistema). Os gráficos têm `accessibilityLabel`/`accessibilityValue` com os valores lidos em voz alta, e os botões só com ícone têm `accessibilityLabel`.

## Extras

Foram adicionados dois extras. Nenhum usa capabilities pagas nem altera o comportamento dos módulos pedidos.

1. **Bloqueio com Face ID** (`Extras/AppLock.swift`, opção em *Definições*): as finanças são dados sensíveis e o iPhone pode estar desbloqueado nas mãos de outra pessoa. A app pede Face ID (ou o código) sempre que volta do segundo plano.
2. **Previsão de fim de mês** (`Extras/ForecastSection.swift`, no *Painel*): projeta o saldo à ordem no último dia do mês com base no ritmo de despesas variáveis e nos recorrentes ainda por ocorrer. Ajuda a perceber a tempo se o mês vai fechar no vermelho.

## CI: como gerar o `.ipa`

O workflow [`.github/workflows/build-ipa.yml`](.github/workflows/build-ipa.yml) corre num runner `macos-15` em cada push de código para a `main` (alterações só em `.md` ou `design/` não disparam o CI) ou à mão em *Actions → Build IPA → Run workflow*. Como o repositório é privado, cada execução (~2 min em macOS) gasta a quota gratuita mensal de Actions do GitHub. O tempo limite é de 20 minutos e o `.ipa` fica guardado 30 dias.

1. `brew install xcodegen` e `xcodegen generate` (gera `Orcamento.xcodeproj` e `App/Info.plist`).
2. **Testes unitários** num simulador iPhone (`xcodebuild test`). Se algum falhar, o build falha.
3. Build **Release** para `iphoneos` sem assinatura: `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`.
4. Monta `Payload/Orcamento.app` e comprime para `Orcamento.ipa`.
5. Valida o `.ipa`: `Info.plist` válido, `MinimumOSVersion = 17.0`, nome "Budget do Fábio", ícone compilado (`CFBundleIconName` e `Assets.car`), sem ficheiros de entitlements e sem extensões (`PlugIns/`, `Extensions/`).
6. Publica o artifact **`Orcamento-ipa`**.
7. Imprime um resumo com a versão do Xcode, os testes executados e a presença de `Metadata.appintents` (prova de que o App Intent foi extraído).

Para instalar o `.ipa` no iPhone a partir do Windows, segue o [SIDELOAD.md](SIDELOAD.md).

### Correr localmente (num Mac, opcional)

```bash
brew install xcodegen
xcodegen generate
open Orcamento.xcodeproj
```

## Privacidade

Todos os dados ficam no iPhone (SwiftData local). A app não faz pedidos de rede, não tem contas nem analytics. As únicas permissões pedidas são Face ID (opcional) e notificações locais (opcional).
