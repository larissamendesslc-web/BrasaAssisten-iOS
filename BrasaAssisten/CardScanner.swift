import Foundation

/// Read-only extraction of rendered, visible cards. It deliberately never
/// queries app stores, network APIs, WebSocket traffic or hidden card data.
/// Changes in the poker website can still break this scanner.
enum CardScanner {
    static let source = #"""
    (() => {
      'use strict';
      const W = window.innerWidth || innerWidth, H = window.innerHeight || innerHeight;
      const empty = { hero:[], board:[], hints:[], source:'none',
                      uncertain:false, observing:true, stage:'waiting',
                      pot:'', diagnostics:'not-ready' };
      if (!W || !H || !document.body) return empty;
      const fullRE=/(?:10|[2-9AJQK])\s*[♠♥♦♣]/gi;
      const rankRE=/^(?:10|[2-9AJQK])$/;
      const suits=/^[♠♥♦♣]$/;
      const ranks=[], suitTexts=[], whole=[];
      const rect = el => { try{return el.getBoundingClientRect()}catch(_){return null} };
      const visible = el => {
        const r=rect(el);
        if(!r || r.width<1 || r.height<1 || r.right<=0 || r.bottom<=0 ||
           r.left>=W || r.top>=H) return false;
        const css=getComputedStyle(el);
        return css.visibility!=='hidden' && css.display!=='none' && Number(css.opacity||'1')>0.02;
      };
      const pos = r => ({x:(r.left+r.right)/2,y:(r.top+r.bottom)/2});
      const compact = t => String(t||'').toUpperCase().replace(/\s+/g,'');
      const uniq = values => new Set(values).size===values.length;
      function addFull(token,p,source,confidence) {
        const t=compact(token);
        if(/^(?:10|[2-9AJQK])[♠♥♦♣]$/.test(t) && p.x>0 && p.x<W && p.y>0 && p.y<H)
          whole.push({...p,token:t,source,confidence});
      }

      let walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
      let node,scanned=0;
      while ((node=walker.nextNode()) && scanned++<3600) {
        const t=(node.textContent||'').trim();
        if(!t || t.length>65) continue;
        const c=compact(t);
        if(!rankRE.test(c) && !suits.test(c) && !/(?:10|[2-9AJQK])\s*[♠♥♦♣]/i.test(t))
          continue;
        if(!node.parentElement || !visible(node.parentElement)) continue;
        let r;
        try { const range=document.createRange();range.selectNodeContents(node);r=range.getBoundingClientRect() }
        catch(_){continue}
        if(!r || r.width<=0 || r.height<=0) continue;
        const p=pos(r);
        if(rankRE.test(c)) ranks.push({...p,rank:c,node});
        if(suits.test(c)) suitTexts.push({...p,suit:c});
        fullRE.lastIndex=0;
        for(const m of t.matchAll(fullRE)) addFull(m[0],p,'text',1);
      }

      // Some cards expose their value through aria-label/title/alt.
      for(const el of Array.from(document.querySelectorAll('[aria-label],[title],img[alt]')).slice(0,450)) {
        if(!visible(el))continue;
        const label=[el.getAttribute('aria-label'),el.getAttribute('title'),el.getAttribute('alt')]
          .filter(Boolean).join(' ');
        if(label.length>90)continue;
        fullRE.lastIndex=0;
        for(const m of label.matchAll(fullRE)) addFull(m[0],pos(rect(el)),'attribute',0.95);
      }

      const SYMBOLS=[['♥','heart|hearts|copa|copas'],
                     ['♦','diamond|diamonds|ouro|ouros'],
                     ['♠','spade|spades|espada|espadas'],
                     ['♣','club|clubs|paus']];
      let glyphMasks=null;
      function normalizedBitmap(bits,width,height) {
        let minX=width,minY=height,maxX=-1,maxY=-1;
        for(let y=0;y<height;y++) for(let x=0;x<width;x++){
          if(!bits[y*width+x])continue;
          minX=Math.min(minX,x);minY=Math.min(minY,y);
          maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);
        }
        if(maxX<0)return null;
        const result=[];
        for(let y=0;y<16;y++)for(let x=0;x<16;x++){
          const px=Math.round(minX+(maxX-minX)*(x+.5)/16);
          const py=Math.round(minY+(maxY-minY)*(y+.5)/16);
          result.push(bits[py*width+px]?1:0);
        }
        return result;
      }
      function templates() {
        if(glyphMasks)return glyphMasks;
        glyphMasks={};
        try{
          const canvas=document.createElement('canvas');
          canvas.width=96;canvas.height=96;
          const ctx=canvas.getContext('2d',{willReadFrequently:true});
          if(!ctx)return glyphMasks;
          for(const symbol of ['♥','♦','♠','♣']){
            ctx.clearRect(0,0,96,96);
            ctx.fillStyle='#000';
            ctx.textAlign='center';ctx.textBaseline='middle';
            ctx.font='bold 83px Georgia, serif';
            ctx.fillText(symbol,48,49);
            const rgba=ctx.getImageData(0,0,96,96).data;
            const binary=new Uint8Array(96*96);
            for(let i=0;i<binary.length;i++)binary[i]=rgba[i*4+3]>90?1:0;
            glyphMasks[symbol]=normalizedBitmap(binary,96,96);
          }
        }catch(_){}
        return glyphMasks;
      }
      function colorFamily(el) {
        for(const candidate of [el,el?.querySelector?.('path,polygon,use'),el?.parentElement]){
          if(!candidate)continue;
          try{
            const css=getComputedStyle(candidate);
            const colors=[css.fill,css.color,candidate.getAttribute('fill')].filter(Boolean).join(' ');
            const reds=colors.match(/(?:rgb|rgba)\(\s*(\d+)[,\s]+\s*(\d+)[,\s]+\s*(\d+)/i);
            if(reds){
              const [r,g,b]=reds.slice(1).map(Number);
              if(r>g*1.20 && r>b*1.12 && r>65)return 'red';
              if(r<90 && g<90 && b<90)return 'black';
            }
          }catch(_){}
        }
        return 'unknown';
      }
      function geometricSuit(svg) {
        const shapes=Array.from(svg.querySelectorAll('path,polygon,circle,ellipse,rect'))
          .filter(s=>typeof s.isPointInFill==='function');
        if(!shapes.length || typeof DOMPoint==='undefined')return null;
        let box;
        try {
          const vb=svg.viewBox?.baseVal;
          box=vb&&vb.width>0&&vb.height>0
            ? {x:vb.x,y:vb.y,width:vb.width,height:vb.height}
            : shapes[0].getBBox();
        }catch(_){return null}
        if(!box?.width || !box?.height)return null;
        const grid=new Uint8Array(32*32);
        try {
          for(let y=0;y<32;y++)for(let x=0;x<32;x++){
            const point=new DOMPoint(box.x+(x+.5)*box.width/32,
                                     box.y+(y+.5)*box.height/32);
            grid[y*32+x]=shapes.some(s=>s.isPointInFill(point))?1:0;
          }
        }catch(_){return null}
        const bitmap=normalizedBitmap(grid,32,32);
        if(!bitmap)return null;
        const family=colorFamily(svg);
        const choices=family==='red'?['♥','♦']:
                      family==='black'?['♠','♣']:['♥','♦','♠','♣'];
        let best=null,bestScore=0,second=0;
        for(const glyph of choices){
          const ref=templates()[glyph];
          if(!ref)continue;
          let intersection=0,union=0;
          for(let i=0;i<bitmap.length;i++){
            if(bitmap[i]&&ref[i])intersection++;
            if(bitmap[i]||ref[i])union++;
          }
          const similarity=union?intersection/union:0;
          if(similarity>bestScore){second=bestScore;bestScore=similarity;best=glyph}
          else second=Math.max(second,similarity);
        }
        // Never invent a suit when shapes are not distinctive enough.
        return best && bestScore>0.56 && bestScore-second>0.09 ? best : null;
      }
      function labelToSuit(value) {
        const v=String(value||'').toLowerCase();
        for(const [symbol,re] of SYMBOLS)if(new RegExp(re,'i').test(v))return symbol;
        for(const symbol of ['♥','♦','♠','♣'])if(v.includes(symbol))return symbol;
        return null;
      }
      function localSuitFromMarkup(node) {
        let el=node?.parentElement;
        for(let level=0;el&&level<4;level++,el=el.parentElement){
          const box=rect(el);
          if(!box || box.width>130 || box.height>140)break;
          const metadata=[
            el.getAttribute?.('data-suit'), el.getAttribute?.('data-card'),
            el.getAttribute?.('class'),el.getAttribute?.('aria-label'),
            el.getAttribute?.('title')
          ].filter(Boolean).join(' ');
          const found=labelToSuit(metadata);
          if(found)return found;
        }
        return null;
      }
      const svgCache=new Map();
      function svgSuit(svg) {
        if(svgCache.has(svg))return svgCache.get(svg);
        const meta=[
          svg.getAttribute('aria-label'),svg.getAttribute('class'),svg.getAttribute('data-testid'),
          svg.querySelector('title')?.textContent,svg.querySelector('use')?.getAttribute('href'),
          svg.querySelector('use')?.getAttribute('xlink:href'),
          svg.getAttribute('id')
        ].filter(Boolean).join(' ').toLowerCase();
        let found=null;
        for(const [symbol,re] of SYMBOLS)if(new RegExp(re,'i').test(meta)){found=symbol;break}
        if(!found){
          for(const symbol of ['♥','♦','♠','♣'])if(meta.includes(symbol)){found=symbol;break}
        }
        if(!found)found=geometricSuit(svg);
        svgCache.set(svg,found);
        return found;
      }
      // Discover visible SVGs only once; expensive matching runs only for ranks
      // without a nearby text-based suit, not on every DOM node.
      const nearbySVGs=Array.from(document.querySelectorAll('svg')).filter(svg=>{
        if(!visible(svg))return false;
        const r=rect(svg);return r.width>=6 && r.height>=6 && r.width<=75 && r.height<=90;
      }).map(svg=>({svg,p:pos(rect(svg))}));
      // CSS backgrounds and <img> files sometimes name their suit even when
      // no inline <svg> exists. Only inspect small, rendered elements near a rank.
      const imageGlyphs=Array.from(document.querySelectorAll('img,[style*="background"]'))
        .filter(el=>{
          if(!visible(el))return false;
          const r=rect(el);return r.width>=6 && r.height>=6 && r.width<=75 && r.height<=90;
        }).map(el=>{
          const src=el.getAttribute('src')||el.getAttribute('alt')||
            getComputedStyle(el).backgroundImage||'';
          return {p:pos(rect(el)),suit:labelToSuit(src)};
        }).filter(entry=>entry.suit);
      const rankCandidates=[];
      for(const rank of ranks) {
        let candidate=null,dist=Infinity;
        const localSuit=localSuitFromMarkup(rank.node);
        if(localSuit)candidate={value:localSuit,confidence:0.96,source:'card-markup'};
        for(const suit of suitTexts) {
          const dx=Math.abs(suit.x-rank.x),dy=suit.y-rank.y;
          if(dx<31 && dy>-14 && dy<65) {
            const cost=dx*1.2+Math.abs(dy-18);
            if(cost<dist){dist=cost;candidate={value:suit.suit,confidence:0.97,source:'suit-text'}}
          }
        }
        if(!candidate) {
          for(const item of imageGlyphs) {
            const dx=Math.abs(item.p.x-rank.x),dy=item.p.y-rank.y;
            if(dx>43 || dy<-15 || dy>75)continue;
            const cost=dx+Math.abs(dy-18);
            if(cost<dist){dist=cost;candidate={value:item.suit,confidence:0.86,source:'image-name'}}
          }
        }
        if(!candidate) {
          for(const item of nearbySVGs) {
            const dx=Math.abs(item.p.x-rank.x),dy=item.p.y-rank.y;
            if(dx>43 || dy<-15 || dy>75)continue;
            const symbol=svgSuit(item.svg);
            if(!symbol)continue;
            const cost=dx+Math.abs(dy-18);
            if(cost<dist){dist=cost;candidate={value:symbol,confidence:0.77,source:'svg'}}
          }
        }
        const token=candidate?rank.rank+candidate.value:null;
        if(token)addFull(token,{x:rank.x,y:rank.y},candidate.source,candidate.confidence);
        rankCandidates.push({...rank,token});
      }
      // One rank can be represented by multiple nested text nodes. Keep one
      // candidate per physical slot instead of accidentally duplicating cards.
      function dedupeCards(list){
        const result=[];
        for(const p of list.sort((a,b)=>b.confidence-a.confidence)){
          if(result.some(q=>Math.abs(q.x-p.x)<16 && Math.abs(q.y-p.y)<20))continue;
          result.push(p);
        }
        return result.sort((a,b)=>a.y-b.y||a.x-b.x);
      }
      const cards=dedupeCards(whole);
      let source='not-found';
      const top=cards.filter(p=>p.y/H<0.23 && p.x/W>0.20 && p.x/W<0.83)
                     .sort((a,b)=>a.x-b.x);
      const bottom=cards.filter(p=>p.y/H>0.73 && p.x/W>0.24 && p.x/W<0.87)
                        .sort((a,b)=>a.x-b.x);
      let hero=[];
      if(top.length===2 && uniq(top.map(p=>p.token))){
        hero=top.map(p=>p.token);source='top';
      }else if(bottom.length===2 && uniq(bottom.map(p=>p.token))){
        hero=bottom.map(p=>p.token);source='bottom';
      }
      // Cluster the community cards on a common horizontal row, rather than
      // relying on their absolute y-coordinate. This tolerates different table sizes.
      const boardRanks=rankCandidates
        .filter(p=>p.y/H>0.28&&p.y/H<0.72&&p.x/W>0.12&&p.x/W<0.89)
        .sort((a,b)=>a.y-b.y||a.x-b.x);
      let row=[];
      for(const anchor of boardRanks){
        const cluster=boardRanks.filter(p=>Math.abs(p.y-anchor.y)<Math.min(38,H*0.035))
          .sort((a,b)=>a.x-b.x);
        const grouped=[];
        for(const item of cluster){
          if(!grouped.some(g=>Math.abs(g.x-item.x)<17))grouped.push(item);
        }
        if(grouped.length>row.length && grouped.length<=6)row=grouped;
      }
      // Text rendered as a full rank+suit token may not have a rank-only node.
      if(row.length<3) {
        for(const anchor of cards.filter(p=>p.y/H>0.28&&p.y/H<0.72)){
          const cluster=cards.filter(p=>p.y/H>0.28&&p.y/H<0.72 &&
            Math.abs(p.y-anchor.y)<Math.min(38,H*0.035) &&
            p.x/W>0.12 && p.x/W<0.89).sort((a,b)=>a.x-b.x);
          const distinct=[];
          for(const item of cluster)if(!distinct.some(g=>Math.abs(g.x-item.x)<17))distinct.push(item);
          if(distinct.length>row.length && distinct.length<=6)
            row=distinct.map(p=>({x:p.x,y:p.y,rank:p.token.replace(/[♠♥♦♣]/g,''),token:p.token}));
        }
      }
      const hints=row.map(p=>p.rank).slice(0,5);
      let board=[];
      if(row.length>=3&&row.length<=5 && row.every(p=>p.token) &&
         uniq(row.map(p=>p.token)))board=row.map(p=>p.token);
      const uncertain=row.length>=3 && board.length!==row.length;
      // No personal cards? Still follow the board as a spectator or folded player.
      const observing=hero.length!==2;
      const stage=board.length===5?'river':board.length===4?'turn':
                  board.length===3?'flop':hints.length>=3?'partial':
                  'preflop';
      const bodyText=(document.body.innerText||'').slice(0,17000);
      const pot=(bodyText.match(/Pote\s*(?:BRL|R\$)\s*([\d.,]+)/i)||[])[1]||'';
      const toCall=(bodyText.match(/(?:Pagar|Passar\/Pagar)\s*(?:BRL|R\$)\s*([\d.,]+)/i)||[])[1]||'';
      const playerTurn=/\bSUA VEZ\b/i.test(bodyText);
      // Only expose cards which the website itself renders face-up at showdown.
      // Never reconstruct concealed opponents' cards or inspect private app state.
      let revealed=[];
      if(board.length===5){
        const onBoard=cards.filter(p=>row.some(q=>Math.abs(q.x-p.x)<16 && Math.abs(q.y-p.y)<20));
        const other=cards.filter(p=>p.y/H>0.19 && p.y/H<0.90)
          .filter(p=>!onBoard.includes(p))
          .filter(p=>!top.includes(p)&&!bottom.includes(p));
        for(const p of other){
          const mate=other.find(q=>q!==p && Math.abs(q.x-p.x)<75 &&
            Math.abs(q.y-p.y)<35 && q.token!==p.token);
          if(!mate)continue;
          const pair=[p.token,mate.token];
          if(!revealed.some(xs=>xs.join('|')===pair.join('|') ||
            xs.join('|')===pair.slice().reverse().join('|')))revealed.push(pair);
        }
      }
      return {hero,board,hints,source,uncertain,observing,stage,pot,toCall,
              playerTurn,revealed:revealed.slice(0,5),
              diagnostics:'DOM cards='+cards.length+' ranks='+ranks.length+
                ' SVGs='+nearbySVGs.length+' imgSuits='+imageGlyphs.length+' boardSlots='+row.length+
                ' scanned='+scanned};
    })()
    """#
}
