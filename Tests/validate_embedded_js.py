#!/usr/bin/env python3
"""Validate the EXACT JavaScript embedded in PageReader.swift, not a copy."""
from pathlib import Path
import re
import subprocess
import tempfile

source = Path("BrasaAssisten/PageReader.swift").read_text(encoding="utf-8")
scripts = re.findall(r'let script = #"""([\s\S]*?)"""#', source)
if len(scripts) < 2:
    raise SystemExit(f"Expected at least two embedded JS scripts, found {len(scripts)}.")

with tempfile.TemporaryDirectory() as folder:
    for i, script in enumerate(scripts):
        js_path = Path(folder) / f"script-{i}.js"
        js_path.write_text(script, encoding="utf-8")
        subprocess.run(["node", "--check", str(js_path)], check=True)
        print(f"JS script {i + 1}: syntax OK")

    scanner_path = Path(folder) / "scanner.js"
    scanner_path.write_text(scripts[0], encoding="utf-8")
    fixture = r"""
const fs = require("node:fs");
const vm = require("node:vm");
const js = fs.readFileSync(process.argv[1], "utf8");
function scan(textNodes, bodyText="") {
  const nodes = textNodes.map(([text,x,y])=>{
    const rect={left:x,top:y,width:25,height:34,bottom:y+34};
    return {textContent:text,rect,parentElement:{
      tagName:"SPAN",getBoundingClientRect:()=>rect
    }};
  });
  const doc = {
    body:{innerText:bodyText},
    createTreeWalker:()=>{
      let n=0;
      return {nextNode:()=>nodes[n++]||null};
    },
    createRange:()=>{
      let node=null;
      return {
        setStart:n=>{node=n},
        setEnd:()=>{},
        selectNodeContents:n=>{node=n},
        getBoundingClientRect:()=>node.rect
      };
    },
    querySelectorAll:()=>[]
  };
  const context={
    document:doc,innerWidth:400,innerHeight:800,
    NodeFilter:{SHOW_TEXT:4},
    getComputedStyle:()=>({display:"block",visibility:"visible"})
  };
  return vm.runInNewContext(js,context);
}
function same(a,b){return JSON.stringify(a)===JSON.stringify(b)}
let result=scan([],"6♦ 2♥");
if(!same(result.hero,["6♦","2♥"])||result.source!=="text-only") {
  throw Error("Text-only fallback failed: "+JSON.stringify(result));
}
result=scan([["K♠",150,70],["K♦",210,70],
             ["Q♥",95,390],["7♠",145,390],["6♥",195,390]],"");
if(!same(result.hero,["K♠","K♦"])||!same(result.board,["Q♥","7♠","6♥"])) {
  throw Error("Top+flop extraction failed: "+JSON.stringify(result));
}
result=scan([["9♦",150,70],["4♣",210,70],
             ["6♦",95,390],["3♣",145,390],["4♦",195,390],
             ["10♦",245,390],["8♦",295,390]],"");
if(!same(result.hero,["9♦","4♣"])||
   !same(result.board,["6♦","3♣","4♦","10♦","8♦"])) {
  throw Error("River extraction failed: "+JSON.stringify(result));
}
console.log("Scanner fixtures passed: text-only, flop and river.");
"""
    subprocess.run(["node", "-e", fixture, str(scanner_path)], check=True)
