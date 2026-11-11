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
