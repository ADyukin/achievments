// Offline behavioral and visual verification of the actual preview renderer.
const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'index.html'),'utf8');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 const page=await browser.newPage({viewport:{width:1050,height:900}}),errors=[],requests=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('request',r=>{if(/^https?:/.test(r.url()))requests.push(r.url())});
 await page.setContent(html);await page.evaluate(()=>document.fonts.ready);
 await page.click('#reset');await page.screenshot({path:path.join(__dirname,'start.png')});
 assert.equal(await page.locator('#variant option').count(),3);
 assert.equal(await page.locator('#ring,.ring').count(),0);
 for(const variant of ['original','transfer','light']){
  await page.selectOption('#variant',variant);
  const reveal={original:2450,transfer:1590,light:1370}[variant];
  await page.evaluate(t=>motionPreview.seek(t),reveal-1);
  assert.equal(await page.locator('#number').innerText(),'2');
  await page.evaluate(t=>motionPreview.seek(t),reveal+390);
  assert.equal(await page.locator('#number').innerText(),'3');
  await page.click('#replay');await page.waitForTimeout(100);await page.click('#pause');
  const time=await page.evaluate(()=>motionPreview.state.time);await page.waitForTimeout(100);
  assert.equal(await page.evaluate(()=>motionPreview.state.time),time);
  await page.selectOption('#variant',variant==='transfer'?'light':'transfer');
  assert.equal(await page.evaluate(()=>motionPreview.state.playing),false);
  assert.equal(await page.locator('#number').innerText(),'3');
 }
 await page.selectOption('#variant','transfer');
 for(const [label,t] of [['full',590],['transfer',950],['arrival',1400],['accent',1900]]){
  await page.evaluate(t=>motionPreview.seek(t),t);
  await page.screenshot({path:path.join(__dirname,label+'.png')});
 }
 // Replays complete through requestAnimationFrame, including a slow-speed change.
 await page.click('#replay');await page.selectOption('#speed','0.5');await page.waitForTimeout(160);
 assert.ok((await page.evaluate(()=>motionPreview.state.time))<140);
 await page.selectOption('#speed','1');
 await page.waitForFunction(()=>!motionPreview.state.playing,{},{timeout:4000});
 assert.equal(await page.locator('#number').innerText(),'3');
 assert.equal(await page.locator('body').getAttribute('data-progress'),'0.000');
 assert.equal(await page.locator('.product').count(),21);
 await page.screenshot({path:path.join(__dirname,'final.png')});
 await page.click('#reset');assert.equal(await page.locator('#number').innerText(),'2');
 await page.check('#reduced');await page.click('#replay');
 assert.equal(await page.locator('#number').innerText(),'3');
 assert.equal(await page.evaluate(()=>motionPreview.state.playing),false);
 await page.uncheck('#reduced');await page.click('#replay');
 await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,value:true});document.dispatchEvent(new Event('visibilitychange'))});
 assert.equal(await page.evaluate(()=>motionPreview.state.playing),false);
 const reduced=await browser.newPage({reducedMotion:'reduce'});await reduced.setContent(html);
 assert.equal(await reduced.evaluate(()=>motionPreview.state.playing),false);
 await reduced.click('#replay');assert.equal(await reduced.locator('#number').innerText(),'3');
 await page.setViewportSize({width:375,height:812});await page.click('#reset');
 await page.evaluate(()=>motionPreview.seek(1900));
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 await page.screenshot({path:path.join(__dirname,'mobile.png')});
 assert.deepEqual(errors,[]);assert.deepEqual(requests,[]);
 console.log('PASS: three variants, reveal timing, replay, pause, speed, cancellation, hidden tab, final state, reduced motion, mobile width, offline assets, no runtime errors.');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
