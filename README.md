# BrasaAssisten iOS

Aplicativo nativo experimental para iPhone 11: abre https://brasa.poker/ usando WKWebView e exibe um painel flutuante, sem mexer na interface original da mesa.

## v0.5 — Assistente de 3 cores + leitor diagnóstico + treino

- Painel flutuante mais compacto (altura máxima de 360 pontos) e com rolagem.
- **Inspecionar HTML:** busca apenas candidatos a cartas no conteúdo visível e conta Canvas, SVG, imagens IMG, fundos CSS e iframes. Isso não é reconhecimento confirmado.
- **Testar imagem:** captura a WKWebView e tenta reconhecer símbolos de cartas e pistas isoladas de valores no rodapé com o Vision OCR da Apple, exclusivamente no dispositivo (sem upload). Ainda não determina com segurança o naipe ou se a carta é sua.
- **Treino de Hold'em:** entrada manual com duas cartas e 0/3/4/5 comunitárias; avalia combinações e estima equidade por 1.200 cenários aleatórios, entre 1 e 8 adversários.
- **Testes matemáticos:** em Tests/main.swift, executados antes da geração do IPA no GitHub Actions.
- Convenção: a=paus, c=copas, e=espadas, d=ouros. Exemplo: Ae Kd.

## Gerar IPA para KSign

Abra Actions → Build BrasaAssisten unsigned IPA → Run workflow. Após execução verde, baixe BrasaAssisten-IPA-KSign na seção Artifacts. Extraia o ZIP, importe o IPA no KSign, assine com seu certificado e instale.

**Nunca envie certificados nem perfis de assinatura ao GitHub.**

## Limites atuais

Não existe leitura automática **confiável** da mesa Brasa (cartas, posição, ações e apostas). Tokens detectados por HTML/OCR são candidatos não verificados; eles NÃO alimentam o motor de treino. O projeto não possui modelo de linguagem ou recomendações automáticas de aposta, não conhece cartas escondidas e não transmite conteúdo da página para servidores próprios. O cálculo offline assume mãos aleatórias e não prevê comportamento humano.

Respeite as regras da plataforma, especialmente nas partidas com dinheiro real. Projeto independente e não afiliado ao Brasa Poker.

## Assistente de sinais v0.5

No painel, há três faixas: VERMELHO (fraca), AMARELO (cautela), VERDE (forte), com explicação e uma ação básica pré-flop. Insira sua mão (ex. Ke 10a) e, se houver, as comunitárias (ex. 5c Je 6d). O app classifica imediatamente, sem depender de serviços de IA.
A leitura automática do HTML roda a cada 3 segundos e exibe candidatos somente após duas leituras iguais; NÃO considera essas cartas confirmadas. Toque em "Confirmar essas duas cartas" quando a correspondência com a mesa estiver correta. Em mesas onde o Brasa não expõe cartas no HTML, use a entrada manual. O app não possui análise automática confiável de apostas, adversários ou probabilidades individuais de vitória e não executa ações no site.

Os sinais são heurísticas básicas de estudo em partidas fictícias e NÃO substituem avaliação do tamanho da aposta, posição e range. Nenhuma situação de aposta deve ser decidida só pelo sinal de cor.

## v0.6 — Leitura rápida separada por posição

- Varredura DOM de 0,6 em 0,6 segundo, com estabilização após duas leituras; antes eram 3 segundos entre varreduras. A meta é reduzir a latência observada, mas isso depende do DOM e do iPhone.
- Diferencia a mão do jogador pela área do topo (alternativamente rodapé) e tenta identificar as cartas comunitárias no centro da mesa. Desconsidera leitura com cartas repetidas/inválidas.
- Se houver ao menos três valores comunitários, mas faltarem naipes para identificar as cartas, o painel para de exibir a recomendação pré-flop e apresenta "MESA NÃO LIDA".
- A análise atualiza automaticamente quando o leitor reconhece flop, turn e river; permite correção manual dos dados, sem sobrepor o conteúdo do site.
- Em nova mão identificada, apaga correções antigas e recupera a análise automática. Correções manuais de cartas da mesa podem ser abandonadas quando novas cartas identificadas as estenderem.
- **Limite:** o DOM do Brasa não foi inspecionado por uma sessão de debug no aparelho. Alguns naipes desenhados em SVG/imagens podem não ser extraídos por esse leitor e exigir reconhecimento visual específico. NÃO apresentamos extração automática de comunitárias como validada.

