#!/usr/bin/env python3
"""Check the exact JavaScript shipped inside CardScanner.swift and DOM diagnostics."""
from pathlib import Path
import re, subprocess, tempfile

def embedded(path, pattern):
    text=Path(path).read_text(encoding="utf-8")
    found=re.findall(pattern,text)
    if not found:
        raise SystemExit("No JavaScript found: "+path)
    return found

scanner=embedded("BrasaAssisten/CardScanner.swift", r'static let source = #"""([\s\S]*?)"""#')[0]
other=embedded("BrasaAssisten/PageReader.swift", r'let script = #"""([\s\S]*?)"""#')
other+=embedded("BrasaAssisten/BrasaWebView.swift", r'let watchScript = #"""([\s\S]*?)"""#')
with tempfile.TemporaryDirectory() as folder:
    for idx,code in enumerate([scanner]+other):
        script=Path(folder)/f"scanner-{idx}.js"
        script.write_text(code,encoding="utf-8")
        subprocess.run(["node","--check",str(script)],check=True)
        print(f"Embedded JavaScript {idx}: syntax verified")

    script=Path(folder)/"CardScanner.js"
    script.write_text(scanner,encoding="utf-8")
    test=Path(folder)/"fixtures.cjs"
    test.write_text(r"""
const fs=require("node:fs");
const vm=require("node:vm");
const code=fs.readFileSync(process.argv[2],"utf8");

function rectangle(x,y,w=25,h=24) {
  return {left:x,top:y,width:w,height:h,right:x+w,bottom:y+h};
}
function node(text,x,y) {
  const box=rectangle(x,y);
  return {textContent:text,box,
    parentElement:{tagName:"SPAN",getBoundingClientRect:()=>box}};
}
function svg(suit,x,y){
  const box=rectangle(x,y,17,17);
  return {name:suit,box,parentElement:null,
    getBoundingClientRect:()=>box,
    getAttribute:(k)=>k==="class" ? "poker-"+suit : null,
    querySelector:()=>null,querySelectorAll:()=>[]};
}
function scan(nodes,icons=[],body=""){
  let n=0;
  const document={
    body:{innerText:body, getBoundingClientRect:()=>rectangle(0,0,400,800)},
    createTreeWalker:()=>({nextNode:()=>nodes[n++]??null}),
    createRange:()=>{
      let point;
      return {setStart:(x)=>{point=x},setEnd:()=>{},
        selectNodeContents:(x)=>{point=x},getBoundingClientRect:()=>point.box};
    },
    querySelectorAll:(selector)=>{
      if(selector==="svg") return icons;
      return [];
    },
    createElement:()=>({width:0,height:0,getContext:()=>null})
  };
  return vm.runInNewContext(code,{
    document,window:{innerWidth:400,innerHeight:800},innerWidth:400,innerHeight:800,
    NodeFilter:{SHOW_TEXT:4},
    getComputedStyle:()=>({visibility:"visible",display:"block",opacity:"1",
                            color:"rgb(20,20,20)",fill:"rgb(20,20,20)"})
  });
}
function eq(left,right){return JSON.stringify(left)===JSON.stringify(right)}
function assert(ok,description){if(!ok)throw Error(description)}
let a=scan([node("K♠",145,65),node("K♦",210,65)]);
assert(eq(Array.from(a.hero),["K♠","K♦"]),"known hand reading");
assert(a.board.length===0,"board not made up");
let b=scan(
  [node("10♥",145,65),node("4♠",210,65),node("Q",95,395),node("4",145,395),node("6",195,395)],
  [svg("diamond",103,422),svg("diamond",153,422),svg("spade",203,422)]
);
assert(eq(Array.from(b.hero),["10♥","4♠"]),"hero top");
assert(eq(Array.from(b.board),["Q♦","4♦","6♠"]),"flop with svg suit");
assert(!b.uncertain && b.stage==="flop","flop confident");
let c=scan(
  [node("10♥",145,65),node("4♠",210,65),
   node("Q",70,395),node("4",120,395),node("6",170,395),
   node("2",220,395),node("A",270,395)],
  [svg("diamond",78,422),svg("diamond",128,422),svg("spade",178,422),
   svg("spade",228,422),svg("diamond",278,422)]
);
assert(eq(Array.from(c.board),["Q♦","4♦","6♠","2♠","A♦"]),"river with 5 svg suits");
assert(c.stage==="river","river stage");
let spectatorRiver=scan(
  [node("Q",70,395),node("4",120,395),node("6",170,395),
   node("2",220,395),node("A",270,395)],
  [svg("diamond",78,422),svg("diamond",128,422),svg("spade",178,422),
   svg("spade",228,422),svg("diamond",278,422)]
);
assert(spectatorRiver.observing===true,"spectator has no hidden cards");
assert(spectatorRiver.board.length===5 && spectatorRiver.stage==="river","spectator sees complete river");

let spectator=scan(
  [node("5",100,395),node("J",150,395),node("4",200,395)],
  [svg("club",108,422),svg("heart",158,422),svg("club",208,422)]
);
assert(spectator.observing===true,"spectator without hole");
assert(eq(Array.from(spectator.board),["5♣","J♥","4♣"]),"spectator board");
let unknown=scan([node("Q",95,395),node("4",145,395),node("6",195,395)]);
assert(unknown.uncertain===true,"unknown suits don't create invented board");
assert(unknown.board.length===0,"no fake flush");
console.log("CardScanner tests: hero, flop, river, spectator river, observer and unrecognized suits passed.");
""",encoding="utf-8")
    subprocess.run(["node",str(test),str(script)],check=True)
