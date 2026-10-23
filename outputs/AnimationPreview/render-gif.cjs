// Offline export of the actual browser renderer; this is not an iOS recording.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path');
(async()=>{
 const dir='/tmp/achievement-preview-harmony';fs.mkdirSync(dir,{recursive:true});
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 const page=await browser.newPage({viewport:{width:1050,height:900},deviceScaleFactor:1});
 await page.setContent(fs.readFileSync(path.join(__dirname,'index.html'),'utf8'));await page.evaluate(()=>document.fonts.ready);
 await page.click('#reset');
 const box=await page.locator('.phone').boundingBox();
 const clip={x:box.x,y:box.y,width:box.width,height:420};
 // 0.4s initial hold, the full 2.59s motion, then 0.8s on the result. 25fps.
 for(let i=0;i<96;i++){
  if(i>=10)await page.evaluate(t=>motionPreview.seek(t),Math.min(2590,(i-10)*40));
  await page.screenshot({path:path.join(dir,String(i).padStart(3,'0')+'.png'),clip});
 }
 await browser.close();console.log(dir);
})().catch(e=>{console.error(e);process.exit(1)});
