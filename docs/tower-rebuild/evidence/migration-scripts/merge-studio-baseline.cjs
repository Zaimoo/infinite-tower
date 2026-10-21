const fs=require('fs'),cp=require('child_process'),path=require('path');
const root='C:/Projects/infinite-tower',baseline='C:/Users/msi/Documents/ChatGPT/Infinite towers/tower-rebuild-baseline-20261021/studio-script-bodies';
const files=['ServerScriptService/Combat/CombatSimulation.server.luau','StarterPlayerScripts/Rendering/EntityRenderer.client.luau','ServerScriptService/ExtractionAndSocial/RelicService.server.luau','ServerScriptService/Core/HeroNavigation.luau','ServerScriptService/Core/PlotManager.server.luau','ServerScriptService/Core/TowerTraversalSetup.server.luau'];
const out=path.join(root,'docs/tower-rebuild/evidence/part2-merge');fs.mkdirSync(out,{recursive:true});
for(const f of files){
 const key=f.replace(/^StarterPlayerScripts\//,'StarterPlayer/StarterPlayerScripts/').replaceAll('/','.').replace(/\.(server|client)\.luau$/,'.luau');
 const base=cp.execFileSync('git',['show','HEAD:src/'+f],{cwd:root,encoding:'utf8'}).replace(/\r\n/g,'\n');
 const theirs=fs.readFileSync(path.join(baseline,key),'utf8').replace(/\r\n/g,'\n');
 if(base===theirs){console.log('Original Studio/source match: '+f);continue;}
 const ours=fs.readFileSync(path.join(root,'src',f),'utf8').replace(/\r\n/g,'\n');
 const names=['ours','base','studio'].map(n=>path.join(out,key+'.'+n));
 [ours,base,theirs].forEach((s,i)=>fs.writeFileSync(names[i],s));
 const r=cp.spawnSync('git',['merge-file','-p',...names],{cwd:root,encoding:'utf8'});
 if(r.status===0){fs.writeFileSync(path.join(root,'src',f),r.stdout);console.log('Merged Studio baseline into source: '+f)}
 else {fs.writeFileSync(path.join(out,key+'.conflict'),r.stdout);console.log('CONFLICT: '+f)}
}
