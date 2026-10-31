# Instalar o Orçamento no iPhone a partir do Windows (Sideloadly)

Este guia explica, passo a passo, como instalar o ficheiro `.ipa` gerado pelo GitHub Actions num iPhone, usando um computador Windows e um Apple ID gratuito.

> **Resumo:** descarregar o `.ipa` → instalar iTunes e iCloud (versões do site da Apple) → ativar o Modo de Programador no iPhone → instalar com o Sideloadly → confiar no perfil → reinstalar de 7 em 7 dias com o **mesmo bundle ID**.

---

## 1. Descarregar o `.ipa` do GitHub Actions

1. Abre o repositório no GitHub e entra no separador **Actions**.
2. Escolhe o workflow **Build IPA** e abre o run mais recente com o visto verde ✅.
3. No fim da página, na secção **Artifacts**, clica em **Orcamento-ipa**. É descarregado um ficheiro `Orcamento-ipa.zip`.
4. Extrai o zip (botão direito → *Extrair tudo…*). Lá dentro está o **`Orcamento.ipa`**.

> Os artifacts expiram ao fim de 90 dias. Se já não existir, corre o workflow outra vez em *Actions → Build IPA → Run workflow*.

## 2. Instalar o iTunes e o iCloud (versões do site da Apple)

O Sideloadly precisa dos controladores e serviços da Apple que vêm com o iTunes e o iCloud **para Windows descarregados diretamente do site da Apple**. As versões da Microsoft Store **não funcionam** com o Sideloadly.

1. Se tiveres o iTunes ou o iCloud instalados a partir da Microsoft Store, desinstala-os primeiro (*Definições → Aplicações*).
2. Descarrega e instala o **iTunes** (versão "Windows" de 64 bits, *não* a da Microsoft Store) a partir de: <https://www.apple.com/itunes/download/win64>
3. Descarrega e instala o **iCloud para Windows** a partir do site da Apple (<https://support.apple.com/pt-pt>, pesquisa "iCloud para Windows"). Usa a ligação direta para o instalador `.exe`, não a ligação para a Microsoft Store. O Sideloadly indica no seu site a versão recomendada, se a mais recente der problemas.
4. Reinicia o computador.
5. Liga o iPhone por cabo USB, abre o iTunes e, no iPhone, toca em **Confiar neste computador**. Confirma que o iTunes mostra o iPhone.

## 3. Ativar o Modo de Programador no iPhone

A partir do iOS 16 é obrigatório para correr apps instaladas por sideload.

1. **Primeiro instala a app uma vez (passo 4).** A opção só aparece depois de existir uma app de programador no iPhone.
2. No iPhone: **Definições → Privacidade e segurança → Modo de programador** → ativar.
3. O iPhone pede para reiniciar. Depois de reiniciar, confirma **Ativar** e introduz o código.

## 4. Instalar com o Sideloadly

1. Descarrega o Sideloadly para Windows em <https://sideloadly.io> e instala-o.
2. Com o iPhone ligado por cabo e desbloqueado, abre o Sideloadly.
3. Arrasta o `Orcamento.ipa` para a janela (ou clica no ícone do IPA e escolhe o ficheiro).
4. Em **Apple account**, escreve o teu Apple ID. Recomenda-se um Apple ID secundário só para isto.
5. Abre **Advanced options** e confirma que:
   - **Bundle ID**: fica `pt.fabio.orcamento`. Não deixes o Sideloadly alterá-lo, porque é deste valor que depende manteres os dados (ver passo 6).
   - Não estão ativadas opções que acrescentem *app extensions* ou *entitlements* extra.
6. Clica em **Start** e introduz a palavra-passe do Apple ID quando for pedida (e o código de dois fatores, se aparecer).
7. Espera pela mensagem **Done**.

> O Sideloadly assina a app com um certificado gratuito ligado ao teu Apple ID. A app não usa capabilities pagas (sem App Groups, iCloud, Push, extensões ou widgets), por isso a assinatura gratuita é suficiente. O Face ID funciona.

## 5. Confiar no perfil de programador

Na primeira instalação o iOS não deixa abrir a app até confiares no certificado:

1. No iPhone: **Definições → Geral → VPN e gestão de dispositivos**.
2. Em **App de programador**, toca no teu Apple ID.
3. Toca em **Confiar em "<o teu Apple ID>"** e confirma.
4. Abre a app **Orçamento**.

## 6. Renovar de 7 em 7 dias sem perder dados

Com um Apple ID gratuito, a assinatura **expira ao fim de 7 dias**. Quando expira, a app deixa de abrir, mas os dados continuam no iPhone.

Para renovar e **manter os dados**:

1. Volta a instalar com o Sideloadly (passo 4), de preferência **antes** de passarem os 7 dias.
2. Usa **o mesmo Apple ID** e **o mesmo bundle ID (`pt.fabio.orcamento`)**. O iOS trata a nova instalação como uma atualização da mesma app e mantém a base de dados.
3. **Não apagues a app** do iPhone antes de reinstalar. Apagar a app apaga os dados.
4. Podes usar o `.ipa` antigo ou um mais recente do GitHub Actions. Ambos têm o mesmo bundle ID.

Dicas:

- O Sideloadly tem a opção de *auto-refresh* via Wi-Fi (o computador tem de estar ligado com o Sideloadly aberto e o iPhone na mesma rede). É opcional.
- Antes de experimentar coisas novas, faz uma cópia de segurança em **Mais → Importar e exportar → Exportar cópia de segurança (JSON)** e guarda-a no app Ficheiros ou envia-a para o computador.
- Os Apple IDs gratuitos podem ter no máximo 3 apps de sideload ativas ao mesmo tempo e um número limitado de bundle IDs novos por semana. Reutilizar o mesmo bundle ID evita esse limite.

## 7. Configurar a captura automática do Apple Pay

Depois de instalada, abre a app e vai a **Mais → Captura Apple Pay**. O ecrã tem o passo a passo para criar a automação **Transação** na app Atalhos com a ação **Registar despesa**.

## Problemas comuns

| Sintoma | Solução |
| --- | --- |
| O Sideloadly não deteta o iPhone | Instala o iTunes do site da Apple (não o da Microsoft Store), troca de cabo e volta a tocar em "Confiar neste computador". |
| "Untrusted Developer" ou a app não abre | Faz o passo 5 (confiar no perfil). |
| A app fecha logo ao abrir após uma semana | O certificado expirou. Reinstala com o mesmo Apple ID e o mesmo bundle ID (passo 6). |
| "Modo de programador" não aparece | Instala a app uma primeira vez e volta a procurar em *Privacidade e segurança*. |
| Erro de palavra-passe no Sideloadly | Se o Apple ID tiver dois fatores, usa o código enviado para os teus dispositivos. |