## v0.7 — Segurança contra análises atrasadas

- Novo HandSession guarda o estado da mão em pré-flop/flop/turn/river, aceita apenas avanço consistente das comunitárias, isola a mão seguinte e interrompe prévias quando as cartas da mesa são incertas.
- Ao começar uma mão nova identificada, as correções manuais antigas são descartadas automaticamente.
- O scanner de texto evita operações caras no DOM para nós que não se parecem com cartas.
- O app exibe o nome da etapa e permite **Copiar diagnóstico da leitura**. Esse diagnóstico contém apenas cartas candidatas, posições lógicas/estado e transições; não inclui histórico completo da página, senhas nem capturas de tela.
- Novo conjunto de testes automáticos em Tests/handSessionMain.swift. A compilação da v0.7 só deverá prosseguir se todos os testes de regressão passarem no GitHub Actions.
- Ainda é necessário verificar no iPhone a detecção de cartas comunitárias quando o site usa imagens/SVG: melhorias na lógica de estado não provam reconhecimento visual completo.

## v0.8 — correção do scanner automático

A v0.7 não lia as cartas porque a função JavaScript executada a cada 0,6 segundo tinha duas declarações da constante `clean` no mesmo escopo, causando SyntaxError. A inspeção manual funcionava porque utilizava outro script.

- Removida a declaração duplicada de `clean`;
- Adicionados testes sintáticos automáticos de TODOS os scripts JavaScript embarcados (Node.js --check), executados no GitHub Actions antes de criar o IPA;
- Adicionadas simulações do próprio scanner com duas cartas, flop e river (o parser e a separação espacial, não o reconhecimento real do site);
- Quando uma chamada a JavaScript falhar, o app exibe a causa em “Copiar diagnóstico da leitura”, em vez de “Leitura indisponível” sem detalhes;
- O reconhecimento de cartas reais no iPhone precisa ser revalidado após a compilação. Não foi afirmado suporte completo a cartas comunitárias do Brasa.

## v0.9 — Leitura comunitária e observação

- Novo scanner espacial `CardScanner.swift`: reúne valores e naipes de cartas visíveis, incluindo símbolos SVG quando a classe/semântica ou a silhueta permite identificar o naipe.
- Detecta comunitárias de flop, turn e river como grupos na mesma fileira, com verificação de consistência. Não depende mais de exatamente duas cartas na página.
- Modo observação funciona sem cartas pessoais expostas, oferecendo análise da textura da mesa. Não revela cartas ocultas.
- `TableSession.swift` acompanha mudança de mão, avanço de rodadas, desistências e leituras parciais. Incerteza bloqueia recomendações antigas.
- Notificações de mudanças visíveis do DOM aceleram tentativas de leitura; timer de 0,6 segundo continua como recuperação.
- Informações visíveis opcionais: pote, valor para pagar, conta de equidade de equilíbrio e pares revelados no showdown (candidatos).
- Painel menor, diagnóstico recolhível; erros detalhados não exigem capturas completas nem envio de credenciais.
- A suíte de testes simula pré-flop, flop com naipe SVG, turn/river, leitura em modo espectador e casos sem naipe reconhecido.

**Importante:** testes simulados verificam comportamento do algoritmo, não garantem que o Brasa Poker exponha todos os SVGs do mesmo modo. A compilação real e a leitura em um iPhone 11 ainda precisam ser verificadas. Em casos incertos o app deve indicar falta de dados, não inventar cartas ou decisões.

## Instalação beta em paralelo

A v0.9 usa o identificador `com.brasaassisten.browser.beta` e o nome **BrasaAssisten Beta**. Assine o IPA pelo KSign com seu próprio certificado válido; isso permite testar a versão experimental sem substituir o aplicativo BrasaAssisten instalado anteriormente. Não envie certificados para este repositório.

## v0.9.1 — painel de leitura rápida

Agora, ao tocar no ícone de chama, aparece um painel compacto com o sinal principal, a etapa (flop/turn/river), as cartas próprias quando visíveis, as comunitárias e o pote. O painel compacto fica acima dos controles de aposta do navegador. O botão **Detalhes e correções** mantém o painel completo e os diagnósticos acessíveis; dentro dele, **Compactar painel** volta ao resumo. Não há alterações no motor de reconhecimento nesta revisão. A versão Beta permanece isolada do aplicativo anterior.
