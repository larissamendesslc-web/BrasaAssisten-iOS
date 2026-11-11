# BrasaAssisten iOS

Aplicativo nativo experimental para iPhone 11: abre https://brasa.poker/ usando WKWebView e exibe um painel flutuante, sem mexer na interface original da mesa.

## v0.4 — Leitor diagnóstico + treino

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
